import Foundation
import SuppTrackCore
import Testing
@testable import SuppTrack

@MainActor
@Test func ingredientsRoundTripThroughJSON() {
    let item = Item(name: "Mag")
    let ings = [
        Ingredient(name: "Magnesium", group: "Magnesium", amount: Amount(value: 400, unit: "mg")),
        Ingredient(name: "Valerian", group: "Valerian", amount: nil, blendName: "Sleep", blendTotal: Amount(value: 200, unit: "mg")),
    ]
    item.ingredients = ings
    #expect(item.ingredients == ings)
}

@MainActor
@Test func snapshotAddsAMAndPMServings() {
    let item = Item(name: "Mag")
    item.amServings = 1
    item.pmServings = 2
    item.isRx = true
    let s = item.snapshot
    #expect(s.dailyServings == 3)
    #expect(s.id == item.id)
    #expect(s.isRx)
}

@MainActor
@Test func newItemHasNoIngredients() {
    #expect(Item(name: "X").ingredients.isEmpty)
}

@MainActor
@Test func slotsListsWhereTheItemIsTaken() {
    let item = Item(name: "X")
    item.amServings = 1
    #expect(item.slots == [.am])
    item.pmServings = 1
    #expect(item.slots == [.am, .pm])
}
