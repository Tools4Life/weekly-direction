import Foundation

// Ports of the web app's derived values (index.html): formatting, caffeine day items, week stats, streak, stats cells,
// habit history and the journal text blocks. Same inputs, same outputs: the record has to read the same on both apps.

enum Fmt {
    static let dow = ["S", "M", "T", "W", "T", "F", "S"]
    static let dowl = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    private static func df(_ f: String) -> DateFormatter {
        let d = DateFormatter()
        d.locale = Locale(identifier: "en_US_POSIX")
        d.dateFormat = f
        return d
    }
    private static let mon = df("MMM"), monDay = df("MMM d"), monDayYear = df("MMM d, yyyy"), md = df("M/d")

    /// "NOV 7 — 14" or "OCT 31 — NOV 7"
    static func range(_ a: Date, _ b: Date) -> String {
        let c = Rules.cal
        let m = { (d: Date) in mon.string(from: d).uppercased() }
        return c.component(.month, from: a) == c.component(.month, from: b)
            ? "\(m(a)) \(c.component(.day, from: a)) — \(c.component(.day, from: b))"
            : "\(m(a)) \(c.component(.day, from: a)) — \(m(b)) \(c.component(.day, from: b))"
    }
    static func weekRange(_ w: Week, _ s: Settings) -> String { range(w.sealedAt, Rules.weekEnd(w.sealedAt, s)) }
    static func date(_ d: Date) -> String { monDay.string(from: d) }
    static func dateYear(_ d: Date) -> String { monDayYear.string(from: d) }
    static func slash(_ d: Date) -> String { md.string(from: d) }

    /// "18:00" → "6:00 pm"
    static func clock(_ hm: String) -> String {
        let p = hm.split(separator: ":").compactMap { Int($0) }
        guard p.count >= 2 else { return hm }
        return String(format: "%d:%02d %@", p[0] % 12 == 0 ? 12 : p[0] % 12, p[1], p[0] < 12 ? "am" : "pm")
    }
    static func clock(_ d: Date) -> String {
        let c = Rules.cal.dateComponents([.hour, .minute], from: d)
        return clock(String(format: "%02d:%02d", c.hour!, c.minute!))
    }
    static func hourLabel(_ h: Int) -> String { "\(h % 12 == 0 ? 12 : h % 12) \(h < 12 ? "am" : "pm")" }
    /// the journal's day-and-time line: "Sunday, 10:22 pm"
    static func stamp(_ d: Date) -> String { "\(dowl[Rules.weekday(d)]), \(clock(d))" }
    static func mmss(_ seconds: TimeInterval) -> String {
        let t = max(0, Int(seconds.rounded(.up)))
        return String(format: "%d:%02d", t / 60, t % 60)
    }
    static func pct(_ a: Int, _ b: Int) -> Int { Int((Double(a) / Double(b) * 100).rounded()) }
}

extension Commitment {
    /// tmLabel: "weekdays · 6:30 am · wknd 8:00 am · 15 min"
    func timeLabel(days showDays: Bool = true) -> String {
        [showDays ? (days == "wd" ? "weekdays" : days == "we" ? "weekends" : "") : "",
         by.map { Fmt.clock($0) + (byWe.map { " · wknd \(Fmt.clock($0))" } ?? "") } ?? "",
         min.map { "\($0) min" } ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
    }
    /// "start by 6:30 am, weekends 8:00 am · 15 min"
    var planMeta: String {
        [by.map { "start by \(Fmt.clock($0))" + (byWe.map { ", weekends \(Fmt.clock($0))" } ?? "") } ?? "",
         min.map { "\($0) min" } ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
    }
    /// same habit across weeks = same library habit, else same name
    var historyKey: String { chipId ?? name.trimmingCharacters(in: .whitespaces).lowercased() }
}

enum Logic {
    static func midnight(_ d: Date) -> Date { Rules.cal.startOfDay(for: d) }
    static func dayDiff(_ a: Date, _ b: Date) -> Int { Int((midnight(b).timeIntervalSince(midnight(a)) / 86400).rounded()) }
    static func noon(_ k: String) -> Date { Rules.localDate(k, "12:00")! }

    // ---- caffeine wean: only what decides a day's items (the doses count toward a kept day when the wean is on) ----
    static func cafFromDate(_ s: Settings) -> Date {
        s.cafFrom.map { Date(timeIntervalSince1970: $0 / 1000) } ?? midnight(Now.date)
    }
    static func cafPlan(_ s: Settings) -> [(mg: Int, from: Int, len: Int)] {
        let step = max(1, s.cafStep), n = max(1, Int((Double(s.cafStart) / Double(step)).rounded(.up)))
        let days = max(n, s.cafDays == 0 ? n : s.cafDays), base = days / n, rem = days % n
        var out: [(mg: Int, from: Int, len: Int)] = [], d = 0
        for i in 0..<n {
            let len = base + (i >= n - rem ? 1 : 0)
            out.append((max(0, s.cafStart - step * i), d, len))
            d += len
        }
        return out
    }
    static func cafLimit(_ s: Settings, _ day: Date) -> Int {
        let plan = cafPlan(s), i = dayDiff(cafFromDate(s), day)
        if i < 0 { return plan[0].mg }
        return plan.first { i >= $0.from && i < $0.from + $0.len }?.mg ?? 0
    }
    static func cafSplit(_ s: Settings, _ mg: Int) -> (am: Int, pm: Int) {
        let st = max(1, s.cafStep == 0 ? 50 : s.cafStep)
        let am = min(mg, Int((Double(mg) / 2 / Double(st)).rounded(.up)) * st)
        return (am, mg - am)
    }
    /// every item that must be done for the day to be kept: the day's habits. The caffeine wean is information only
    /// since Nov 11 2026 (Eddie: it is not a habit): its doses are no longer checked off and no longer part of a kept day.
    /// Days recorded before that stay as they were marked.
    static func dayItems(_ w: Week, _ day: Date, _ s: Settings) -> [String] {
        w.commitments.filter { Rules.onDay($0, day) }.map(\.id)
    }
    /// today's caffeine allowance as one line ("Caffeine 150 am · 100 pm"), or nil when the wean is off
    static func cafLine(_ s: Settings, _ day: Date) -> String? {
        guard s.cafOn else { return nil }
        let (am, pm) = cafSplit(s, cafLimit(s, day))
        if am + pm == 0 { return "Caffeine-free" }
        return "Caffeine " + [am > 0 ? "\(am) am" : nil, pm > 0 ? "\(pm) pm" : nil].compactMap { $0 }.joined(separator: " · ")
    }

    // ---- week stats ----
    struct WeekStats { let days: [Date]; let kept: Int; let pct: Int }
    static func weekStats(_ w: Week, _ s: Settings) -> WeekStats {
        let days = Rules.habitDays(w, s).filter { !dayItems(w, $0, s).isEmpty }
        let kept = days.filter { w.marks[Rules.ymd($0)] == "on" }.count
        let pct = w.status == "closed" && w.percentage != nil ? w.percentage! : Fmt.pct(kept, max(1, days.count))
        return WeekStats(days: days, kept: kept, pct: pct)
    }

    /// on-time share of done habits that have a start-by, for the whole week (nil when there are none)
    static func onTimePct(_ w: Week, _ s: Settings) -> Int? {
        var on = 0, lt = 0
        for c in w.commitments where c.by != nil {
            for d in Rules.habitDays(w, s) {
                let k = Rules.ymd(d)
                if w.flag(k, c.id) { if w.flag(k, c.id + "@late") { lt += 1 } else { on += 1 } }
            }
        }
        return on + lt > 0 ? Fmt.pct(on, on + lt) : nil
    }

    // ---- streak: a day counts when it is marked kept; the review day neither counts nor breaks it ----
    static let miles = [1, 3, 7, 14, 30, 90]
    static func streak(_ weeks: [Week], _ s: Settings) -> (cur: Int, best: Int) {
        var marks: [String: Int] = [:], habit = Set<String>(), empty = Set<String>()
        for w in weeks {
            for d in Rules.habitDays(w, s) {
                let k = Rules.ymd(d)
                if dayItems(w, d, s).isEmpty { empty.insert(k); continue }
                habit.insert(k)
                if w.marks[k] == "on" { marks[k] = 1 }
                if w.marks[k] == "drift" { marks[k] = -1 }
            }
        }
        let todayK = Rules.ymd(Now.date)
        var run = 0, best = 0
        if let first = habit.sorted().first {
            var d = noon(first)
            while Rules.ymd(d) <= todayK {
                let k = Rules.ymd(d)
                if habit.contains(k) {
                    if marks[k] == 1 { run += 1; best = max(best, run) } else if k != todayK || marks[k] == -1 { run = 0 }
                } else if !empty.contains(k) && Rules.weekday(d) != s.closeDay && k != todayK { run = 0 }
                d = Rules.cal.date(byAdding: .day, value: 1, to: d)!
            }
        }
        return (run, best)
    }

    // ---- stats cells: one habit on one day ----
    enum Cell: String { case on, grace, late, fail, miss, open, fut, na
        var counted: Bool { self == .on || self == .grace || self == .late || self == .fail || self == .miss }
        var ok: Bool { self == .on || self == .grace || self == .late }
    }
    static func cell(_ w: Week, _ k: String, _ c: Commitment) -> Cell {
        if !Rules.onDay(c, noon(k)) { return .na }
        let today = Rules.ymd(Now.date)
        if k > today { return .fut }
        if w.flag(k, c.id + "@fail") { return .fail }
        if w.flag(k, c.id) { return w.flag(k, c.id + "@late") ? .late : w.flag(k, c.id + "@grace") ? .grace : .on }
        if k < today { return .miss }
        return Rules.state(w, k, c) == .miss ? .miss : .open
    }

    struct HabitTally: Identifiable {
        let c: Commitment
        var on = 0, grace = 0, late = 0, fail = 0, miss = 0, due = 0
        var done: Int { on + grace + late }
        var id: String { c.id }
    }
    struct WeekDetail {
        let stats: WeekStats
        let keys: [String]
        let per: [HabitTally]
        let done: Int, due: Int, grace: Int, miss: Int, fail: Int
        let tDone: Int, tOn: Int
        /// percent of that day's habits done; nil for future days and days with nothing due
        let daily: [Int?]
        let prev: Week?, next: Week?
        let prevPct: Int?
    }
    static func weekDetail(_ w: Week, _ weeks: [Week], _ s: Settings) -> WeekDetail {
        let st = weekStats(w, s), keys = st.days.map(Rules.ymd)
        let per: [HabitTally] = w.commitments.map { c in
            var t = HabitTally(c: c)
            for k in keys {
                switch cell(w, k, c) {
                case .on: t.on += 1; t.due += 1
                case .grace: t.grace += 1; t.due += 1
                case .late: t.late += 1; t.due += 1
                case .fail: t.fail += 1; t.due += 1
                case .miss: t.miss += 1; t.due += 1
                default: break
                }
            }
            return t
        }
        let timed = per.filter { $0.c.by != nil }
        let today = Rules.ymd(Now.date)
        let daily: [Int?] = keys.map { k in
            var dn = 0, du = 0
            for c in w.commitments { let v = cell(w, k, c); if v.counted { du += 1; if v.ok { dn += 1 } } }
            return k > today || du == 0 ? nil : Fmt.pct(dn, du)
        }
        let ws = weeks.sorted { $0.sealedAtMs < $1.sealedAtMs }, i = ws.firstIndex { $0.id == w.id }
        let pv = i.flatMap { $0 > 0 ? ws[$0 - 1] : nil }, nx = i.flatMap { $0 + 1 < ws.count ? ws[$0 + 1] : nil }
        return WeekDetail(stats: st, keys: keys, per: per,
                          done: per.reduce(0) { $0 + $1.done }, due: per.reduce(0) { $0 + $1.due },
                          grace: per.reduce(0) { $0 + $1.grace }, miss: per.reduce(0) { $0 + $1.miss }, fail: per.reduce(0) { $0 + $1.fail },
                          tDone: timed.reduce(0) { $0 + $1.done }, tOn: timed.reduce(0) { $0 + $1.on + $1.grace },
                          daily: daily, prev: pv, next: nx, prevPct: pv.map { weekStats($0, s).pct })
    }

    struct AllHabit: Identifiable { var c: Commitment; var done = 0, due = 0, on = 0, tdone = 0; var id: String { c.historyKey } }
    struct AllTime {
        let weeks: [(w: Week, pct: Int)]
        let pct: Int, kept: Int, days: Int, perfect: Int, closed: Int
        let avg: Int?, best: (w: Week, pct: Int)?
        let onTime: Int?, grace: Int, miss: Int, fail: Int
        let habits: [AllHabit]
    }
    static func allTime(_ weeks: [Week], _ s: Settings) -> AllTime {
        let ws = weeks.sorted { $0.sealedAtMs < $1.sealedAtMs }
        var H: [String: AllHabit] = [:], order: [String] = []
        var done = 0, due = 0, grace = 0, fail = 0, miss = 0, tDone = 0, tOn = 0, kept = 0, days = 0, perfect = 0
        var wk: [(w: Week, pct: Int)] = []
        for w in ws {
            let st = weekStats(w, s)
            kept += st.kept; days += st.days.count
            if w.status == "closed" && st.pct == 100 { perfect += 1 }
            for k in st.days.map(Rules.ymd) {
                for c in w.commitments {
                    let v = cell(w, k, c)
                    guard v.counted else { continue }
                    let key = c.historyKey
                    if H[key] == nil { H[key] = AllHabit(c: c); order.append(key) }
                    H[key]!.c = c
                    due += 1; H[key]!.due += 1
                    if v.ok {
                        done += 1; H[key]!.done += 1
                        if c.by != nil { tDone += 1; H[key]!.tdone += 1; if v != .late { tOn += 1; H[key]!.on += 1 } }
                    }
                    if v == .grace { grace += 1 } else if v == .fail { fail += 1 } else if v == .miss { miss += 1 }
                }
            }
            wk.append((w, st.pct))
        }
        let closed = wk.filter { $0.w.status == "closed" }
        let avg = closed.isEmpty ? nil : Int((Double(closed.reduce(0) { $0 + $1.pct }) / Double(closed.count)).rounded())
        var best: (w: Week, pct: Int)?
        for x in closed where best == nil || x.pct >= best!.pct { best = x }
        // stable sort by days due, most first (JavaScript's sort is stable)
        let hs = order.enumerated().map { ($0.offset, H[$0.element]!) }
            .sorted { $0.1.due != $1.1.due ? $0.1.due > $1.1.due : $0.0 < $1.0 }.map(\.1)
        return AllTime(weeks: wk, pct: due > 0 ? Fmt.pct(done, due) : 0, kept: kept, days: days, perfect: perfect, closed: closed.count,
                       avg: avg, best: best, onTime: tDone > 0 ? Fmt.pct(tOn, tDone) : nil, grace: grace, miss: miss, fail: fail, habits: hs)
    }

    // ---- per-habit history across the last six weeks ----
    struct HistCell { let k: Int; let t: Int; let focus: String }
    struct HabitHist: Identifiable {
        var c: Commitment
        var cells: [HistCell?]
        var kept = 0, tot = 0, on = 0, late = 0, rs = 0, gr = 0, last = 0
        var id: String { c.historyKey }
    }
    static func habitHistory(_ weeks: [Week], _ s: Settings) -> (weeks: Int, rows: [HabitHist]) {
        let ws = Array(weeks.sorted { $0.sealedAtMs < $1.sealedAtMs }.suffix(6)), todayK = Rules.ymd(Now.date)
        var H: [String: HabitHist] = [:]
        for (wi, w) in ws.enumerated() {
            for c in w.commitments {
                let key = c.historyKey
                if H[key] == nil { H[key] = HabitHist(c: c, cells: Array(repeating: nil, count: ws.count)) }
                H[key]!.c = c; H[key]!.last = wi
                var k = 0, t = 0
                for d in Rules.habitDays(w, s) where Rules.onDay(c, d) {
                    let dk = Rules.ymd(d)
                    if dk > todayK { continue }
                    if dk == todayK && !w.flag(dk, c.id) && !w.flag(dk, c.id + "@fail") { continue }
                    t += 1
                    if w.flag(dk, c.id + "@rs") { H[key]!.rs += 1 }
                    if w.flag(dk, c.id) && w.flag(dk, c.id + "@grace") { H[key]!.gr += 1 }
                    if w.flag(dk, c.id) {
                        k += 1
                        if c.by != nil { if w.flag(dk, c.id + "@late") { H[key]!.late += 1 } else { H[key]!.on += 1 } }
                    }
                }
                H[key]!.cells[wi] = t > 0 ? HistCell(k: k, t: t, focus: w.focus) : nil
                H[key]!.kept += k; H[key]!.tot += t
            }
        }
        let rows = H.values.filter { $0.tot > 0 }.sorted { $0.last != $1.last ? $0.last > $1.last : $0.c.name.localizedCompare($1.c.name) == .orderedAscending }
        return (ws.count, rows)
    }

    // ---- Saturday questions ----
    static func qsOf(_ w: Week?, _ s: Settings) -> [String] { w?.qs ?? s.revQs }
    static func normQs(_ qs: [String], _ s: Settings) -> [String] {
        Array(([s.anchorQ] + qs.filter { !$0.isEmpty && $0 != s.anchorQ }).prefix(3))
    }
    static func libGroups(_ s: Settings) -> [(title: String, qs: [String])] {
        var out: [(title: String, qs: [String])] = [], g: (title: String, qs: [String]) = ("Questions", [])
        for l in s.qLib.components(separatedBy: "\n").map({ $0.trimmingCharacters(in: .whitespaces) }) where !l.isEmpty {
            if l.hasPrefix("#") {
                if !g.qs.isEmpty { out.append(g) }
                g = (l.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression), [])
            } else { g.qs.append(l) }
        }
        if !g.qs.isEmpty { out.append(g) }
        return out
    }

    /// the most recent moment the week closes (first-week planning starts there)
    static func lastClose(_ s: Settings, now: Date = Now.date) -> Date {
        var d = Rules.cal.date(bySettingHour: s.closeHour, minute: 0, second: 0, of: now)!
        d = Rules.cal.date(byAdding: .day, value: -((Rules.weekday(d) - s.closeDay + 7) % 7), to: d)!
        if d > now { d = Rules.cal.date(byAdding: .day, value: -7, to: d)! }
        return d
    }
}

// ---- journal text: blocks separated by a blank line, first line a stamp like "Sunday, 10:22 pm" ----
enum Journal {
    struct Block: Identifiable, Equatable {
        /// index in the raw split, which edits and deletes address
        let i: Int
        /// weekday and time of a stamped entry
        var d: String?, t: String?
        /// the question, for a Saturday answer
        var q: String?
        let x: String
        var id: Int { i }
        /// the text for reading: an empty line between its paragraphs (Eddie, Nov 11 2026). Display only: the stored
        /// entry keeps single line breaks, because a blank line is what separates one entry from the next.
        var read: String { x.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: "\n\n") }
    }

    private static let sep = try! NSRegularExpression(pattern: "\\n\\s*\\n")
    private static let stampRx = try! NSRegularExpression(
        pattern: "^(Sunday|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday), (\\d{1,2}:\\d{2} [ap]m)$")
    private static let ws = CharacterSet.whitespacesAndNewlines

    /// JavaScript's t.split(/\n\s*\n/): every piece, empty ones included, so indexes match the web app's
    static func split(_ t: String) -> [String] {
        let s = t.replacingOccurrences(of: "\r\n", with: "\n") as NSString
        var out: [String] = [], at = 0
        for m in sep.matches(in: s as String, range: NSRange(location: 0, length: s.length)) {
            out.append(s.substring(with: NSRange(location: at, length: m.range.location - at)))
            at = m.range.location + m.range.length
        }
        out.append(s.substring(from: at))
        return out
    }

    private static func stamp(_ line: String) -> (String, String)? {
        let n = line as NSString
        guard let m = stampRx.firstMatch(in: line, range: NSRange(location: 0, length: n.length)) else { return nil }
        return (n.substring(with: m.range(at: 1)), n.substring(with: m.range(at: 2)))
    }

    /// rfBlocks: stamped entries {d,t,x}, Saturday answers {q,x}, or plain {x}
    static func blocks(_ t: String) -> [Block] {
        split(t).enumerated().compactMap { i, b in
            let ls = b.trimmingCharacters(in: ws).components(separatedBy: "\n")
            let h = ls[0].trimmingCharacters(in: ws)
            let blk: Block
            if let m = stamp(h), ls.count > 1 {
                blk = Block(i: i, d: m.0, t: m.1, x: ls.dropFirst().joined(separator: "\n"))
            } else if ls.count > 1, h.range(of: "\\?\\s*$", options: .regularExpression) != nil {
                blk = Block(i: i, q: h, x: ls.dropFirst().joined(separator: "\n"))
            } else {
                blk = Block(i: i, x: ls.joined(separator: "\n"))
            }
            return blk.x.trimmingCharacters(in: ws).isEmpty ? nil : blk
        }
    }
    /// entries only (no Saturday answers)
    static func entries(_ t: String) -> [Block] { blocks(t).filter { $0.q == nil } }

    /// a blank line inside an entry would split it: collapse to single newlines
    static func clean(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\\n\\s*\\n+", with: "\n", options: .regularExpression)
            .trimmingCharacters(in: ws)
    }
    private static func rejoin(_ raw: [String]) -> String {
        raw.map { $0.trimmingCharacters(in: ws) }.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    /// vcAppend: the new liveRefl with a stamped entry added at the end (nil when there is nothing to add)
    static func appended(_ live: String, at: Date, text: String) -> String? {
        let t = clean(text)
        guard !t.isEmpty else { return nil }
        let cur = live.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
        return (cur.isEmpty ? "" : cur + "\n\n") + Fmt.stamp(at) + "\n" + t
    }
    /// rfSetEntry: replace one block's text keeping its stamp, or remove it when the text is empty
    static func replaced(_ live: String, index i: Int, text: String) -> String? {
        var raw = split(live)
        guard i >= 0, i < raw.count else { return nil }
        let ls = raw[i].trimmingCharacters(in: ws).components(separatedBy: "\n")
        let h = ls[0].trimmingCharacters(in: ws)
        let st = stamp(h) != nil && ls.count > 1 ? h : ""
        let t = clean(text)
        if t.isEmpty { raw.remove(at: i) } else { raw[i] = (st.isEmpty ? "" : st + "\n") + t }
        return rejoin(raw)
    }
    static func removed(_ live: String, indexes: [Int]) -> String {
        var raw = split(live)
        for i in indexes.sorted(by: >) where i >= 0 && i < raw.count { raw.remove(at: i) }
        return rejoin(raw)
    }
}
