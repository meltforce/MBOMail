import SwiftUI
import ServiceManagement

@Observable
final class AppSettings {

    var zoomLevel: Double {
        get { UserDefaults.standard.double(forKey: "zoomLevel").nonZero ?? 1.0 }
        set { UserDefaults.standard.set(newValue, forKey: "zoomLevel") }
    }

    var startAtLogin: Bool {
        get { UserDefaults.standard.bool(forKey: "startAtLogin") }
        set {
            UserDefaults.standard.set(newValue, forKey: "startAtLogin")
            updateLoginItem(newValue)
        }
    }

    var customCSS: String {
        get { UserDefaults.standard.string(forKey: "customCSS") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "customCSS") }
    }

    var customJS: String {
        get { UserDefaults.standard.string(forKey: "customJS") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "customJS") }
    }

    var showInMenuBar: Bool {
        get {
            if UserDefaults.standard.object(forKey: "showInMenuBar") == nil { return true }
            return UserDefaults.standard.bool(forKey: "showInMenuBar")
        }
        set { UserDefaults.standard.set(newValue, forKey: "showInMenuBar") }
    }

    var autoHideOnFocusLoss: Bool {
        get { UserDefaults.standard.bool(forKey: "autoHideOnFocusLoss") }
        set { UserDefaults.standard.set(newValue, forKey: "autoHideOnFocusLoss") }
    }

    // Stored properties so @Observable can track changes and trigger SwiftUI re-renders.
    // Computed properties backed by UserDefaults are NOT observed by the @Observable macro.

    var trackerBlockingEnabled: Bool {
        didSet { UserDefaults.standard.set(trackerBlockingEnabled, forKey: "trackerBlockingEnabled") }
    }

    var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }

    var notificationSound: String {
        didSet { UserDefaults.standard.set(notificationSound, forKey: "notificationSound") }
    }

    var onlyNotifyInbox: Bool {
        didSet { UserDefaults.standard.set(onlyNotifyInbox, forKey: "onlyNotifyInbox") }
    }

    var composeInSeparateWindow: Bool {
        didSet {
            UserDefaults.standard.set(composeInSeparateWindow, forKey: "composeInSeparateWindow")
            NotificationCenter.default.post(name: .composeSettingChanged, object: nil)
        }
    }

    var defaultMailClientState = false

    init() {
        let ud = UserDefaults.standard

        trackerBlockingEnabled = ud.object(forKey: "trackerBlockingEnabled") == nil ? true : ud.bool(forKey: "trackerBlockingEnabled")
        notificationsEnabled = ud.object(forKey: "notificationsEnabled") == nil ? true : ud.bool(forKey: "notificationsEnabled")
        notificationSound = ud.string(forKey: "notificationSound") ?? "default"
        onlyNotifyInbox = ud.object(forKey: "onlyNotifyInbox") == nil ? true : ud.bool(forKey: "onlyNotifyInbox")
        composeInSeparateWindow = ud.bool(forKey: "composeInSeparateWindow")
    }

    func checkDefaultMailClient() {
        guard let mailtoURL = URL(string: "mailto:"),
              let handlerURL = NSWorkspace.shared.urlForApplication(toOpen: mailtoURL),
              let handlerBundle = Bundle(url: handlerURL)?.bundleIdentifier else {
            defaultMailClientState = false
            return
        }
        defaultMailClientState = handlerBundle.caseInsensitiveCompare(Bundle.main.bundleIdentifier ?? "") == .orderedSame
    }

    /// Returns true if set successfully, false if user needs to do it manually.
    func setAsDefaultMailClient() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return false }
        let status = LSSetDefaultHandlerForURLScheme("mailto" as CFString, bundleID as CFString)
        checkDefaultMailClient()
        return status == noErr && defaultMailClientState
    }

    private func updateLoginItem(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update login item: \(error)")
        }
    }
}

private extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
}
