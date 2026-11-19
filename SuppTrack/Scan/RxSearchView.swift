import SuppTrackCore
import SwiftData
import SwiftUI

/// Find a prescription in RxNorm and add it.
struct RxSearchView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Item> { !$0.isHidden && $0.isActive }) private var items: [Item]

    @State private var text = ""
    @State private var results: [RxDrug] = []
    @State private var message: String?
    @State private var isLoading = false
    @State private var pending: RxDrug?
    @State private var slot = Slot.am

    private let client = LookupClient()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Drug name, e.g. levothyroxine", text: $text)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .accessibilityIdentifier("rx-search-field")
                        Button("Search") { Task { await search() } }
                            .disabled(text.isEmpty || isLoading)
                            .accessibilityIdentifier("rx-search-button")
                    }
                    Picker("Usually taken", selection: $slot) {
                        Text("Morning").tag(Slot.am)
                        Text("Night").tag(Slot.pm)
                    }
                    .pickerStyle(.segmented)
                }
                .accessibilityIdentifier("rx-search")

                if isLoading { ProgressView() }
                if let message { Text(message).accessibilityIdentifier("rx-message") }

                Section("Pick your exact medication") {
                    ForEach(results, id: \.rxcui) { drug in
                        Button(drug.name) { choose(drug) }
                    }
                }
                .accessibilityIdentifier("rx-results")
            }
            .navigationTitle("Add prescription")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .alert("Ask your doctor", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })) {
                Button("Add anyway") { if let pending { add(pending) } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(flags(for: pending).map(\.text).joined(separator: "\n\n"))
            }
        }
        .accessibilityIdentifier("rx-screen")
    }

    private func search() async {
        isLoading = true
        message = nil
        defer { isLoading = false }
        do {
            results = try await client.searchRx(text)
            if results.isEmpty { message = "No matches. Check the spelling, or try just the drug name." }
        } catch {
            message = ScanView.describe(error)
        }
    }

    private func flags(for drug: RxDrug?) -> [DoctorFlag] {
        guard let drug else { return [] }
        let supplements = items.filter { !$0.isRx }.map(\.snapshot)
        return SpacingRules.doctorFlags(rxNames: [UUID(): drug.name], supplements: supplements)
    }

    private func choose(_ drug: RxDrug) {
        if flags(for: drug).isEmpty { add(drug) } else { pending = drug }
    }

    private func add(_ drug: RxDrug) {
        let item = Item(name: drug.name)
        item.isRx = true
        item.rxcui = drug.rxcui
        if slot == .am { item.amServings = 1 } else { item.pmServings = 1 }
        item.doseText = "1"
        context.insert(item)
        dismiss()
    }
}
