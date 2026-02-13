import SwiftUI

struct SettingsView: View {

    @Environment(AppSettings.self) private var appSettings
    @State private var showManualInstructions = false

    var body: some View {
        @Bindable var settings = appSettings

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
        }
        .formStyle(.grouped)
        .frame(width: 400, height: showManualInstructions ? 300 : 250)
        .onAppear {
            appSettings.checkDefaultMailClient()
        }
    }
}
