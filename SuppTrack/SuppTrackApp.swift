import SwiftUI

@main
struct SuppTrackApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(for: [Item.self, DoseLog.self])
    }
}
