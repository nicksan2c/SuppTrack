import SuppTrackCore
import SwiftData
import SwiftUI

/// Shows a looked-up label so Nick can set servings and save it.
struct ConfirmItemView: View {
    let label: LabelInfo
    let barcode: String?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Item> { !$0.isHidden && $0.isActive }) private var items: [Item]
    @State private var am: Double = 0
    @State private var pm: Double = 0
    @State private var note = ""
    @State private var prepared = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(label.name).font(.headline)
                    if !label.brand.isEmpty { Text(label.brand).foregroundStyle(.secondary) }
                    Text("Serving: \(label.servingQuantity.formatted()) \(label.servingUnit)")
                        .font(.caption)
                    if items.contains(where: { $0.dsldId == label.dsldId }) {
                        Text("This product is already in My Bottles.")
                            .foregroundStyle(.orange)
                    }
                }
                .accessibilityIdentifier("confirm-product")

                Section("Ingredients per serving") {
                    if label.ingredients.isEmpty {
                        Text("The label lists no ingredients.").foregroundStyle(.secondary)
                    }
                    ForEach(label.ingredients, id: \.self) { ing in
                        HStack {
                            Text(ing.name)
                            Spacer()
                            Text(IngredientText.amount(ing)).foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityIdentifier("confirm-ingredients")

                Section("Servings per day") {
                    Stepper("Morning: \(am.formatted())", value: $am, in: 0...10)
                    Stepper("Night: \(pm.formatted())", value: $pm, in: 0...10)
                    TextField("Note", text: $note)
                }
                .accessibilityIdentifier("confirm-schedule")
            }
            .navigationTitle("Add bottle")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(am + pm == 0)
                        .accessibilityIdentifier("confirm-save")
                }
            }
            .onAppear(perform: prepare)
        }
        .accessibilityIdentifier("confirm-screen")
    }

    /// Pre-fill the slot from the timing rules, moved away from a conflicting prescription.
    private func prepare() {
        guard !prepared else { return }
        prepared = true
        let snapshot = ItemSnapshot(id: UUID(), name: label.name, isRx: false, dailyServings: 1, ingredients: label.ingredients)
        let defaults = TimingRules.defaults(for: label.ingredients.map(\.group), name: label.name)
        let rx = items.filter(\.isRx)
        let rxNames = Dictionary(uniqueKeysWithValues: rx.map { ($0.id, $0.name) })
        let rxSlots = Dictionary(uniqueKeysWithValues: rx.compactMap { r in r.slots.first.map { (r.id, $0) } })
        let slot = SpacingRules.suggestedSlot(for: snapshot, rxNames: rxNames, rxSlots: rxSlots) ?? defaults.slot
        if slot == .am { am = 1 } else { pm = 1 }
        note = defaults.note ?? ""
    }

    private func save() {
        let item = Item(name: label.name)
        item.brand = label.brand
        item.dsldId = label.dsldId
        item.upc = barcode
        item.ingredients = label.ingredients
        item.amServings = am
        item.pmServings = pm
        item.doseText = "\(label.servingQuantity.formatted()) \(label.servingUnit)"
        item.note = note.isEmpty ? nil : note
        context.insert(item)
        dismiss()
    }
}
