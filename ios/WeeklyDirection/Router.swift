import SwiftUI

/// What is on screen above the tabs. Kept in one place so a launch argument (`-OpenScreen <name>`), the Reflect
/// App Intent and the Home Screen quick action can open any screen directly.
@MainActor
final class Router: ObservableObject {
    static let shared = Router()

    enum Cover: Identifiable, Equatable {
        case settings
        case plan(replan: String?)
        case vision(String)
        case stats(String?)                 // week id, or nil for All time
        case focus(week: String, habit: String, day: String)
        case weekPage(String)
        case write
        case edit(Int)
        case closed(String)                 // the closing moment for a week
        var id: String { String(describing: self) }
    }
    enum Sheet: Identifiable, Equatable {
        case habit(week: String, habit: String, day: String?)
        case close(String)
        case prayer(String?, pinned: Bool)  // prayer id, or nil for a new one
        var id: String { String(describing: self) }
    }

    @Published var tab = "week"             // week | reflect (the journal list) | prayer | progress
    @Published var cover: Cover?
    @Published var sheet: Sheet? {
        didSet {
            guard let s = sheet else { return }
            // a habit, and a prayer that is only its name, open as a half sheet; anything to read or write gets the page
            if case .habit = s { detent = .medium } else if case .prayer = s, half { detent = .medium } else { detent = .large }
            half = false
        }
    }
    /// `-OpenScreen close-rate`: open the review on its rating step (screenshots)
    var rateOnOpen = false
    /// the review was opened from the mic: start listening as it opens
    var dictateOnOpen = false
    /// `-OpenScreen settings-…`: the settings page to open on
    var settingsPage: String?
    /// how tall the open sheet is; a half sheet goes to `.large` when its editor opens
    @Published var detent: PresentationDetent = .large
    /// set right before `sheet` to open a prayer as a half sheet
    var half = false
    /// the day the habit list shows (nil = today)
    @Published var selK: String?
    /// the Reflect intent arrived before the data did
    @Published var pendingRecord = false
    /// the recording space is up: an overlay, not a cover, so it opens and closes at once
    @Published var recording = false
    func endRecording() { withAnimation(.easeOut(duration: 0.16)) { recording = false } }

    func startRecording() {
        sheet = nil
        cover = nil
        if !recording { withAnimation(.easeOut(duration: 0.16)) { recording = true } }
    }

    /// `-OpenScreen <name>`: used by scripts/shot.sh with sample data
    func open(screen: String, store: Store) {
        let aw = store.activeWeek, k = Rules.ymd(Now.date)
        let first = aw?.commitments.first, last = aw?.commitments.last
        switch screen {
        case "week": break
        case "week-day": selK = aw.flatMap { w in Rules.habitDays(w, store.settings).map(Rules.ymd).first { $0 < k && w.marks[$0] == nil } }
        case "habit": if let aw, let last { sheet = .habit(week: aw.id, habit: last.id, day: k) }
        case "habit-past": if let aw, let last { selK = "2026-11-10"; sheet = .habit(week: aw.id, habit: last.id, day: "2026-11-10") }
        case "focus": if let aw, let first { store.setRun(aw, k, first.id, Now.ms - 5 * 60000 - 20000); cover = .focus(week: aw.id, habit: first.id, day: k) }
        case "vision": if let aw { cover = .vision(aw.id) }
        case "settings": cover = .settings
        case "settings-questions": settingsPage = "questions"; cover = .settings
        case "settings-caffeine":
            if store.isMock { store.setSettings(["cafOn": true, "cafFrom": Logic.midnight(Now.date.addingTimeInterval(-6 * 86400)).timeIntervalSince1970 * 1000]) }
            settingsPage = "caffeine"; cover = .settings
        case "plan": cover = .plan(replan: aw?.id)
        case "reflect": tab = "reflect"
        case "week-page": tab = "reflect"; if let aw { cover = .weekPage(aw.id) }
        case "week-page-past": tab = "reflect"; if let w = store.weeks.first(where: { !$0.isActive && $0.summary != nil }) { cover = .weekPage(w.id) }
        case "week-page-select": tab = "reflect"; selectMode = true; if let aw { cover = .weekPage(aw.id) }
        case "entry-menu": tab = "reflect"; entryMenu = aw.flatMap { Journal.entries($0.liveRefl).last?.i }
        case "edit": tab = "reflect"; if let i = aw.flatMap({ Journal.entries($0.liveRefl).last?.i }) { cover = .edit(i) }
        case "write": tab = "reflect"; cover = .write
        case "recording": recording = true
        case "prayer": tab = "prayer"
        case "prayer-open": tab = "prayer"; sheet = .prayer(store.prayers.first { !$0.pinned }?.id, pinned: false)
        case "prayer-short": tab = "prayer"; half = true; sheet = .prayer(store.prayers.first { !$0.pinned && $0.body.isEmpty }?.id, pinned: false)
        case "progress": tab = "progress"
        case "progress-habits": tab = "progress"; progressView = "habits"
        case "progress-growth": tab = "progress"; progressView = "growth"
        case "close-rate": if let aw { rateOnOpen = true; sheet = .close(aw.id) }
        case "stats": tab = "progress"; if let aw { cover = .stats(aw.id) }
        case "stats-all": tab = "progress"; cover = .stats(nil)
        case "close": if let aw { sheet = .close(aw.id) }
        case "closed": if let aw { cover = .closed(aw.id) }
        default: break
        }
    }

    // small pieces of screen state that screenshots need to reach
    @Published var selectMode = false
    @Published var entryMenu: Int?
    @Published var progressView = "weeks"
}
