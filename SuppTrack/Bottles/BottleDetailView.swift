import SuppTrackCore
import SwiftData
import SwiftUI

struct BottleDetailView: View {
    @Bindable var item: Item
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Item> { !$0.isHidden && $0.isActive }) private var allItems: [Item]
    @AppStorage("ageGroup") private var ageGroup = AgeGroup.adult19to50

    var body: some View {
        Form {
            Section("Ingredients per serving") {
                if item.ingredients.isEmpty {
                    Text(item.isRx ? "Prescriptions don't list ingredients." : "No ingredients yet: scan the label.")
                        .foregroundStyle(.secondary)
                }
                ForEach(item.ingredients, id: \.self) { ing in
                    HStack {
                        Text(ing.name)
                        Spacer()
                        Text(IngredientText.amount(ing)).foregroundStyle(.secondary)
                    }
                }
            }
            .accessibilityIdentifier("detail-ingredients")

            if !sharedLines.isEmpty {
                Section("Overlap and limits") {
                    ForEach(sharedLines, id: \.self) { Text($0) }
                }
                .accessibilityIdentifier("detail-shared")
            }

            Section("When you take it") {
                Stepper("Morning: \(item.amServings.formatted())", value: $item.amServings, in: 0...10, step: 1)
                Stepper("Night: \(item.pmServings.formatted())", value: $item.pmServings, in: 0...10, step: 1)
                TextField("Dose (e.g. 1 softgel)", text: $item.doseText)
                TextField("Note (e.g. with food)", text: Binding($item.note, default: ""))
            }
            .accessibilityIdentifier("detail-schedule")

            Section {
                Button("Delete", role: .destructive, action: delete)
                    .accessibilityIdentifier("detail-delete")
            }
        }
        .navigationTitle(item.name)
        .accessibilityIdentifier("detail-screen")
    }

    /// Findings for ingredient groups this item contains.
    private var sharedLines: [String] {
        let myGroups = Set(item.ingredients.map { $0.group.lowercased() })
        return OverlapCalculator.findings(allItems.map(\.snapshot), age: ageGroup).compactMap { f in
            switch f {
            case let .overLimit(g, _, _, _), let .unknownAmounts(g, _, _), let .sharedUnderLimit(g, _):
                myGroups.contains(g.lowercased()) ? FindingText.text(f) : nil
            case .missingIngredients:
                nil
            }
        }
    }

    private func delete() {
        // Health imports are hidden so the next import doesn't bring them back.
        if item.healthConceptID != nil {
            item.isHidden = true
        } else {
            context.delete(item)
        }
        dismiss()
    }
}

enum IngredientText {
    static func amount(_ ing: Ingredient) -> String { FindingText.amountText(ing) }
}

extension Binding where Value == String {
    /// Edits an optional string as a plain one; empty text stores nil.
    init(_ source: Binding<String?>, default value: String) {
        self.init(get: { source.wrappedValue ?? value },
                  set: { source.wrappedValue = $0.isEmpty ? nil : $0 })
    }
}
