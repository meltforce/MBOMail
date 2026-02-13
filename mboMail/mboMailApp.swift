import SwiftUI

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
                Button("Find...") {
                    NotificationCenter.default.post(name: .toggleFind, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
            }

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
            }
        }

        Settings {
            SettingsView()
                .environment(appSettings)
        }
    }
}

extension Notification.Name {
    static let toggleFind = Notification.Name("toggleFind")
    static let zoomIn = Notification.Name("zoomIn")
    static let zoomOut = Notification.Name("zoomOut")
    static let zoomReset = Notification.Name("zoomReset")
}
