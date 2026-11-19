import Testing
@testable import SuppTrackCore

@Test func magnesiumDefaultsToPM() {
    let d = TimingRules.defaults(for: ["Magnesium"], name: "Magnesium Glycinate")
    #expect(d.slot == .pm)
    #expect(d.note == nil)
}

@Test func vitaminDDefaultsToAMWithFood() {
    let d = TimingRules.defaults(for: ["Vitamin D"], name: "D3 2000 IU")
    #expect(d.slot == .am)
    #expect(d.note == "with food")
}

@Test func multivitaminByNameIsAMWithFoodEvenWithMagnesium() {
    let d = TimingRules.defaults(for: ["Vitamin A", "Magnesium"], name: "Men's Multivitamin")
    #expect(d.slot == .am)
    #expect(d.note == "with food")
}

@Test func manyIngredientsAreTreatedAsAMultivitamin() {
    let groups = ["Vitamin A", "Vitamin C", "Vitamin D", "Zinc", "Magnesium", "Selenium"]
    #expect(TimingRules.defaults(for: groups, name: "Daily Pack").slot == .am)
}

@Test func probioticIsAMEmptyStomach() {
    let d = TimingRules.defaults(for: ["Lactobacillus"], name: "Probiotic 10 Billion")
    #expect(d.slot == .am)
    #expect(d.note == "empty stomach")
}

@Test func ironGetsItsOwnNote() {
    #expect(TimingRules.defaults(for: ["Iron"], name: "Iron 65 mg").note == "empty stomach, or with vitamin C")
}

@Test func unknownDefaultsToAMWithNoNote() {
    let d = TimingRules.defaults(for: ["Lutein"], name: "Eye Health")
    #expect(d.slot == .am)
    #expect(d.note == nil)
}
