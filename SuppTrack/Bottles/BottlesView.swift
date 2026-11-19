import SwiftData
import SwiftUI

/// My Bottles: list on the left, detail on the right (iPad) or pushed (iPhone).
struct BottlesView: View {
    @Query(filter: #Predicate<Item> { !$0.isHidden && $0.isActive }, sort: \Item.createdAt)
    private var items: [Item]
    @State private var selection: Item?
    @State private var showManualEntry = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(items) { item in
                    NavigationLink(value: item) { BottleRow(item: item) }
                }
            }
            .overlay {
                if items.isEmpty {
                    ContentUnavailableView("No bottles yet", systemImage: "pills",
                                           description: Text("Scan a barcode or add one by hand."))
                }
            }
            .navigationTitle("My Bottles")
            .toolbar {
                Button("Add by hand", systemImage: "plus") { showManualEntry = true }
                    .accessibilityIdentifier("bottles-add-button")
            }
            .accessibilityIdentifier("bottles-list")
        } detail: {
            if let selection {
                BottleDetailView(item: selection)
            } else {
                Text("Select a bottle").foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showManualEntry) { ManualEntryView() }
        .accessibilityIdentifier("bottles-screen")
    }
}

struct BottleRow: View {
    let item: Item

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack(spacing: 6) {
                    Text(item.name)
                    if item.isRx { RxTag() }
                }
                if !item.brand.isEmpty {
                    Text(item.brand).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !item.isRx && item.ingredients.isEmpty {
                Text("No ingredients yet")
                    .font(.caption2)
                    .padding(4)
                    .background(.orange.opacity(0.2), in: .rect(cornerRadius: 4))
            }
        }
        .accessibilityIdentifier("bottles-row-\(item.id.uuidString)")
    }
}

struct RxTag: View {
    var body: some View {
        Text("Rx")
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .background(.blue, in: .rect(cornerRadius: 4))
    }
}
