/// Converts amounts between mass units, and from IU for vitamins A, D and E.
public enum UnitConverter {
    /// mcg per unit, for mass units.
    private static let mcgPer: [String: Double] = ["mcg": 1, "mg": 1_000, "g": 1_000_000]

    /// mcg (or mg for vitamin E) per IU, chosen to err high (spec section 7).
    private static let iu: [String: (factor: Double, unit: String)] = [
        "vitamin d": (0.025, "mcg"),
        "vitamin a": (0.3, "mcg"),
        "vitamin e": (0.67, "mg"),
    ]

    /// Reduces DSLD unit text to mcg, mg, g, IU, or the original text.
    static func base(_ unit: String) -> String {
        let first = unit.split(separator: " ").first.map(String.init)?.lowercased() ?? ""
        switch first {
        case "mcg", "µg", "ug": return "mcg"
        case "mg": return "mg"
        case "g", "gram(s)", "gram", "grams": return "g"
        case "iu": return "IU"
        default: return unit
        }
    }

    public static func convert(_ a: Amount, to unit: String, group: String) -> Amount? {
        var value = a.value
        var from = base(a.unit)
        if from == "IU" {
            guard let rule = iu[group.lowercased()] else { return nil }
            value *= rule.factor
            from = rule.unit
        }
        guard let fromMcg = mcgPer[from], let toMcg = mcgPer[base(unit)] else { return nil }
        return Amount(value: value * fromMcg / toMcg, unit: unit)
    }
}
