import SwiftUI

extension WidgetSnapshot {
    private static let dayFormat: DateFormatter = { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f }()
    /// the habits as they stand at `date`: an open one past its grace is missed; on another day the states are unknown
    func habits(at date: Date) -> [Habit] {
        let today = Self.dayFormat.string(from: date) == day
        return habits.map { h in
            var x = h
            if !today { x.state = "open"; x.missAt = nil }
            else if x.state == "open", let m = x.missAt, date >= m { x.state = "miss" }
            return x
        }
    }
}

/// The This Week widget's layouts. Plain SwiftUI so the app can show the same views in sample-data mode
/// (`-OpenScreen widgets`) for screenshots; the extension wraps it with the widget background.
struct WeekWidgetBody: View {
    enum Size { case small, medium, large, lock }
    let snap: WidgetSnapshot?
    let date: Date
    let size: Size

    private var p: WPalette { WPalette.of(light: snap?.light ?? false) }
    private func serif(_ s: CGFloat) -> Font { .custom("Fraunces-Regular", size: s) }
    private func italic(_ s: CGFloat) -> Font { .custom("Fraunces-Italic", size: s) }
    private func label(_ s: CGFloat) -> Font { .custom("BarlowCondensed-Medium", size: s) }
    private func caps(_ s: CGFloat) -> Font { .custom("BarlowCondensed-SemiBold", size: s) }

    var body: some View {
        if let s = snap {
            let hs = s.habits(at: date)
            switch size {
            case .small: small(s, hs)
            case .medium: medium(s, hs)
            case .lock: lock(s, hs)
            case .large: large(s, hs)
            }
        } else { empty }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WEEKLY DIRECTION").font(label(11)).tracking(2.2).foregroundStyle(p.ac)
            Text("Plan the week").font(serif(22)).foregroundStyle(p.tx)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func eyebrow(_ s: WidgetSnapshot) -> some View {
        Text((s.reviewDue ? "REVIEW DUE" : "THIS WEEK · \(s.range)").uppercased()).font(label(11)).tracking(2.2).foregroundStyle(p.ac).lineLimit(1)
    }

    private func count(_ hs: [WidgetSnapshot.Habit]) -> String { "\(hs.filter { $0.state == "done" }.count) of \(hs.count) today" }

    /// one square per habit, in the app's day-square language
    private func squares(_ hs: [WidgetSnapshot.Habit]) -> some View {
        HStack(spacing: 5) {
            ForEach(Array(hs.prefix(7).enumerated()), id: \.offset) { _, h in
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(h.state == "done" ? p.ac : h.state == "run" ? p.acDim : p.card)
                    .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(h.state == "miss" || h.state == "fail" ? p.line : h.state == "done" ? Color.clear : p.line,
                                style: StrokeStyle(lineWidth: 1, dash: h.state == "miss" || h.state == "fail" ? [3, 3] : [])))
                    .frame(maxWidth: 26).frame(height: 20)
            }
        }
    }

    private func row(_ h: WidgetSnapshot.Habit, size: CGFloat, time: Bool = true) -> some View {
        let off = h.state == "miss" || h.state == "fail"
        return HStack(spacing: 9) {
            Image(systemName: h.symbol).font(.system(size: size - 1, weight: .light)).foregroundStyle(h.state == "done" ? p.tx : p.mu).frame(width: size + 6)
            Text(h.name.uppercased()).font(caps(size)).tracking(size * 0.1).foregroundStyle(off ? p.mu2 : p.tx).lineLimit(1)
                .strikethrough(off, color: p.mu2)
            Spacer(minLength: 4)
            if time, !h.meta.isEmpty, h.state == "open" { Text(h.meta).font(label(size - 2)).foregroundStyle(p.mu2).lineLimit(1) }
            ZStack {
                if h.state == "done" {
                    Circle().fill(p.tx)
                    Image(systemName: "checkmark").font(.system(size: size * 0.55, weight: .bold)).foregroundStyle(p.bg)
                } else if off {
                    Circle().stroke(p.mu2, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    Image(systemName: "xmark").font(.system(size: size * 0.5)).foregroundStyle(p.mu2)
                } else {
                    Circle().stroke(h.state == "run" ? p.ac : p.mu, lineWidth: 1.2)
                }
            }
            .frame(width: size + 3, height: size + 3)
        }
    }

    private func small(_ s: WidgetSnapshot, _ hs: [WidgetSnapshot.Habit]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(s.reviewDue ? "REVIEW DUE" : "THIS WEEK").font(label(11)).tracking(2.2).foregroundStyle(p.ac)
            Text(s.focus).font(serif(27)).foregroundStyle(p.tx).lineLimit(1).minimumScaleFactor(0.6).padding(.top, 2)
            Spacer(minLength: 6)
            squares(hs)
            Text(count(hs).uppercased()).font(label(11)).tracking(1.6).foregroundStyle(p.mu).padding(.top, 7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func medium(_ s: WidgetSnapshot, _ hs: [WidgetSnapshot.Habit]) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                Text(s.reviewDue ? "REVIEW DUE" : "THIS WEEK").font(label(11)).tracking(2.2).foregroundStyle(p.ac)
                Text(s.focus).font(serif(26)).foregroundStyle(p.tx).lineLimit(1).minimumScaleFactor(0.6).padding(.top, 2)
                if !s.verseRef.isEmpty { Text(s.verseRef.uppercased()).font(label(11)).tracking(1.8).foregroundStyle(p.mu2).padding(.top, 4) }
                Spacer(minLength: 6)
                Link(destination: Shared.dictateURL) {
                    HStack(spacing: 6) {
                        Image(systemName: "mic").font(.system(size: 12, weight: .medium))
                        Text("DICTATE").font(caps(12)).tracking(1.6)
                    }
                    .foregroundStyle(p.onAc).padding(.horizontal, 11).frame(height: 28).background(p.ac, in: Capsule())
                }
            }
            .frame(width: 118, alignment: .leading)
            // the habits share the full height evenly, first at the top edge and last at the bottom, however many there are
            VStack(alignment: .leading, spacing: 0) {
                let shown = Array(hs.prefix(4))
                ForEach(Array(shown.enumerated()), id: \.offset) { i, h in
                    row(h, size: 13, time: false)
                    if i < shown.count - 1 { Spacer(minLength: 4) }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func large(_ s: WidgetSnapshot, _ hs: [WidgetSnapshot.Habit]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            eyebrow(s)
            Text(s.focus).font(serif(38)).foregroundStyle(p.tx).lineLimit(1).minimumScaleFactor(0.6).padding(.top, 2)
            if !s.verse.isEmpty {
                Text(s.verse).font(italic(15)).lineSpacing(3).foregroundStyle(p.tx.opacity(0.92)).lineLimit(3).padding(.top, 6)
            }
            if !s.verseRef.isEmpty { Text(s.verseRef.uppercased()).font(label(11)).tracking(2).foregroundStyle(p.mu2).padding(.top, 5) }
            Rectangle().fill(p.line).frame(height: 1).padding(.vertical, 12)
            VStack(alignment: .leading, spacing: 10) { ForEach(Array(hs.prefix(5).enumerated()), id: \.offset) { _, h in row(h, size: 15) } }
            Spacer(minLength: 8)
            HStack {
                Text(count(hs).uppercased()).font(label(12)).tracking(1.8).foregroundStyle(p.mu)
                Spacer()
                // the one thing this widget does besides show the week: straight into dictation
                Link(destination: Shared.dictateURL) {
                    HStack(spacing: 8) {
                        Image(systemName: "mic").font(.system(size: 15, weight: .medium))
                        Text("DICTATE").font(caps(14)).tracking(1.8)
                    }
                    .foregroundStyle(p.onAc).padding(.horizontal, 16).frame(height: 38).background(p.ac, in: Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func lock(_ s: WidgetSnapshot, _ hs: [WidgetSnapshot.Habit]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(s.focus).font(serif(18)).lineLimit(1)
            Text(count(hs).uppercased()).font(label(12)).tracking(1.4)
            HStack(spacing: 4) {
                ForEach(Array(hs.prefix(7).enumerated()), id: \.offset) { _, h in
                    RoundedRectangle(cornerRadius: 3).fill(.primary.opacity(h.state == "done" ? 1 : 0.25)).frame(width: 14, height: 9)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

