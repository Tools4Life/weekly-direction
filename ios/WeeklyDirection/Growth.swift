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
                }
                HStack(spacing: 6) {
                    ForEach(0..<pad, id: \.self) { _ in Color.clear.frame(maxWidth: .infinity).frame(height: 1) }
                    ForEach(g.weeks) { w in Text(Fmt.slash(w.sealedAt)).font(Theme.label(11)).foregroundStyle(Theme.mu2).frame(maxWidth: .infinity) }
                }
                .padding(.top, 10)
                HStack(spacing: 14) { key(1, "Better"); key(0, "Same"); key(-1, "Worse"); key(nil, "Not said") }.padding(.top, 28)
            }
        }
    }

    private func key(_ v: Int?, _ t: String) -> some View {
        HStack(spacing: 6) {
            GrowthSquare(v: v, radius: 4).frame(width: 18, height: 16)
            Text(t).font(Theme.label(12)).tracking(1.2).textCase(.uppercase).foregroundStyle(Theme.mu)
        }
    }
}
