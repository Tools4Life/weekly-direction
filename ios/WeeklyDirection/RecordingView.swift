import SwiftUI

/// The mic on the Journal view: tap to record a reflection. A status line above it shows the last result and
/// anything still waiting to upload.
struct MicDock: View {
    @EnvironmentObject var recorder: Recorder
    @EnvironmentObject var router: Router

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                if recorder.state == .busy { Text("Transcribing…") }
                else if let m = recorder.message { Text(m) }
                if recorder.pending > 0, recorder.state == .idle {
                    Text("\(recorder.pending) waiting ·")
                    Button("Retry") { Task { await recorder.flush() } }.foregroundStyle(Theme.ac)
                }
            }
            .font(Theme.ui(15)).foregroundStyle(Theme.mu).frame(height: 20)
            Button { router.startRecording() } label: {
                ZStack {
                    Circle().stroke(Theme.ac.opacity(0.25), lineWidth: 1).frame(width: 100, height: 100)
                    Circle().fill(Theme.ac.opacity(0.16)).frame(width: 96, height: 96)
                    Circle().fill(Theme.ac).frame(width: 84, height: 84)
                    Image(systemName: "mic").font(.system(size: 28, weight: .regular)).foregroundStyle(Theme.onAc)
                }
            }
            .buttonStyle(.plain)
            .disabled(recorder.state != .idle)
            .opacity(recorder.state == .busy ? 0.5 : 1)
            .accessibilityLabel("Speak a reflection")
        }
    }
}

/// The recording space (web: vcFocus): Cancel and the timer, the words as you say them, the voice level as a
/// scrolling bar waveform, and the orb with a stop square. Tap the orb to finish.
struct RecordingView: View {
    @EnvironmentObject var recorder: Recorder
    @EnvironmentObject var router: Router
    @EnvironmentObject var store: Store
    @State private var risen = false
    @State private var demo: Timer?
    @State private var demoWords = 0

    private static let demoText = "This is a preview of live words. As you talk, what you say shows up here a few words at a time"

    var body: some View {
        let busy = recorder.state == .busy
        VStack(spacing: 0) {
            ZStack {
                HStack {
                    Button("Cancel") { recorder.cancel(); router.cover = nil }.font(Theme.ui(18)).foregroundStyle(Theme.mu)
                    Spacer()
                }
                Text(Fmt.mmss(floor(recorder.elapsed))).font(Theme.label(17)).tracking(1.5).monospacedDigit().foregroundStyle(Theme.mu)
            }
            .frame(height: 52)
            ScrollViewReader { proxy in
                ScrollView {
                    Text(recorder.liveText).font(Theme.serif(26)).lineSpacing(9).foregroundStyle(Theme.tx)
                        .fullWidth().padding(.top, 20).id("end")
                }
                .defaultScrollAnchor(.bottom)
                .onChange(of: recorder.liveText) { _, _ in proxy.scrollTo("end", anchor: .bottom) }
            }
            Wave(levels: recorder.levels).frame(height: 60).padding(.top, 26)
            Button {
                if store.isMock { router.cover = nil } else { recorder.stop() }
            } label: {
                ZStack {
                    Circle().fill(Theme.ac).frame(width: 105, height: 105)
                    RoundedRectangle(cornerRadius: 3).fill(Theme.onAc).frame(width: 14, height: 14)
                }
                .scaleEffect(1 + 0.08 * (recorder.levels.last ?? 0))
                .animation(.easeOut(duration: 0.12), value: recorder.levels.last)
            }
            .buttonStyle(.plain).disabled(busy)
            .accessibilityLabel("Finish recording")
            .padding(.top, 38)
            .offset(y: risen ? 0 : 60)
            Text(busy ? "Saving…" : "Tap to finish").font(Theme.ui(15)).foregroundStyle(Theme.mu2).padding(.top, 16).padding(.bottom, 30)
        }
        .padding(.horizontal, 24)
        .background(Theme.bg.ignoresSafeArea())
        .opacity(risen ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { risen = true }
            if store.isMock { startDemo(); return }
            Task { if !(await recorder.start()) { router.cover = nil } }
        }
        .onDisappear { demo?.invalidate(); if recorder.state == .rec { recorder.cancel() } }
        // sent (or queued): back to the journal, where the status line says what happened
        .onChange(of: recorder.state) { old, new in if old != .idle && new == .idle { router.cover = nil } }
    }

    /// sample words and a moving level for simulator screenshots; nothing is recorded
    private func startDemo() {
        let words = Self.demoText.split(separator: " ")
        demoWords = words.count
        recorder.elapsed = 4
        recorder.liveText = words.joined(separator: " ")
        var ph = 0.0
        recorder.levels = recorder.levels.indices.map { i in
            ph = Double(i) * 0.19
            return max(0, 0.35 + 0.3 * sin(ph) + 0.25 * sin(ph * 2.7))
        }
    }
}

/// the last ~2 s of voice level as rounded bars: newest on the right, older ones fading
private struct Wave: View {
    let levels: [Double]
    var body: some View {
        Canvas { ctx, size in
            let n = levels.count, bw = size.width / CGFloat(n), gap = max(1.5, bw * 0.38)
            for (i, v) in levels.enumerated() {
                let h = max(3, min(size.height, CGFloat(v) * size.height * 1.15))
                let r = CGRect(x: CGFloat(i) * bw + gap / 2, y: (size.height - h) / 2, width: bw - gap, height: h)
                let alpha = 0.25 + 0.75 * pow(Double(i) / Double(n - 1), 1.4)
                ctx.fill(Path(roundedRect: r, cornerRadius: min(r.width, r.height) / 2), with: .color(Theme.ac.opacity(alpha)))
            }
        }
        .accessibilityHidden(true)
    }
}
