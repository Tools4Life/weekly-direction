import SwiftUI

/// The caffeine wean as a page to look at (Eddie, Nov 11 2026): today's allowance, the plan as a staircase down to zero
/// with today marked on it, and the next step. Nothing to check off. The plan itself is edited in Settings.
struct CaffeineView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @Environment(\.dismiss) private var dismiss
    @State private var drawn = false

    var body: some View {
        let s = store.settings, plan = Logic.cafPlan(s), from = Logic.cafFromDate(s)
        let total = plan.reduce(0) { $0 + $1.len }, day = Logic.dayDiff(from, Now.date)
        let mg = Logic.cafLimit(s, Now.date), sp = Logic.cafSplit(s, mg)
        func date(_ n: Int) -> Date { Rules.cal.date(byAdding: .day, value: n, to: from) ?? from }
        let next = plan.first { $0.from > day }
        return VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    HStack(spacing: 10) { Image(systemName: "chevron.left").font(.system(size: 15, weight: .medium)); Text("This week") }
                        .caps(16).foregroundStyle(Theme.mu)
                }
                .buttonStyle(.plain)
                Spacer()
                Button("Edit plan") { router.settingsPage = "caffeine"; router.cover = .settings }.caps(16).foregroundStyle(Theme.ac)
            }
            .padding(.horizontal, 24).frame(height: 52)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Eyebrow(text: day < 0 ? "Caffeine wean · starts \(Fmt.date(from))" : mg > 0 ? "Caffeine wean · day \(min(day + 1, total)) of \(total)" : "Caffeine wean · done",
                            color: Theme.ac)
                    if mg > 0 {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(mg)").font(Theme.num(72)).foregroundStyle(Theme.tx)
                            Text("mg today").font(Theme.ui(17)).foregroundStyle(Theme.mu)
                        }
                        .padding(.top, 2)
                        HStack(spacing: 10) {
                            dose("Morning", sp.am)
                            dose("Afternoon", sp.pm)
                        }
                        .padding(.top, 14).rise(0)
                    } else {
                        Text("Caffeine-free").title(44).foregroundStyle(Theme.tx).padding(.top, 6)
                        Text("since \(Fmt.date(date(total)))").font(Theme.ui(17)).foregroundStyle(Theme.mu).padding(.top, 4)
                    }
                    Stairs(plan: plan, total: total, day: day, top: max(1, s.cafStart), drawn: drawn)
                        .frame(height: 170).padding(.top, 36)
                    HStack {
                        Eyebrow(text: Fmt.date(from), color: Theme.mu2, size: 12)
                        Spacer()
                        Eyebrow(text: "0 mg · " + Fmt.date(date(total)), color: Theme.mu2, size: 12)
                    }
                    .padding(.top, 10)
                    if let next, mg > 0 {
                        let x = Logic.cafSplit(s, next.mg), left = next.from - day
                        Rectangle().fill(Theme.rule).frame(height: 1).padding(.top, 30)
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 6) {
                                Eyebrow(text: "Next step", color: Theme.mu, size: 12)
                                Text("\(next.mg) mg").font(Theme.num(26)).foregroundStyle(Theme.tx)
                                Text("\(x.am) morning · \(x.pm) afternoon").font(Theme.ui(15)).foregroundStyle(Theme.mu)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 6) {
                                Eyebrow(text: Fmt.dowl[Rules.weekday(date(next.from))] + " · " + Fmt.date(date(next.from)), color: Theme.mu, size: 12)
                                Text("\(left)").font(Theme.num(26)).foregroundStyle(Theme.ac)
                                Text(left == 1 ? "day away" : "days away").font(Theme.ui(15)).foregroundStyle(Theme.mu)
                            }
                        }
                        .padding(.top, 20)
                    } else if mg > 0 {
                        Rectangle().fill(Theme.rule).frame(height: 1).padding(.top, 30)
                        VStack(alignment: .leading, spacing: 6) {
                            Eyebrow(text: "Last step", color: Theme.mu, size: 12)
                            Text("Caffeine-free from \(Fmt.dowl[Rules.weekday(date(total))]), \(Fmt.date(date(total)))").font(Theme.serif(20)).foregroundStyle(Theme.tx)
                        }
                        .padding(.top, 20)
                    }
                }
                .fullWidth().padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 50)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear { withAnimation(.timingCurve(0.2, 0.9, 0.2, 1, duration: 0.8).delay(0.15)) { drawn = true } }
    }

    private func dose(_ name: String, _ mg: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: name, color: Theme.mu, size: 12)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(mg > 0 ? "\(mg)" : "None").font(Theme.num(26)).foregroundStyle(mg > 0 ? Theme.tx : Theme.mu2)
                if mg > 0 { Text("mg").font(Theme.ui(15)).foregroundStyle(Theme.mu) }
            }
        }
        .fullWidth().padding(.horizontal, 16).padding(.vertical, 14).card(16)
    }
}

/// The plan as steps down to zero: one bar per step, as wide as its days and as tall as its limit. Steps behind you are
/// quiet, the one you are on is lit, and a dot marks today.
private struct Stairs: View {
    let plan: [(mg: Int, from: Int, len: Int)]
    let total: Int
    let day: Int
    let top: Int
    let drawn: Bool

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, unit = w / CGFloat(max(1, total)), gap: CGFloat = 3
            ZStack(alignment: .bottomLeading) {
                Rectangle().fill(Theme.rule).frame(height: 1)
                ForEach(Array(plan.enumerated()), id: \.offset) { _, l in
                    let cur = day >= l.from && day < l.from + l.len, past = day >= l.from + l.len
                    let bh = max(6, h * CGFloat(l.mg) / CGFloat(top)) * (drawn ? 1 : 0.02)
                    RoundedRectangle(cornerRadius: Theme.r(5), style: .continuous)
                        .fill(cur ? Theme.ac : past ? Theme.acDim.opacity(0.45) : Theme.card2)
                        .overlay(RoundedRectangle(cornerRadius: Theme.r(5), style: .continuous).stroke(cur || past ? Color.clear : Theme.line, lineWidth: 1))
                        .frame(width: max(2, unit * CGFloat(l.len) - gap), height: bh)
                        .offset(x: unit * CGFloat(l.from))
                    if cur {
                        // today, on top of its step
                        Circle().fill(Theme.tx).frame(width: 9, height: 9)
                            .offset(x: unit * (CGFloat(day) + 0.5) - 4.5 - gap / 2, y: -(bh + 7))
                            .opacity(drawn ? 1 : 0)
                    }
                }
            }
            .frame(width: w, height: h, alignment: .bottomLeading)
        }
        .accessibilityHidden(true)
    }
}
