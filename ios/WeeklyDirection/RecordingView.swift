import SwiftUI

/// The recording space (web: vcFocus). Nov 10 2026 (Eddie: a stream of consciousness, so show a lot of it): the words
/// in small journal type from the top of the page down, then the voice level, the elapsed time and the orb. Cancel is
/// the only other thing on screen; tapping the orb finishes.
struct RecordingView: View {
    @EnvironmentObject var recorder: Recorder
    @EnvironmentObject var router: Router
    @EnvironmentObject var store: Store
    @State private var risen = false
    @State private var demo: Timer?
    @State private var demoWords = 0

    private static let demoText = "This is a preview of live words. As you talk, what you say shows up here a few words at a time, starting at the top of the page and working its way down. It was a long day on site and I did not get to devotion until after lunch, which I think is the real pattern this week. When the morning goes, the rest of the day runs me instead of the other way around. Tonight I want to be home by six and actually put the phone down at the door"

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { recorder.cancel(); router.endRecording() }.caps(16).foregroundStyle(Theme.mu)
                Spacer()
            }
            .frame(height: 52)
            ScrollViewReader { proxy in
                ScrollView {
                    // top of the page down; once it fills the space the newest line stays in view
                    Text(recorder.liveText).font(Theme.jserif(17)).lineSpacing(7).foregroundStyle(Theme.tx)
                        .fullWidth().padding(.top, 8).padding(.bottom, 12)
                    Color.clear.frame(height: 1).id("end")
                }
                .scrollIndicators(.hidden)
                .onChange(of: recorder.liveText) { _, _ in withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("end", anchor: .bottom) } }
                .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.9), .init(color: .clear, location: 1)],
                                     startPoint: .top, endPoint: .bottom))
            }
            Wave(levels: recorder.levels).frame(height: 40).padding(.top, 14)
            Text(Fmt.mmss(floor(recorder.elapsed))).font(Theme.num(22)).monospacedDigit().foregroundStyle(Theme.tx)
                .contentTransition(.numericText()).padding(.top, 16)
            Button {
                if !store.online { router.endRecording() } else { recorder.stop(); router.endRecording() }
            } label: {
                ZStack {
                    Circle().fill(Theme.ac).frame(width: 88, height: 88)
                    RoundedRectangle(cornerRadius: Theme.r(3)).fill(Theme.onAc).frame(width: 14, height: 14)
                }
                .scaleEffect(1 + 0.08 * (recorder.levels.last ?? 0))
                .animation(.easeOut(duration: 0.12), value: recorder.levels.last)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Finish recording")
            .padding(.top, 16)
            // the orb grows out of the tab bar mic
            .scaleEffect(risen ? 1 : 0.68).offset(y: risen ? 0 : 60)
            .padding(.bottom, 34)
        }
        .padding(.horizontal, 24)
        .background(Theme.bg.ignoresSafeArea())
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) { risen = true }
            if !store.online { startDemo(); return }
            Task { if !(await recorder.start()) { router.endRecording() } }
        }
        .onDisappear { demo?.invalidate(); if recorder.state == .rec { recorder.cancel() } else { recorder.abortIfStarting() } }
        // stopped by the 10 minute limit: close; the status line says what happened next
        .onChange(of: recorder.state) { old, new in if old == .rec && new == .idle { router.endRecording() } }
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
