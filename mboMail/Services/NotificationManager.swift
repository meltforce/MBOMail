import Foundation
import UserNotifications
import AppKit

@Observable
@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationManager()

    var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private var previousUnreadCount: Int = -1

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        // Clear any stale delivered notifications on launch
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        Task { await refreshAuthorizationStatus() }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Show notifications even when the app is in the foreground.
    /// Uses completion-handler variant for reliable dispatch under MainActor isolation.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    /// Handle notification clicks — activate the existing window instead of opening a new instance.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            NSApp.activate(ignoringOtherApps: true)
            // Bring the first visible main window to front
            if let window = NSApp.windows.first(where: { $0.isVisible && !$0.title.isEmpty }) {
                window.makeKeyAndOrderFront(nil)
            } else if let window = NSApp.windows.first(where: { !$0.title.isEmpty }) {
                window.makeKeyAndOrderFront(nil)
            }
        }
        completionHandler()
    }

    // MARK: - Permission

    func requestPermission() async {
        do {
            try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Notification permission request failed: \(error)")
        }
        await refreshAuthorizationStatus()
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    // MARK: - Unread Count Tracking

    func handleUnreadCountChange(_ newCount: Int, subject: String, from: String, settings: AppSettings) {
        defer { previousUnreadCount = newCount }

        guard settings.notificationsEnabled else { return }

        // Auto-request permission on first opportunity if not yet determined
        if authorizationStatus == .notDetermined {
            Task { await requestPermission() }
            return
        }

        guard authorizationStatus == .authorized,
              previousUnreadCount >= 0,
              newCount > previousUnreadCount else { return }

        let delta = newCount - previousUnreadCount
        postNotification(newCount: delta, subject: subject, from: from)
    }

    private func postNotification(newCount: Int, subject: String, from: String) {
        let content = UNMutableNotificationContent()

        if !subject.isEmpty, !from.isEmpty {
            content.title = from
            content.body = subject
        } else if !subject.isEmpty {
            content.title = "MBOMail"
            content.body = subject
        } else {
            content.title = "MBOMail"
            content.body = newCount == 1
                ? "You have 1 new email"
                : "You have \(newCount) new emails"
        }

        let soundName = UserDefaults.standard.string(forKey: "notificationSound") ?? "default"
        switch soundName {
        case "default":
            content.sound = .default
        case "none":
            content.sound = nil
        default:
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "\(soundName).aiff"))
        }

        let request = UNNotificationRequest(
            identifier: "newMail-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Available Sounds

    func availableSounds() -> [String] {
        var sounds: Set<String> = []
        let dirs = [
            "/System/Library/Sounds",
            "/Library/Sounds",
            NSHomeDirectory() + "/Library/Sounds"
        ]
        let fm = FileManager.default
        for dir in dirs {
            guard let files = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for file in files where file.hasSuffix(".aiff") {
                sounds.insert(String(file.dropLast(5))) // remove ".aiff"
            }
        }
        return sounds.sorted()
    }
}
