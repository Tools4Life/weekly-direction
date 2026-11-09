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
        case recording
        case closed(String)                 // the closing moment for a week
        var id: String { String(describing: self) }
    }
    enum Sheet: Identifiable, Equatable {
        case habit(week: String, habit: String, day: String?)
        case close(String)
        case prayer(String?, pinned: Bool)  // prayer id, or nil for a new one
        var id: String { String(describing: self) }
    }

    @Published var tab = "week"             // week | reflect | progress
    @Published var reflectView = "j"        // j = journal, p = prayer
    @Published var cover: Cover?
    @Published var sheet: Sheet?
    /// the day the habit list shows (nil = today)
    @Published var selK: String?
    /// the Reflect intent arrived before the data did
    @Published var pendingRecord = false

    func startRecording() {
        sheet = nil
        tab = "reflect"; reflectView = "j"
        if cover != .recording { cover = .recording }
    }

    /// `-OpenScreen <name>`: used by scripts/shot.sh with sample data
    func open(screen: String, store: Store) {
        let aw = store.activeWeek, k = Rules.ymd(Now.date)
        let first = aw?.commitments.first, last = aw?.commitments.last
        switch screen {
        case "week": break
        case "week-day": selK = aw.flatMap { w in Rules.habitDays(w, store.settings).map(Rules.ymd).first { $0 < k && w.marks[$0] == nil } }
        case "habit": if let aw, let last { sheet = .habit(week: aw.id, habit: last.id, day: k) }
        case "focus": if let aw, let first { store.setRun(aw, k, first.id, Now.ms - 5 * 60000 - 20000); cover = .focus(week: aw.id, habit: first.id, day: k) }
        case "vision": if let aw { cover = .vision(aw.id) }
        case "settings": cover = .settings
        case "plan": cover = .plan(replan: aw?.id)
        case "reflect": tab = "reflect"
        case "reflect-past": tab = "reflect"; reflectIndex = 1
        case "week-page": tab = "reflect"; if let aw { cover = .weekPage(aw.id) }
        case "week-page-select": tab = "reflect"; selectMode = true; if let aw { cover = .weekPage(aw.id) }
        case "entry-menu": tab = "reflect"; entryMenu = aw.flatMap { Journal.entries($0.liveRefl).last?.i }
        case "edit": tab = "reflect"; if let i = aw.flatMap({ Journal.entries($0.liveRefl).last?.i }) { cover = .edit(i) }
        case "write": tab = "reflect"; cover = .write
        case "recording": tab = "reflect"; cover = .recording
        case "prayer": tab = "reflect"; reflectView = "p"
        case "prayer-open": tab = "reflect"; reflectView = "p"; sheet = .prayer(store.prayers.first { !$0.pinned }?.id, pinned: false)
        case "progress": tab = "progress"
        case "progress-habits": tab = "progress"; progressView = "habits"
        case "stats": tab = "progress"; if let aw { cover = .stats(aw.id) }
        case "stats-all": tab = "progress"; cover = .stats(nil)
        case "close": if let aw { sheet = .close(aw.id) }
        case "closed": if let aw { cover = .closed(aw.id) }
        default: break
        }
    }

    // small pieces of screen state that screenshots need to reach
    @Published var reflectIndex = 0
    @Published var selectMode = false
    @Published var entryMenu: Int?
    @Published var progressView = "weeks"
}
