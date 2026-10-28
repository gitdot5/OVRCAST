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
}
