import SwiftUI
import FirebaseCore

@main
struct WeeklyDirectionApp: App {
    @StateObject private var store: Store
    @StateObject private var router = Router.shared
    @StateObject private var recorder = Recorder()
    @StateObject private var notifier = Notifier()
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        let mock = Mock.enabled
        if !mock { FirebaseApp.configure() }
        let s = Store(mock: mock)
        if mock { Mock.load(into: s) }
        _store = StateObject(wrappedValue: s)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(router)
                .environmentObject(recorder)
                .environmentObject(notifier)
                .onAppear {
                    recorder.attach(store)
                    // screenshots: two recordings waiting on the phone, one with on-phone words and one without
                    if store.isMock, UserDefaults.standard.string(forKey: "OpenScreen") == "reflect-offline" {
                        recorder.waiting = [.init(at: Now.date.addingTimeInterval(-3000), seconds: 42, text: nil),
                                            .init(at: Now.date.addingTimeInterval(-600), seconds: 75, text: "Long day on site and I did not get to devotion until after lunch, which I think is the real pattern this week")]
                    }
                }
                .onChange(of: store.weeks) { _, _ in notifier.schedule(store: store); WidgetBridge.sync(store) }
                .onChange(of: store.settings) { _, _ in notifier.schedule(store: store); WidgetBridge.sync(store) }
                .onChange(of: store.signedIn) { _, on in if !on, !store.isMock { WidgetBridge.clear() } }
                .onChange(of: store.practice) { was, on in if was, !on { recorder.dropPractice(since: store.practiceSince) } }
                // widget links: weeklydirection://dictate starts recording, anything else just opens the week
                .onOpenURL { url in
                    router.tab = "week"
                    if url.host == "dictate" { router.pendingRecord = true }
                }
        }
    }
}

struct RootView: View {
    @Environment(\.scenePhase) private var phase
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @EnvironmentObject var recorder: Recorder

    /// appearance: dark (default), light, or follow the phone
    private var scheme: ColorScheme? {
        switch store.settings.theme {
        case "light": return .light
        case "auto": return nil
        default: return .dark
        }
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            if Mock.enabled, UserDefaults.standard.string(forKey: "OpenScreen") == "icons" {
                IconOptions()
            } else if Mock.enabled, UserDefaults.standard.string(forKey: "OpenScreen") == "widgets" {
                WidgetPreview()
            } else if !store.signedIn {
                SignInView()
            } else if !store.ready {
                ProgressView().tint(Theme.mu)
            } else {
                MainTabs()
            }
        }
        // practice mode is always visible on the main pages, with the way out
        .safeAreaInset(edge: .top, spacing: 0) {
            if store.practice {
                Button { Haptic.tick(); store.exitPractice() } label: {
                    HStack(spacing: 8) {
                        Text("Practice").caps(13)
                        Text("nothing is saved").font(Theme.ui(13))
                        Text("Exit").caps(13).padding(.leading, 6)
                    }
                    .foregroundStyle(Theme.onAc).padding(.horizontal, 14).frame(height: 30).background(Theme.ac, in: Capsule())
                }
                .buttonStyle(.plain).padding(.top, 2).padding(.bottom, 4).frame(maxWidth: .infinity).background(Theme.bg)
            }
        }
        .preferredColorScheme(scheme)
        .onChange(of: store.ready) { _, ready in if ready { arrive() } }
        // back in front: the Dictate control or shortcut may have asked for a recording; the widgets and the timer on
        // the Lock Screen are brought up to date on the way in and on the way out
        .onChange(of: phase) { _, ph in
            if ph == .active, Shared.defaults?.bool(forKey: Shared.pendingDictateKey) == true {
                Shared.defaults?.set(false, forKey: Shared.pendingDictateKey)
                router.pendingRecord = true
            }
            if ph != .inactive, store.ready { WidgetBridge.sync(store) }
        }
        .onChange(of: router.pendingRecord) { _, p in if p, store.ready { arrive() } }
        .onAppear { if store.ready { arrive() } }
    }

    private func arrive() {
        if store.isMock, let s = UserDefaults.standard.string(forKey: "OpenScreen") { router.open(screen: s, store: store) }
        if Shared.defaults?.bool(forKey: Shared.pendingDictateKey) == true {
            Shared.defaults?.set(false, forKey: Shared.pendingDictateKey)
            router.pendingRecord = true
        }
        WidgetBridge.sync(store)
        if router.pendingRecord {
            router.pendingRecord = false
            if store.activeWeek != nil { router.startRecording() }
        }
        if !store.isMock { Task { try? await Task.sleep(nanoseconds: 3_000_000_000); await recorder.flush() } }
    }
}

struct MainTabs: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @EnvironmentObject var recorder: Recorder
    @EnvironmentObject var notifier: Notifier

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch router.tab {
                case "reflect": JournalList()
                case "prayer":
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Prayer").font(Theme.serif(34)).foregroundStyle(Theme.tx).padding(.horizontal, 24).padding(.top, 20)
                        PrayerList()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                case "progress": ProgressScreen()
                default: ThisWeekView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
            TabBar()
        }
        .background(Theme.bg.ignoresSafeArea())
        .ignoresSafeArea(.keyboard)
        .overlay { if router.recording { RecordingView().transition(.opacity).zIndex(5) } }
        .modifier(EntryMenu(onEdit: { i in router.cover = .edit(i) }))
        .fullScreenCover(item: $router.cover) { c in
            cover(c).environmentObject(store).environmentObject(router).environmentObject(recorder).environmentObject(notifier)
                .preferredColorScheme(store.settings.theme == "light" ? .light : store.settings.theme == "auto" ? nil : .dark)
        }
        .sheet(item: $router.sheet) { s in
            sheet(s).environmentObject(store).environmentObject(router).environmentObject(recorder)
                // a habit, and a prayer with nothing but its name, open as a half sheet; pull it up for more room
                .presentationDetents({ if case .close = s { return [.large] } else { return [.medium, .large] } }(), selection: $router.detent)
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .presentationBackground(Theme.bg)
                .preferredColorScheme(store.settings.theme == "light" ? .light : store.settings.theme == "auto" ? nil : .dark)
        }
    }

    @ViewBuilder private func cover(_ c: Router.Cover) -> some View {
        switch c {
        case .settings: SettingsView()
        case .plan(let id): PlanView(replanId: id)
        case .vision(let id): VisionView(weekId: id, log: false)
        case .stats(let id): StatsView(weekId: id)
        case .focus(let wid, let hid, let k): FocusView(weekId: wid, habitId: hid, day: k)
        case .weekPage(let id): WeekPage(weekId: id)
        case .write: EntryEditor(entry: nil)
        case .edit(let i): EntryEditor(entry: i)
        case .closed(let id): ClosedMoment(weekId: id)
        case .prayerWeeks: PrayerWeeksView()
        }
    }

    @ViewBuilder private func sheet(_ s: Router.Sheet) -> some View {
        switch s {
        case .habit(let wid, let hid, let k): HabitSheet(weekId: wid, habitId: hid, day: k)
        case .prayer(let id, let pinned): PrayerSheet(prayerId: id, pinned: pinned)
        case .close(let id): CloseSheet(weekId: id)
        }
    }
}

/// This Week, Journal, the mic (speak a thought from any screen), Prayer, Progress
struct TabBar: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var recorder: Recorder
    @EnvironmentObject var store: Store
    private let tabs = [("week", "calendar.badge.checkmark"), ("reflect", "book"), ("mic", "mic"), ("prayer", "hands.sparkles"),
                        ("progress", "chart.line.uptrend.xyaxis")]
    @State private var bounce: String?

    var body: some View {
        HStack {
            ForEach(tabs, id: \.0) { t in
                if t.0 == "mic" {
                    // on the Prayer tab the same button records a prayer into the prayer log. It stays the mic on every tab
                    // (Eddie, Nov 11 2026, after trying a cross and praying hands): it writes into the page you are on
                    let praying = router.tab == "prayer"
                    Button { router.startRecording(prayer: praying) } label: {
                        ZStack {
                            // larger (Eddie, Nov 10 2026): it is the most used control in the app
                            Circle().fill(Theme.bg).frame(width: 90, height: 90)
                            Circle().fill(Theme.ac.opacity(0.18)).frame(width: 84, height: 84)
                            Circle().fill(Theme.ac).frame(width: 72, height: 72)
                            Image(systemName: "mic").font(.system(size: 29, weight: .regular)).foregroundStyle(Theme.onAc)
                        }
                        .frame(maxWidth: .infinity).frame(height: 52).offset(y: -22)
                    }
                    .buttonStyle(.plain)
                    // a thought needs a week to go into; a prayer does not
                    .disabled(store.activeWeek == nil && !praying)
                    .opacity(store.activeWeek == nil && !praying ? 0.45 : 1)
                    .accessibilityLabel(praying ? "Pray out loud" : "Speak a reflection")
                } else {
                Button {
                    if router.tab != t.0 { Haptic.tick() }
                    if t.0 == "week" { router.selK = nil }
                    router.tab = t.0
                    bounce = t.0
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { bounce = nil }
                } label: {
                    TabIcon(name: t.0, size: 30)
                        .foregroundStyle(router.tab == t.0 ? Theme.tx : Theme.mu2)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .scaleEffect(bounce == t.0 ? 1.16 : 1)
                        .animation(.spring(response: 0.25, dampingFraction: 0.5), value: bounce)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(t.0 == "week" ? "This week" : t.0 == "reflect" ? "Journal" : t.0 == "prayer" ? "Prayer" : "Progress")
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        // the rule sits behind the mic, which rises above the bar
        .background(alignment: .top) { Rectangle().fill(Theme.rule).frame(height: 1) }
        .background(Theme.bg)
    }
}

