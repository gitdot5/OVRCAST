import Foundation
import UserNotifications

@MainActor enum Notifications {
    static func request() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }
    static func deliver(_ alert: UsageAlert) {
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.body
        // Alerts deliberately omit account identities, machines and balances.
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
    static func test() async -> String {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return "Enable OVRCAST alerts and allow notifications in System Settings before testing."
        }
        let content = UNMutableNotificationContent()
        content.title = "OVRCAST test alert"; content.body = "Notifications are connected. No account information is included."
        let id = "ovrcast-test-" + UUID().uuidString
        do {
            try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            let delivered = await center.deliveredNotifications()
            return delivered.contains(where: { $0.request.identifier == id }) ? "Test alert delivered to Notification Center. Check your banner and Focus settings." : "macOS accepted the test alert. Check Notification Center and Focus settings."
        } catch { return "The test alert could not be scheduled. Check OVRCAST notification permissions." }
    }
}
