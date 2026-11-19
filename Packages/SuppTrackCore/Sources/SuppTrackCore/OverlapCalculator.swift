import Foundation

/// What the overlap math needs to know about one bottle or prescription.
public struct ItemSnapshot: Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var isRx: Bool
    /// Label servings taken per day (AM + PM).
    public var dailyServings: Double
    public var ingredients: [Ingredient]

    public init(id: UUID, name: String, isRx: Bool, dailyServings: Double, ingredients: [Ingredient]) {
        self.id = id
        self.name = name
        self.isRx = isRx
        self.dailyServings = dailyServings
        self.ingredients = ingredients
    }
}

public enum OverlapFinding: Hashable, Sendable {
    /// `atLeast` is true when some amounts in the group are unknown, so the total is a minimum.
    case overLimit(group: String, total: Amount, limit: UpperLimit, atLeast: Bool)
    case unknownAmounts(group: String, itemCount: Int, unknownCount: Int)
    case sharedUnderLimit(group: String, itemCount: Int)
    case missingIngredients(itemCount: Int)
}

public enum OverlapCalculator {
    public static func findings(_ items: [ItemSnapshot], age: AgeGroup) -> [OverlapFinding] {
        let supplements = items.filter { !$0.isRx }
        var result: [OverlapFinding] = []

        // Group (item, ingredient) pairs by ingredient group, ignoring case.
        var groups: [String: [(item: ItemSnapshot, ingredient: Ingredient)]] = [:]
        var order: [String] = []
        for item in supplements {
            for ing in item.ingredients {
                let key = UpperLimits.canonicalKey(ing.group)
                if groups[key] == nil { order.append(key) }
                groups[key, default: []].append((item, ing))
            }
        }

        for key in order {
            let entries = groups[key]!
            // Only nutrients with an upper limit get findings; Calories, CFU etc. would be noise.
            guard let limit = UpperLimits.limit(for: entries[0].ingredient.group, age: age) else { continue }
            let name = limit.group
            let itemCount = Set(entries.map(\.item.id)).count
            let targetUnit = limit.amount.unit

            var total = 0.0
            var unknownItems = Set<UUID>()
            for e in entries {
                if let a = e.ingredient.amount, let c = UnitConverter.convert(a, to: targetUnit, group: name) {
                    total += c.value * e.item.dailyServings
                } else {
                    unknownItems.insert(e.item.id)
                }
            }

            let over = total > limit.amount.value
            if over {
                result.append(.overLimit(group: name, total: Amount(value: total, unit: targetUnit), limit: limit,
                                         atLeast: !unknownItems.isEmpty))
            }
            if itemCount >= 2, !unknownItems.isEmpty {
                result.append(.unknownAmounts(group: name, itemCount: itemCount, unknownCount: unknownItems.count))
            } else if itemCount >= 2, !over {
                result.append(.sharedUnderLimit(group: name, itemCount: itemCount))
            }
        }

        let missing = supplements.filter { $0.ingredients.isEmpty }.count
        if missing > 0 { result.append(.missingIngredients(itemCount: missing)) }
        return result
    }
}
