import Foundation
import AVFoundation
import Speech
import Network
import SwiftUI

/// Voice reflections (web: vcStart / vcStop / vcSend / vcFlush). The saved entry always comes from the full recording,
/// sent to the `transcribe` Cloud Function; live words on screen are display only (on-device speech recognition).
/// Recordings wait on the phone when the upload fails and are retried when the network returns.
@MainActor
final class Recorder: NSObject, ObservableObject {
    /// recording or not; sending a finished recording is separate (`sending`), so the screen closes the moment you
    /// finish and you can start the next thought while the last one is still being transcribed
    enum State { case idle, rec }
    static let voiceURL = URL(string: "https://us-central1-ops-hub-9bebc.cloudfunctions.net/transcribe")!
    static let maxSeconds: TimeInterval = 10 * 60

    @Published var state: State = .idle {
        didSet {
            Sound.hold = state == .rec
            // the phone must not auto-lock in the middle of a long thought: locking suspends the app and cuts the recording
            if (state == .rec) != (oldValue == .rec) { UIApplication.shared.isIdleTimerDisabled = state == .rec }
        }
    }
    @Published var message: String?
    @Published var pending = 0
    @Published var elapsed: TimeInterval = 0
    /// last ~2 s of voice level, newest last
    @Published var levels = [Double](repeating: 0, count: 56)
    @Published var liveText = ""
    /// a finished recording is being transcribed
    @Published var sending = false
    /// the on-device words of the recording being transcribed: shown as a placeholder until the real text arrives
    @Published var draftText: String?
    /// Recordings still on the phone (offline, or the server could not be reached), oldest first. Each shows in the
    /// journal as a placeholder entry until its transcript arrives; `text` is what the phone itself heard, if anything.
    struct Waiting: Identifiable, Equatable { let at: Date; let seconds: Int; let text: String?; var id: Double { at.timeIntervalSince1970 } }
    @Published var waiting: [Waiting] = []
    /// the same for prayers spoken on the Prayer tab: they wait for the prayer log, never the journal
    @Published var waitingPrayers: [Waiting] = []
    /// the recording in progress is a prayer (started from the Prayer tab)
    private var prayer = false

    weak var store: Store?
    private var recorder: AVAudioRecorder?
    private var startedAt = Date()
    private var meter: Timer?
    private var cancelled = false
    private var messageToken = 0
    private let monitor = NWPathMonitor()
    private var online = true

    // live words
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var tapped = false
    /// audio session changes block for a moment: they run here, in order, never on the main thread
    private let audioQ = DispatchQueue(label: "wd.audio")
    private struct Rec: @unchecked Sendable { let r: AVAudioRecorder?; let t0: Date }

    private var dir: URL {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("voice", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    func attach(_ store: Store) {
        self.store = store
        guard !store.isMock else { return }
        refreshPending()
        monitor.pathUpdateHandler = { [weak self] p in
            Task { @MainActor in
                guard let self else { return }
                let was = self.online
                self.online = p.status == .satisfied
                if self.online && !was { try? await Task.sleep(nanoseconds: 1_500_000_000); await self.flush() }
            }
        }
        monitor.start(queue: DispatchQueue(label: "wd.net"))
    }

    private func say(_ m: String?) {
        message = m
        messageToken += 1
        guard let m else { return }
        let token = messageToken, quick = ["Added to this week", "Added to your prayers", "Too short", "Nothing heard"].contains(m)
        DispatchQueue.main.asyncAfter(deadline: .now() + (quick ? 1.8 : 3.5)) { [weak self] in
            if self?.messageToken == token { self?.message = nil }
        }
    }

    // MARK: record

    /// returns false when the mic is blocked or recording can't start
    func start(prayer: Bool = false) async -> Bool {
        guard state == .idle, !starting else { return false }
        self.prayer = prayer
        starting = true; abortStart = false
        defer { starting = false }
        say(nil)
        guard await AVAudioApplication.requestRecordPermission() else { say("Mic blocked: allow it in iPhone Settings"); return false }
        // the knock and the tone come first, on the tap, before the microphone opens (so the tone is not in the recording)
        Haptic.micOn()
        let url0 = dir
        let made: Rec = await withCheckedContinuation { c in
            audioQ.async {
                do {
                    let s = AVAudioSession.sharedInstance()
                    try s.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
                    // iOS mutes haptics while a recording session is active unless asked not to
                    try? s.setAllowHapticsAndSystemSoundsDuringRecording(true)
                    try s.setActive(true)
                    let t0 = Date()
                    let url = url0.appendingPathComponent("rec-\(Int(t0.timeIntervalSince1970 * 1000)).m4a")
                    let r = try AVAudioRecorder(url: url, settings: [
                        AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 16000, AVNumberOfChannelsKey: 1,
                        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                    ])
                    r.isMeteringEnabled = true
                    c.resume(returning: Rec(r: r.record() ? r : nil, t0: t0))
                } catch { c.resume(returning: Rec(r: nil, t0: Date())) }
            }
        }
        // cancelled or started twice while the microphone was opening
        guard state == .idle, !abortStart, let r = made.r else {
            made.r?.stop(); if let u = made.r?.url { try? FileManager.default.removeItem(at: u) }
            if abortStart { audioQ.async { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) } }
            if made.r == nil { say("This phone can’t record audio right now") }
            return false
        }
        recorder = r
        startedAt = made.t0
        cancelled = false
        elapsed = 0
        liveText = ""
        levels = [Double](repeating: 0, count: levels.count)
        state = .rec
        meter = Timer.scheduledTimer(withTimeInterval: 0.035, repeats: true) { [weak self] _ in Task { @MainActor in self?.tick() } }
        // live words start once the screen has finished opening, so the animation never waits on the speech engine
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            if self?.state == .rec { self?.startLive() }
        }
        return true
    }

    private func tick() {
        guard state == .rec, let r = recorder else { return }
        r.updateMeters()
        // dB (-60…0) → 0…1, close to the web's rms × 5.5
        let lv = max(0, min(1, (Double(r.averagePower(forChannel: 0)) + 50) / 42))
        levels.removeFirst()
        levels.append(lv)
        elapsed = Date().timeIntervalSince(startedAt)
        if elapsed >= Self.maxSeconds { stop() }
    }

    func cancel() {
        cancelled = true
        stop()
    }

    /// the microphone is still opening (permission, audio session): a stop or cancel now must end it, or it would go on
    /// recording with no screen
    private var starting = false
    private var abortStart = false
    func abortIfStarting() { if starting, state == .idle { abortStart = true } }

    // MARK: dictation into a screen (plan, review)

    /// the recording in progress belongs to a screen, not the journal
    private(set) var dictating = false

    func startDictation() async -> Bool {
        guard state == .idle, !dictating else { return false }
        dictating = true
        let ok = await start()
        if !ok { dictating = false }
        return ok
    }

    /// stops the recording and returns its text; nothing is queued or written. The transcript comes from the server;
    /// if that fails, the words recognised on the phone are returned instead.
    func finishDictation(cancel: Bool = false) async -> String? {
        guard dictating else { return nil }
        guard state == .rec, let r = recorder else { abortIfStarting(); dictating = false; return nil }
        meter?.invalidate(); meter = nil
        stopLive()
        let dur = Date().timeIntervalSince(startedAt), url = r.url
        r.stop()
        recorder = nil
        dictating = false
        audioQ.async { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
        let heard = liveText.trimmingCharacters(in: .whitespacesAndNewlines)
        state = .idle
        defer { try? FileManager.default.removeItem(at: url) }
        if cancel { Haptic.tick(); return nil }
        Haptic.micOff()
        if dur < 1.5 { say("Too short"); return nil }
        guard let store, store.online else { return heard.isEmpty ? nil : heard }
        do {
            var req = URLRequest(url: Self.voiceURL)
            req.httpMethod = "POST"
            req.setValue("Bearer " + (try await store.token()), forHTTPHeaderField: "Authorization")
            req.setValue("audio/mp4", forHTTPHeaderField: "Content-Type")
            req.setValue(String(Int(dur.rounded())), forHTTPHeaderField: "X-Duration")
            let (data, resp) = try await URLSession.shared.upload(for: req, fromFile: url)
            guard (200..<300).contains((resp as? HTTPURLResponse)?.statusCode ?? 0) else { throw URLError(.badServerResponse) }
            let text = (((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["text"] as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { return text }
        } catch {}
        if heard.isEmpty { say("Couldn’t reach the voice server"); return nil }
        return heard
    }

    func stop() {
        // a dictation is ended by its own screen (`finishDictation`), never queued for the journal
        guard !dictating else { return }
        guard state == .rec, let r = recorder else { abortIfStarting(); return }
        meter?.invalidate(); meter = nil
        stopLive()
        let dur = Date().timeIntervalSince(startedAt), url = r.url
        r.stop()
        recorder = nil
        audioQ.async { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
        if cancelled { Haptic.tick() } else { Haptic.micOff() }
        let heard = liveText.trimmingCharacters(in: .whitespacesAndNewlines)
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        if cancelled { try? FileManager.default.removeItem(at: url); state = .idle; say(nil); return }
        if dur < 1.5 || size == 0 { try? FileManager.default.removeItem(at: url); state = .idle; say("Too short"); return }
        // queue it under its start time and length, then send; it stays on the phone until the server has it
        let at = Int(startedAt.timeIntervalSince1970 * 1000)
        // a prayer is marked in the file name, so it still goes to the prayer log if it is sent hours later
        let queued = dir.appendingPathComponent("v\(at)_\(Int(dur.rounded()))\(prayer ? "_p" : "").m4a")
        try? FileManager.default.moveItem(at: url, to: queued)
        // what the phone heard, kept beside the recording: the placeholder shown until the real transcript arrives
        if !heard.isEmpty { try? heard.write(to: queued.deletingPathExtension().appendingPathExtension("txt"), atomically: true, encoding: .utf8) }
        // the screen closes now; transcription carries on behind it
        state = .idle
        if !cancelled, !prayer { draftText = heard.isEmpty ? nil : heard }
        refreshPending()
        // offline: it stays on the phone and is sent by itself when the network is back
        if !online { say("Offline · saved, will be written down later"); return }
        Task { await drain() }
    }

    // MARK: send and queue

    private func queue() -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.lastPathComponent.hasPrefix("v") && $0.pathExtension == "m4a" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
    func refreshPending() {
        let q = queue()
        pending = q.count
        func rows(_ fs: [URL]) -> [Waiting] {
            fs.map { f in
                let name = f.deletingPathExtension().lastPathComponent.dropFirst().split(separator: "_")
                let text = (try? String(contentsOf: f.deletingPathExtension().appendingPathExtension("txt"), encoding: .utf8))?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return Waiting(at: Date(timeIntervalSince1970: (Double(name.first ?? "") ?? 0) / 1000), seconds: Int(name.count > 1 ? name[1] : "0") ?? 0,
                               text: text?.isEmpty == false ? text : nil)
            }
        }
        waiting = rows(q.filter { !Self.isPrayer($0) })
        waitingPrayers = rows(q.filter { Self.isPrayer($0) })
    }
    static func isPrayer(_ f: URL) -> Bool { f.deletingPathExtension().lastPathComponent.hasSuffix("_p") }

    private func send(_ file: URL) async -> Bool {
        var ok = false
        let name = file.deletingPathExtension().lastPathComponent.dropFirst().split(separator: "_")
        let at = Double(name.first ?? "") ?? Date().timeIntervalSince1970 * 1000
        do {
            guard let store else { throw URLError(.cancelled) }
            let isPrayer = Self.isPrayer(file)
            // with no week in progress there is nowhere to write a thought: it stays on the phone, unsent, until a week is
            // sealed. A prayer belongs to no week and is sent regardless.
            guard isPrayer || store.activeWeek != nil else { say("No week in progress · saved"); refreshPending(); return false }
            let token = try await store.token()
            var req = URLRequest(url: Self.voiceURL)
            req.httpMethod = "POST"
            req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
            req.setValue("audio/mp4", forHTTPHeaderField: "Content-Type")
            req.setValue(String(name.count > 1 ? name[1] : "0"), forHTTPHeaderField: "X-Duration")
            let (data, resp) = try await URLSession.shared.upload(for: req, fromFile: file)
            let j = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(code) else { throw VoiceError(status: code, detail: "\(j["detail"] ?? j["error"] ?? "")") }
            let text = (j["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty, isPrayer {
                // the recording is only deleted once the log has the words
                do { try await store.addPrayerLog(at: at, text: text) }
                catch { say("Couldn’t save the prayer · kept on the phone"); refreshPending(); return false }
            } else if !text.isEmpty {
                // the week was closed while this was uploading: keep the recording rather than lose the words
                guard let w = store.activeWeek else { say("No week in progress · saved"); refreshPending(); return false }
                if let t = Journal.appended(w.liveRefl, at: Date(timeIntervalSince1970: at / 1000), text: text) { store.patchWeek(w, ["liveRefl": t]) }
            }
            try? FileManager.default.removeItem(at: file)
            try? FileManager.default.removeItem(at: file.deletingPathExtension().appendingPathExtension("txt"))
            ok = true
            say(text.isEmpty ? "Nothing heard" : isPrayer ? "Added to your prayers" : "Added to this week")
            if !text.isEmpty { Haptic.success() }
        } catch let e as VoiceError {
            let d = e.detail
            say(e.status == 404 ? "Voice server not reachable · saved" : e.status == 429 ? "Daily limit reached · saved"
                : e.status == 401 ? "Sign in again · saved"
                : d.range(of: "insufficient_quota|billing", options: [.regularExpression, .caseInsensitive]) != nil ? "OpenAI has no credit · saved"
                : "Failed \(e.status): \(String(d.prefix(60)))")
        } catch {
            say(online ? "Voice server not reachable · saved" : "Offline · saved for later")
        }
        refreshPending()
        return ok
    }

    /// send what is waiting, oldest first, one at a time; a recording finished meanwhile is picked up by the same loop
    private func drain() async {
        guard !sending else { return }
        sending = true
        defer { sending = false; draftText = nil }
        guard store?.online == true else { return }
        var failed = Set<String>()
        // In practice mode only recordings made during practice are sent (into the sample week). Real ones still
        // waiting on the phone are left alone until practice is over.
        let since = store?.practice == true ? store?.practiceSince : nil
        while let f = queue().first(where: { !failed.contains($0.lastPathComponent) && (since == nil || Self.madeAt($0) >= since!) }) {
            if !(await send(f)) { failed.insert(f.lastPathComponent); break }
        }
    }

    var isOnline: Bool { online }

    private static func madeAt(_ f: URL) -> Date {
        let ms = Double(f.deletingPathExtension().lastPathComponent.dropFirst().split(separator: "_").first ?? "") ?? 0
        return Date(timeIntervalSince1970: ms / 1000)
    }

    /// leaving practice mode: recordings made during it that never got sent are deleted, so they can't reach the real journal
    func dropPractice(since: Date?) {
        guard let since else { return }
        for f in queue() where Self.madeAt(f) >= since {
            try? FileManager.default.removeItem(at: f)
            try? FileManager.default.removeItem(at: f.deletingPathExtension().appendingPathExtension("txt"))
        }
        refreshPending()
    }

    /// retry everything still waiting (network back, app opened, Retry tapped)
    func flush() async {
        guard online else { return }
        await drain()
    }

    private struct VoiceError: Error { let status: Int; let detail: String }

    // MARK: live words (display only)

    private func startLive() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                guard let self, status == .authorized, self.state == .rec else { return }
                self.beginRecognition()
            }
        }
    }

    private func beginRecognition() {
        guard let rec = SFSpeechRecognizer(), rec.isAvailable else { return }
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if rec.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
        let input = engine.inputNode, format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { return }
        Self.tap(input, format, req)
        tapped = true
        engine.prepare()
        do { try engine.start() } catch { stopLive(); return }
        request = req
        task = rec.recognitionTask(with: req) { [weak self] result, _ in
            guard let text = result?.bestTranscription.formattedString else { return }
            Task { @MainActor in if self?.state == .rec { self?.liveText = text } }
        }
    }

    /// the tap runs on the audio thread, so it is installed from outside the main actor
    nonisolated private static func tap(_ input: AVAudioInputNode, _ format: AVAudioFormat, _ req: SFSpeechAudioBufferRecognitionRequest) {
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { buf, _ in req.append(buf) }
    }

    private func stopLive() {
        if engine.isRunning { engine.stop() }
        if tapped { engine.inputNode.removeTap(onBus: 0); tapped = false }
        request?.endAudio()
        task?.cancel()
        request = nil; task = nil
    }
}
