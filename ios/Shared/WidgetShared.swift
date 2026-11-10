import Foundation
import ActivityKit
import AppIntents
import SwiftUI

// Shared by the app and its widget extension (Nov 10 2026): what the widgets show, the timer Live Activity, and the
// "Dictate" shortcut. The app writes a small snapshot of the open week into the App Group; the extension only reads it.
// Nothing here talks to Firebase, and the widgets never write habit data.

enum Shared {
    static let group = "group.com.redeemedtools.WeeklyDirection"
    static var defaults: UserDefaults? { UserDefaults(suiteName: group) }
    static let dictateURL = URL(string: "weeklydirection://dictate")!
    static let weekURL = URL(string: "weeklydirection://week")!
    /// set by the Dictate shortcut / control; the app starts recording when it becomes active and clears it
    static let pendingDictateKey = "pendingDictate"
}

/// The open week as the widgets need it. `day` is the day the habit states were worked out for.
struct WidgetSnapshot: Codable, Equatable {
    struct Habit: Codable, Equatable {
        var name: String
        var symbol: String
        /// "done" | "fail" | "miss" | "open" | "run"
        var state: String
        /// the time under the name ("6:00 pm", "15 min"), if any
        var meta: String
        /// an open habit counts as missed from this moment (start-by plus grace)
        var missAt: Date?
    }
    var focus: String
    var range: String
    var verse: String
    var verseRef: String
    var day: String
    var habits: [Habit]
    var light: Bool
    var reviewDue: Bool

    static let key = "widgetSnapshot"
    static func load() -> WidgetSnapshot? {
        guard let d = Shared.defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: d)
    }
    func save() { if let d = try? JSONEncoder().encode(self) { Shared.defaults?.set(d, forKey: Self.key) } }
    static func clear() { Shared.defaults?.removeObject(forKey: key) }

    static let sample = WidgetSnapshot(
        focus: "Purpose", range: "Nov 7 – 14", verse: "But Daniel purposed in his heart that he would not defile himself.", verseRef: "Daniel 1:8",
        day: "", habits: [.init(name: "Morning Devotion", symbol: "sunrise", state: "done", meta: "15 min", missAt: nil),
                          .init(name: "Work Review", symbol: "briefcase", state: "done", meta: "7:30 am", missAt: nil),
                          .init(name: "Guard My Eyes", symbol: "eye", state: "open", meta: "", missAt: nil),
                          .init(name: "Present at Home", symbol: "heart", state: "open", meta: "6:00 pm", missAt: nil)],
        light: false, reviewDue: false)
}

/// The running habit timer (Lock Screen and Dynamic Island). The countdown runs by itself from `endsAt`.
struct TimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startedAt: Date
        var endsAt: Date
    }
    var habit: String
    var symbol: String
    var minutes: Int
}

/// "Dictate": opens the app straight into recording. Used by the Lock Screen / Control Center control, Siri, Shortcuts,
/// Back Tap and the Action button. It only leaves a flag; the app does the rest when it opens.
struct DictateIntent: AppIntent {
    static var title: LocalizedStringResource = "Record a thought"
    static var description = IntentDescription("Open Weekly Direction and start recording a thought.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        Shared.defaults?.set(true, forKey: Shared.pendingDictateKey)
        return .result()
    }
}

/// the app's colours for the widgets (dark first, like the app). The dark background is true black (Eddie, Nov 10 2026):
/// on the Home Screen the app's near-black read as dark grey.
struct WPalette {
    let bg, card, tx, mu, mu2, line, ac, acDim, onAc: Color
    static func of(light: Bool) -> WPalette {
        func c(_ h: UInt32) -> Color { Color(.sRGB, red: Double((h >> 16) & 0xFF) / 255, green: Double((h >> 8) & 0xFF) / 255, blue: Double(h & 0xFF) / 255) }
        return light
            ? WPalette(bg: c(0xF6F5F2), card: c(0xF0EEE9), tx: c(0x1B1917), mu: c(0x6F6A63), mu2: c(0x8D877F), line: c(0xD9D5CE), ac: c(0xD2602A), acDim: c(0xE9A07C), onAc: c(0xFFFFFF))
            : WPalette(bg: c(0x000000), card: c(0x1C1C1F), tx: c(0xF7F4EF), mu: c(0xABA69F), mu2: c(0x8A857F), line: c(0x2C2C30), ac: c(0xE8743B), acDim: c(0x86452A), onAc: c(0x0B0B0C))
    }
}
