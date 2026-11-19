/// Default AM/PM slot and how-to-take note for a supplement (spec section 8).
public enum TimingRules {
    private static let pmGroups: Set<String> = ["magnesium", "melatonin", "ashwagandha", "glycine", "l-theanine", "valerian"]
    private static let withFoodGroups: Set<String> = ["vitamin a", "vitamin d", "vitamin e", "vitamin k", "fish oil", "omega-3", "coq10", "coenzyme q10", "turmeric", "curcumin"]
    private static let withFoodNames = ["multivitamin", "fish oil", "omega", "coq10", "turmeric", "curcumin"]

    /// A product with more than this many ingredient groups is treated as a multivitamin.
    private static let multiThreshold = 5

    public static func defaults(for groups: [String], name: String) -> (slot: Slot, note: String?) {
        let g = Set(groups.map { $0.lowercased() })
        let n = name.lowercased()

        if n.contains("probiotic") { return (.am, "empty stomach") }
        if n.contains("multivitamin") || g.count > multiThreshold { return (.am, "with food") }

        let slot: Slot = g.isDisjoint(with: pmGroups) ? .am : .pm
        if g.contains("iron") { return (slot, "empty stomach, or with vitamin C") }
        if !g.isDisjoint(with: withFoodGroups) || withFoodNames.contains(where: n.contains) {
            return (slot, "with food")
        }
        return (slot, nil)
    }
}
