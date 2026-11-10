import SwiftUI
import Charts

/// Progress (web: renderHistory): this week's result and the weekly trend, then every week or every habit.
struct ProgressScreen: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @State private var tip: [String: String] = [:]

    var body: some View {
        let weeks = store.weeks.sorted { $0.sealedAtMs > $1.sealedAtMs }
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Progress").title(34).foregroundStyle(Theme.tx)
                if let aw = weeks.first(where: { $0.isActive }) ?? weeks.first {
                    hero(aw, weeks).padding(.top, 18).rise(0)
                    Seg(options: [("weeks", "Weeks"), ("habits", "Habits"), ("growth", "Growth")], value: $router.progressView).padding(.top, 18).rise(1)
                    if router.progressView == "habits" { habits } else if router.progressView == "growth" { GrowthGrid() } else { list(weeks.filter { $0.id != aw.id }) }
                } else {
                    Text("Your weeks will appear here once you seal your first one.").font(Theme.serifItalic(17)).foregroundStyle(Theme.mu).padding(.top, 20)
                }
            }
            .fullWidth().padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(Theme.bg)
    }

    private func hero(_ aw: Week, _ weeks: [Week]) -> some View {
        let st = Logic.weekStats(aw, store.settings), ot = Logic.onTimePct(aw, store.settings)
        let trend = Array(weeks.filter { $0.status == "closed" }.prefix(12).reversed())
        let pcts = trend.map { Logic.weekStats($0, store.settings).pct }
        let avg = pcts.isEmpty ? nil : Int((Double(pcts.reduce(0, +)) / Double(pcts.count)).rounded())
        return Button { router.cover = .stats(aw.id) } label: {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 0) {
                    (Text((aw.isActive ? "This week" : Fmt.weekRange(aw, store.settings)) + " · ").foregroundColor(Theme.mu)
                     + Text(aw.focus.uppercased()).foregroundColor(Theme.ac))
                        .font(Theme.label(12)).tracking(2.4).textCase(.uppercase).lineLimit(1)
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text("\(st.pct)").font(Theme.num(38)).foregroundStyle(Theme.tx)
                        Text("%").font(Theme.ui(17)).foregroundStyle(Theme.mu)
                    }
                    Text("\(st.kept) of \(st.days.count) days" + (ot.map { " · \($0)% on time" } ?? ""))
                        .font(Theme.ui(14)).foregroundStyle(Theme.mu).multilineTextAlignment(.leading)
                    MiniDays(week: aw, days: st.days, size: 12).padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Rectangle().fill(Theme.rule).frame(width: 1)
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(text: "Weekly trend", color: Theme.mu, size: 12)
                    if let avg, pcts.count >= 2 { Text("avg \(avg)%").font(Theme.ui(14)).foregroundStyle(Theme.mu) }
                    if pcts.count >= 2 { Spark(values: pcts).frame(height: 70) }
                    else { Text("Starts after \(pcts.isEmpty ? "two reviews" : "one more review").").font(Theme.serifItalic(15)).foregroundStyle(Theme.mu2) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.r(22), style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.r(22), style: .continuous).stroke(Theme.ac.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open stats")
    }

    @ViewBuilder private func list(_ past: [Week]) -> some View {
        if past.isEmpty { Text("Past weeks will show here.").font(Theme.serifItalic(16)).foregroundStyle(Theme.mu2).padding(.top, 18) }
        ForEach(past) { w in
            let st = Logic.weekStats(w, store.settings)
            Button { router.cover = .stats(w.id) } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(w.focus).font(Theme.serif(19)).foregroundStyle(Theme.tx).lineLimit(1)
                        Eyebrow(text: Fmt.weekRange(w, store.settings), color: Theme.mu2)
                    }
                    Spacer()
                    MiniDays(week: w, days: st.days, size: 10)
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text("\(st.pct)").font(Theme.num(21)).foregroundStyle(Theme.tx)
                        Text("%").font(Theme.ui(12)).foregroundStyle(Theme.mu)
                    }
                    .frame(width: 62, alignment: .trailing)
                }
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Rectangle().fill(Theme.rule).frame(height: 1)
        }
    }

    @ViewBuilder private var habits: some View {
        let h = Logic.habitHistory(store.weeks, store.settings)
        if h.rows.isEmpty {
            Text("Habit history starts once a day has been recorded.").font(Theme.serifItalic(16)).foregroundStyle(Theme.mu2).padding(.top, 18)
        } else {
            Text("Last \(h.weeks) week\(h.weeks > 1 ? "s" : ""), oldest → newest · tap a square").font(Theme.ui(13)).foregroundStyle(Theme.mu2).padding(.top, 14)
            ForEach(h.rows) { r in
                let ot = r.on + r.late > 0 ? Fmt.pct(r.on, r.on + r.late) : nil
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Ico(name: r.c.icon, size: 17).foregroundStyle(Theme.mu)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(r.c.name).rowTitle().foregroundStyle(Theme.tx).lineLimit(1)
                            Text("\(r.kept)/\(r.tot) days" + (ot.map { " · \($0)% on time" } ?? "") + (r.gr > 0 ? " · \(r.gr) grace" : "") + (r.rs > 0 ? " · \(r.rs) resched." : ""))
                                .font(Theme.label(13)).tracking(0.8).foregroundStyle(Theme.mu2).lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        HStack(spacing: 4) {
                            ForEach(Array(r.cells.enumerated()), id: \.offset) { _, c in
                                if let c {
                                    RoundedRectangle(cornerRadius: Theme.r(3)).fill(Theme.ac.opacity(0.15 + 0.85 * Double(c.k) / Double(c.t)))
                                        .frame(width: 13, height: 13)
                                        .onTapGesture { tip[r.id] = "\(c.focus): \(c.k) of \(c.t) days" }
                                } else {
                                    RoundedRectangle(cornerRadius: Theme.r(3)).stroke(Theme.rule, lineWidth: 1).frame(width: 13, height: 13)
                                }
                            }
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            Text("\(Fmt.pct(r.kept, r.tot))").font(Theme.num(18)).foregroundStyle(Theme.tx)
                            Text("%").font(Theme.ui(12)).foregroundStyle(Theme.mu)
                        }
                        .frame(width: 50, alignment: .trailing)
                    }
                    if let t = tip[r.id] { Text(t).font(Theme.ui(13)).foregroundStyle(Theme.ac).padding(.leading, 38) }
                }
                .padding(.vertical, 13)
                Rectangle().fill(Theme.rule).frame(height: 1)
            }
        }
    }
}

/// a week's day marks as small squares
struct MiniDays: View {
    let week: Week
    let days: [Date]
    var size: CGFloat = 12
    var body: some View {
        HStack(spacing: 4) {
            ForEach(days, id: \.self) { d in
                let m = week.marks[Rules.ymd(d)]
                RoundedRectangle(cornerRadius: Theme.r(3), style: .continuous)
                    .fill(m == "on" ? Theme.ac : m == "drift" ? Color(hex: 0xF2EFEA) : Color.clear)
                    .overlay(RoundedRectangle(cornerRadius: Theme.r(3), style: .continuous).stroke(m == nil ? Theme.line : Color.clear, lineWidth: 1))
                    .frame(width: size, height: size)
            }
        }
    }
}

/// compact weekly trend: closed weeks, oldest → newest, the last one labelled
private struct Spark: View {
    let values: [Int]
    var body: some View {
        Chart {
            ForEach(Array(values.enumerated()), id: \.offset) { i, v in
                LineMark(x: .value("Week", i), y: .value("Percent", v)).foregroundStyle(Theme.ac).lineStyle(StrokeStyle(lineWidth: 2))
                PointMark(x: .value("Week", i), y: .value("Percent", v)).foregroundStyle(Theme.ac).symbolSize(40)
                    .annotation(position: .top, spacing: 4) {
                        if i == values.count - 1 { Text("\(v)%").font(Theme.num(13)).foregroundStyle(Theme.tx) }
                    }
            }
        }
        .chartYScale(domain: 0...100)
        .chartXScale(domain: -0.2...(Double(values.count) - 0.5))
        .chartXAxis(.hidden)
        .chartYAxis { AxisMarks(values: [0, 100]) { _ in AxisGridLine().foregroundStyle(Theme.rule) } }
        .accessibilityLabel("Weekly percentage trend: " + values.map { "\($0)%" }.joined(separator: ", "))
    }
}
