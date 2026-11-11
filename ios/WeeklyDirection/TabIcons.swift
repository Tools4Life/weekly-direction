import SwiftUI

/// Tab bar icons drawn on the web app's 24-point grid with one stroke, so all four belong together.
/// `framed` puts each glyph in the web's rounded square (its own tab icons do this); `.circle` echoes the mic.
struct TabIcon: View {
    enum Frame { case square, circle, none }
    let name: String          // week | reflect | prayer | progress
    var frame: Frame = .square
    var size: CGFloat = 27
    /// prayer mark: cross | flame | hands | heart
    var prayer = "cross"

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
            case .none: break
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
                func curve(_ to: (CGFloat, CGFloat), _ c1: (CGFloat, CGFloat), _ c2: (CGFloat, CGFloat)) {
                    path.addCurve(to: p(to.0, to.1), control1: p(c1.0, c1.1), control2: p(c2.0, c2.1))
                }
                switch prayer {
                case "flame":
                    path.move(to: p(12, 6.9))
                    curve((15.3, 13.4), (13.2, 8.7), (15.3, 10.7)); curve((12, 17), (15.3, 15.5), (13.9, 17))
                    curve((8.7, 13.4), (10.1, 17), (8.7, 15.5)); curve((12, 6.9), (8.7, 10.7), (10.8, 8.7))
                case "hands":
                    line([(9.2, 16.9), (9.2, 12.2), (12, 7)]); line([(14.8, 16.9), (14.8, 12.2), (12, 7)]); line([(12, 7), (12, 13.2)])
                case "heart":
                    path.move(to: p(12, 16.7))
                    curve((7.9, 11.1), (9.4, 15.1), (7.9, 13.2)); curve((12, 9.7), (7.9, 8.5), (10.9, 8))
                    curve((16.1, 11.1), (13.1, 8), (16.1, 8.5)); curve((12, 16.7), (16.1, 13.2), (14.6, 15.1))
                default:
                    line([(12, 7.2), (12, 16.8)]); line([(8.9, 10.4), (15.1, 10.4)])
                }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Tab icons").font(Theme.serif(34)).foregroundStyle(Theme.tx).padding(.bottom, 6)
            Text("Squares are in. The cross clashes with the app icon, so here are other marks for Prayer.")
                .font(Theme.ui(14)).foregroundStyle(Theme.mu)
            Eyebrow(text: "Prayer icon options", color: Theme.mu).padding(.top, 34)
            HStack {
                ForEach(["flame", "hands", "heart", "cross"], id: \.self) { g in
                    VStack(spacing: 10) {
                        TabIcon(name: "prayer", size: 44, prayer: g).foregroundStyle(Theme.tx)
                        Text(g == "cross" ? "cross (now)" : g).font(Theme.ui(14)).foregroundStyle(Theme.mu)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 22)
            Eyebrow(text: "In the bar", color: Theme.mu).padding(.top, 40)
            ForEach(["flame", "hands", "heart"], id: \.self) { g in
                HStack {
                    ForEach(tabs, id: \.self) { n in
                        Group {
                            if n == "mic" {
                                ZStack { Circle().fill(Theme.ac).frame(width: 52, height: 52); Image(systemName: "mic").font(.system(size: 21)).foregroundStyle(Theme.onAc) }
                            } else { TabIcon(name: n, size: 30, prayer: g).foregroundStyle(n == "week" ? Theme.tx : Theme.mu2) }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 70).padding(.horizontal, -10)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
            }
            Spacer()
        }
        .padding(.horizontal, 24).padding(.top, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.bg.ignoresSafeArea())
    }
}
