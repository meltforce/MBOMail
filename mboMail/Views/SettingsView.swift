import SwiftUI
import KeyboardShortcuts
import UniformTypeIdentifiers
import UserNotifications
import Sparkle

struct SettingsView: View {

    let updater: SPUUpdater

    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            UserInterfaceSettingsTab()
                .tabItem { Label("User Interface", systemImage: "macwindow") }
            ShortcutsSettingsTab()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
            UpdateSettingsTab(updater: updater)
                .tabItem { Label("Update", systemImage: "arrow.down.circle") }
            AdvancedSettingsTab()
                .tabItem { Label("Advanced", systemImage: "chevron.left.forwardslash.chevron.right") }
            DonationSettingsTab()
                .tabItem { Label("Donation", systemImage: "heart") }
        }
        .frame(width: 500, height: 480)
        .onAppear {
            appSettings.checkDefaultMailClient()
        }
    }
}

// MARK: - Tab 1: General

private struct GeneralSettingsTab: View {
    @Environment(AppSettings.self) private var appSettings
    @State private var showManualInstructions = false

    var body: some View {
        @Bindable var settings = appSettings

        Form {
            Section("Startup") {
                Toggle("Start at login", isOn: $settings.startAtLogin)
            }

            Section("Mail") {
                if appSettings.defaultMailClientState {
                    LabeledContent("Default mail app") {
                        Text("MBOMail")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button("Set as default mail app") {
                        let success = appSettings.setAsDefaultMailClient()
                        showManualInstructions = !success
                    }
                    if showManualInstructions {
                        Text("Could not set automatically (app must be in /Applications). Open Mail.app \u{2192} Settings \u{2192} General \u{2192} Default email reader \u{2192} select MBOMail.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Display") {
                LabeledContent("Zoom level") {
                    Text("\(Int(appSettings.zoomLevel * 100))%")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Privacy") {
                Toggle("Block email trackers", isOn: $settings.trackerBlockingEnabled)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Tab 2: User Interface

private struct UserInterfaceSettingsTab: View {
    @Environment(AppSettings.self) private var appSettings
    @State private var showSoundInfo = false

    var body: some View {
        @Bindable var settings = appSettings
        let notificationManager = NotificationManager.shared

        Form {
            Section("General") {
                Toggle(isOn: $settings.showInMenuBar) {
                    Text("Show MBOMail in the Menu Bar")
                    Text("Also shows the number of unread mails")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Toggle("Hide when losing focus", isOn: $settings.autoHideOnFocusLoss)
            }

            Section("Notifications") {
                LabeledContent {
                    HStack {
                        Picker("", selection: $settings.notificationSound) {
                            Text("Default").tag("default")
                            Divider()
                            ForEach(notificationManager.availableSounds(), id: \.self) { sound in
                                Text(sound).tag(sound)
                            }
                            Divider()
                            Text("None").tag("none")
                        }
                        .labelsHidden()
                        .frame(width: 150)

                        Button {
                            showSoundInfo.toggle()
                        } label: {
                            Image(systemName: "info.circle")
                        }
                        .buttonStyle(.borderless)
                        .popover(isPresented: $showSoundInfo) {
                            Text("Sounds are loaded from /System/Library/Sounds, /Library/Sounds, ~/Library/Sounds. You can add your own .aiff sound files to ~/Library/Sounds.")
                                .font(.caption)
                                .padding()
                                .frame(width: 260)
                        }
                    }
                } label: {
                    Text("Notification Sound")
                }

                Text("The mailbox.org Desktop Notifications are disabled because they are not compatible with MBOMail")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Only notify for new mails that arrive in the Inbox", isOn: $settings.onlyNotifyInbox)

                if notificationManager.authorizationStatus != .authorized {
                    Text("MBOMail does **not have permission** to show notifications")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Request Notification Permission") {
                        Task { await notificationManager.requestPermission() }
                    }
                } else {
                    Toggle("Enable notifications", isOn: $settings.notificationsEnabled)
                }
            }
        }
        .formStyle(.grouped)
        .task {
            await notificationManager.refreshAuthorizationStatus()
        }
    }
}

// MARK: - Tab 3: Shortcuts

private struct ShortcutsSettingsTab: View {
    var body: some View {
        Form {
            Section("Toggle Visibility") {
                LabeledContent("Global shortcut") {
                    KeyboardShortcuts.Recorder(for: .toggleVisibility)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Tab 4: Update

private struct UpdateSettingsTab: View {
    @ObservedObject private var viewModel: UpdateSettingsViewModel

    init(updater: SPUUpdater) {
        self.viewModel = UpdateSettingsViewModel(updater: updater)
    }

    var body: some View {
        Form {
            Section("Automatic Updates") {
                Toggle("Automatically check for updates", isOn: $viewModel.automaticallyChecks)
                Toggle("Automatically download updates", isOn: $viewModel.automaticallyDownloads)
                    .disabled(!viewModel.automaticallyChecks)

                Picker("Check interval", selection: $viewModel.checkInterval) {
                    Text("Daily").tag(TimeInterval(86400))
                    Text("Weekly").tag(TimeInterval(604800))
                    Text("Monthly").tag(TimeInterval(2592000))
                }
            }

            Section {
                if let date = viewModel.lastCheckDate {
                    LabeledContent("Last checked") {
                        Text(date, style: .relative)
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Check for Updates Now") {
                    viewModel.checkForUpdates()
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Tab 5: Advanced

private struct AdvancedSettingsTab: View {
    @Environment(AppSettings.self) private var appSettings
    @State private var extensionError: String?

    var body: some View {
        @Bindable var settings = appSettings

        Form {
            Section("Custom CSS") {
                TextEditor(text: $settings.customCSS)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 80)
            }

            Section("Custom JavaScript") {
                TextEditor(text: $settings.customJS)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 80)
            }

            Section {
                let manager = ExtensionManager.shared
                if manager.extensions.isEmpty {
                    Text("No extensions loaded.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(manager.extensions) { ext in
                        HStack {
                            Image(systemName: "puzzlepiece.extension")
                            Text(ext.name)
                            Spacer()
                            Button("Remove") {
                                manager.removeExtension(ext)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                if let extensionError {
                    Text(extensionError)
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                Button("Add Extension...") {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [UTType(filenameExtension: "appex") ?? .item]
                    panel.canChooseDirectories = false
                    panel.canChooseFiles = true
                    panel.allowsMultipleSelection = false
                    guard panel.runModal() == .OK, let url = panel.url else { return }
                    do {
                        try manager.loadExtension(from: url)
                        self.extensionError = nil
                    } catch {
                        self.extensionError = error.localizedDescription
                    }
                }
            } header: {
                Text("Extensions")
            } footer: {
                Text("Load .appex bundles to extend MBOMail. This feature is experimental.")
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Tab 6: Donation

private struct DonationSettingsTab: View {
    var body: some View {
        Form {
            Section {
                Text("MBOMail offers all functionality for free. If you'd like to support its development, you can buy me a coffee or make a small donation.")
                Text("No pressure \u{2014} just gratitude!")
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Buy Me a Coffee") {
                        // placeholder
                    }
                    .disabled(true)

                    Button("Donate via PayPal") {
                        // placeholder
                    }
                    .disabled(true)
                }
            }
        }
        .formStyle(.grouped)
    }
}
