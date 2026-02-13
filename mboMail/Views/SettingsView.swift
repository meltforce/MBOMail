import SwiftUI

struct SettingsView: View {

    @Environment(AppSettings.self) private var appSettings

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
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 200)
    }
}
