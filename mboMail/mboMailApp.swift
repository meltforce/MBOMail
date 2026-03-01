import SwiftUI
import Carbon.HIToolbox
import Sparkle

// MARK: - Focused Value for Active Account

struct FocusedAccountKey: FocusedValueKey {
    typealias Value = UUID
}

extension FocusedValues {
    var activeAccountID: UUID? {
        get { self[FocusedAccountKey.self] }
        set { self[FocusedAccountKey.self] = newValue }
    }
}

// MARK: - Window ↔ Account Association

extension NSWindow {
    private static var accountIDKey: UInt8 = 0

    var mboMailAccountID: UUID? {
        get { objc_getAssociatedObject(self, &Self.accountIDKey) as? UUID }
        set { objc_setAssociatedObject(self, &Self.accountIDKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

// MARK: - Window Identity

/// Wraps an account UUID with a unique instance ID so that SwiftUI's
/// WindowGroup always creates a fresh window instead of reusing an existing one.
struct WindowID: Hashable, Codable {
    let accountID: UUID
    let instanceID: UUID

    init(accountID: UUID, instanceID: UUID = UUID()) {
        self.accountID = accountID
        self.instanceID = instanceID
    }
}

// MARK: - Window Action Router

@MainActor
final class WindowActionRouter {
    static let shared = WindowActionRouter()
    private var openAction: ((WindowID) -> Void)?

    func configure(_ action: @escaping (WindowID) -> Void) {
        openAction = action
    }

    func openAccount(_ accountID: UUID, inNewWindow: Bool) {
        if inNewWindow {
            NSWindow.allowsAutomaticWindowTabbing = false
        }
        openAction?(WindowID(accountID: accountID))
        if inNewWindow {
            DispatchQueue.main.async {
                NSWindow.allowsAutomaticWindowTabbing = true
            }
        }
    }
}

// MARK: - App

@main
struct MBOMailApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appSettings = AppSettings()
    @State private var networkMonitor = NetworkMonitor()

    private let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    init() {
        // Ensure at least one account exists before any window opens
        if AccountManager.shared.accounts.isEmpty {
            AccountManager.shared.addAccount()
        }
    }

    var body: some Scene {
        WindowGroup(id: "mail", for: WindowID.self) { $windowID in
            MainWindow(accountID: windowID.accountID)
                .environment(appSettings)
                .environment(networkMonitor)
        } defaultValue: {
            WindowID(accountID: AccountManager.shared.defaultAccount?.id ?? UUID())
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

        // Menu bar icon is managed by StatusItemManager (supports account list + badges)
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

// MARK: - File Menu Account Manager

@MainActor
final class FileMenuAccountManager {
    static let shared = FileMenuAccountManager()
    private var observation: NSObjectProtocol?

    func setup() {
        guard observation == nil else { return }
        rebuildMenu()
        observation = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.rebuildMenu()
        }
    }

    private func rebuildMenu() {
        guard let fileMenu = NSApp.mainMenu?.item(withTitle: "File")?.submenu else { return }

        // Remove previously inserted account items (tagged)
        for item in fileMenu.items where item.tag == 9999 {
            fileMenu.removeItem(item)
        }

        let accounts = AccountManager.shared.accounts
        guard accounts.count > 1 else { return }

        // Insert after the last item (before nothing, at end)
        let insertionIndex = fileMenu.items.count

        let separator = NSMenuItem.separator()
        separator.tag = 9999
        fileMenu.insertItem(separator, at: insertionIndex)

        for (_, account) in accounts.enumerated() {
            let openItem = NSMenuItem(
                title: "Open \(account.displayName)",
                action: #selector(openAccount(_:)),
                keyEquivalent: ""
            )
            openItem.target = self
            openItem.tag = 9999
            openItem.representedObject = account.id
            fileMenu.insertItem(openItem, at: insertionIndex + 1)

            let newWindowItem = NSMenuItem(
                title: "Open \(account.displayName) in New Window",
                action: #selector(openAccountInNewWindow(_:)),
                keyEquivalent: ""
            )
            newWindowItem.target = self
            newWindowItem.tag = 9999
            newWindowItem.isAlternate = true
            newWindowItem.keyEquivalentModifierMask = [.option]
            newWindowItem.representedObject = account.id
            fileMenu.insertItem(newWindowItem, at: insertionIndex + 2)
        }
    }

    @objc private func openAccount(_ sender: NSMenuItem) {
        guard let accountID = sender.representedObject as? UUID else { return }
        if let window = NSApp.windows.first(where: {
            $0.isVisible
                && $0.tabbingIdentifier == "mboMailMainWindow"
                && $0.mboMailAccountID == accountID
        }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            WindowActionRouter.shared.openAccount(accountID, inNewWindow: false)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openAccountInNewWindow(_ sender: NSMenuItem) {
        guard let accountID = sender.representedObject as? UUID else { return }
        WindowActionRouter.shared.openAccount(accountID, inNewWindow: true)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Status Item Manager

@MainActor
final class StatusItemManager {
    static let shared = StatusItemManager()

    private var statusItem: NSStatusItem?
    private var observation: NSObjectProtocol?

    var isVisible: Bool = true {
        didSet {
            if isVisible {
                createStatusItemIfNeeded()
            } else {
                removeStatusItem()
            }
        }
    }

    func setup() {
        guard observation == nil else { return }
        let show = UserDefaults.standard.object(forKey: "showInMenuBar") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "showInMenuBar")
        isVisible = show

        observation = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let show = UserDefaults.standard.object(forKey: "showInMenuBar") == nil
                ? true
                : UserDefaults.standard.bool(forKey: "showInMenuBar")
            self?.isVisible = show
        }
    }

    func refreshIcon() {
        guard let button = statusItem?.button else { return }
        let total = AccountManager.shared.totalUnread
        button.image = NSImage(systemSymbolName: total > 0 ? "envelope.badge" : "envelope.fill", accessibilityDescription: "MBOMail")
    }

    private func createStatusItemIfNeeded() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "envelope.fill", accessibilityDescription: "MBOMail")
        statusItem = item
        rebuildMenu()
    }

    private func removeStatusItem() {
        guard let item = statusItem else { return }
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let accounts = AccountManager.shared.accounts
        if accounts.count > 1 {
            for account in accounts {
                let item = NSMenuItem(
                    title: account.displayName,
                    action: #selector(openAccountFromMenu(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = account.id
                let unread = AccountManager.shared.unreadCounts[account.id] ?? 0
                if unread > 0 {
                    item.badge = .init(string: "\(unread)")
                }
                menu.addItem(item)
            }
            menu.addItem(.separator())
        }

        let showHide = NSMenuItem(title: "Show / Hide MBOMail", action: #selector(toggleVisibility), keyEquivalent: "m")
        showHide.keyEquivalentModifierMask = [.option]
        showHide.target = self
        menu.addItem(showHide)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit MBOMail", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem?.menu = menu
    }

    @objc private func openAccountFromMenu(_ sender: NSMenuItem) {
        guard let accountID = sender.representedObject as? UUID else { return }
        if let window = NSApp.windows.first(where: {
            $0.isVisible
                && $0.tabbingIdentifier == "mboMailMainWindow"
                && $0.mboMailAccountID == accountID
        }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            WindowActionRouter.shared.openAccount(accountID, inNewWindow: false)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleVisibility() {
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

// MARK: - Zoom & Tab Key Monitor

/// Monitors raw key events for numpad zoom and tab switching.
/// Main zoom shortcuts (+/-/0) are handled by SwiftUI menu commands which have
/// highest priority and are keyboard-layout-aware.
@MainActor
final class ZoomKeyMonitor {
    static let shared = ZoomKeyMonitor()

    private var monitor: Any?
    private var ctrlMonitor: Any?

    init() {
        // Cmd shortcuts: zoom + tab switching (original monitor)
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

        // Ctrl+digit: account switching (SEPARATE monitor to avoid breaking Cmd+N/T)
        ctrlMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.contains(.control),
                  !event.modifierFlags.contains(.command) else {
                return event
            }

            guard let chars = event.charactersIgnoringModifiers,
                  let digit = chars.first?.wholeNumberValue,
                  digit >= 1, digit <= 9 else {
                return event
            }

            let accounts = AccountManager.shared.accounts
            let index = digit - 1
            guard index < accounts.count else { return event }
            let accountID = accounts[index].id

            if event.modifierFlags.contains(.option) {
                WindowActionRouter.shared.openAccount(accountID, inNewWindow: true)
            } else {
                if let window = NSApp.windows.first(where: {
                    $0.isVisible
                        && $0.tabbingIdentifier == "mboMailMainWindow"
                        && $0.mboMailAccountID == accountID
                }) {
                    window.makeKeyAndOrderFront(nil)
                } else {
                    WindowActionRouter.shared.openAccount(accountID, inNewWindow: false)
                }
            }
            NSApp.activate(ignoringOtherApps: true)
            return nil
        }
    }
}

// MARK: - Window Commands

struct WindowCommands: View {
    @Environment(\.openWindow) private var openWindow
    @FocusedValue(\.activeAccountID) var activeAccountID

    private var effectiveAccountID: UUID {
        activeAccountID ?? AccountManager.shared.defaultAccount?.id ?? UUID()
    }

    private func configureWindowActions() {
        WindowActionRouter.shared.configure { [openWindow] windowID in
            openWindow(id: "mail", value: windowID)
        }
    }

    var body: some View {
        let _ = configureWindowActions()

        Button("New Window") {
            NSWindow.allowsAutomaticWindowTabbing = false
            openWindow(id: "mail", value: WindowID(accountID: effectiveAccountID))
            DispatchQueue.main.async {
                NSWindow.allowsAutomaticWindowTabbing = true
            }
        }
        .keyboardShortcut("n", modifiers: .command)

        Button("New Tab") {
            openWindow(id: "mail", value: WindowID(accountID: effectiveAccountID))
        }
        .keyboardShortcut("t", modifiers: .command)
    }
}

// MARK: - Notification Names

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
