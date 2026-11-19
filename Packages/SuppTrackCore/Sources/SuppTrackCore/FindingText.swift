import Foundation

/// User-facing wording for overlap findings (spec section 7).
public enum FindingText {
    public static func text(_ f: OverlapFinding) -> String {
        switch f {
        case let .overLimit(group, total, limit, atLeast):
            let scope = limit.supplementsOnly ? " from supplements" : ""
            let food = limit.supplementsOnly ? "" : " Food adds more."
            let floor = atLeast ? "at least " : ""
            return "\(group) today: \(floor)\(format(total)). Upper limit\(scope) is \(format(limit.amount)).\(food)"
        case let .unknownAmounts(group, itemCount, unknownCount):
            let verb = unknownCount == 1 ? "has" : "have"
            return "\(group) is in \(itemCount) items. \(unknownCount) \(verb) no usable amount, so the total can't be calculated."
        case let .sharedUnderLimit(group, itemCount):
            return "\(group) is in \(itemCount) items (under the limit)."
        case let .missingIngredients(itemCount):
            let noun = itemCount == 1 ? "item has" : "items have"
            return "\(itemCount) \(noun) no ingredient info, so totals may be incomplete."
        }
    }

    /// Shared-under-limit lines appear only in My Bottles, not on Today.
    public static func showsOnToday(_ f: OverlapFinding) -> Bool {
        if case .sharedUnderLimit = f { return false }
        return true
    }

    /// How one ingredient's amount is shown in My Bottles and on the confirm screen.
    public static func amountText(_ ing: Ingredient) -> String {
        if let a = ing.amount {
            let base = UnitConverter.base(a.unit)
            if ["mcg", "mg", "g", "IU"].contains(base) { return format(a) }
            let n = a.value.formatted(.number.precision(.fractionLength(0...1)))
            return "\(n) · can't total (unit \(a.unit))"
        }
        if let blend = ing.blendName {
            let total = ing.blendTotal.map { " · \(format($0)) total" } ?? ""
            return "amount not listed (part of \(blend)\(total))"
        }
        return "amount not listed"
    }

    public static func format(_ a: Amount) -> String {
        let n = a.value.formatted(.number.precision(.fractionLength(0...1)).grouping(.automatic))
        return "\(n) \(a.unit)"
    }
}
