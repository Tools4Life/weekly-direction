import XCTest
@testable import WeeklyDirection

/// The record is strict: these pin the ported rules and the exact fields each write sends, on the sample week
/// (sealed Sat Nov 7 2026 5:30 pm; "now" is Wed Nov 11, 10:00 am).
@MainActor
final class RulesTests: XCTestCase {
    var store: Store!
    var w: Week { store.activeWeek! }
    func habit(_ id: String) -> Commitment { w.commitments.first { $0.id == id }! }

    override func setUp() async throws {
        UserDefaults.standard.removeObject(forKey: "MockNow")
        store = Store(mock: true)
        Mock.load(into: store)
    }
    override func tearDown() async throws { Now.fixed = nil }

    func testHabitDaysRunSundayToReviewSaturday() {
        XCTAssertEqual(Rules.habitDays(w, store.settings).map(Rules.ymd),
                       ["2026-11-08", "2026-11-09", "2026-11-10", "2026-11-11", "2026-11-12", "2026-11-13", "2026-11-14"])
        XCTAssertEqual(Rules.ymd(Rules.weekEnd(w.sealedAt, store.settings)), "2026-11-14")
    }

    func testStatesAtTenOnWednesday() {
        let k = "2026-11-11"
        XCTAssertEqual(Rules.state(w, k, habit("md")), .done)
        XCTAssertEqual(Rules.state(w, k, habit("wr")), .miss)     // 7:30 + 2 h grace ended 9:30
        XCTAssertEqual(Rules.state(w, k, habit("ge")), .open)
        XCTAssertEqual(Rules.state(w, k, habit("ph")), .open)
        XCTAssertEqual(Rules.state(w, "2026-11-09", habit("ph")), .fail)
    }

    func testGraceWindow() {
        let k = "2026-11-11", c = habit("wr")
        XCTAssertEqual(Rules.state(w, k, c, now: Rules.localDate(k, "07:30")!), .open)
        XCTAssertEqual(Rules.state(w, k, c, now: Rules.localDate(k, "07:31")!), .grace)
        XCTAssertEqual(Rules.state(w, k, c, now: Rules.localDate(k, "09:30")!), .grace)
        XCTAssertEqual(Rules.state(w, k, c, now: Rules.localDate(k, "09:31")!), .miss)
    }

    func testWeekendStartBy() {
        XCTAssertEqual(Rules.baseBy("2026-11-08", habit("md")), "08:00")
        XCTAssertEqual(Rules.baseBy("2026-11-09", habit("md")), "06:30")
        XCTAssertFalse(Rules.onDay(habit("wr"), Logic.noon("2026-11-08")))
    }

    func testWeekStatsAndCells() {
        let st = Logic.weekStats(w, store.settings)
        XCTAssertEqual(st.kept, 1); XCTAssertEqual(st.days.count, 7); XCTAssertEqual(st.pct, 14)
        let d = Logic.weekDetail(w, store.weeks, store.settings)
        XCTAssertEqual([d.done, d.due, d.grace, d.miss, d.fail, d.tOn, d.tDone], [10, 13, 1, 2, 1, 7, 7])
        XCTAssertEqual(d.daily, [100, 75, 75, 50, nil, nil, nil])
        XCTAssertEqual(Logic.cell(w, "2026-11-09", habit("md")), .grace)
        XCTAssertEqual(Logic.cell(w, "2026-11-10", habit("md")), .miss)
        XCTAssertEqual(Logic.cell(w, "2026-11-08", habit("wr")), .na)
    }

    func testStreak() {
        let s = Logic.streak(store.weeks, store.settings)
        XCTAssertEqual(s.cur, 0); XCTAssertEqual(s.best, 1)
    }

    func testCheckOnTimeWritesOnlyItsFieldsAndNoMark() {
        store.setItem(w, "2026-11-11", "ge", true)
        let day = w.done["2026-11-11"]!
        XCTAssertEqual(day["ge"] as? Bool, true)
        XCTAssertEqual(day["ge@late"] as? Bool, false)
        XCTAssertEqual(day["ge@grace"] as? Bool, false)
        XCTAssertEqual(day["md"] as? Bool, true)                  // earlier checks untouched
        XCTAssertNil(w.marks["2026-11-11"])                       // a habit is missed, so the day isn't kept
        XCTAssertEqual(w.marks["2026-11-08"], "on")
    }

    func testCheckInGraceIsFlagged() {
        Now.fixed = Rules.localDate("2026-11-11", "19:00")        // Present at Home: start by 6:00 pm
        store.setItem(w, "2026-11-11", "ph", true)
        XCTAssertEqual(w.done["2026-11-11"]?["ph@grace"] as? Bool, true)
        XCTAssertEqual(w.done["2026-11-11"]?["ph@late"] as? Bool, false)
    }

    func testLastCheckKeepsTheDay() {
        Now.fixed = Rules.localDate("2026-11-12", "06:00")
        for id in ["md", "wr", "ge"] { store.setItem(w, "2026-11-12", id, true); XCTAssertNil(w.marks["2026-11-12"]) }
        store.setItem(w, "2026-11-12", "ph", true)
        XCTAssertEqual(w.marks["2026-11-12"], "on")
    }

    func testFailIsFinalAndDrifts() {
        store.fail(w, "2026-11-11", habit("ph"))
        XCTAssertEqual(w.done["2026-11-11"]?["ph@fail"] as? Bool, true)
        XCTAssertEqual(w.done["2026-11-11"]?["ph"] as? Bool, false)
        XCTAssertEqual(w.marks["2026-11-11"], "drift")
        XCTAssertEqual(Rules.state(w, "2026-11-11", habit("ph")), .fail)
    }

    /// a past day's check can be corrected to failed with the same fields as a failure made on the day
    func testPastDoneDayCanBeChangedToFailed() {
        XCTAssertEqual(Rules.state(w, "2026-11-10", habit("ph")), .done)
        store.fail(w, "2026-11-10", habit("ph"))
        XCTAssertEqual(w.done["2026-11-10"]?["ph@fail"] as? Bool, true)
        XCTAssertEqual(w.done["2026-11-10"]?["ph"] as? Bool, false)
        XCTAssertEqual(w.done["2026-11-10"]?["wr"] as? Bool, true)
        XCTAssertEqual(w.marks["2026-11-10"], "drift")
        XCTAssertEqual(Rules.state(w, "2026-11-10", habit("ph")), .fail)
    }

    func testJournalBlocksAndEdits() {
        let ents = Journal.entries(w.liveRefl)
        XCTAssertEqual(ents.map(\.d), ["Sunday", "Monday", "Tuesday", "Wednesday"])
        XCTAssertEqual(ents.last?.t, "6:52 am")
        let edited = Journal.replaced(w.liveRefl, index: 3, text: "New text\n\nwith a gap")!
        XCTAssertTrue(edited.hasSuffix("Wednesday, 6:52 am\nNew text\nwith a gap"))
        XCTAssertEqual(Journal.entries(Journal.removed(w.liveRefl, indexes: [0, 2])).map(\.d), ["Monday", "Wednesday"])
        let added = Journal.appended(w.liveRefl, at: Now.date, text: " Said aloud ")!
        XCTAssertTrue(added.hasSuffix("\n\nWednesday, 10:00 am\nSaid aloud"))
        XCTAssertEqual(Journal.blocks("Is it easier?\nYes.").first?.q, "Is it easier?")
    }

    func testRemindersMatchTheServerRules() {
        let items = Notifier.plan(week: w, settings: store.settings, now: Now.date)
        let today = items.filter { $0.id.contains("2026-11-11") }.map(\.id)
        // Work Review is already missed (no reminder); Present at Home gets start-by and grace; by 9 pm its grace
        // has ended too, so the evening reminder lists only what can still be done
        XCTAssertEqual(today, ["by:2026-11-11:ph", "grace:2026-11-11:ph", "eve:2026-11-11"])
        XCTAssertEqual(items.first { $0.id == "by:2026-11-11:ph" }?.body, "Start by 6:00 pm — 15 minutes left.")
        XCTAssertEqual(items.first { $0.id == "eve:2026-11-11" }?.body, "1 habit still open: Guard My Eyes.")
        XCTAssertEqual(items.first { $0.id == "rev:2026-11-14" }?.at, Rules.localDate("2026-11-14", "17:00"))
        XCTAssertEqual(items.count, 23)
    }
}
