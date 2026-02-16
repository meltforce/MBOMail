import SwiftUI
import Carbon.HIToolbox
import Sparkle

@main
struct MBOMailApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appSettings = AppSettings()
    @State private var networkMonitor = NetworkMonitor()

    private let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    var body: some Scene {
        WindowGroup(id: "main") {
            MainWindow()
                .environment(appSettings)
                .environment(networkMonitor)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
            CommandGroup(replacing: .newItem) {
                WindowCommands()
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
            CommandGroup(after: .toolbar) {
                Button("Reload Page") {
                    NotificationCenter.default.post(name: .reloadPage, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)
            }
            // Zoom commands — SwiftUI menu shortcuts have highest priority and
            // match on the produced character, so "+" works on any keyboard layout.
            CommandGroup(after: .toolbar) {
                Button("Zoom In") {
                    NotificationCenter.default.post(name: .zoomIn, object: nil)
                }
                .keyboardShortcut("+", modifiers: .command)
                Button("Zoom Out") {
                    NotificationCenter.default.post(name: .zoomOut, object: nil)
                }
                .keyboardShortcut("-", modifiers: .command)
                Button("Actual Size") {
                    NotificationCenter.default.post(name: .zoomReset, object: nil)
                }
                .keyboardShortcut("0", modifiers: .command)

                Divider()

                Picker("Appearance", selection: $appSettings.appearanceMode) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.inline)
            }
        }

        Settings {
            SettingsView(updater: updaterController.updater)
                .environment(appSettings)
        }

        MenuBarExtra("MBOMail", systemImage: "envelope.fill", isInserted: $appSettings.showInMenuBar) {
            Button("Show / Hide MBOMail") {
                toggleAppVisibility()
            }
            .keyboardShortcut("m", modifiers: .option)
            Divider()
            Button("Quit MBOMail") {
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

/// Monitors raw key events for numpad zoom and tab switching.
/// Main zoom shortcuts (+/-/0) are handled by SwiftUI menu commands which have
/// highest priority and are keyboard-layout-aware.
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

            // Numpad plus/minus for zoom
            if keyCode == kVK_ANSI_KeypadPlus {
                NotificationCenter.default.post(name: .zoomIn, object: nil)
                return nil
            }
            if keyCode == kVK_ANSI_KeypadMinus {
                NotificationCenter.default.post(name: .zoomOut, object: nil)
                return nil
            }

            // Cmd+= (US keyboard zoom-in without Shift, keyCode 24)
            if keyCode == kVK_ANSI_Equal {
                NotificationCenter.default.post(name: .zoomIn, object: nil)
                return nil
            }

            // Character-based fallback for "+" (covers German/ISO keyboards where
            // + is an unshifted key and may not match the menu shortcut)
            if let chars = event.charactersIgnoringModifiers, chars == "+" {
                NotificationCenter.default.post(name: .zoomIn, object: nil)
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

struct WindowCommands: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("New Window") {
            NSWindow.allowsAutomaticWindowTabbing = false
            openWindow(id: "main")
            DispatchQueue.main.async {
                NSWindow.allowsAutomaticWindowTabbing = true
            }
        }
        .keyboardShortcut("n", modifiers: .command)

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
    static let reloadPage = Notification.Name("reloadPage")
    static let handleMailto = Notification.Name("handleMailto")
}
