import Foundation
import SuppTrackCore
import SwiftData

/// One supplement bottle or prescription. CloudKit-safe: every property has a default.
@Model
final class Item {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var name: String = ""
    var brand: String = ""
    var isRx: Bool = false
    var upc: String?
    var dsldId: Int?
    var rxcui: String?
    var healthConceptID: String?
    var amServings: Double = 0
    var pmServings: Double = 0
    /// e.g. "1 softgel"
    var doseText: String = ""
    var note: String?
    var isHidden: Bool = false
    var isActive: Bool = true
    /// JSON-encoded `[Ingredient]`, kept as a blob to keep CloudKit simple.
    var ingredientsJSON: Data = Data()

    init(name: String) {
        self.name = name
    }

    var ingredients: [Ingredient] {
        get { (try? JSONDecoder().decode([Ingredient].self, from: ingredientsJSON)) ?? [] }
        set { ingredientsJSON = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    /// The slots this item is taken in.
    var slots: [Slot] {
        Slot.allCases.filter { servings(in: $0) > 0 }
    }

    func servings(in slot: Slot) -> Double {
        slot == .am ? amServings : pmServings
    }

    var snapshot: ItemSnapshot {
        ItemSnapshot(id: id, name: name, isRx: isRx, dailyServings: amServings + pmServings, ingredients: ingredients)
    }
}
