import Foundation

// Mirrors the web app's Firestore documents (users/{uid}/weeklyDirection/...).
// Decoded loosely from dictionaries so a field the web app adds later never breaks the native app.
// Each model keeps its raw dictionary: writes that replace an array (commitments) carry unknown fields through.

func intOf(_ v: Any?) -> Int? { (v as? NSNumber)?.intValue }
func msOf(_ v: Any?) -> Double? { (v as? NSNumber)?.doubleValue }
func strOf(_ v: Any?) -> String? { (v as? String).flatMap { $0.isEmpty ? nil : $0 } }

struct Commitment: Identifiable, Equatable {
    let id: String
    let chipId: String?
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
    let about: String?
    let raw: [String: Any]

    init?(_ d: [String: Any]) {
        guard let id = d["id"] as? String, let name = d["name"] as? String else { return nil }
        self.id = id
        self.name = name
        chipId = strOf(d["chipId"])
        icon = strOf(d["icon"])
        by = strOf(d["by"])
        byWe = strOf(d["byWe"])
        let dd = d["days"] as? String
        days = dd == "wd" || dd == "we" ? dd : nil
        min = intOf(d["min"]).flatMap { $0 > 0 ? $0 : nil }
        about = strOf(d["about"])
        raw = d
    }

    static func == (a: Commitment, b: Commitment) -> Bool { a.id == b.id && NSDictionary(dictionary: a.raw).isEqual(to: b.raw) }
}

struct Week: Identifiable, Equatable {
    let id: String
    let focus: String
    let verse: String?
    let verseRef: String?
    let status: String          // "active" | "closed"
    let sealedAtMs: Double
    let sealedAt: Date
    let closedAt: Date?
    let percentage: Int?
    let planThoughts: String
    let commitments: [Commitment]
    /// the week's own Saturday questions, if it has a set
    let qs: [String]?
    /// done[dayKey][habitId or habitId@flag]
    let done: [String: [String: Any]]
    /// marks[dayKey] = "on" | "drift"
    let marks: [String: String]
    /// runs[dayKey][habitId] = start time in ms
    let runs: [String: [String: Double]]
    let liveRefl: String
    let reflection: String
    let summary: String?
    /// ratings confirmed at the review: one per Saturday question he spoke to (iOS only; older weeks have none)
    let growth: [Rating]
    /// `s` is the sphere the question belonged to when it was rated (its group in the question library)
    /// `t` is the sentence of his the rating rested on, when the proposal he confirmed came with one
    struct Rating: Equatable { let q: String; let v: Int; let s: String; var t: String = "" }
    let raw: [String: Any]

    var isActive: Bool { status == "active" }

    init?(id: String, _ d: [String: Any]) {
        guard let sealed = msOf(d["sealedAt"]) else { return nil }
        self.id = id
        focus = d["focus"] as? String ?? ""
        verse = strOf(d["verse"])
        verseRef = strOf(d["verseRef"])
        status = d["status"] as? String ?? "closed"
        sealedAtMs = sealed
        sealedAt = Date(timeIntervalSince1970: sealed / 1000)
        closedAt = msOf(d["closedAt"]).map { Date(timeIntervalSince1970: $0 / 1000) }
        percentage = intOf(d["percentage"])
        planThoughts = d["planThoughts"] as? String ?? ""
        commitments = (d["commitments"] as? [[String: Any]] ?? []).compactMap(Commitment.init)
        let q = (d["qs"] as? [Any])?.compactMap { $0 as? String } ?? []
        qs = q.isEmpty ? nil : q
        done = d["done"] as? [String: [String: Any]] ?? [:]
        marks = (d["marks"] as? [String: Any] ?? [:]).compactMapValues { $0 as? String }
        var r: [String: [String: Double]] = [:]
        for (k, v) in d["runs"] as? [String: [String: Any]] ?? [:] {
            r[k] = v.compactMapValues { msOf($0) }
        }
        runs = r
        liveRefl = d["liveRefl"] as? String ?? ""
        reflection = d["reflection"] as? String ?? ""
        summary = strOf(d["summary"])
        growth = (d["growth"] as? [[String: Any]] ?? []).compactMap { r in
            guard let q = r["q"] as? String, let v = intOf(r["v"]), (-1...1).contains(v) else { return nil }
            return Rating(q: q, v: v, s: strOf(r["s"]) ?? q, t: strOf(r["t"]) ?? "")
        }
        raw = d
    }

    /// JavaScript truthiness of done[day][key]
    func flag(_ day: String, _ key: String) -> Bool {
        guard let v = done[day]?[key] else { return false }
        if let b = v as? Bool { return b }
        if let s = v as? String { return !s.isEmpty }
        if let n = v as? NSNumber { return n.doubleValue != 0 }
        return false
    }
    func value(_ day: String, _ key: String) -> Any? { done[day]?[key] }
    func run(_ day: String, _ id: String) -> Double? { runs[day]?[id].flatMap { $0 > 0 ? $0 : nil } }

    static func == (a: Week, b: Week) -> Bool { a.id == b.id && NSDictionary(dictionary: a.raw).isEqual(to: b.raw) }
}

struct Settings: Equatable {
    var closeDay = 6      // 0 = Sunday ... 6 = Saturday
    var closeHour = 17
    var theme = "dark"
    var sounds = true
    var cafOn = true
    var cafStart = 400
    var cafStep = 50
    var cafDays = 21
    var cafFrom: Double?
    var anchorQ = Defaults.anchorQ
    var qLib = Defaults.qLib
    var revQs = Defaults.revQs
    var raw: [String: Any] = [:]

    init(_ d: [String: Any] = [:]) {
        closeDay = intOf(d["closeDay"]) ?? 6
        closeHour = intOf(d["closeHour"]) ?? 17
        theme = strOf(d["theme"]) ?? "dark"
        sounds = d["sounds"] as? Bool ?? true
        cafOn = d["cafOn"] as? Bool ?? true
        cafStart = intOf(d["cafStart"]) ?? 400
        cafStep = intOf(d["cafStep"]) ?? 50
        cafDays = intOf(d["cafDays"]) ?? 21
        cafFrom = msOf(d["cafFrom"]).flatMap { $0 > 0 ? $0 : nil }
        anchorQ = strOf(d["anchorQ"]) ?? Defaults.anchorQ
        qLib = strOf(d["qLib"]) ?? Defaults.qLib
        if let r = d["revQs"] as? [Any] { revQs = r.compactMap { $0 as? String } }
        raw = d
    }

    static func == (a: Settings, b: Settings) -> Bool { NSDictionary(dictionary: a.raw).isEqual(to: b.raw) }
}

struct Prayer: Identifiable, Equatable {
    let id: String
    let text: String
    let body: String
    let icon: String?
    let created: Double
    let pinned: Bool
    let raw: [String: Any]

    init(id: String, _ d: [String: Any]) {
        self.id = id
        text = d["text"] as? String ?? ""
        body = d["body"] as? String ?? ""
        icon = strOf(d["icon"])
        created = msOf(d["created"]) ?? 0
        pinned = d["pinned"] as? Bool ?? false
        raw = d
    }

    static func == (a: Prayer, b: Prayer) -> Bool { a.id == b.id && NSDictionary(dictionary: a.raw).isEqual(to: b.raw) }
}

/// a habit in the library (plan screen chips)
struct Chip: Identifiable, Equatable {
    let id: String
    let name: String
    let icon: String?
    let order: Int
    let raw: [String: Any]

    init(id: String, _ d: [String: Any]) {
        self.id = id
        name = d["name"] as? String ?? ""
        icon = strOf(d["icon"])
        order = intOf(d["order"]) ?? 0
        raw = d
    }

    static func == (a: Chip, b: Chip) -> Bool { a.id == b.id && NSDictionary(dictionary: a.raw).isEqual(to: b.raw) }
}

/// the web's uid(): time in base 36 plus five random base-36 characters
func newUid() -> String {
    let t = String(Int(Date().timeIntervalSince1970 * 1000), radix: 36)
    let chars = Array("0123456789abcdefghijklmnopqrstuvwxyz")
    return t + String((0..<5).map { _ in chars.randomElement()! })
}
