import SwiftUI

/// Design finding, sample-data mode only (`-OpenScreen growth-a | growth-b | growth-rate`, Nov 10 2026): growth read
/// from the weekly reflections. Nothing here reads or writes real data; the numbers below are made up for the mockup.
/// A = the app's own square language in one colour (full = better, half = same, empty = worse).
/// B = green / grey / red, as Eddie first described it.
struct GrowthMock: View {
    let screen: String
    private var green: Bool { screen == "growth-b" || UserDefaults.standard.string(forKey: "MockGrowth") == "b" }

    static let good = Color(hex: 0x4F9D6E), bad = Color(hex: 0xC8553F)
    /// 1 better, 0 same, -1 worse, nil not spoken about (or not asked that week)
    static let rows: [(q: String, v: [Int?])] = [
        ("Are temptations weaker, or easier to refuse?", [-1, -1, 0, 0, 1, 0, 1, 1]),
        ("Is it easier to get into His presence and worship with a free mind?", [0, 1, 1, 0, 1, 1, nil, 1]),
        ("Am I more present: with God in the morning, at work, at home?", [-1, 0, -1, 0, 0, 1, 1, 0]),
        ("Did I show up for morning devotion, even on the hard days?", [nil, nil, 1, 1, 0, -1, 0, 1])
    ]
    static let weeks = ["9/19", "9/26", "10/3", "10/10", "10/17", "10/24", "10/31", "11/7"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) { if screen == "growth-rate" { rate } else { grid } }
                .fullWidth().padding(.horizontal, 24).padding(.top, 30).padding(.bottom, 40)
        }
        .background(Theme.bg.ignoresSafeArea())
    }

    // MARK: the grid on Progress

    @ViewBuilder private var grid: some View {
        Text("Growth").title(34).foregroundStyle(Theme.tx)
        Eyebrow(text: "From your reflections · last 8 weeks", color: Theme.mu2).padding(.top, 6)
        ForEach(Array(Self.rows.enumerated()), id: \.offset) { _, r in
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(r.q).font(Theme.serif(17)).foregroundStyle(Theme.tx).lineLimit(2)
                    Spacer(minLength: 10)
                    let t = trend(r.v)
                    Text(t.0).font(Theme.label(13)).tracking(1.4).textCase(.uppercase)
                        .foregroundStyle(green ? (t.1 > 0 ? Self.good : t.1 < 0 ? Self.bad : Theme.mu2) : (t.1 > 0 ? Theme.ac : Theme.mu2))
                }
                HStack(spacing: 6) {
                    ForEach(Array(r.v.enumerated()), id: \.offset) { _, v in square(v).frame(maxWidth: .infinity).frame(height: 26) }
                }
            }
            .padding(.top, 28)
        }
        HStack(spacing: 6) {
            ForEach(Self.weeks, id: \.self) { w in
                Text(w).font(Theme.label(11)).foregroundStyle(Theme.mu2).frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 10)
        HStack(spacing: 16) {
            legend(1, "Better"); legend(0, "Same"); legend(-1, "Worse"); legend(nil, "Not said")
        }
        .padding(.top, 30)
    }

    private func legend(_ v: Int?, _ t: String) -> some View {
        HStack(spacing: 7) { square(v).frame(width: 18, height: 16); Text(t).font(Theme.label(12)).tracking(1.2).textCase(.uppercase).foregroundStyle(Theme.mu) }
    }

    /// the last three spoken weeks against the three before
    private func trend(_ v: [Int?]) -> (String, Int) {
        let s = v.compactMap { $0 }
        guard s.count >= 4 else { return ("new", 0) }
        let late = s.suffix(3).reduce(0, +), early = s.dropLast(3).suffix(3).reduce(0, +)
        return late > early ? ("improving", 1) : late < early ? ("slipping", -1) : ("steady", 0)
    }

    @ViewBuilder private func square(_ v: Int?) -> some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        if green {
            switch v {
            case 1: shape.fill(Self.good)
            case 0: shape.fill(Theme.line)
            case -1: shape.fill(Self.bad)
            default: shape.stroke(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        } else {
            switch v {
            case 1: shape.fill(Theme.ac)
            case 0: shape.fill(Theme.card2).overlay(alignment: .bottom) { Rectangle().fill(Theme.acDim).frame(height: 13) }.clipShape(shape)
                .overlay(shape.stroke(Theme.acDim, lineWidth: 1))
            case -1: shape.fill(Theme.card2).overlay(shape.stroke(Theme.line, lineWidth: 1))
            default: shape.stroke(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
    }

    // MARK: confirming the ratings at the review

    private static let said = ["I caught it twice before it went anywhere. Thursday night was the hard one.",
                               "Worship was freer Sunday. Midweek my mind was on the job site.",
                               "At home, yes. Mornings with God were rushed."]

    @ViewBuilder private var rate: some View {
        Eyebrow(text: "Nov 7 – 14", color: Theme.mu2)
        Text("How did it go?").title(30).foregroundStyle(Theme.tx).padding(.top, 6)
        ForEach(0..<3, id: \.self) { i in
            VStack(alignment: .leading, spacing: 10) {
                Text(Self.rows[i].q).font(Theme.serif(18)).lineSpacing(3).foregroundStyle(Theme.tx)
                Text("“\(Self.said[i])”").font(Theme.serifItalic(15)).lineSpacing(3).foregroundStyle(Theme.mu)
                HStack(spacing: 8) {
                    pick("Worse", -1, on: [1, 0, 0][i] == -1)
                    pick("Same", 0, on: [1, 0, 0][i] == 0)
                    pick("Better", 1, on: [1, 0, 0][i] == 1)
                }
                .padding(.top, 2)
            }
            .padding(.top, 26)
        }
        Text("Close the week").caps(16).foregroundStyle(Theme.onAc).frame(maxWidth: .infinity).frame(height: 52)
            .background(Theme.ac, in: RoundedRectangle(cornerRadius: 14, style: .continuous)).padding(.top, 34)
    }

    private func pick(_ t: String, _ v: Int, on: Bool) -> some View {
        let c: Color = green ? (v > 0 ? Self.good : v < 0 ? Self.bad : Theme.mu) : (v > 0 ? Theme.ac : Theme.mu)
        return Text(t).caps(14).foregroundStyle(on ? (v == 0 && !green ? Theme.tx : (green || v > 0 ? Theme.onAc : Theme.tx)) : Theme.mu2)
            .frame(maxWidth: .infinity).frame(height: 40)
            .background(on ? (v == 0 ? Theme.card2 : (!green && v < 0 ? Theme.card2 : c)) : Color.clear, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(on ? (v == 0 || (!green && v < 0) ? Theme.mu2 : c) : Theme.line, lineWidth: 1))
    }
}
