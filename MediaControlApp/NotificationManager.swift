import Foundation
import UserNotifications

/// Manages macOS notifications for errors and status messages
class NotificationManager {
    static let shared = NotificationManager()

    private init() {
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }

    /// Show an error notification
    /// - Parameters:
    ///   - device: Device name (e.g., "Shield TV", "Receiver")
    ///   - message: Error message
    func showError(device: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = "MediaControl"
        content.body = "\(device): \(message)"
        content.sound = nil // Silent notification

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Show immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to show notification: \(error)")
            }
        }
    }

    /// Show a success notification
    /// - Parameters:
    ///   - device: Device name
    ///   - message: Success message
    func showSuccess(device: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = "MediaControl"
        content.body = "\(device): \(message)"
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
