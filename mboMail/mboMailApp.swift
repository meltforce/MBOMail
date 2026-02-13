import SwiftUI
import Carbon.HIToolbox

@main
struct mboMailApp: App {

    @State private var appSettings = AppSettings()
    @State private var networkMonitor = NetworkMonitor()

    var body: some Scene {
        WindowGroup {
            MainWindow()
                .environment(appSettings)
                .environment(networkMonitor)
        }
        .commands {
            CommandGroup(after: .textEditing) {
                Button("Search Mail...") {
                    NotificationCenter.default.post(name: .focusOXSearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environment(appSettings)
        }
    }
}

/// Monitors raw key events for zoom shortcuts using hardware key codes,
/// so Cmd+plus works regardless of keyboard layout (US, German, etc.).
@MainActor
final class ZoomKeyMonitor {
    static let shared = ZoomKeyMonitor()

    private var monitor: Any?

    init() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.contains(.command),
                  !event.modifierFlags.contains(.control),
                  !event.modifierFlags.contains(.option) else {
                return event
            }

            let keyCode = Int(event.keyCode)

            // kVK_ANSI_Equal (24) — the +/= key on US, +/* on German
            if keyCode == kVK_ANSI_Equal {
                NotificationCenter.default.post(name: .zoomIn, object: nil)
                return nil
            }

            // kVK_ANSI_Minus (27)
            if keyCode == kVK_ANSI_Minus {
                NotificationCenter.default.post(name: .zoomOut, object: nil)
                return nil
            }

            // kVK_ANSI_0 (29)
            if keyCode == kVK_ANSI_0 {
                NotificationCenter.default.post(name: .zoomReset, object: nil)
                return nil
            }

            return event
        }
    }
}

extension Notification.Name {
    static let focusOXSearch = Notification.Name("focusOXSearch")
    static let zoomIn = Notification.Name("zoomIn")
    static let zoomOut = Notification.Name("zoomOut")
    static let zoomReset = Notification.Name("zoomReset")
}
