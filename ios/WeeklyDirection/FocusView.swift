import SwiftUI
import UIKit

/// Full-screen countdown for a timed habit (web: openFocus / fcDraw). The start time lives on the week (`runs`), so it
/// keeps running if the screen is closed; when it runs out the habit is completed.
struct FocusView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let weekId: String
    let habitId: String
    let day: String
    @State private var seen = false
    @State private var fin = false
    @State private var confirmStop = false
    @State private var opened = Now.date
    @State private var pull: CGFloat = 0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            content(now: Now.date)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg.ignoresSafeArea())
        // swipe down to leave: the page follows the finger and the timer keeps running
        .offset(y: pull)
        .gesture(DragGesture(minimumDistance: 12)
            .onChanged { g in if g.translation.height > 0, abs(g.translation.height) > abs(g.translation.width) { pull = g.translation.height } }
            .onEnded { g in
                if g.translation.height > 110 || g.predictedEndTranslation.height > 320 { Haptic.tick(); router.cover = nil }
                else { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { pull = 0 } }
            })
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    @ViewBuilder private func content(now: Date) -> some View {
        let w = store.week(weekId), c = w?.commitments.first { $0.id == habitId }
        if let w, let c, let m = c.min {
            let start = w.run(day, c.id)
            let left = start.map { max(0, ($0 + Double(m) * 60000 - now.timeIntervalSince1970 * 1000) / 1000) } ?? Double(m * 60)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    HStack(spacing: 8) {
                        Ico(name: c.icon, size: 15).foregroundStyle(Theme.ac)
                        Eyebrow(text: "Timer · \(m) min", color: Theme.ac)
                    }
                    Spacer()
                    Button { router.cover = nil } label: {
                        Image(systemName: "xmark").font(.system(size: 20, weight: .medium)).foregroundStyle(Theme.mu).frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Close")
                }
                .padding(.trailing, -12)
                Text(c.name).title(34).foregroundStyle(Theme.tx).lineLimit(2).minimumScaleFactor(0.7).padding(.top, 2).wordLand()
                Spacer(minLength: 20)
                Ring(fraction: min(1, left / Double(m * 60)), done: left <= 0) {
                    VStack(spacing: 6) {
                        Text(left > 0 ? Fmt.mmss(left) : "Done")
                            .font(Theme.num(58)).monospacedDigit().foregroundStyle(left > 0 ? Theme.tx : Theme.ac)
                            .contentTransition(.numericText(countsDown: true))
                        Eyebrow(text: left > 0 ? (start.map { "ends " + Fmt.clock(Date(timeIntervalSince1970: ($0 + Double(m) * 60000) / 1000)) } ?? "left") : "kept",
                                color: Theme.mu2)
                    }
                }
                .frame(maxWidth: 300).frame(maxWidth: .infinity)
                .rise(0)
                Spacer(minLength: 20)
                // nothing to explain while it runs (Eddie, Nov 10 2026); one line only when it has finished
                Text(fin ? "\(c.name) is done for today." : " ")
                    .font(Theme.ui(15)).foregroundStyle(Theme.mu).frame(maxWidth: .infinity).padding(.bottom, 18)
                Button { confirmStop = true } label: {
                    // the app's quiet outlined row (same as Delete entries): stopping is possible, not invited
                    Text("Stop timer").caps(16).foregroundStyle(Theme.mu)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(Theme.card2, in: RoundedRectangle(cornerRadius: Theme.r(13), style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Theme.r(13), style: .continuous).stroke(Theme.line, lineWidth: 1))
                }
                .buttonStyle(.plain).opacity(fin ? 0 : 1).disabled(fin).padding(.bottom, 12)
            }
            .padding(.horizontal, 24).padding(.top, 8)
            .onChange(of: start != nil, initial: true) { _, has in
                // the start time can take a moment to sync back; only close if a run we already saw was stopped elsewhere
                if has { seen = true } else if seen || Now.date.timeIntervalSince(opened) > 4 { router.cover = nil }
            }
            .onChange(of: left <= 0 && start != nil, initial: true) { _, done in if done { finish(w, c) } }
            .confirmationDialog("Stop the \(c.name) timer? It won’t count as done.", isPresented: $confirmStop, titleVisibility: .visible) {
                Button("Stop timer", role: .destructive) {
                    if let cur = store.week(weekId) { store.setRun(cur, day, c.id, nil) }
                    router.cover = nil
                }
                Button("Keep going", role: .cancel) {}
            }
        } else {
            Color.clear.onAppear { router.cover = nil }
        }
    }

    private func finish(_ w: Week, _ c: Commitment) {
        guard !fin else { return }
        fin = true
        Haptic.success()
        let k = day, items = Logic.dayItems(w, Logic.noon(k), store.settings)
        Sound.play(items.allSatisfy { $0 == c.id || w.flag(k, $0) } ? .day : .done, store.settings)
        if !w.flag(day, c.id), !w.flag(day, c.id + "@fail") { store.setItem(w, day, c.id, true) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { if case .focus = router.cover { router.cover = nil } }
    }
}

/// The time left as a ring that empties (Nov 10 2026: replaces the kitchen-timer face, which had its own colours, type
/// and numbers that ran into each other). One accent arc on a quiet track, the time in the middle.
private struct Ring<Label: View>: View {
    let fraction: Double
    let done: Bool
    @ViewBuilder var label: () -> Label
    @State private var drawn = false
    @Environment(\.accessibilityReduceMotion) private var still

    var body: some View {
        ZStack {
            Circle().stroke(Theme.card2, lineWidth: 12)
            // sixty faint minute marks inside the track, like the day squares: structure without numbers
            ForEach(0..<60, id: \.self) { i in
                Rectangle().fill(i % 5 == 0 ? Theme.mu2 : Theme.line).frame(width: 1, height: i % 5 == 0 ? 8 : 4)
                    .offset(y: -108).rotationEffect(.degrees(Double(i) * 6))
            }
            Circle().trim(from: 0, to: done ? 1 : (drawn || still ? max(0.002, fraction) : 0))
                .stroke(done ? Theme.acDim : Theme.ac, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: fraction)
            label()
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(6)
        .pop(on: done)
        .onAppear { if !drawn { withAnimation(.timingCurve(0.2, 0.9, 0.2, 1, duration: 0.9).delay(0.15)) { drawn = true } } }
        .accessibilityHidden(true)
    }
}
