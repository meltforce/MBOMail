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

    // Stored property so @Observable can track changes
    var defaultMailClientState = false

    func checkDefaultMailClient() {
        guard let handler = LSCopyDefaultHandlerForURLScheme("mailto" as CFString)?.takeRetainedValue() as String? else {
            defaultMailClientState = false
            return
        }
        defaultMailClientState = handler.caseInsensitiveCompare(Bundle.main.bundleIdentifier ?? "") == .orderedSame
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
