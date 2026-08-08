import Foundation
import UserNotifications

@Observable final class NotificationManager {
  static let shared = NotificationManager()
  var authorizationStatus: UNAuthorizationStatus = .notDetermined
  private init() {}

  func refreshStatus() async {
    authorizationStatus = await UNUserNotificationCenter.current().notificationSettings()
      .authorizationStatus
  }

  func schedulePillReminder(hour: Int, minute: Int) async throws {
    let center = UNUserNotificationCenter.current()
    let allowed = try await center.requestAuthorization(options: [.alert, .badge, .sound])
    guard allowed else {
      await refreshStatus()
      return
    }
    center.removePendingNotificationRequests(withIdentifiers: ["lumen.pill.daily"])
    let content = UNMutableNotificationContent()
    content.title = "Pill reminder"
    content.body = "A gentle reminder to take and log today’s pill."
    content.sound = .default
    var components = DateComponents()
    components.hour = hour
    components.minute = minute
    try await center.add(
      UNNotificationRequest(
        identifier: "lumen.pill.daily", content: content,
        trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)))
    await refreshStatus()
  }

  func cancelPillReminder() {
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
      "lumen.pill.daily"
    ])
  }
}
