import SwiftUI

/// Today's habits for the active week, with the same states the web app shows. Read-only in this build.
struct ThisWeekView: View {
    @EnvironmentObject var store: Store
    @State private var now = Date()
    private let tick = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let w = store.activeWeek {
                    header(w)
                    let k = Rules.ymd(now)
                    let items = Rules.items(w, on: now)
                    if !Rules.habitDays(w, store.settings).contains(where: { Rules.ymd($0) == k }) {
                        Text("No habits today.").foregroundStyle(Theme.mu)
                    } else if items.isEmpty {
                        Text("Nothing planned for today.").foregroundStyle(Theme.mu)
                    } else {
                        ForEach(items) { c in HabitRow(week: w, day: k, c: c, now: now) }
                    }
                } else {
                    Text("No active week. Plan one in the web app for now.")
                        .foregroundStyle(Theme.mu)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
        }
        .background(Theme.bg)
        .onReceive(tick) { now = $0 }
    }

    private func header(_ w: Week) -> some View {
        let end = Rules.weekEnd(w.sealedAt, store.settings)
        return VStack(alignment: .leading, spacing: 6) {
            Text(w.focus).font(Theme.serif(44)).foregroundStyle(Theme.tx)
            Eyebrow(text: "This week · " + range(w.sealedAt, end), color: Theme.ac)
        }
        .padding(.bottom, 6)
    }

    private func range(_ a: Date, _ b: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM d"
        let g = DateFormatter(); g.dateFormat = Calendar.current.isDate(a, equalTo: b, toGranularity: .month) ? "d" : "MMM d"
        return "\(f.string(from: a)) — \(g.string(from: b))"
    }
}

struct HabitRow: View {
    let week: Week
    let day: String
    let c: Commitment
    let now: Date

    var body: some View {
        let st = Rules.state(week, day, c, now: now)
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(st == .done ? Theme.ac : Theme.card2)
                if st == .done { Image(systemName: "checkmark").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.onAc) }
                if st == .fail || st == .miss { Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.mu2) }
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(c.name).font(.system(size: 17, weight: .medium)).foregroundStyle(st == .miss || st == .fail ? Theme.mu2 : Theme.tx)
                if let s = subtitle(st) { Text(s).font(.footnote).foregroundStyle(st == .grace ? Theme.ac : Theme.mu) }
            }
            Spacer()
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
    }

    private func subtitle(_ st: HabitState) -> String? {
        switch st {
        case .done: return week.flag(day, c.id + "@grace") ? "Done · in grace" : "Done"
        case .fail: return "Failed"
        case .miss: return "Missed"
        case .late: return "Late"
        case .grace:
            if let dl = Rules.deadline(day, c, week) {
                let left = dl.addingTimeInterval(Rules.graceSeconds).timeIntervalSince(now)
                return "Grace · \(Int(left / 60)) min left"
            }
            return "Grace"
        case .run: return "Running"
        case .fin: return "Time's up · tap to finish"
        case .open:
            if let b = Rules.byOf(week, day, c) { return "Start by \(clock(b))" }
            return nil
        }
    }

    private func clock(_ hm: String) -> String {
        let p = hm.split(separator: ":").compactMap { Int($0) }
        guard p.count == 2 else { return hm }
        let h = p[0] % 12 == 0 ? 12 : p[0] % 12
        return String(format: "%d:%02d %@", h, p[1], p[0] < 12 ? "am" : "pm")
    }
}
