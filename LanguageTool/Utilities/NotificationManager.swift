import Foundation
import UserNotifications

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    private init() {}

    // MARK: - Permission Management

    /// Request notification permission from the user
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            return granted
        } catch {
            print("Failed to request notification permission: \(error)")
            return false
        }
    }

    /// Check current notification permission status
    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Notification Sending

    /// Send a translation completion notification
    /// - Parameter languageCount: Number of languages translated
    func sendTranslationCompleteNotification(languageCount: Int) {
        Task {
            let status = await checkPermissionStatus()
            guard status == .authorized else { return }

            let content = UNMutableNotificationContent()
            content.title = NSLocalizedString("Translation Complete", comment: "Notification title for completed translation")
            content.body = String(format: NSLocalizedString("Successfully generated localizations for %d languages", comment: "Notification body for completed translation"), languageCount)
            content.sound = UNNotificationSound.default

            let request = UNNotificationRequest(
                identifier: "translation-complete-\(UUID().uuidString)",
                content: content,
                trigger: nil // Send immediately
            )

            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                print("Failed to send translation complete notification: \(error)")
            }
        }
    }

    /// Send a translation failure notification
    /// - Parameter errorMessage: The error message to display
    func sendTranslationFailedNotification(errorMessage: String) {
        Task {
            let status = await checkPermissionStatus()
            guard status == .authorized else { return }

            let content = UNMutableNotificationContent()
            content.title = NSLocalizedString("Translation Failed", comment: "Notification title for failed translation")
            content.body = String(format: NSLocalizedString("Translation failed: %@", comment: "Notification body for failed translation"), errorMessage)
            content.sound = UNNotificationSound.defaultCritical

            let request = UNNotificationRequest(
                identifier: "translation-failed-\(UUID().uuidString)",
                content: content,
                trigger: nil // Send immediately
            )

            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                print("Failed to send translation failed notification: \(error)")
            }
        }
    }

    // MARK: - Utility Methods

    /// Clear all pending notifications
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Clear all delivered notifications
    func clearAllDeliveredNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}

// MARK: - Notification Settings Storage

extension NotificationManager {

    /// Check if notifications are enabled in app settings
    var areNotificationsEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: "notificationsEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "notificationsEnabled")
        }
    }

    /// Initialize default notification settings
    func initializeDefaultSettings() {
        if UserDefaults.standard.object(forKey: "notificationsEnabled") == nil {
            areNotificationsEnabled = true // Default to enabled
        }
    }
}