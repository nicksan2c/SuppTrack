import SwiftUI

struct RootTabView: View {
    @AppStorage("disclaimerAccepted") private var disclaimerAccepted = false

    var body: some View {
        TabView {
            Tab("Today", systemImage: "checklist") {
                TodayView()
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
        .fullScreenCover(isPresented: .constant(!disclaimerAccepted)) { DisclaimerView() }
    }
}
