import Foundation

// The web app's habit actions (index.html: setItem, the check tap in renderWeek, Mark failed in openHabit),
// built on the field-level store writes. Past days are locked and nothing here undoes a check or a failure.
extension Store {
    /// setItem: sets one item for a day and keeps the day's kept mark in step with it
    func setItem(_ w: Week, _ k: String, _ id: String, _ val: Bool) {
        let day = Rules.habitDays(w, settings).first { Rules.ymd($0) == k } ?? Logic.noon(k)
        let items = Logic.dayItems(w, day, settings)
        let all = items.allSatisfy { $0 == id ? val : w.flag(k, $0) }
        let cur = w.marks[k]
        var nv = cur
        if all && cur != "on" { nv = "on" } else if !all && cur == "on" { nv = nil }
        guard let c = w.commitments.first(where: { $0.id == id }) else {
            setDay(w, k, [id: val], mark: nv)      // a caffeine dose (am / pm)
            return
        }
        // past its start-by: when the timer was started (or now) is after the deadline
        let dl = Rules.deadline(k, c, w)
        let at = w.run(k, id).map { Date(timeIntervalSince1970: $0 / 1000) } ?? Now.date
        let past = val && dl != nil && at > dl!
        var fields: [String: Any] = [id: val, id + "@late": past && !Rules.graceDay(k)]
        if Rules.graceDay(k) { fields[id + "@grace"] = past }
        setDay(w, k, fields, mark: nv)
    }

    /// Mark failed: final; the day won't be kept
    func fail(_ w: Week, _ k: String, _ c: Commitment) {
        if w.run(k, c.id) != nil { setRun(w, k, c.id, nil) }
        setDay(w, k, [c.id: false, c.id + "@fail": true], mark: "drift")
    }

    /// saveHabitAbout: the About note is saved on the week's habit and on its library habit
    func saveAbout(_ w: Week, _ c: Commitment, _ text: String) {
        let about = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard about != (c.about ?? "") else { return }
        let list: [[String: Any]] = w.commitments.map { x in
            guard x.id == c.id else { return x.raw }
            var r = x.raw
            r["about"] = about.isEmpty ? nil : about
            return r
        }
        patchWeek(w, ["commitments": list])
        if let chipId = c.chipId, let ch = library.first(where: { $0.id == chipId }) {
            var r = ch.raw
            r["about"] = about.isEmpty ? nil : about
            putChip(id: ch.id, r)
        }
    }
}
