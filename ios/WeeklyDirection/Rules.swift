import Foundation

// A line-for-line port of the web app's habit rules (index.html: onDay, baseBy, byOf, deadline, hState, weekEnd, habitDays).
// The record is strict, so these must match the web app exactly; change both together.

enum HabitState: String {
    case done, fail, run, fin, open, grace, miss, late
}

/// The current time. Fixed only by the snapshot mode (sample data rendered at the spec's "today"); otherwise the real clock.
enum Now {
    static var fixed: Date?
    static var date: Date { fixed ?? Date() }
    static var ms: Double { date.timeIntervalSince1970 * 1000 }
}

enum Rules {
    static let graceFrom = "2026-11-08"
    static let graceSeconds: TimeInterval = 2 * 3600
    /// weeks sealed from Nov 2 2026 on also do habits on the review day
    static let sealRule2 = localDate("2026-11-02", "00:00")!

    static var cal: Calendar { Calendar.current }

    /// "yyyy-MM-dd" in local time, the web app's day key
    static func ymd(_ d: Date) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    static func localDate(_ day: String, _ hm: String) -> Date? {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return f.date(from: "\(day)T\(hm)")
    }

    static func graceDay(_ k: String) -> Bool { k >= graceFrom }

    /// 0 = Sunday ... 6 = Saturday, like JavaScript's getDay()
    static func weekday(_ d: Date) -> Int { cal.component(.weekday, from: d) - 1 }

    static func onDay(_ c: Commitment, _ day: Date) -> Bool {
        guard let days = c.days else { return true }
        let wd = weekday(day)
        return (days == "wd") == (wd > 0 && wd < 6)
    }

    static func baseBy(_ k: String, _ c: Commitment) -> String? {
        guard let by = c.by else { return nil }
        let d = weekday(localDate(k, "12:00")!)
        if (d == 0 || d == 6), let we = c.byWe { return we }
        return by
    }

    static func byOf(_ w: Week, _ k: String, _ c: Commitment) -> String? {
        guard c.by != nil else { return nil }
        if let rs = w.value(k, c.id + "@rs") as? String, !rs.isEmpty { return rs }
        return baseBy(k, c)
    }

    /// on the sealing day, a start-by (plus grace) that had already passed before sealing doesn't apply
    static func deadline(_ k: String, _ c: Commitment, _ w: Week) -> Date? {
        guard let b = byOf(w, k, c), let t = localDate(k, b) else { return nil }
        if k == ymd(w.sealedAt), t.addingTimeInterval(graceDay(k) ? graceSeconds : 0) < w.sealedAt { return nil }
        return t
    }

    static func state(_ w: Week, _ k: String, _ c: Commitment, now: Date = Now.date) -> HabitState {
        if w.flag(k, c.id + "@fail") { return .fail }
        if w.flag(k, c.id) { return .done }
        if let r = w.run(k, c.id), let m = c.min {
            let start = Date(timeIntervalSince1970: r / 1000)
            return now >= start.addingTimeInterval(TimeInterval(m * 60)) ? .fin : .run
        }
        guard let dl = deadline(k, c, w), now > dl else { return .open }
        if !graceDay(k) { return .late }
        return now > dl.addingTimeInterval(graceSeconds) ? .miss : .grace
    }

    static func weekEnd(_ start: Date, _ s: Settings) -> Date {
        var d = start.addingTimeInterval(3600)
        d = cal.date(bySettingHour: s.closeHour, minute: 0, second: 0, of: d)!
        let add = (s.closeDay - weekday(d) + 7) % 7
        d = cal.date(byAdding: .day, value: add, to: d)!
        if d <= start.addingTimeInterval(3600) { d = cal.date(byAdding: .day, value: 7, to: d)! }
        return d
    }

    static func habitDays(_ w: Week, _ s: Settings) -> [Date] {
        let start = w.sealedAt, end = weekEnd(start, s)
        var d = start
        let skipFirst = start >= sealRule2 ? weekday(start) == s.closeDay : cal.component(.hour, from: start) >= 12
        if skipFirst { d = cal.date(byAdding: .day, value: 1, to: d)! }
        d = cal.date(bySettingHour: 12, minute: 0, second: 0, of: d)!
        let last = cal.date(bySettingHour: 12, minute: 0, second: 0, of: end)!
        let incl = start >= sealRule2
        var out: [Date] = []
        while (incl ? d <= last : d < last) && out.count < 14 {
            out.append(d)
            d = cal.date(byAdding: .day, value: 1, to: d)!
        }
        return out
    }

    static func items(_ w: Week, on day: Date) -> [Commitment] {
        w.commitments.filter { onDay($0, day) }
    }
}
