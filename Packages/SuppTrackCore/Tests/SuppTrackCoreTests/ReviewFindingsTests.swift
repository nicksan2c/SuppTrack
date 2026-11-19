import Foundation
import Testing
@testable import SuppTrackCore

private func item(_ name: String, _ ings: [Ingredient]) -> ItemSnapshot {
    ItemSnapshot(id: UUID(), name: name, isRx: false, dailyServings: 1, ingredients: ings)
}
private func ing(_ group: String, _ value: Double?, _ unit: String = "mg", blend: String? = nil) -> Ingredient {
    Ingredient(name: group, group: group, amount: value.map { Amount(value: $0, unit: unit) }, blendName: blend)
}

@Test func twoFishOilsListingCaloriesGiveNoFindings() {
    let f = OverlapCalculator.findings([
        item("Fish A", [ing("Calories", 10, "{Calories}"), ing("Fish Oil", 1000)]),
        item("Fish B", [ing("Calories", 10, "{Calories}"), ing("Fish Oil", 1200)]),
    ], age: .adult19to50)
    #expect(f.isEmpty)
}

@Test func twoProbioticsInCFUGiveNoFindings() {
    let f = OverlapCalculator.findings([
        item("P1", [ing("Lactobacillus", 10, "Billion CFU")]),
        item("P2", [ing("Lactobacillus", 5, "Billion CFU")]),
    ], age: .adult19to50)
    #expect(f.isEmpty)
}

@Test func folicAcidAndFolateAreTotalledTogether() {
    let f = OverlapCalculator.findings([
        item("Manual", [ing("Folic Acid", 600, "mcg")]),
        item("Multi", [ing("Folate", 600, "mcg")]),
    ], age: .adult19to50)
    #expect(f.contains { if case let .overLimit("Folate", total, _, _) = $0 { total.value == 1200 } else { false } })
}

@Test func singleItemWithUnknownBlendMemberIsAtLeast() {
    let f = OverlapCalculator.findings([
        item("Mag + blend", [ing("Magnesium", 400), ing("Magnesium", nil, blend: "Sleep Blend")]),
    ], age: .adult19to50)
    #expect(f.contains { if case .overLimit(_, _, _, atLeast: true) = $0 { true } else { false } })
}

@Test func fullyKnownTotalIsNotAtLeast() {
    let f = OverlapCalculator.findings([item("Mag", [ing("Magnesium", 400)])], age: .adult19to50)
    #expect(f.contains { if case .overLimit(_, _, _, atLeast: false) = $0 { true } else { false } })
}

@Test func atLeastWording() {
    let limit = UpperLimits.limit(for: "Magnesium", age: .adult19to50)!
    let f = OverlapFinding.overLimit(group: "Magnesium", total: Amount(value: 400, unit: "mg"), limit: limit, atLeast: true)
    #expect(FindingText.text(f) == "Magnesium today: at least 400 mg. Upper limit from supplements is 350 mg.")
}

@Test func amountTextShowsCantTotalForOddUnits() {
    #expect(FindingText.amountText(ing("Magnesium", 400)) == "400 mg")
    #expect(FindingText.amountText(ing("Vitamin D", 2000, "IU")) == "2,000 IU")
    #expect(FindingText.amountText(ing("Calories", 10, "{Calories}")) == "10 · can't total (unit {Calories})")
    #expect(FindingText.amountText(Ingredient(name: "Valerian", group: "Valerian", amount: nil,
                                              blendName: "Sleep", blendTotal: Amount(value: 200, unit: "mg")))
            == "amount not listed (part of Sleep · 200 mg total)")
    #expect(FindingText.amountText(ing("Zinc", nil)) == "amount not listed")
}
