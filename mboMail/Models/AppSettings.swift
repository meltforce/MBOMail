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
