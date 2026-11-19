import Testing
@testable import SuppTrackCore

@Test func overLimitSupplementsOnlyText() {
    let limit = UpperLimits.limit(for: "Magnesium", age: .adult19to50)!
    let f = OverlapFinding.overLimit(group: "Magnesium", total: Amount(value: 520, unit: "mg"), limit: limit)
    #expect(FindingText.text(f) == "Magnesium today: 520 mg. Upper limit from supplements is 350 mg.")
}

@Test func overLimitTotalIntakeTextMentionsFood() {
    let limit = UpperLimits.limit(for: "Zinc", age: .adult19to50)!
    let f = OverlapFinding.overLimit(group: "Zinc", total: Amount(value: 50.5, unit: "mg"), limit: limit)
    #expect(FindingText.text(f) == "Zinc today: 50.5 mg. Upper limit is 40 mg. Food adds more.")
}

@Test func unknownAmountsText() {
    #expect(FindingText.text(.unknownAmounts(group: "Magnesium", itemCount: 3, unknownCount: 1))
            == "Magnesium is in 3 items. 1 doesn't list the amount, so the total can't be calculated.")
    #expect(FindingText.text(.unknownAmounts(group: "Zinc", itemCount: 2, unknownCount: 2))
            == "Zinc is in 2 items. 2 don't list the amount, so the total can't be calculated.")
}

@Test func sharedAndMissingText() {
    #expect(FindingText.text(.sharedUnderLimit(group: "Zinc", itemCount: 2)) == "Zinc is in 2 items (under the limit).")
    #expect(FindingText.text(.missingIngredients(itemCount: 1)) == "1 item has no ingredient info, so totals may be incomplete.")
    #expect(FindingText.text(.missingIngredients(itemCount: 2)) == "2 items have no ingredient info, so totals may be incomplete.")
}

@Test func onlySharedIsQuietOnToday() {
    #expect(!FindingText.showsOnToday(.sharedUnderLimit(group: "Zinc", itemCount: 2)))
    #expect(FindingText.showsOnToday(.missingIngredients(itemCount: 1)))
}
