import SwiftUI

/// Tab bar icons drawn on the web app's 24-point grid with one stroke, so all four belong together.
/// `framed` puts each glyph in the web's rounded square (its own tab icons do this); `.circle` echoes the mic.
struct TabIcon: View {
    enum Frame { case square, circle }
    let name: String          // week | reflect | prayer | progress
    var frame: Frame = .square
    var size: CGFloat = 27

    var body: some View {
        Canvas { ctx, sz in
            let k = sz.width / 24
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * k, y: y * k) }
            var path = Path()
            func line(_ pts: [(CGFloat, CGFloat)]) {
                path.move(to: p(pts[0].0, pts[0].1))
                for q in pts.dropFirst() { path.addLine(to: p(q.0, q.1)) }
            }
            switch frame {
            case .square: path.addRoundedRect(in: CGRect(x: 3.5 * k, y: 3.5 * k, width: 17 * k, height: 17 * k), cornerSize: CGSize(width: 4 * k, height: 4 * k), style: .continuous)
            case .circle: path.addEllipse(in: CGRect(x: 3 * k, y: 3 * k, width: 18 * k, height: 18 * k))
            }
            switch name {
            case "week":
                if frame == .square {
                    line([(3.5, 8.8), (20.5, 8.8)]); line([(8.5, 2.5), (8.5, 5.1)]); line([(15.5, 2.5), (15.5, 5.1)])
                    line([(9.2, 14.4), (11.2, 16.4), (15, 12.6)])
                } else { line([(8.4, 12.3), (11, 14.9), (15.8, 9.6)]) }
            case "reflect":
                line([(8, 9), (16, 9)]); line([(8, 12), (16, 12)]); line([(8, 15), (12.8, 15)])
            case "prayer":
                line([(12, 7.2), (12, 16.8)]); line([(8.9, 10.4), (15.1, 10.4)])
            default:
                line([(7.2, 15), (10.3, 11.7), (12.9, 14.1), (16.8, 9.5)])
            }
            ctx.stroke(path, with: .foreground, style: StrokeStyle(lineWidth: 1.55 * k, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}

/// Design finding (-OpenScreen icons, sample data only): the tab icon options side by side.
struct IconOptions: View {
    private let tabs = ["week", "reflect", "mic", "prayer", "progress"]
    private let sf = ["week": "calendar.badge.checkmark", "reflect": "book", "prayer": "hands.sparkles", "progress": "chart.line.uptrend.xyaxis"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Tab icons").font(Theme.serif(34)).foregroundStyle(Theme.tx).padding(.bottom, 6)
            Text("Order: This Week, Journal, mic, Prayer, Progress. First icon shown selected.")
                .font(Theme.ui(14)).foregroundStyle(Theme.mu)
            row("Now · iOS symbols") { n in AnyView(Image(systemName: sf[n]!).font(.system(size: 25))) }
            row("A · Squares (the web app's family)") { n in AnyView(TabIcon(name: n, frame: .square)) }
            row("B · Circles (echo the mic)") { n in AnyView(TabIcon(name: n, frame: .circle)) }
            Spacer()
        }
        .padding(.horizontal, 24).padding(.top, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.bg.ignoresSafeArea())
    }

    private func row(_ title: String, _ icon: @escaping (String) -> AnyView) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: title, color: Theme.mu).padding(.top, 34)
            HStack {
                ForEach(tabs, id: \.self) { n in
                    Group {
                        if n == "mic" {
                            ZStack {
                                Circle().fill(Theme.ac.opacity(0.18)).frame(width: 70, height: 70)
                                Circle().fill(Theme.ac).frame(width: 60, height: 60)
                                Image(systemName: "mic").font(.system(size: 24)).foregroundStyle(Theme.onAc)
                            }
                        } else {
                            icon(n).foregroundStyle(n == "week" ? Theme.tx : Theme.mu2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 76)
            .padding(.horizontal, -10)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
        }
    }
}
