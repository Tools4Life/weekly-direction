import Foundation

// Mirrors the web app's Firestore documents (users/{uid}/weeklyDirection/...).
// Decoded loosely from dictionaries so a field the web app adds later never breaks the native app.

struct Commitment: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String?
    /// "HH:mm" start-by on weekdays, or nil
    let by: String?
    /// "HH:mm" start-by on Saturday and Sunday, if different
    let byWe: String?
    /// "wd" = weekdays only, "we" = weekends only, nil = every day
    let days: String?
    /// minutes for a timed habit
    let min: Int?

    init?(_ d: [String: Any]) {
        guard let id = d["id"] as? String, let name = d["name"] as? String else { return nil }
        self.id = id
        self.name = name
        icon = d["icon"] as? String
        by = (d["by"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        byWe = (d["byWe"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        days = d["days"] as? String
        min = (d["min"] as? NSNumber)?.intValue
    }
}

struct Week: Identifiable {
    let id: String
    let focus: String
    let verse: String?
    let verseRef: String?
    let status: String          // "active" | "closed"
    let sealedAt: Date
    let commitments: [Commitment]
    /// done[dayKey][habitId or habitId@flag]
    let done: [String: [String: Any]]
    /// runs[dayKey][habitId] = start time in ms
    let runs: [String: [String: Double]]
    let liveRefl: String
    let reflection: String
    let summary: String?

    var isActive: Bool { status == "active" }

    init?(id: String, _ d: [String: Any]) {
        guard let sealed = (d["sealedAt"] as? NSNumber)?.doubleValue else { return nil }
        self.id = id
        focus = d["focus"] as? String ?? ""
        verse = d["verse"] as? String
        verseRef = d["verseRef"] as? String
        status = d["status"] as? String ?? "closed"
        sealedAt = Date(timeIntervalSince1970: sealed / 1000)
        commitments = (d["commitments"] as? [[String: Any]] ?? []).compactMap(Commitment.init)
        done = d["done"] as? [String: [String: Any]] ?? [:]
        var r: [String: [String: Double]] = [:]
        for (k, v) in d["runs"] as? [String: [String: Any]] ?? [:] {
            r[k] = v.compactMapValues { ($0 as? NSNumber)?.doubleValue }
        }
        runs = r
        liveRefl = d["liveRefl"] as? String ?? ""
        reflection = d["reflection"] as? String ?? ""
        summary = d["summary"] as? String
    }

    func flag(_ day: String, _ key: String) -> Bool {
        (done[day]?[key] as? Bool) ?? false
    }
    func value(_ day: String, _ key: String) -> Any? { done[day]?[key] }
}

struct Settings {
    var closeDay = 6      // 0 = Sunday ... 6 = Saturday
    var closeHour = 17

    init(_ d: [String: Any] = [:]) {
        closeDay = (d["closeDay"] as? NSNumber)?.intValue ?? 6
        closeHour = (d["closeHour"] as? NSNumber)?.intValue ?? 17
    }
}
