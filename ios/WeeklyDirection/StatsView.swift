import SwiftUI
import Charts

/// Stats (web: openStats / openAllStats): ALL TIME | WEEK. The week view steps through weeks with ‹ › or a swipe.
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

    // MARK: week

    @ViewBuilder private func week(_ w: Week) -> some View {
        let d = Logic.weekDetail(w, store.weeks, store.settings), st = d.stats
        HStack(spacing: 6) {
            navButton("chevron.left", d.prev)
            Eyebrow(text: Fmt.weekRange(w, store.settings), color: Theme.mu2, size: 12)
            navButton("chevron.right", d.next)
            Spacer()
            Button { vision = true } label: {
                HStack(spacing: 8) { Image(systemName: "book").font(.system(size: 14)).foregroundStyle(Theme.ac); Text("Vision").font(Theme.ui(15)).foregroundStyle(Theme.tx) }
                    .padding(.horizontal, 14).frame(height: 32)
                    .overlay(Theme.pill.stroke(Theme.ac.opacity(0.6), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, -12)
        HStack(alignment: .lastTextBaseline) {
            Text(w.focus).title(34).foregroundStyle(Theme.tx).lineLimit(1).minimumScaleFactor(0.5)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                bigPct(st.pct)
                if let pv = d.prev, let pp = d.prevPct {
                    Text("\(st.pct >= pp ? "▲" : "▼") \(abs(st.pct - pp)) vs \(pv.focus)").font(Theme.label(13)).tracking(1).foregroundStyle(Theme.mu)
                }
            }
        }
        .padding(.top, 6)
        let today = Rules.ymd(Now.date)
        TrendChart(title: "Daily trend", sub: "",
                   points: d.keys.enumerated().map { i, k in .init(label: Fmt.dow[Rules.weekday(st.days[i])], value: d.daily[i], live: k == today) }, height: 150)
            .padding(.top, 12)
        StatGrid(rows: [("Days kept", "\(st.kept)/\(st.days.count)"), ("Habits done", "\(d.done)/\(d.due)"),
                        ("On time", d.tDone > 0 ? "\(Fmt.pct(d.tOn, d.tDone))% · \(d.tOn)/\(d.tDone)" : "—"),
                        ("In grace", "\(d.grace)"), ("Missed", "\(d.miss)"), ("Failed", "\(d.fail)")]).padding(.top, 8)
        section("Day by day") { grid(w, d) }
        section("By habit") {
            ForEach(Array(d.per.enumerated()), id: \.offset) { i, t in
                let pct = t.due > 0 ? Fmt.pct(t.done, t.due) : 0
                let bits = ["\(t.done)/\(t.due)", t.c.by != nil && t.done > 0 ? "\(Fmt.pct(t.on + t.grace, t.done))% on time" : "",
                            t.grace > 0 ? "\(t.grace) grace" : "", t.late > 0 ? "\(t.late) late" : "", t.fail > 0 ? "\(t.fail) failed" : ""]
                HabitBar(c: t.c, sub: bits.filter { !$0.isEmpty }.joined(separator: " · "), pct: pct, last: i == d.per.count - 1)
            }
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

    private func bigPct(_ v: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text("\(v)").font(Theme.num(36)).foregroundStyle(Theme.tx)
            Text("%").font(Theme.ui(17)).foregroundStyle(Theme.mu)
        }
    }

    private func section<V: View>(_ title: String, @ViewBuilder _ content: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: title, color: Theme.tx, size: 12)
            content()
        }
        .fullWidth().padding(15)
        .card(22)
        .padding(.top, 16)
    }

    /// habit × day cells: on time, grace, late, missed, failed
    private func grid(_ w: Week, _ d: Logic.WeekDetail) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Color.clear.frame(width: 30, height: 1)
                ForEach(d.stats.days, id: \.self) { day in
                    Text(Fmt.dow[Rules.weekday(day)]).font(Theme.label(12)).tracking(1).foregroundStyle(Theme.mu).frame(maxWidth: .infinity)
                }
            }
            ForEach(w.commitments) { c in
                HStack(spacing: 6) {
                    Ico(name: c.icon, size: 16).foregroundStyle(Theme.mu).frame(width: 30)
                    ForEach(d.keys, id: \.self) { k in
                        CellView(cell: Logic.cell(w, k, c)).frame(maxWidth: .infinity).frame(height: 28)
                            .accessibilityLabel("\(c.name) · \(Fmt.dowl[Rules.weekday(Logic.noon(k))]): \(Logic.cell(w, k, c).rawValue)")
                    }
                }
            }
            HStack(spacing: 14) {
                legend(.on, "on time"); legend(.grace, "grace"); legend(.late, "late"); legend(.miss, "missed")
            }
            .padding(.top, 6)
            legend(.fail, "failed")
        }
    }
    private func legend(_ c: Logic.Cell, _ t: String) -> some View {
        HStack(spacing: 7) {
            CellView(cell: c, round: true).frame(width: 14, height: 14)
            Text(t).font(Theme.ui(13)).foregroundStyle(Theme.mu)
        }
    }

    // MARK: all time

    @ViewBuilder private var allTime: some View {
        let a = Logic.allTime(store.weeks, store.settings), s = Logic.streak(store.weeks, store.settings)
        if let first = a.weeks.first {
            Eyebrow(text: "Since \(Fmt.dateYear(first.w.sealedAt)) · \(a.weeks.count) week\(a.weeks.count > 1 ? "s" : "")", color: Theme.mu2, size: 12)
            Text("All time").title(34).foregroundStyle(Theme.tx).padding(.top, 4)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                bigPct(a.pct)
                Text("of all habits done").font(Theme.label(13)).tracking(1).foregroundStyle(Theme.tx)
            }
            TrendChart(title: "Weekly trend",
                       sub: a.avg.map { "avg \($0)%" + (a.best.map { " · best \($0.w.focus) \($0.pct)%" } ?? "") } ?? "",
                       points: a.weeks.map { .init(label: Fmt.slash($0.w.sealedAt.addingTimeInterval(86400)), value: $0.pct, live: $0.w.isActive) }, height: 190)
                .padding(.top, 10)
            StatGrid(rows: [("Days kept", "\(a.kept)/\(a.days)"), ("Day streak", "\(s.cur) · best \(s.best)"),
                            ("On time", a.onTime.map { "\($0)%" } ?? "—"), ("Perfect weeks", "\(a.perfect)"), ("Weeks closed", "\(a.closed)"),
                            ("In grace", "\(a.grace)"), ("Missed", "\(a.miss)"), ("Failed", "\(a.fail)")]).padding(.top, 8)
            section("By habit") {
                ForEach(Array(a.habits.enumerated()), id: \.offset) { i, h in
                    let p = h.due > 0 ? Fmt.pct(h.done, h.due) : 0
                    HabitBar(c: h.c, sub: ["\(h.done)/\(h.due) days", h.tdone > 0 ? "\(Fmt.pct(h.on, h.tdone))% on time" : ""].filter { !$0.isEmpty }.joined(separator: " · "),
                             pct: p, last: i == a.habits.count - 1)
                }
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

/// stat grid, three across, numbers centered
struct StatGrid: View {
    let rows: [(String, String)]
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 0) {
            ForEach(rows, id: \.0) { r in
                VStack(spacing: 4) {
                    Text(r.1).font(Theme.ui(17)).foregroundStyle(Theme.tx).lineLimit(1).minimumScaleFactor(0.7)
                    Text(r.0).font(Theme.ui(13)).foregroundStyle(Theme.mu)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
            }
        }
    }
}

struct HabitBar: View {
    let c: Commitment
    let sub: String
    let pct: Int
    let last: Bool
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Ico(name: c.icon, size: 17).foregroundStyle(Theme.tx)
                VStack(alignment: .leading, spacing: 3) {
                    Text(c.name).font(Theme.ui(16.5)).foregroundStyle(Theme.tx).lineLimit(1)
                    Text(sub).font(Theme.label(13)).tracking(0.9).foregroundStyle(Theme.mu2).lineLimit(1)
                }
                Spacer(minLength: 6)
                ZStack(alignment: .leading) {
                    Theme.pill.fill(Theme.line).frame(width: 40, height: 4)
                    Theme.pill.fill(Theme.ac).frame(width: 40 * CGFloat(pct) / 100, height: 4)
                }
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(pct)").font(Theme.num(18)).foregroundStyle(Theme.tx)
                    Text("%").font(Theme.ui(11)).foregroundStyle(Theme.mu)
                }
                .frame(width: 54, alignment: .trailing)
            }
            .padding(.vertical, 12)
            if !last { Rectangle().fill(Theme.rule).frame(height: 1) }
        }
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
