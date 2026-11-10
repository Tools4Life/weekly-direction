import SwiftUI

/// Growth read from the weekly reviews (Eddie, Nov 10 2026). At each review every Saturday question gets a rating he
/// confirms: better (1), same (0), worse (-1), or none. Saved on the week as `growth: [{q, v}]`, a field only the
/// iOS app writes. Weeks closed before this existed have none and stay empty.
enum Growth {
    /// the last three rated weeks against the three before them: 1 improving, -1 slipping, 0 steady; nil until there are four
    static func trend(_ v: [Int]) -> Int? {
        guard v.count >= 4 else { return nil }
        let late = v.suffix(3).reduce(0, +), early = v.dropLast(3).suffix(3).reduce(0, +)
        return late > early ? 1 : late < early ? -1 : 0
    }

    struct Row: Identifiable { let q: String; let cells: [Int?]; let trend: Int?; var id: String { q } }

    /// one row per question that has ever been rated; cells are the last `n` closed weeks, oldest first
    static func rows(_ weeks: [Week], anchor: String, last n: Int = 8) -> (weeks: [Week], rows: [Row]) {
        let closed = weeks.filter { !$0.isActive }.sorted { $0.sealedAtMs < $1.sealedAtMs }
        let shown = Array(closed.suffix(n))
        var latest: [String: Double] = [:]
        for w in closed { for r in w.growth { latest[r.q] = w.sealedAtMs } }
        let qs = latest.keys.sorted { a, b in a == anchor ? true : b == anchor ? false : (latest[a]!, a) > (latest[b]!, b) }
        return (shown, qs.map { q in
            Row(q: q, cells: shown.map { w in w.growth.first { $0.q == q }?.v },
                trend: trend(closed.compactMap { w in w.growth.first { $0.q == q }?.v }))
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
        let g = Growth.rows(store.weeks, anchor: store.settings.anchorQ)
        // always eight columns, newest on the right: the squares keep their size while the first weeks fill in
        let pad = max(0, 8 - g.weeks.count)
        VStack(alignment: .leading, spacing: 0) {
            if g.rows.isEmpty {
                Text("Your first rated review will show here.").font(Theme.serifItalic(17)).foregroundStyle(Theme.mu2).padding(.top, 24)
            } else {
                ForEach(Array(g.rows.enumerated()), id: \.element.id) { n, r in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(r.q).font(Theme.serif(17)).foregroundStyle(Theme.tx).lineLimit(2).multilineTextAlignment(.leading)
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
                    .padding(.top, 26).rise(n)
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
