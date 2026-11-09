import SwiftUI
import FirebaseCore

@main
struct WeeklyDirectionApp: App {
    @StateObject private var store: Store

    init() {
        FirebaseApp.configure()
        _store = StateObject(wrappedValue: Store())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: Store

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
    }
}

struct MainTabs: View {
    var body: some View {
        TabView {
            ThisWeekView()
                .tabItem { Label("Week", systemImage: "calendar") }
            JournalView()
                .tabItem { Label("Reflect", systemImage: "square.and.pencil") }
        }
        .tint(Theme.ac)
    }
}
