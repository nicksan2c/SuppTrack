import Foundation
import Testing
@testable import SuppTrackCore

private func item(_ name: String, _ ingredients: [Ingredient], servings: Double = 1, rx: Bool = false) -> ItemSnapshot {
    ItemSnapshot(id: UUID(), name: name, isRx: rx, dailyServings: servings, ingredients: ingredients)
}

private func ing(_ group: String, _ value: Double?, _ unit: String = "mg", blend: String? = nil) -> Ingredient {
    Ingredient(name: group, group: group, amount: value.map { Amount(value: $0, unit: unit) }, blendName: blend)
}

@Test func magnesiumOverLimitAcrossTwoBottles() {
    let f = OverlapCalculator.findings([
        item("Multi", [ing("Magnesium", 400)]),
        item("Mag", [ing("Magnesium", 120)]),
    ], age: .adult19to50)
    let over = f.compactMap { if case let .overLimit(g, total, limit, _) = $0 { (g, total, limit) } else { nil } }
    #expect(over.count == 1)
    #expect(over.first?.0 == "Magnesium")
    #expect(over.first?.1 == Amount(value: 520, unit: "mg"))
    #expect(over.first?.2.amount == Amount(value: 350, unit: "mg"))
    #expect(over.first?.2.supplementsOnly == true)
}

@Test func vitaminDInIUAndMcgTotalsExactlyAtLimitIsNotOver() {
    let f = OverlapCalculator.findings([
        item("D3", [ing("Vitamin D", 2000, "IU")]),
        item("Multi", [ing("Vitamin D", 50, "mcg")]),
    ], age: .adult19to50)
    #expect(!f.contains { if case .overLimit = $0 { true } else { false } })
    #expect(f.contains(.sharedUnderLimit(group: "Vitamin D", itemCount: 2)))
}

@Test func calciumLimitDependsOnAge() {
    let items = [item("Cal", [ing("Calcium", 2200)])]
    #expect(OverlapCalculator.findings(items, age: .adult51plus).contains { if case .overLimit = $0 { true } else { false } })
    #expect(OverlapCalculator.findings(items, age: .adult19to50).isEmpty)
}

@Test func servingsPerDayMultiplyTheAmount() {
    let f = OverlapCalculator.findings([item("Zinc", [ing("Zinc", 25)], servings: 2)], age: .adult19to50)
    #expect(f.contains { if case let .overLimit(_, total, _, _) = $0 { total.value == 50 } else { false } })
}

@Test func blendMemberWithUnknownAmountGivesBothFindings() {
    let f = OverlapCalculator.findings([
        item("Mag", [ing("Magnesium", 400)]),
        item("Sleep blend", [ing("Magnesium", nil, blend: "Sleep Blend")]),
    ], age: .adult19to50)
    #expect(f.contains { if case .overLimit(group: "Magnesium", _, _, _) = $0 { true } else { false } })
    #expect(f.contains(.unknownAmounts(group: "Magnesium", itemCount: 2, unknownCount: 1)))
}

@Test func sharedUnderLimit() {
    let f = OverlapCalculator.findings([
        item("A", [ing("Zinc", 10)]),
        item("B", [ing("Zinc", 5)]),
    ], age: .adult19to50)
    #expect(f == [.sharedUnderLimit(group: "Zinc", itemCount: 2)])
}

@Test func supplementWithNoIngredientsIsReported() {
    let f = OverlapCalculator.findings([item("Mystery", []), item("Rx", [], rx: true)], age: .adult19to50)
    #expect(f == [.missingIngredients(itemCount: 1)])
}

@Test func unconvertibleUnitCountsAsUnknown() {
    let f = OverlapCalculator.findings([
        item("A", [ing("Vitamin E", 100, "mg")]),
        item("B", [ing("Vitamin E", 5, "{Calories}")]),
    ], age: .adult19to50)
    #expect(f == [.unknownAmounts(group: "Vitamin E", itemCount: 2, unknownCount: 1)])
}

@Test func groupsMatchCaseInsensitively() {
    let f = OverlapCalculator.findings([
        item("A", [ing("magnesium", 300)]),
        item("B", [ing("Magnesium", 100)]),
    ], age: .adult19to50)
    #expect(f.contains { if case .overLimit = $0 { true } else { false } })
}

@Test func unitConverterHandlesMassAndIU() {
    #expect(UnitConverter.convert(Amount(value: 1, unit: "Gram(s)"), to: "mg", group: "Calcium") == Amount(value: 1000, unit: "mg"))
    #expect(UnitConverter.convert(Amount(value: 400, unit: "IU"), to: "mcg", group: "Vitamin D") == Amount(value: 10, unit: "mcg"))
    #expect(UnitConverter.convert(Amount(value: 900, unit: "mcg RAE"), to: "mcg", group: "Vitamin A") == Amount(value: 900, unit: "mcg"))
    #expect(UnitConverter.convert(Amount(value: 400, unit: "IU"), to: "mg", group: "Zinc") == nil)
}
