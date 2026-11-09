import SwiftUI
import FirebaseCore

@main
struct WeeklyDirectionApp: App {
    @StateObject private var store: Store
    @StateObject private var router = Router.shared

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
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @Environment(\.colorScheme) private var system

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
        .onAppear { if store.ready { arrive() } }
    }

    private func arrive() {
        if store.isMock, let s = UserDefaults.standard.string(forKey: "OpenScreen") { router.open(screen: s, store: store) }
        if router.pendingRecord, store.activeWeek != nil { router.pendingRecord = false; router.startRecording() }
    }
}

struct MainTabs: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch router.tab {
                case "reflect": ReflectView()
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
        .fullScreenCover(item: $router.cover) { c in
            cover(c).environmentObject(store).environmentObject(router)
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
        case .settings: Text("Settings")
        case .plan: Text("Plan")
        case .vision(let id): VisionView(weekId: id, log: false)
        case .stats: Text("Stats")
        case .focus(let wid, let hid, let k): FocusView(weekId: wid, habitId: hid, day: k)
        case .weekPage, .write, .edit, .recording, .closed: Text("Soon")
        }
    }

    @ViewBuilder private func sheet(_ s: Router.Sheet) -> some View {
        switch s {
        case .habit(let wid, let hid, let k): HabitSheet(weekId: wid, habitId: hid, day: k)
        case .close, .prayer: Text("Soon")
        }
    }
}

/// three square icons: week, reflect, progress
struct TabBar: View {
    @EnvironmentObject var router: Router
    private let tabs = [("week", "calendar.badge.checkmark"), ("reflect", "square.and.pencil"), ("progress", "chart.line.uptrend.xyaxis")]
    @State private var bounce: String?

    var body: some View {
        HStack {
            ForEach(tabs, id: \.0) { t in
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
                .accessibilityLabel(t.0 == "week" ? "This week" : t.0 == "reflect" ? "Reflect" : "Progress")
            }
        }
        .padding(.horizontal, 36)
        .padding(.top, 6)
        .background(Theme.bg)
        .overlay(alignment: .top) { Rectangle().fill(Theme.rule).frame(height: 1) }
    }
}

struct ProgressScreen: View { var body: some View { Text("Progress").foregroundStyle(Theme.mu) } }
struct ReflectView: View { var body: some View { JournalView() } }
