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
                .onAppear { recorder.attach(store) }
                .onChange(of: store.weeks) { _, _ in notifier.schedule(store: store) }
                .onChange(of: store.settings) { _, _ in notifier.schedule(store: store) }
        }
    }
}

struct RootView: View {
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
            if !store.signedIn {
                SignInView()
            } else if !store.ready {
                ProgressView().tint(Theme.mu)
            } else {
                MainTabs()
            }
        }
        .preferredColorScheme(scheme)
        .onChange(of: store.ready) { _, ready in if ready { arrive() } }
        .onChange(of: router.pendingRecord) { _, p in if p, store.ready { arrive() } }
        .onAppear { if store.ready { arrive() } }
    }

    private func arrive() {
        if store.isMock, let s = UserDefaults.standard.string(forKey: "OpenScreen") { router.open(screen: s, store: store) }
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
                case "reflect": if Theme.micFirst { JournalList() } else { ReflectView() }
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
        .modifier(EntryMenu(onEdit: { i in router.cover = .edit(i) }))
        .fullScreenCover(item: $router.cover) { c in
            cover(c).environmentObject(store).environmentObject(router).environmentObject(recorder).environmentObject(notifier)
                .preferredColorScheme(store.settings.theme == "light" ? .light : store.settings.theme == "auto" ? nil : .dark)
        }
        .sheet(item: $router.sheet) { s in
            sheet(s).environmentObject(store).environmentObject(router)
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
        case .recording: RecordingView()
        case .closed(let id): ClosedMoment(weekId: id)
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

/// three square icons: week, reflect, progress
struct TabBar: View {
    @EnvironmentObject var router: Router
    private var tabs: [(String, String)] {
        Theme.micFirst
            ? [("week", "calendar.badge.checkmark"), ("reflect", "book"), ("mic", "mic"), ("prayer", "hands.sparkles"), ("progress", "chart.line.uptrend.xyaxis")]
            : [("week", "calendar.badge.checkmark"), ("reflect", "square.and.pencil"), ("progress", "chart.line.uptrend.xyaxis")]
    }
    @State private var bounce: String?

    var body: some View {
        HStack {
            ForEach(tabs, id: \.0) { t in
                if t.0 == "mic" {
                    Button { router.startRecording() } label: {
                        ZStack {
                            Circle().fill(Theme.bg).frame(width: 76, height: 76)
                            Circle().fill(Theme.ac.opacity(0.18)).frame(width: 70, height: 70)
                            Circle().fill(Theme.ac).frame(width: 60, height: 60)
                            Image(systemName: "mic").font(.system(size: 24, weight: .regular)).foregroundStyle(Theme.onAc)
                        }
                        .frame(maxWidth: .infinity).frame(height: 52).offset(y: -16)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Speak a reflection")
                } else {
                Button {
                    if router.tab != t.0 { Haptic.tick() }
                    if t.0 == "week" { router.selK = nil }
                    router.tab = t.0
                    bounce = t.0
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { bounce = nil }
                } label: {
                    Image(systemName: t.1)
                        .font(.system(size: 25, weight: .regular))
                        .foregroundStyle(router.tab == t.0 ? Theme.tx : Theme.mu2)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .scaleEffect(bounce == t.0 ? 1.16 : 1)
                        .animation(.spring(response: 0.25, dampingFraction: 0.5), value: bounce)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(t.0 == "week" ? "This week" : t.0 == "reflect" ? "Reflect" : t.0 == "prayer" ? "Prayer" : "Progress")
                }
            }
        }
        .padding(.horizontal, Theme.micFirst ? 14 : 36)
        .padding(.top, 6)
        .background(Theme.bg)
        .overlay(alignment: .top) { Rectangle().fill(Theme.rule).frame(height: 1) }
    }
}

