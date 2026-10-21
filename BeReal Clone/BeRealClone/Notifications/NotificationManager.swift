import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let postReminderIdentifier = "post-reminder"

    private init() {}

    func requestPermissionAndScheduleReminder() {
        center.requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, error in
            if let error = error {
                print("❌ Notification permission error: \(error.localizedDescription)")
                return
            }

            guard granted else {
                print("Notifications were not allowed.")
                return
            }

            self?.scheduleDemonstrationReminder()
        }
    }

    func unregisterNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        center.setBadgeCount(0)
    }

    private func scheduleDemonstrationReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [postReminderIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Time to post!"
        content.body = "Capture and share your BeReal moment now."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(
            identifier: postReminderIdentifier,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                print("❌ Notification scheduling error: \(error.localizedDescription)")
            }
        }
    }
}
