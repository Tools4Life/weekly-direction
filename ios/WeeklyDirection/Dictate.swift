import SwiftUI

/// Speak into a screen (Eddie, Nov 10 2026): "Reflect on this week" on the review, "Plan next week" on the plan.
/// The recording is transcribed by the same `transcribe` function as a journal thought, but the text is handed to the
/// screen instead of joining the journal, and nothing is saved until that screen saves it.
struct DictateCard: View {
    @EnvironmentObject var recorder: Recorder
    let title: String
    /// opened from a mic button: start listening straight away
    var autoStart = false
    /// what to do with the spoken words (tidy them, fill the fields); the card shows it is working until this returns
    let onText: (String) async -> String?

    enum Phase { case idle, rec, working }
    @State private var phase: Phase = .idle
    @State private var note: String?
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch phase {
            case .idle:
                Button { Task { await begin() } } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "mic").font(.system(size: 19, weight: .medium)).foregroundStyle(Theme.onAc)
                            .frame(width: 46, height: 46).background(Theme.ac, in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(title).caps(16).foregroundStyle(Theme.tx)
                            // no standing explanation (Eddie: minimal); only what just happened, when something did
                            if let note { Text(note).font(Theme.ui(14)).foregroundStyle(Theme.mu).multilineTextAlignment(.leading) }
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("dictate")
            case .rec:
                HStack(spacing: 10) {
                    Circle().fill(Theme.ac).frame(width: 10, height: 10).opacity(pulse ? 0.35 : 1)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
                    Text(Fmt.mmss(recorder.elapsed)).font(Theme.num(20)).monospacedDigit().foregroundStyle(Theme.tx)
                    Spacer()
                    Button("Cancel") { Task { _ = await recorder.finishDictation(cancel: true); phase = .idle } }
                        .caps(14).foregroundStyle(Theme.mu).buttonStyle(.plain)
                }
                Text(recorder.liveText.isEmpty ? "Listening…" : recorder.liveText)
                    .font(Theme.jserif(15)).lineSpacing(4).foregroundStyle(Theme.mu).lineLimit(10, reservesSpace: false)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button { Task { await finish() } } label: {
                    Text("Done").caps(16).foregroundStyle(Theme.onAc).frame(maxWidth: .infinity).frame(height: 46)
                        .background(Theme.ac, in: RoundedRectangle(cornerRadius: Theme.r(13), style: .continuous))
                }
                .buttonStyle(.plain)
            case .working:
                HStack(spacing: 12) {
                    ProgressView().tint(Theme.ac)
                    Text("Writing down what you said…").font(Theme.ui(15)).foregroundStyle(Theme.mu)
                }
                .frame(height: 46)
            }
        }
        // at rest it is just the mic and its name; the box appears only while it is listening or working
        .padding(phase == .idle ? 0 : 16).fullWidth()
        .background(phase == .idle ? Color.clear : Theme.card, in: RoundedRectangle(cornerRadius: Theme.r(18), style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.r(18), style: .continuous).stroke(phase == .idle ? Color.clear : Theme.acDim, lineWidth: 1))
        .animation(.easeOut(duration: 0.18), value: phase)
        .onChange(of: recorder.elapsed) { _, e in if phase == .rec, e >= Recorder.maxSeconds - 1 { Task { await finish() } } }
        .onAppear {
            guard autoStart, phase == .idle else { return }
            // after the sheet has finished rising
            Task { try? await Task.sleep(nanoseconds: 450_000_000); if phase == .idle { await begin() } }
        }
        .onDisappear { if phase == .rec { Task { _ = await recorder.finishDictation(cancel: true) } } }
    }

    private func begin() async {
        note = nil
        guard await recorder.startDictation() else { note = recorder.message ?? "The microphone is busy."; return }
        phase = .rec; pulse = true
    }

    private func finish() async {
        guard phase == .rec else { return }
        phase = .working; pulse = false
        guard let text = await recorder.finishDictation() else { note = recorder.message ?? "Nothing heard."; phase = .idle; return }
        note = await onText(text)
        phase = .idle
    }
}

/// The `tidy` Cloud Function: spoken words cleaned up (fillers, repeats, false starts), never summarized.
/// Returns nil when it can't be reached, so the caller keeps the words as spoken.
enum Tidy {
    static let url = URL(string: "https://us-central1-ops-hub-9bebc.cloudfunctions.net/tidy")!

    @MainActor private static func call(_ store: Store, _ body: [String: Any]) async -> [String: Any]? {
        guard !store.isMock else { return nil }
        do {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.timeoutInterval = 45
            req.setValue("Bearer " + (try await store.token()), forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        } catch { return nil }
    }

    /// mode "vision" (a plan) or "reflection" (a review): the same clean-up, told what the note is
    @MainActor static func clean(_ store: Store, _ text: String, mode: String) async -> String? {
        let t = (await call(store, ["mode": mode, "text": text])?["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return t?.isEmpty == false ? t : nil
    }

    /// a proposed rating per question (1 better, 0 same, -1 worse, nil not spoken to) with the sentence it rests on;
    /// nil when the function can't be reached. He confirms or changes each one before anything is saved.
    @MainActor static func rate(_ store: Store, _ text: String, _ questions: [String]) async -> [(v: Int?, quote: String)]? {
        guard !questions.isEmpty, let j = await call(store, ["mode": "rate", "text": text, "questions": questions]),
              let a = j["ratings"] as? [[String: Any]], a.count == questions.count else { return nil }
        return a.map { (intOf($0["v"]).flatMap { (-1...1).contains($0) ? $0 : nil }, $0["quote"] as? String ?? "") }
    }

    static let asSpoken = "Added as spoken."
}
