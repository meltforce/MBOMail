import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleVisibility = Self("toggleVisibility", default: .init(.m, modifiers: .option))
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = true

        KeyboardShortcuts.onKeyUp(for: .toggleVisibility) {
            toggleAppVisibility()
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
