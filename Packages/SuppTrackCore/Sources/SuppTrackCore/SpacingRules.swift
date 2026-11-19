import Foundation

public struct SpacingHint: Hashable, Sendable {
    public var blockedItem: UUID
    public var byItemName: String
    public var hours: Double
    /// Set once the blocking item has been taken today.
    public var notBefore: Date?

    public init(blockedItem: UUID, byItemName: String, hours: Double, notBefore: Date?) {
        self.blockedItem = blockedItem
        self.byItemName = byItemName
        self.hours = hours
        self.notBefore = notBefore
    }
}

public struct DoctorFlag: Hashable, Sendable {
    public var text: String
    public var itemIDs: [UUID]
}

/// Curated prescription/supplement spacing rules (spec sections 8 and 11.4).
/// Callers pass only the items present in the slot being shown.
public enum SpacingRules {
    private struct Rule {
        var rxSubstrings: [String]
        /// Empty means every supplement.
        var groups: Set<String>
        var hours: Double
    }

    private static let minerals: Set<String> = ["calcium", "iron", "magnesium", "zinc"]

    private static let rules: [Rule] = [
        Rule(rxSubstrings: ["levothyroxine", "liothyronine"], groups: ["calcium", "iron", "magnesium", "soy"], hours: 4),
        Rule(rxSubstrings: ["doxycycline", "minocycline", "tetracycline"], groups: minerals, hours: 4),
        Rule(rxSubstrings: ["ciprofloxacin", "levofloxacin", "moxifloxacin"], groups: minerals, hours: 6),
        Rule(rxSubstrings: ["alendronate", "risedronate", "ibandronate"], groups: [], hours: 0.5),
    ]

    private static func groups(_ item: ItemSnapshot) -> Set<String> {
        Set(item.ingredients.map { $0.group.lowercased() })
    }

    private static func rule(rx: String, supplement: ItemSnapshot) -> Rule? {
        let name = rx.lowercased()
        let g = groups(supplement)
        return rules.first { r in
            r.rxSubstrings.contains(where: name.contains)
                && (r.groups.isEmpty || g.contains { group in r.groups.contains { group.contains($0) } })
        }
    }

    public static func hints(rxNames: [UUID: String], supplements: [ItemSnapshot], takenAt: [UUID: Date]) -> [SpacingHint] {
        let rxs = rxNames.sorted { $0.value < $1.value }
        var result: [SpacingHint] = []
        for s in supplements {
            for (rxID, rxName) in rxs {
                if let r = rule(rx: rxName, supplement: s) {
                    result.append(SpacingHint(blockedItem: s.id, byItemName: rxName, hours: r.hours,
                                              notBefore: takenAt[rxID]?.addingTimeInterval(r.hours * 3600)))
                }
            }
            // Calcium waits 2 hours after a separate iron supplement.
            let sg = groups(s)
            if sg.contains("calcium"), !sg.contains("iron") {
                for ironItem in supplements where ironItem.id != s.id {
                    let ig = groups(ironItem)
                    if ig.contains("iron"), !ig.contains("calcium") {
                        result.append(SpacingHint(blockedItem: s.id, byItemName: ironItem.name, hours: 2,
                                                  notBefore: takenAt[ironItem.id]?.addingTimeInterval(7200)))
                    }
                }
            }
        }
        return result
    }

    private static let warfarinKeywords = ["vitamin k", "fish oil", "omega-3", "vitamin e", "ginkgo", "turmeric", "curcumin"]
    private static let stJohnsKeywords = ["st. john", "st john", "hypericum"]

    private static func matches(_ item: ItemSnapshot, _ keywords: [String]) -> Bool {
        let texts = [item.name.lowercased()] + groups(item)
        return texts.contains { t in keywords.contains(where: t.contains) }
    }

    public static func doctorFlags(rxNames: [UUID: String], supplements: [ItemSnapshot]) -> [DoctorFlag] {
        var flags: [DoctorFlag] = []
        for (rxID, rxName) in rxNames.sorted(by: { $0.value < $1.value }) where rxName.lowercased().contains("warfarin") {
            let hits = supplements.filter { matches($0, warfarinKeywords) }
            if !hits.isEmpty {
                let names = hits.map(\.name).joined(separator: ", ")
                flags.append(DoctorFlag(text: "Ask your doctor: \(names) may change how warfarin works.",
                                        itemIDs: [rxID] + hits.map(\.id)))
            }
        }
        if !rxNames.isEmpty {
            for s in supplements where matches(s, stJohnsKeywords) {
                flags.append(DoctorFlag(text: "Ask your doctor: St. John's wort interacts with many medications. Check with your pharmacist too.",
                                        itemIDs: rxNames.keys.sorted { $0.uuidString < $1.uuidString } + [s.id]))
            }
        }
        return flags
    }

    /// The slot to suggest for a new supplement so it avoids a conflicting prescription, or nil.
    public static func suggestedSlot(for supplement: ItemSnapshot, rxNames: [UUID: String], rxSlots: [UUID: Slot]) -> Slot? {
        for (rxID, rxName) in rxNames where rule(rx: rxName, supplement: supplement) != nil {
            if let slot = rxSlots[rxID] { return slot.opposite }
        }
        return nil
    }
}
