import AppKit
import Carbon.HIToolbox
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleVisibility = Self("toggleVisibility", default: .init(.m, modifiers: .option))
}

class AppDelegate: NSObject, NSApplicationDelegate {

    /// Mailto params received during cold start (before MainWindow exists).
    static var pendingMailtoParams: [String: String]?

    /// Register GetURL handler BEFORE SwiftUI's scene system processes it.
    /// Must be in willFinishLaunching to intercept before SwiftUI creates a new window.
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = true

        // Initialize NotificationManager early so UNUserNotificationCenter delegate
        // is set before any notifications arrive or are clicked
        _ = NotificationManager.shared

        KeyboardShortcuts.onKeyUp(for: .toggleVisibility) {
            toggleAppVisibility()
        }
    }

    /// Handle mailto: URLs intercepted at the AppleEvent level.
    @objc private func handleGetURL(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString),
              url.scheme == "mailto" else { return }

        let params = MailtoHandler.parse(url)

        // If a main window is already visible, route compose to it via notification.
        // Otherwise store for the MainWindow to pick up on appear.
        if NSApp.windows.contains(where: { $0.isVisible && $0.tabbingIdentifier == "mboMailMainWindow" }) {
            NotificationCenter.default.post(
                name: .handleMailto,
                object: nil,
                userInfo: params
            )
        } else {
            AppDelegate.pendingMailtoParams = params
        }
    }
}

private func toggleAppVisibility() {
    if NSApp.isHidden {
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
    } else if NSApp.isActive {
        NSApp.hide(nil)
    } else {
        NSApp.activate(ignoringOtherApps: true)
    }
}
