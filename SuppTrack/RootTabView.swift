import SwiftUI

struct RootTabView: View {
    @AppStorage("disclaimerAccepted") private var disclaimerAccepted = false
    @State private var showSettings = false

    var body: some View {
        TabView {
            Tab("Today", systemImage: "checklist") {
                NavigationStack {
                    Text("Today")
                        .navigationTitle("Today")
                        .toolbar { settingsButton }
                }
                .accessibilityIdentifier("today-tab")
            }
            Tab("Scan", systemImage: "barcode.viewfinder") {
                ScanView()
                    .accessibilityIdentifier("scan-tab")
            }
            Tab("My Bottles", systemImage: "pills") {
                BottlesView()
                    .accessibilityIdentifier("bottles-tab")
            }
        }
        .accessibilityIdentifier("root-tabs")
        .sheet(isPresented: $showSettings) { SettingsView() }
        .fullScreenCover(isPresented: .constant(!disclaimerAccepted)) { DisclaimerView() }
    }

    private var settingsButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Settings", systemImage: "gearshape") { showSettings = true }
                .accessibilityIdentifier("today-settings-button")
        }
    }
}
