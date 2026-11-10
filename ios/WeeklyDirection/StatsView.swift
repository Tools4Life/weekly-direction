import SwiftUI
import Charts

/// Stats (web: openStats / openAllStats, simplified Nov 9 2026 at Eddie's request): ALL TIME | WEEK. One headline, the week
/// as a grid, what slipped in one quiet line, each habit as a bar. A week in progress is never compared with a finished one. The week view steps through weeks with ‹ › or a swipe.
struct StatsView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    /// the week the Week view shows; nil opens on All time
    @State var weekId: String?
    @State private var mode: String
    @State private var vision = false

    init(weekId: String?) {
        _weekId = State(initialValue: weekId)
        _mode = State(initialValue: weekId == nil ? "all" : "week")
    }

    private var shown: Week? { store.week(weekId) ?? store.activeWeek ?? store.weeks.first }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Seg(options: [("all", "All time"), ("week", "Week")], value: $mode)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 20, weight: .medium)).foregroundStyle(Theme.mu).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Close")
            }
            .padding(.leading, 24).padding(.trailing, 12).padding(.top, 8)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if mode == "all" { allTime } else if let w = shown { week(w) }
                }
                .fullWidth().padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 50)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.bg.ignoresSafeArea())
        .gesture(DragGesture(minimumDistance: 40).onEnded { g in
            guard mode == "week", let w = shown, abs(g.translation.width) > 60, abs(g.translation.width) > abs(g.translation.height) * 1.6 else { return }
            let d = Logic.weekDetail(w, store.weeks, store.settings)
            if let t = g.translation.width < 0 ? d.next : d.prev { Haptic.tick(); weekId = t.id }
        })
        .fullScreenCover(isPresented: $vision) {
            if let w = shown { VisionView(weekId: w.id, log: true).environmentObject(store) }
        }
    }

    private func navButton(_ icon: String, _ target: Week?) -> some View {
        Button { if let target { Haptic.tick(); weekId = target.id } } label: {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(target == nil ? Theme.line : Theme.tx)
                .frame(width: 36, height: 36).contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(target == nil)
        .accessibilityLabel(icon == "chevron.left" ? "Previous week" : "Next week")
    }

    private func legend(_ c: Logic.Cell, _ t: String) -> some View {
        HStack(spacing: 7) {
            CellView(cell: c, round: true).frame(width: 14, height: 14)
            Text(t).font(Theme.ui(13)).foregroundStyle(Theme.mu)
        }
    }

    // MARK: week

    /// one headline, the week as a grid, what slipped in a single quiet line, then each habit
    @ViewBuilder private func week(_ w: Week) -> some View {
        let d = Logic.weekDetail(w, store.weeks, store.settings), st = d.stats
        let today = Rules.ymd(Now.date)
        let elapsed = w.isActive ? d.keys.filter { $0 <= today }.count : st.days.count
        HStack(spacing: 6) {
            navButton("chevron.left", d.prev)
            Eyebrow(text: Fmt.weekRange(w, store.settings), color: Theme.mu2, size: 12)
            navButton("chevron.right", d.next)
            Spacer()
            Button { vision = true } label: { Text("Vision").caps(14).foregroundStyle(Theme.ac) }.buttonStyle(.plain)
        }
        .padding(.leading, -12)
        Text(w.focus).title(34).foregroundStyle(Theme.tx).lineLimit(1).minimumScaleFactor(0.5).padding(.top, 6)
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(st.kept)").font(Theme.num(52)).foregroundStyle(Theme.tx)
            Text("of \(elapsed) day\(elapsed == 1 ? "" : "s") kept" + (w.isActive ? " so far" : "")).font(Theme.ui(17)).foregroundStyle(Theme.mu)
        }
        .padding(.top, 14)
        Text("\(d.done) of \(d.due) habits done" + (d.tDone > 0 ? " · \(Fmt.pct(d.tOn, d.tDone))% on time" : ""))
            .font(Theme.ui(15)).foregroundStyle(Theme.mu)
        grid(w, d, today).padding(.top, 30)
        let slipped = [d.miss > 0 ? "\(d.miss) missed" : "", d.fail > 0 ? "\(d.fail) failed" : "", d.grace > 0 ? "\(d.grace) in grace" : ""].filter { !$0.isEmpty }
        Text(slipped.isEmpty ? "Nothing missed." : slipped.joined(separator: " · ")).font(Theme.ui(14)).foregroundStyle(Theme.mu2).padding(.top, 14)
        Eyebrow(text: "By habit", color: Theme.mu2, size: 12).padding(.top, 34)
        ForEach(Array(d.per.enumerated()), id: \.offset) { _, t in
            HabitLine(c: t.c, value: "\(t.done)/\(t.due)", pct: t.due > 0 ? Fmt.pct(t.done, t.due) : 0)
        }
    }

    private func grid(_ w: Week, _ d: Logic.WeekDetail, _ today: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Color.clear.frame(width: 30, height: 1)
                ForEach(Array(d.stats.days.enumerated()), id: \.offset) { i, day in
                    Text(Fmt.dow[Rules.weekday(day)]).font(Theme.label(12)).tracking(1)
                        .foregroundStyle(d.keys[i] == today ? Theme.tx : Theme.mu2).frame(maxWidth: .infinity)
                }
            }
            ForEach(w.commitments) { c in
                HStack(spacing: 7) {
                    Ico(name: c.icon, size: 16).foregroundStyle(Theme.mu).frame(width: 30)
                    ForEach(d.keys, id: \.self) { k in
                        CellView(cell: Logic.cell(w, k, c)).frame(maxWidth: .infinity).frame(height: 34)
                    }
                }
            }
            // only the marks that actually appear this week
            let seen = Set(w.commitments.flatMap { c in d.keys.map { Logic.cell(w, $0, c) } })
            HStack(spacing: 14) {
                ForEach([(Logic.Cell.on, "on time"), (.grace, "grace"), (.late, "late"), (.miss, "missed"), (.fail, "failed")], id: \.1) { c, t in
                    if seen.contains(c) { legend(c, t) }
                }
            }
            .padding(.top, 8)
        }
    }

    // MARK: all time

    @ViewBuilder private var allTime: some View {
        let a = Logic.allTime(store.weeks, store.settings), s = Logic.streak(store.weeks, store.settings)
        if let first = a.weeks.first {
            Eyebrow(text: "Since \(Fmt.dateYear(first.w.sealedAt)) · \(a.weeks.count) week\(a.weeks.count > 1 ? "s" : "")", color: Theme.mu2, size: 12)
            Text("All time").title(34).foregroundStyle(Theme.tx).padding(.top, 4)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(a.pct)").font(Theme.num(52)).foregroundStyle(Theme.tx)
                Text("% of all habits done").font(Theme.ui(17)).foregroundStyle(Theme.mu)
            }
            .padding(.top, 14)
            Text("\(a.kept) of \(a.days) days kept · streak \(s.cur), best \(s.best)").font(Theme.ui(15)).foregroundStyle(Theme.mu)
            // finished weeks only: a week in progress would always look like a drop
            let closed = a.weeks.filter { !$0.w.isActive }
            if closed.count >= 2 {
                TrendChart(title: "Finished weeks", sub: a.best.map { "best \($0.w.focus) \($0.pct)%" } ?? "",
                           points: closed.map { .init(label: Fmt.slash($0.w.sealedAt.addingTimeInterval(86400)), value: $0.pct, live: false) }, height: 150)
                    .padding(.top, 22)
            }
            let slipped = [a.miss > 0 ? "\(a.miss) missed" : "", a.fail > 0 ? "\(a.fail) failed" : "", a.grace > 0 ? "\(a.grace) in grace" : "",
                           a.perfect > 0 ? "\(a.perfect) perfect week\(a.perfect == 1 ? "" : "s")" : ""].filter { !$0.isEmpty }
            if !slipped.isEmpty { Text(slipped.joined(separator: " · ")).font(Theme.ui(14)).foregroundStyle(Theme.mu2).padding(.top, 14) }
            Eyebrow(text: "By habit", color: Theme.mu2, size: 12).padding(.top, 34)
            ForEach(Array(a.habits.enumerated()), id: \.offset) { _, h in
                HabitLine(c: h.c, value: "\(h.due > 0 ? Fmt.pct(h.done, h.due) : 0)%", pct: h.due > 0 ? Fmt.pct(h.done, h.due) : 0)
            }
        }
    }

}

struct CellView: View {
    let cell: Logic.Cell
    var round = false
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: round ? 7 : 7, style: .continuous)
        ZStack {
            switch cell {
            case .on: shape.fill(Theme.ac)
            case .grace: shape.fill(Theme.acDim); shape.stroke(Theme.ac, lineWidth: 1)
            case .late: shape.fill(Theme.acSoft); shape.stroke(Theme.acDim, lineWidth: 1)
            case .miss: shape.stroke(Theme.mu2, style: StrokeStyle(lineWidth: 1, dash: [3, 2.5]))
            case .fail:
                shape.stroke(Theme.mu2, lineWidth: 1)
                Image(systemName: "xmark").font(.system(size: round ? 7 : 10, weight: .bold)).foregroundStyle(Theme.tx)
            case .open: shape.stroke(Theme.ac, style: StrokeStyle(lineWidth: 1, dash: [3, 2.5]))
            case .fut: shape.stroke(Theme.rule, lineWidth: 1)
            case .na: Color.clear
            }
        }
        .clipShape(round ? AnyShape(Circle()) : AnyShape(shape))
        .overlay { if round, cell == .miss || cell == .fail { Circle().stroke(Theme.mu2, style: StrokeStyle(lineWidth: 1, dash: cell == .miss ? [3, 2.5] : [])) } }
    }
}

/// a habit as its name, one figure and a full-width hairline bar
struct HabitLine: View {
    let c: Commitment
    let value: String
    let pct: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                Ico(name: c.icon, size: 16).foregroundStyle(Theme.mu)
                Text(c.name).rowTitle().foregroundStyle(Theme.tx).lineLimit(1)
                Spacer(minLength: 6)
                Text(value).font(Theme.num(16)).foregroundStyle(Theme.tx)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Theme.pill.fill(Theme.rule)
                    Theme.pill.fill(Theme.ac).frame(width: g.size.width * CGFloat(pct) / 100)
                }
            }
            .frame(height: 3)
        }
        .padding(.top, 16)
    }
}

/// the focal trend line of the stats page (web: stChart): 0–100 with grid lines at 0, 50, 100, last value labelled
struct TrendChart: View {
    struct Point { let label: String; let value: Int?; let live: Bool }
    let title: String
    let sub: String
    let points: [Point]
    var height: CGFloat = 170

    var body: some View {
        let shown = points.enumerated().filter { $0.element.value != nil }
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Eyebrow(text: title, color: Theme.mu, size: 12)
                Spacer()
                if !sub.isEmpty { Text(sub).font(Theme.ui(13)).foregroundStyle(Theme.mu).lineLimit(1) }
            }
            if shown.isEmpty {
                Text("Nothing recorded yet.").font(Theme.serifItalic(16)).foregroundStyle(Theme.mu2)
            } else {
                Chart {
                    ForEach(shown, id: \.offset) { i, p in
                        AreaMark(x: .value("x", i), y: .value("Percent", p.value ?? 0))
                            .foregroundStyle(LinearGradient(colors: [Theme.ac.opacity(0.28), Theme.ac.opacity(0)], startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("x", i), y: .value("Percent", p.value ?? 0)).foregroundStyle(Theme.ac).lineStyle(StrokeStyle(lineWidth: 2.5))
                        PointMark(x: .value("x", i), y: .value("Percent", p.value ?? 0))
                            .foregroundStyle(Theme.ac).symbolSize(i == shown.last?.offset ? 90 : 36)
                            .annotation(position: .top, spacing: 5) {
                                if i == shown.last?.offset { Text("\(p.value ?? 0)%").font(Theme.num(14)).foregroundStyle(Theme.tx) }
                            }
                    }
                }
                .chartYScale(domain: 0...100)
                .chartXScale(domain: -0.15...(Double(max(1, points.count - 1)) + 0.15))
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 50, 100]) { v in
                        AxisGridLine().foregroundStyle(Theme.line)
                        AxisValueLabel { if let n = v.as(Int.self) { Text("\(n)").font(Theme.label(12)).foregroundStyle(Theme.mu) } }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: Array(points.indices)) { v in
                        AxisValueLabel {
                            if let i = v.as(Int.self), points.indices.contains(i), points.count <= 8 || i % Int((Double(points.count) / 6).rounded(.up)) == 0 || i == points.count - 1 {
                                Text(points[i].label).font(Theme.label(12)).foregroundStyle(Theme.mu)
                            }
                        }
                    }
                }
                .frame(height: height)
                .accessibilityLabel("\(title): " + shown.map { "\($0.element.value ?? 0)%" }.joined(separator: ", "))
            }
        }
        .padding(14)
        .card(22)
    }
}
