import AppIntents
import UIKit

/// "Reflect": opens the app straight into recording. Map it to Back Tap (Settings › Accessibility › Touch › Back Tap ›
/// Shortcuts), ask Siri, or use the Home Screen quick action.
struct ReflectIntent: AppIntent {
    static var title: LocalizedStringResource = "Reflect"
    static var description = IntentDescription("Record a spoken reflection for this week.")
    static var openAppWhenRun = true

    @MainActor func perform() async throws -> some IntentResult {
        Router.shared.pendingRecord = true
        return .result()
    }
}

/// "Dictate" (`DictateIntent`, Shared/WidgetShared.swift) is the same action for the Lock Screen / Control Center control
/// and the Action button; both appear in the Shortcuts app.
struct WeeklyDirectionShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: DictateIntent(), phrases: ["Record a thought in \(.applicationName)", "Speak in \(.applicationName)"],
                    shortTitle: "Record a thought", systemImageName: "mic.fill")
        AppShortcut(intent: ReflectIntent(), phrases: ["Reflect in \(.applicationName)", "Record a reflection in \(.applicationName)"],
                    shortTitle: "Reflect", systemImageName: "mic")
    }
}

/// Home Screen quick action "Reflect" (UIApplicationShortcutItems in Info.plist)
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if options.shortcutItem?.type == "reflect" { Task { @MainActor in Router.shared.pendingRecord = true } }
        let c = UISceneConfiguration(name: nil, sessionRole: session.role)
        c.delegateClass = SceneDelegate.self
        return c
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        if shortcutItem.type == "reflect" { Task { @MainActor in Router.shared.pendingRecord = true } }
        completionHandler(true)
    }
}
