import SuppTrackCore
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("ageGroup") private var ageGroup = AgeGroup.adult19to50
    @AppStorage("healthImportEnabled") private var healthImportEnabled = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Age group") {
                    AgeGroupPicker(selection: $ageGroup)
                }
                .accessibilityIdentifier("settings-age")
                Section {
                    Toggle("Import from Apple Health", isOn: $healthImportEnabled)
                        .disabled(true)
                } footer: {
                    Text("Available once the app is signed with a paid Apple Developer account.")
                }
                .accessibilityIdentifier("settings-health")
                Section {
                    Text(disclaimerText).foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("settings-disclaimer")
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .accessibilityIdentifier("settings-screen")
    }
}
