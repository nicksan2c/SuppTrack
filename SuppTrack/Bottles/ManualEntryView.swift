import SuppTrackCore
import SwiftData
import SwiftUI

/// Add a product by hand when no lookup finds it.
struct ManualEntryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var initialName = ""
    @State private var name = ""
    @State private var brand = ""
    @State private var isRx = false
    @State private var rows: [Row] = [Row()]

    struct Row: Identifiable {
        let id = UUID()
        var name = ""
        var amount = ""
        var unit = "mg"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name).accessibilityIdentifier("manual-name")
                    TextField("Brand", text: $brand)
                    Toggle("Prescription", isOn: $isRx)
                }
                .accessibilityIdentifier("manual-product")
                if !isRx {
                    Section("Ingredients per serving") {
                        ForEach($rows) { $row in
                            HStack {
                                TextField("Ingredient", text: $row.name)
                                TextField("Amount", text: $row.amount)
                                    .keyboardType(.decimalPad)
                                    .frame(width: 70)
                                Picker("Unit", selection: $row.unit) {
                                    ForEach(["mg", "mcg", "g", "IU"], id: \.self) { Text($0) }
                                }
                                .labelsHidden()
                            }
                        }
                        .onDelete { rows.remove(atOffsets: $0) }
                        Button("Add ingredient", systemImage: "plus") { rows.append(Row()) }
                    }
                    .accessibilityIdentifier("manual-ingredients")
                }
            }
            .navigationTitle("Add by hand")
            .onAppear { if name.isEmpty { name = initialName } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityIdentifier("manual-save")
                }
            }
        }
        .accessibilityIdentifier("manual-screen")
    }

    private func save() {
        let item = Item(name: name.trimmingCharacters(in: .whitespaces))
        item.brand = brand
        item.isRx = isRx
        if !isRx {
            item.ingredients = rows.compactMap { r in
                let n = r.name.trimmingCharacters(in: .whitespaces)
                guard !n.isEmpty else { return nil }
                let value = Double(r.amount.replacingOccurrences(of: ",", with: "."))
                return Ingredient(name: n, group: n, amount: value.map { Amount(value: $0, unit: r.unit) })
            }
        }
        let defaults = TimingRules.defaults(for: item.ingredients.map(\.group), name: item.name)
        if defaults.slot == .am { item.amServings = 1 } else { item.pmServings = 1 }
        item.note = isRx ? nil : defaults.note
        context.insert(item)
        dismiss()
    }
}
