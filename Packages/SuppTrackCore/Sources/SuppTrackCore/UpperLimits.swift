public struct UpperLimit: Hashable, Sendable {
    public var group: String
    public var amount: Amount
    /// True when the limit applies to supplements only (not food).
    public var supplementsOnly: Bool
}

/// Adult (19+) upper limits from the NIH ODS fact sheets (spec section 7).
public enum UpperLimits {
    private static func ul(_ g: String, _ v: Double, _ u: String, supps: Bool = false) -> UpperLimit {
        UpperLimit(group: g, amount: Amount(value: v, unit: u), supplementsOnly: supps)
    }

    private static let table: [UpperLimit] = [
        ul("Vitamin A", 3_000, "mcg"),
        ul("Vitamin C", 2_000, "mg"),
        ul("Vitamin D", 100, "mcg"),
        ul("Vitamin E", 1_000, "mg", supps: true),
        ul("Niacin", 35, "mg", supps: true),
        ul("Vitamin B6", 100, "mg"),
        ul("Folate", 1_000, "mcg", supps: true),
        ul("Choline", 3_500, "mg"),
        ul("Calcium", 2_500, "mg"),
        ul("Iron", 45, "mg"),
        ul("Magnesium", 350, "mg", supps: true),
        ul("Zinc", 40, "mg"),
        ul("Selenium", 400, "mcg"),
        ul("Copper", 10_000, "mcg"),
        ul("Iodine", 1_100, "mcg"),
        ul("Manganese", 11, "mg"),
        ul("Molybdenum", 2_000, "mcg"),
        ul("Phosphorus", 4_000, "mg"),
    ]

    private static let aliases = ["folic acid": "folate", "pyridoxine": "vitamin b6"]

    public static func limit(for group: String, age: AgeGroup) -> UpperLimit? {
        var key = group.lowercased()
        key = aliases[key] ?? key
        guard var found = table.first(where: { $0.group.lowercased() == key }) else { return nil }
        if found.group == "Calcium", age == .adult51plus { found.amount.value = 2_000 }
        return found
    }
}
