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

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            content(now: Now.date)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: 0x060607).ignoresSafeArea())
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    @ViewBuilder private func content(now: Date) -> some View {
        let w = store.week(weekId), c = w?.commitments.first { $0.id == habitId }
        if let w, let c, let m = c.min {
            let start = w.run(day, c.id)
            let span = Double(m <= 60 ? 60 : m)
            let left = start.map { max(0, ($0 + Double(m) * 60000 - now.timeIntervalSince1970 * 1000) / 1000) } ?? Double(m * 60)
            VStack(spacing: 20) {
                HStack {
                    Spacer()
                    Button { router.cover = nil } label: {
                        Image(systemName: "xmark").font(.system(size: 20, weight: .medium)).foregroundStyle(Color(hex: 0xABA69F))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Close")
                }
                Spacer()
                HStack(spacing: 8) {
                    Ico(name: c.icon, size: 18).foregroundStyle(Theme.ac)
                    Text(c.name).font(Theme.ui(18, .medium)).foregroundStyle(Color(hex: 0xF7F4EF))
                }
                Dial(span: span, minutesLeft: left / 60).frame(width: 300, height: 300)
                Text(left > 0 ? Fmt.mmss(left) : "Done")
                    .font(Theme.num(44)).monospacedDigit().foregroundStyle(left > 0 ? Color(hex: 0xF7F4EF) : Theme.ac)
                Text(fin ? "\(c.name) · done" : "Keeps running if you close").font(Theme.ui(15)).foregroundStyle(Color(hex: 0x8A857F))
                Spacer()
                if !fin {
                    Button("Stop timer") { confirmStop = true }.font(Theme.ui(16)).foregroundStyle(Color(hex: 0xABA69F)).padding(.bottom, 20)
                }
            }
            .padding(.horizontal, 20)
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
        if !w.flag(day, c.id), !w.flag(day, c.id + "@fail") { store.setItem(w, day, c.id, true) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { if case .focus = router.cover { router.cover = nil } }
    }
}

/// a kitchen-timer face: the accent wedge is the time left, out of 60 minutes (or the habit's length if longer)
private struct Dial: View {
    let span: Double
    let minutesLeft: Double

    var body: some View {
        Canvas { ctx, size in
            let R = min(size.width, size.height) / 2 - 2, c = CGPoint(x: size.width / 2, y: size.height / 2)
            let face = Path(ellipseIn: CGRect(x: c.x - R, y: c.y - R, width: R * 2, height: R * 2))
            ctx.fill(face, with: .color(Color(hex: 0x0E0E10)))
            ctx.stroke(face, with: .color(Color(hex: 0x2C2C30)), lineWidth: 1.5)
            let frac = min(0.99999, max(0, minutesLeft / span))
            if minutesLeft > 0 {
                var wedge = Path()
                wedge.move(to: c)
                wedge.addArc(center: c, radius: R - 14, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * frac), clockwise: false)
                wedge.closeSubpath()
                ctx.fill(wedge, with: .color(Color(hex: 0xE8743B).opacity(0.85)))
            }
            let step = span <= 60 ? 5.0 : span <= 120 ? 10.0 : 30.0, tick = span <= 120 ? 1.0 : 5.0
            var m = 0.0
            while m < span {
                let a = m / span * 2 * .pi, major = m.truncatingRemainder(dividingBy: step) == 0, r1 = major ? R - 16 : R - 9
                var p = Path()
                p.move(to: CGPoint(x: c.x + sin(a) * r1, y: c.y - cos(a) * r1))
                p.addLine(to: CGPoint(x: c.x + sin(a) * (R - 3), y: c.y - cos(a) * (R - 3)))
                ctx.stroke(p, with: .color(Color(hex: major ? 0x8E8A84 : 0x3A3A3E)), lineWidth: major ? 2 : 1)
                if major {
                    let t = Text("\(Int(m))").font(.custom("BarlowCondensed-Medium", size: 15)).foregroundColor(Color(hex: 0xB5B0A8))
                    ctx.draw(t, at: CGPoint(x: c.x + sin(a) * (R - 32), y: c.y - cos(a) * (R - 32)))
                }
                m += tick
            }
            let a = frac * 2 * .pi
            var hand = Path()
            hand.move(to: c)
            hand.addLine(to: CGPoint(x: c.x + sin(a) * (R - 4), y: c.y - cos(a) * (R - 4)))
            ctx.stroke(hand, with: .color(Color(hex: 0xF2EFEA)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }
        .accessibilityHidden(true)
    }
}
