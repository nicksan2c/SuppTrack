import Foundation

/// User-facing wording for overlap findings (spec section 7).
public enum FindingText {
    public static func text(_ f: OverlapFinding) -> String {
        switch f {
        case let .overLimit(group, total, limit):
            let scope = limit.supplementsOnly ? " from supplements" : ""
            let food = limit.supplementsOnly ? "" : " Food adds more."
            return "\(group) today: \(format(total)). Upper limit\(scope) is \(format(limit.amount)).\(food)"
        case let .unknownAmounts(group, itemCount, unknownCount):
            let verb = unknownCount == 1 ? "doesn't" : "don't"
            return "\(group) is in \(itemCount) items. \(unknownCount) \(verb) list the amount, so the total can't be calculated."
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

    public static func format(_ a: Amount) -> String {
        let n = a.value.formatted(.number.precision(.fractionLength(0...1)).grouping(.automatic))
        return "\(n) \(a.unit)"
    }
}
