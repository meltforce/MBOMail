import SwiftUI
import KeyboardShortcuts
import UniformTypeIdentifiers

struct SettingsView: View {

    @Environment(AppSettings.self) private var appSettings
    @State private var showManualInstructions = false

    var body: some View {
        @Bindable var settings = appSettings

        TabView {
            Form {
                Section("General") {
                    Toggle("Start at login", isOn: $settings.startAtLogin)

                    LabeledContent("Zoom level") {
                        Text("\(Int(appSettings.zoomLevel * 100))%")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Mail") {
                    if appSettings.defaultMailClientState {
                        LabeledContent("Default mail app") {
                            Text("mboMail")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button("Set as default mail app") {
                            let success = appSettings.setAsDefaultMailClient()
                            showManualInstructions = !success
                        }
                        if showManualInstructions {
                            Text("Could not set automatically (app must be in /Applications). Open Mail.app \u{2192} Settings \u{2192} General \u{2192} Default email reader \u{2192} select mboMail.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Privacy") {
                    Toggle("Block email trackers", isOn: $settings.trackerBlockingEnabled)
                }

                Section("Appearance") {
                    Toggle("Show in menu bar", isOn: $settings.showInMenuBar)
                    Toggle("Auto-hide when switching apps", isOn: $settings.autoHideOnFocusLoss)

                    LabeledContent("Global shortcut") {
                        KeyboardShortcuts.Recorder(for: .toggleVisibility)
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("General", systemImage: "gearshape") }

            Form {
                Section("Custom CSS") {
                    TextEditor(text: $settings.customCSS)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 100)
                }

                Section("Custom JavaScript") {
                    TextEditor(text: $settings.customJS)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 100)
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("Advanced", systemImage: "chevron.left.forwardslash.chevron.right") }

            ExtensionsSettingsView()
                .tabItem { Label("Extensions", systemImage: "puzzlepiece.extension") }
        }
        .frame(width: 500, height: 400)
        .onAppear {
            appSettings.checkDefaultMailClient()
        }
    }
}

// MARK: - Extensions Settings

private struct ExtensionsSettingsView: View {
    @State private var errorMessage: String?

    var body: some View {
        let manager = ExtensionManager.shared

        Form {
            Section {
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
            } header: {
                Text("Loaded Extensions")
            } footer: {
                Text("Load .appex bundles to extend mboMail. This feature is experimental.")
                    .font(.caption)
            }

            if let errorMessage {
                Text(errorMessage)
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
                    errorMessage = nil
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
        .formStyle(.grouped)
    }
}
