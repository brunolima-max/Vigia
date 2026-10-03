import SwiftUI
import UserNotifications

final class NotifDelegate: NSObject, UNUserNotificationCenterDelegate {
    // Mostra banner e toca o som mesmo com o app aberto.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}

@main
struct VigiliaApp: App {
    static let delegate = NotifDelegate()
    @StateObject private var store = Store()
    @Environment(\.scenePhase) private var phase

    init() { UNUserNotificationCenter.current().delegate = Self.delegate }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .tint(Theme.olive)
                .task { await store.start() }
                .onChange(of: phase) { p in if p == .active { store.refresh() } }
        }
    }
}
