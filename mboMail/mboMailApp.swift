import SwiftUI
import Carbon.HIToolbox

@main
struct mboMailApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appSettings = AppSettings()
    @State private var networkMonitor = NetworkMonitor()

    var body: some Scene {
        WindowGroup(id: "main") {
            MainWindow()
                .environment(appSettings)
                .environment(networkMonitor)
        }
        .commands {
            CommandGroup(after: .newItem) {
                NewTabCommand()
            }
            CommandGroup(after: .textEditing) {
                Button("Search Mail...") {
                    NotificationCenter.default.post(name: .focusOXSearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
            }
            CommandGroup(after: .pasteboard) {
                Button("Copy Link to Mail") {
                    NotificationCenter.default.post(name: .copyMailLink, object: nil)
                }
                .keyboardShortcut("l", modifiers: .command)
            }
            CommandGroup(replacing: .printItem) {
                Button("Print...") {
                    NotificationCenter.default.post(name: .printMail, object: nil)
                }
                .keyboardShortcut("p", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environment(appSettings)
        }

        MenuBarExtra("mboMail", systemImage: "envelope.fill", isInserted: $appSettings.showInMenuBar) {
            Button("Show / Hide mboMail") {
                toggleAppVisibility()
            }
            .keyboardShortcut("m", modifiers: .option)
            Divider()
            Button("Quit mboMail") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
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
}

/// Monitors raw key events for zoom shortcuts and tab switching.
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

            // Tab switching: Cmd+1 through Cmd+9
            if let chars = event.charactersIgnoringModifiers,
               let digit = chars.first?.wholeNumberValue,
               digit >= 1, digit <= 9 {
                if let mainWindow = NSApp.mainWindow,
                   let tabs = mainWindow.tabbedWindows {
                    let index = (digit == 9) ? tabs.count - 1 : digit - 1
                    if index >= 0, index < tabs.count {
                        tabs[index].makeKeyAndOrderFront(nil)
                    }
                }
                return nil
            }

            return event
        }
    }
}

struct NewTabCommand: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("New Tab") {
            openWindow(id: "main")
        }
        .keyboardShortcut("t", modifiers: .command)
    }
}

extension Notification.Name {
    static let focusOXSearch = Notification.Name("focusOXSearch")
    static let zoomIn = Notification.Name("zoomIn")
    static let zoomOut = Notification.Name("zoomOut")
    static let zoomReset = Notification.Name("zoomReset")
    static let copyMailLink = Notification.Name("copyMailLink")
    static let printMail = Notification.Name("printMail")
}
