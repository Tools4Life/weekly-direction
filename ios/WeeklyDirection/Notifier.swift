import Foundation
import UserNotifications

/// Local notifications that replace web push, with the same reminders and wording as the server's reminders.js:
/// 15 minutes before each start-by, 15 minutes before grace ends, when a timer finishes, 9 pm if habits are still open
/// (missed ones are skipped), and the weekly review at the close time. Rebuilt from the active week on every change.
/// The on/off choice is kept on this phone only; nothing is written to Firestore.
@MainActor
final class Notifier: ObservableObject {
    @Published var on = UserDefaults.standard.bool(forKey: "notifyOn")
    @Published var note = "Reminders from your week, even when the app is closed."
    private let center = UNUserNotificationCenter.current()
    private var token = 0

    func refresh() {
        center.getNotificationSettings { s in
            Task { @MainActor in
                let denied = s.authorizationStatus == .denied
                if denied { self.on = false }
                self.note = denied ? "Notifications are blocked: iPhone Settings › Notifications › Weekly Direction."
                    : "Reminders from your week, even when the app is closed."
            }
        }
    }

    func set(_ want: Bool, store: Store) async {
        if want {
            let ok = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            on = ok
            if !ok { refresh() }
        } else { on = false }
        UserDefaults.standard.set(on, forKey: "notifyOn")
        schedule(store: store)
    }

    /// debounced: data changes arrive in bursts
    func schedule(store: Store) {
        token += 1
        let t = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self, t == self.token, !store.isMock else { return }
            self.rebuild(week: store.activeWeek, settings: store.settings)
        }
    }

    struct Item { let id: String; let at: Date; let title: String; let body: String }

    /// every reminder still ahead for the week (pure, so it can be checked without a phone)
    static func plan(week w: Week, settings s: Settings, now: Date) -> [Item] {
        var out: [Item] = []
        let todayK = Rules.ymd(now), sealedK = Rules.ymd(w.sealedAt), end = Rules.weekEnd(w.sealedAt, s)
        for d in Rules.habitDays(w, s) {
            let k = Rules.ymd(d)
            guard k >= todayK, k >= sealedK else { continue }
            let habits = w.commitments.filter { Rules.onDay($0, d) }
            let open = { (c: Commitment) in !w.flag(k, c.id) && !w.flag(k, c.id + "@fail") }
            for c in habits where c.by != nil && open(c) && w.run(k, c.id) == nil {
                guard let by = Rules.byOf(w, k, c), let t = Rules.localDate(k, by) else { continue }
                out.append(Item(id: "by:\(k):\(c.id)", at: t.addingTimeInterval(-15 * 60), title: c.name, body: "Start by \(Fmt.clock(by)) — 15 minutes left."))
                if Rules.graceDay(k) {
                    let g = t.addingTimeInterval(Rules.graceSeconds)
                    out.append(Item(id: "grace:\(k):\(c.id)", at: g.addingTimeInterval(-15 * 60), title: c.name, body: "Grace ends at \(Fmt.clock(g)) — start now or it’s missed."))
                }
            }
            for c in w.commitments {
                if let r = w.run(k, c.id), let m = c.min, !w.flag(k, c.id) {
                    out.append(Item(id: "timer:\(k):\(c.id)", at: Date(timeIntervalSince1970: r / 1000 + Double(m) * 60), title: "\(c.name) · done", body: "Your \(m)-minute timer finished."))
                }
            }
            if let eve = Rules.localDate(k, "21:00") {
                let left = habits.filter { c in
                    guard open(c) else { return false }
                    if Rules.graceDay(k), c.by != nil, w.run(k, c.id) == nil, let by = Rules.byOf(w, k, c), let t = Rules.localDate(k, by),
                       eve > t.addingTimeInterval(Rules.graceSeconds) { return false }      // missed by then
                    return true
                }
                if !left.isEmpty {
                    out.append(Item(id: "eve:\(k)", at: eve, title: "Today isn’t finished",
                                    body: "\(left.count) habit\(left.count > 1 ? "s" : "") still open: \(left.map(\.name).joined(separator: ", "))."))
                }
            }
        }
        out.append(Item(id: "rev:\(Rules.ymd(end))", at: end, title: "Weekly review", body: "“\(w.focus)” is ready to close. Reflect, answer your questions, and plan the next week."))
        return out.filter { $0.at > now }.sorted { $0.at < $1.at }
    }

    private func rebuild(week: Week?, settings: Settings) {
        center.removeAllPendingNotificationRequests()
        guard on, let week else { return }
        // iOS keeps at most 64 pending requests; the soonest ones win and the list is rebuilt on every change
        for n in Self.plan(week: week, settings: settings, now: Date()).prefix(60) {
            let c = UNMutableNotificationContent()
            c.title = n.title; c.body = n.body; c.sound = .default
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: n.at)
            center.add(UNNotificationRequest(identifier: n.id, content: c, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
        }
    }
}
