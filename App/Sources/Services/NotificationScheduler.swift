import Foundation
import UserNotifications

/// Race-day reminders: one actionable "leave now" alert for the next spot,
/// rescheduled whenever the ETA model shifts (check-ins, recalibrations).
struct NotificationScheduler: Sendable {
    private static let leavePrefix = "cheerplan.leave."

    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Replaces any pending leave alert with one firing at `date`.
    func scheduleLeaveAlert(legIndex: Int, title: String, body: String, at date: Date) async throws {
        await cancelLeaveAlerts()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, date.timeIntervalSinceNow),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: Self.leavePrefix + String(legIndex),
            content: content,
            trigger: trigger
        )
        try await UNUserNotificationCenter.current().add(request)
    }

    func cancelLeaveAlerts() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let identifiers = pending.map(\.identifier).filter { $0.hasPrefix(Self.leavePrefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
