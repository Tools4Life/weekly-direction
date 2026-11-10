import SwiftUI

/// Growth read from the weekly reviews (Eddie, Nov 10 2026). At each review every Saturday question gets a rating he
/// confirms: better (1), same (0), worse (-1), or none. Saved on the week as `growth: [{q, v, s}]`, a field only the
/// iOS app writes. Weeks closed before this existed have none and stay empty.
/// The grid is by sphere (`s`: the question's group in the library, "Anchor" for the anchor question), not by exact
/// question, because the questions change from week to week and the spheres do not.
enum Growth {
    /// the last three rated weeks against the three before them: 1 improving, -1 slipping, 0 steady; nil until there are four
    static func trend(_ v: [Int]) -> Int? {
        guard v.count >= 4 else { return nil }
        let late = v.suffix(3).reduce(0, +), early = v.dropLast(3).suffix(3).reduce(0, +)
        return late > early ? 1 : late < early ? -1 : 0
    }

    static let anchorSphere = "Anchor"
    /// the sphere a question belongs to: "Anchor", its group in the question library, or "Other"
    static func sphere(_ q: String, _ s: Settings) -> String {
        if q == s.anchorQ { return anchorSphere }
        return Logic.libGroups(s).first { $0.qs.contains(q) }?.title ?? "Other"
    }

    /// a sphere's rating for one week: the balance of its questions that week (two better and one worse is better)
    static func value(_ w: Week, _ sphere: String) -> Int? {
        let v = w.growth.filter { $0.s == sphere }.map(\.v)
        guard !v.isEmpty else { return nil }
        let sum = v.reduce(0, +)
        return sum > 0 ? 1 : sum < 0 ? -1 : 0
    }

    /// one rated week of a sphere, with what he said
    struct Point: Identifiable { let week: Week; let v: Int; let said: [String]; var id: String { week.id } }

    /// every rated week of a sphere, oldest first
    static func points(_ weeks: [Week], _ sphere: String) -> [Point] {
        weeks.filter { !$0.isActive }.sorted { $0.sealedAtMs < $1.sealedAtMs }.compactMap { w in
            value(w, sphere).map { Point(week: w, v: $0, said: w.growth.filter { $0.s == sphere && !$0.t.isEmpty }.map(\.t)) }
        }
    }
    /// "better in 5 of the last 8": the count and the window
    static func standing(_ p: [Point]) -> (better: Int, of: Int) { let l = p.suffix(8); return (l.filter { $0.v > 0 }.count, l.count) }
    /// weeks in a row, up to now, without a "worse"
    static func holding(_ p: [Point]) -> Int { p.reversed().prefix { $0.v >= 0 }.count }

    struct Row: Identifiable { let sphere: String; let cells: [Int?]; let trend: Int?; var id: String { sphere } }

    /// one row per sphere that has ever been rated (Anchor first, then the most recently rated); cells are the last
    /// `n` closed weeks, oldest first
    static func rows(_ weeks: [Week], last n: Int = 8) -> (weeks: [Week], rows: [Row]) {
        let closed = weeks.filter { !$0.isActive }.sorted { $0.sealedAtMs < $1.sealedAtMs }
        let shown = Array(closed.suffix(n))
        var latest: [String: Double] = [:]
        for w in closed { for r in w.growth { latest[r.s] = w.sealedAtMs } }
        let names = latest.keys.sorted { a, b in a == anchorSphere ? true : b == anchorSphere ? false : (latest[a]!, b) > (latest[b]!, a) }
        return (shown, names.map { s in
            Row(sphere: s, cells: shown.map { value($0, s) }, trend: trend(closed.compactMap { value($0, s) }))
        })
    }
}

/// one square of the grid, in the app's own square language: full = better, half = same, empty = worse, dashed = none
struct GrowthSquare: View {
    let v: Int?
    var radius: CGFloat = 6
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.r(radius), style: .continuous)
        switch v {
        case 1: shape.fill(Theme.ac)
        case 0: GeometryReader { g in
            shape.fill(Theme.card2).overlay(alignment: .bottom) { Rectangle().fill(Theme.acDim).frame(height: g.size.height / 2) }.clipShape(shape)
                .overlay(shape.stroke(Theme.acDim, lineWidth: 1))
        }
        case -1: shape.fill(Theme.card2).overlay(shape.stroke(Theme.line, lineWidth: 1))
        default: shape.stroke(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
    }
}

/// Progress → Growth: each question a row, each square a week
struct GrowthGrid: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @State private var open: Open?
    struct Open: Identifiable { let id: String }

    var body: some View {
        let g = Growth.rows(store.weeks)
        // always eight columns, newest on the right: the squares keep their size while the first weeks fill in
        let pad = max(0, 8 - g.weeks.count)
        VStack(alignment: .leading, spacing: 0) {
            if g.rows.isEmpty {
                Text("Your first rated review will show here.").font(Theme.serifItalic(17)).foregroundStyle(Theme.mu2).padding(.top, 24)
            } else {
                ForEach(Array(g.rows.enumerated()), id: \.element.id) { n, r in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(r.sphere).caps(16).foregroundStyle(Theme.tx).lineLimit(1)
                            Spacer(minLength: 10)
                            if let t = r.trend {
                                Text(t > 0 ? "improving" : t < 0 ? "slipping" : "steady").font(Theme.label(13)).tracking(1.4).textCase(.uppercase)
                                    .foregroundStyle(t > 0 ? Theme.ac : Theme.mu2)
                            }
                        }
                        HStack(spacing: 6) {
                            ForEach(0..<pad, id: \.self) { _ in Color.clear.frame(maxWidth: .infinity).frame(height: 26) }
                            ForEach(Array(r.cells.enumerated()), id: \.offset) { _, v in GrowthSquare(v: v).frame(maxWidth: .infinity).frame(height: 26) }
                        }
                    }
                    .padding(.top, 22).rise(n)
                    .contentShape(Rectangle())
                    .onTapGesture { Haptic.tick(); open = Open(id: r.sphere) }
                }
                HStack(spacing: 6) {
                    ForEach(0..<pad, id: \.self) { _ in Color.clear.frame(maxWidth: .infinity).frame(height: 1) }
                    ForEach(g.weeks) { w in Text(Fmt.slash(w.sealedAt)).font(Theme.label(11)).foregroundStyle(Theme.mu2).frame(maxWidth: .infinity) }
                }
                .padding(.top, 10)
                HStack(spacing: 14) { key(1, "Better"); key(0, "Same"); key(-1, "Worse"); key(nil, "Not said") }.padding(.top, 28)
            }
        }
        .sheet(item: $open) { o in
            SphereView(sphere: o.id).environmentObject(store)
                .presentationDetents([.large]).presentationDragIndicator(.visible).presentationCornerRadius(28).presentationBackground(Theme.bg)
                .preferredColorScheme(store.settings.theme == "light" ? .light : store.settings.theme == "auto" ? nil : .dark)
        }
        .onAppear { if let s = router.openSphere { router.openSphere = nil; open = Open(id: s) } }
    }

    private func key(_ v: Int?, _ t: String) -> some View {
        HStack(spacing: 6) {
            GrowthSquare(v: v, radius: 4).frame(width: 18, height: 16)
            Text(t).font(Theme.label(12)).tracking(1.2).textCase(.uppercase).foregroundStyle(Theme.mu)
        }
    }
}

/// One sphere over time (Nov 10 2026): where it stands, the running line, and what he said week by week.
struct SphereView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let sphere: String

    var body: some View {
        let p = Growth.points(store.weeks, sphere), st = Growth.standing(p), hold = Growth.holding(p)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Eyebrow(text: "Growth", color: Theme.ac)
                    Spacer()
                    Button("Done") { dismiss() }.caps(16).foregroundStyle(Theme.ac)
                }
                Text(sphere).title(32).foregroundStyle(Theme.tx).padding(.top, 6)
                if p.isEmpty {
                    Text("Nothing rated here yet.").font(Theme.serifItalic(17)).foregroundStyle(Theme.mu2).padding(.top, 20)
                } else {
                    Text("Better in \(st.better) of the last \(st.of) \(st.of == 1 ? "week" : "weeks").")
                        .font(Theme.serif(19)).foregroundStyle(Theme.tx).padding(.top, 16)
                    if hold >= 2 { Eyebrow(text: "\(hold) weeks without slipping", color: Theme.ac).padding(.top, 8) }
                    RunningLine(values: p.map(\.v)).frame(height: 120).padding(.top, 26).rise(0)
                    HStack {
                        Text(Fmt.date(p.first!.week.sealedAt)); Spacer(); Text(Fmt.date(p.last!.week.sealedAt))
                    }
                    .font(Theme.label(12)).tracking(1.2).textCase(.uppercase).foregroundStyle(Theme.mu2).padding(.top, 8)
                    Eyebrow(text: "In your words", color: Theme.mu).padding(.top, 34)
                    ForEach(Array(p.reversed().enumerated()), id: \.element.id) { n, x in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                GrowthSquare(v: x.v, radius: 4).frame(width: 18, height: 16)
                                Text("\(x.v > 0 ? "Better" : x.v < 0 ? "Worse" : "Same") · \(Fmt.weekRange(x.week, store.settings))")
                                    .font(Theme.label(12)).tracking(1.6).textCase(.uppercase).foregroundStyle(Theme.mu2)
                                Spacer()
                                Text(x.week.focus).font(Theme.jitalic(14)).foregroundStyle(Theme.mu2)
                            }
                            ForEach(x.said, id: \.self) { t in
                                Text(t).font(Theme.jserif(17)).lineSpacing(6).foregroundStyle(Theme.tx)
                            }
                        }
                        .fullWidth().padding(.vertical, 16).rise(1 + n)
                        Rectangle().fill(Theme.rule).frame(height: 1)
                    }
                }
            }
            .fullWidth().padding(.horizontal, 22).padding(.top, 30).padding(.bottom, 40)
        }
        .background(Theme.bg)
    }
}

/// each better steps the line up, each worse steps it down, same holds: the slope is the story
private struct RunningLine: View {
    let values: [Int]
    var body: some View {
        Canvas { ctx, size in
            var sum = 0
            let run = [0] + values.map { sum += $0; return sum }
            let lo = Double(min(run.min() ?? 0, -1)), hi = Double(max(run.max() ?? 0, 1)), n = run.count
            func pt(_ i: Int) -> CGPoint {
                CGPoint(x: n < 2 ? 6 : 6 + (size.width - 12) * CGFloat(i) / CGFloat(n - 1),
                        y: 6 + (size.height - 12) * CGFloat(1 - (Double(run[i]) - lo) / (hi - lo)))
            }
            // where it started
            var base = Path(); base.move(to: CGPoint(x: 0, y: pt(0).y)); base.addLine(to: CGPoint(x: size.width, y: pt(0).y))
            ctx.stroke(base, with: .color(Theme.line), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
            var line = Path(); line.move(to: pt(0))
            for i in 1..<n { line.addLine(to: pt(i)) }
            ctx.stroke(line, with: .color(Theme.ac), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            for i in 1..<n {
                let c = pt(i), r: CGFloat = i == n - 1 ? 5 : 3.5
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(values[i - 1] < 0 ? Theme.acDim : Theme.ac))
            }
        }
        .accessibilityHidden(true)
    }
}
