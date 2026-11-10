import Foundation
import WidgetKit
import ActivityKit
import SwiftUI

/// App side of the widgets and the timer Live Activity (Nov 10 2026). Called whenever the weeks or settings change and
/// when the app goes to the background: it writes what the widgets show into the App Group and keeps the Dynamic Island
/// timer in step with the habit timer that is actually running. Read-only towards the week: nothing here writes habit data.
@MainActor
enum WidgetBridge {
    private static var last: WidgetSnapshot?

    static func sync(_ store: Store) {
        guard !store.isMock else { return }
        publish(store)
        timer(store)
    }

    /// signed out: the widgets go back to their empty state and any timer on the Lock Screen is removed
    static func clear() {
        WidgetSnapshot.clear(); last = nil
        WidgetCenter.shared.reloadAllTimelines()
        Task { for a in Activity<TimerAttributes>.activities { await a.end(nil, dismissalPolicy: .immediate) } }
    }

    static func snapshot(_ store: Store, now: Date = Now.date) -> WidgetSnapshot? {
        guard let w = store.activeWeek else { return nil }
        let s = store.settings, k = Rules.ymd(now)
        let day = Rules.habitDays(w, s).first { Rules.ymd($0) == k }
        let habits: [WidgetSnapshot.Habit] = w.commitments.filter { c in day.map { Rules.onDay(c, $0) } ?? true }.map { c in
            let st = day == nil ? HabitState.open : Rules.state(w, k, c, now: now)
            let state = st == .done ? "done" : st == .fail ? "fail" : st == .miss ? "miss" : st == .run || st == .fin ? "run" : "open"
            let by = day == nil ? nil : Rules.byOf(w, k, c).map(Fmt.clock)
            return .init(name: c.name, symbol: Theme.symbol(c.icon), state: state, meta: by ?? c.min.map { "\($0) min" } ?? "",
                         missAt: day == nil ? nil : Rules.deadline(k, c, w).map { $0.addingTimeInterval(Rules.graceSeconds) })
        }
        let light = s.theme == "light"
        return WidgetSnapshot(focus: w.focus, range: Fmt.weekRange(w, s), verse: w.verse ?? "", verseRef: w.verseRef ?? "", day: k,
                              habits: habits, light: light, reviewDue: now >= Rules.weekEnd(w.sealedAt, s))
    }

    private static func publish(_ store: Store) {
        let snap = snapshot(store)
        guard snap != last else { return }
        last = snap
        if let snap { snap.save() } else { WidgetSnapshot.clear() }
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// one Live Activity for the habit timer that is running today, none otherwise
    private static func timer(_ store: Store) {
        let now = Now.date, k = Rules.ymd(now)
        var want: (TimerAttributes, TimerAttributes.ContentState)?
        if let w = store.activeWeek {
            for c in w.commitments {
                guard let m = c.min, let r = w.run(k, c.id), Rules.state(w, k, c, now: now) == .run else { continue }
                let start = Date(timeIntervalSince1970: r / 1000), end = start.addingTimeInterval(Double(m) * 60)
                if end > now { want = (TimerAttributes(habit: c.name, symbol: Theme.symbol(c.icon), minutes: m), .init(startedAt: start, endsAt: end)); break }
            }
        }
        let running = Activity<TimerAttributes>.activities
        if let (attr, state) = want {
            if running.contains(where: { $0.attributes.habit == attr.habit && $0.content.state == state }) { return }
            Task {
                for a in running { await a.end(nil, dismissalPolicy: .immediate) }
                guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
                // stale at the end time: the Lock Screen then shows Done until the app next opens and removes it
                _ = try? Activity.request(attributes: attr, content: .init(state: state, staleDate: state.endsAt))
            }
        } else if !running.isEmpty {
            Task { for a in running { await a.end(nil, dismissalPolicy: .immediate) } }
        }
    }
}
