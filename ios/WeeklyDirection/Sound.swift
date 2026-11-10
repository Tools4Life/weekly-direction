import AVFoundation

/// The web app's soft tones (index.html: snd), rebuilt as short sine notes: a rising note when a timer starts, a two-note
/// chime when a habit is finished, and four rising notes when the day is kept or a week closes. They follow the Sounds
/// setting, stay silent when the phone is on silent (ambient audio), and never play while the microphone is open.
@MainActor
enum Sound {
    enum Kind { case start, done, day }
    /// the microphone is open: no tones (they would end up in the recording and fight the recording session)
    static var hold = false
    private static var players: [Kind: AVAudioPlayer] = [:]
    private static let rate = 44_100.0

    static func play(_ kind: Kind, _ settings: Settings) {
        guard settings.sounds, !hold else { return }
        if players[kind] == nil, let p = try? AVAudioPlayer(data: wav(kind)) { p.prepareToPlay(); players[kind] = p }
        guard let p = players[kind] else { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        p.currentTime = 0
        p.play()
    }

    /// (frequency, starts at, lasts, loudness): the web's tone(): a 12 ms rise, then an exponential fall to silence
    private static func notes(_ kind: Kind) -> [(Double, Double, Double, Double)] {
        switch kind {
        case .start: return []                                                     // a glide, drawn separately
        case .done: return [(659.25, 0, 0.5, 0.8), (987.77, 0.07, 0.6, 0.5)]        // E5 + B5
        case .day: return [(523.25, 0, 0.7, 0.6), (659.25, 0.11, 0.7, 0.6), (783.99, 0.22, 0.9, 0.6), (1046.5, 0.33, 1.2, 0.4)]   // C E G C
        }
    }

    private static func wav(_ kind: Kind) -> Data {
        let length = kind == .start ? 0.42 : (notes(kind).map { $0.1 + $0.2 }.max() ?? 0.5) + 0.06
        var s = [Double](repeating: 0, count: Int(length * rate))
        if kind == .start {
            // 330 Hz gliding up to 495 Hz over 0.16 s, fading by 0.32 s
            var phase = 0.0
            for i in s.indices {
                let t = Double(i) / rate
                let f = 330 * pow(495.0 / 330.0, min(1, t / 0.16))
                phase += 2 * .pi * f / rate
                let env = t < 0.02 ? 0.7 * t / 0.02 : 0.7 * pow(0.0001 / 0.7, (t - 0.02) / 0.30)
                s[i] += sin(phase) * (t > 0.34 ? 0 : env)
            }
        }
        for (f, at, dur, vol) in notes(kind) {
            let a = Int(at * rate), n = Int((dur + 0.02) * rate)
            for j in 0..<n where a + j < s.count {
                let t = Double(j) / rate
                let env = t < 0.012 ? vol * t / 0.012 : vol * pow(0.0001 / vol, (t - 0.012) / (dur - 0.012))
                s[a + j] += sin(2 * .pi * f * t) * env
            }
        }
        // quiet on purpose: these sit under whatever else the phone is playing
        let pcm = s.map { Int16(max(-1, min(1, $0 * 0.34)) * 32767) }
        var d = Data()
        func put<T: FixedWidthInteger>(_ v: T) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        d.append(contentsOf: Array("RIFF".utf8)); put(UInt32(36 + pcm.count * 2)); d.append(contentsOf: Array("WAVEfmt ".utf8))
        put(UInt32(16)); put(UInt16(1)); put(UInt16(1)); put(UInt32(rate)); put(UInt32(rate * 2)); put(UInt16(2)); put(UInt16(16))
        d.append(contentsOf: Array("data".utf8)); put(UInt32(pcm.count * 2))
        for v in pcm { put(v) }
        return d
    }
}
