import Foundation

/// Sample data for simulator screenshots and UI checks (`-UITestSeed 1`): the same week the reference screenshots in
/// spec/screens were rendered from. Nothing here touches Firebase; writes stay in memory.
enum Mock {
    /// also on under XCTest, so tests never start Firebase
    static var enabled: Bool {
        UserDefaults.standard.bool(forKey: "UITestSeed") || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private static func ms(_ day: String, _ hm: String) -> Double { Rules.localDate(day, hm)!.timeIntervalSince1970 * 1000 }

    @MainActor static func load(into store: Store) {
        // "today" is Wed Nov 11 2026, 10:00 am unless -MockNow yyyy-MM-ddTHH:mm says otherwise
        let now = UserDefaults.standard.string(forKey: "MockNow") ?? "2026-11-11T10:00"
        let p = now.components(separatedBy: "T")
        Now.fixed = Rules.localDate(p[0], p.count > 1 ? p[1] : "10:00")

        let habits: [[String: Any]] = [
            ["id": "md", "chipId": "c0", "name": "Morning Devotion", "icon": "sun", "by": "06:30", "byWe": "08:00", "min": 15],
            ["id": "wr", "name": "Work Review", "icon": "briefcase", "days": "wd", "by": "07:30"],
            ["id": "ge", "name": "Guard My Eyes", "icon": "eye"],
            ["id": "ph", "name": "Present at Home", "icon": "heart", "by": "18:00",
             "about": "Phone down at the door. \"Love is patient, love is kind\" (1 Corinthians 13:4)."]
        ]
        let live = """
        Sunday, 11:45 am
        We enjoyed it. Praise God, the girls made it through the situation last night and through the baby shower.

        Monday, 6:40 am
        Up before the alarm. Devotion in Daniel 1, the part about purposing in his heart before the test came.

        Tuesday, 9:15 pm
        Slipped on devotion this morning. Overslept after a late night on the laptop.
        Present at home went well though.

        Wednesday, 6:52 am
        Back on track. I think the evening is the real battle, not the morning.
        """
        let active: [String: Any] = [
            "id": "2026-11-07", "status": "active", "focus": "Purpose",
            "verse": "But Daniel purposed in his heart that he would not defile himself.", "verseRef": "Daniel 1:8",
            "sealedAt": ms("2026-11-07", "17:30"), "commitments": habits,
            "planThoughts": "Commit seriously after two slack days.\n\nMornings first.",
            "qs": Defaults.revQs,
            "done": [
                "2026-11-08": ["md": true, "ge": true, "ph": true],
                "2026-11-09": ["md": true, "md@grace": true, "wr": true, "ge": true, "ph": false, "ph@fail": true],
                "2026-11-10": ["wr": true, "ge": true, "ph": true],
                "2026-11-11": ["md": true]
            ],
            "marks": ["2026-11-08": "on"],
            "liveRefl": live
        ]
        func closed(_ id: String, _ focus: String, _ pct: Int, _ refl: String = "", _ summary: String? = nil, growth: [Int?] = []) -> [String: Any] {
            var w: [String: Any] = ["id": id, "status": "closed", "focus": focus, "sealedAt": ms(id, "17:30"),
                                    "closedAt": ms(id, "17:30") + 7 * 864e5, "percentage": pct, "commitments": habits, "reflection": refl]
            if let summary { w["summary"] = summary }
            let said = [1: ["I caught it twice before it went anywhere.", "Worship was freer than it has been in a month.", "I was home by six most nights."],
                        0: ["About the same as last week, honestly.", "Sunday was good; midweek my mind was on the job.", "At home, yes. Mornings with God were rushed."],
                        -1: ["Thursday night got away from me again.", "I could not settle my mind at all.", "I was on the phone through dinner twice."]]
            let rated = zip(Defaults.revQs.indices, growth).compactMap { i, v in
                v.map { ["q": Defaults.revQs[i], "v": $0, "s": Growth.sphere(Defaults.revQs[i], Settings()), "t": said[$0]![i]] as [String: Any] }
            }
            if !rated.isEmpty { w["growth"] = rated }
            return w
        }
        let weeks = [
            active,
            closed("2026-10-31", "Law", 71, "Thursday, 8:10 pm\nTwo very different days this week.",
                   "I saw two very different days this week: one where I followed my commitments and one where I did not, and the difference was night and day. Morning devotion set the tone.", growth: [1, 1, 0]),
            closed("2026-10-24", "Word", 80, growth: [0, 1, nil]),
            closed("2026-10-17", "Rest", 64, growth: [-1, 0, -1])
        ]
        let prayers: [[String: Any]] = [
            ["id": "p1", "text": "Provision", "icon": "money", "body": "Lord, provide for the house and the church.\n\nAmen.", "created": ms("2026-12-31", "09:00")],
            ["id": "p2", "text": "Lyudmila", "icon": "heart", "body": "", "created": ms("2026-12-30", "09:00")],
            ["id": "p3", "text": "Redeemed Church", "icon": "church", "body": "", "created": ms("2026-12-29", "09:00")]
        ]
        let seed = [("Morning devotion", "sun"), ("Prayer", "hands"), ("Scripture reading", "book"), ("Scripture memory", "pen"),
                    ("Evening prayer", "moon"), ("Worship", "music"), ("Fast", "moon"), ("No YouTube on phone", "phone")]
        let library = seed.enumerated().map { ["id": "c\($0.offset)", "name": $0.element.0, "icon": $0.element.1, "order": $0.offset] as [String: Any] }
        var settings: [String: Any] = ["closeDay": 6, "closeHour": 17, "cafOn": false, "theme": "dark"]
        if let t = UserDefaults.standard.string(forKey: "MockTheme") { settings["theme"] = t }
        store.loadMock(settings: settings, weeks: weeks, prayers: prayers, library: library)
    }
}
