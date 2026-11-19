import Foundation
import Testing
@testable import SuppTrackCore

private func supp(_ name: String, _ groups: [String]) -> ItemSnapshot {
    ItemSnapshot(id: UUID(), name: name, isRx: false, dailyServings: 1,
                 ingredients: groups.map { Ingredient(name: $0, group: $0, amount: nil) })
}

private let levo = UUID()
private let levoName = "levothyroxine sodium 0.1 MG Oral Tablet"

@Test func levothyroxineBlocksCalciumInMultiFor4Hours() {
    let multi = supp("Multivitamin", ["Vitamin A", "Calcium"])
    let hints = SpacingRules.hints(rxNames: [levo: levoName], supplements: [multi], takenAt: [:])
    #expect(hints == [SpacingHint(blockedItem: multi.id, byItemName: levoName, hours: 4, notBefore: nil)])
}

@Test func notBeforeIsTakenTimePlusHours() {
    let multi = supp("Multivitamin", ["Calcium"])
    let taken = Date(timeIntervalSince1970: 1_000_000)
    let hints = SpacingRules.hints(rxNames: [levo: levoName], supplements: [multi], takenAt: [levo: taken])
    #expect(hints.first?.notBefore == taken.addingTimeInterval(4 * 3600))
}

@Test func unrelatedSupplementHasNoHint() {
    let fish = supp("Fish Oil", ["Fish Oil"])
    #expect(SpacingRules.hints(rxNames: [levo: levoName], supplements: [fish], takenAt: [:]).isEmpty)
}

@Test func ciprofloxacinWithZincIs6Hours() {
    let zinc = supp("Zinc", ["Zinc"])
    let hints = SpacingRules.hints(rxNames: [UUID(): "ciprofloxacin 500 MG Oral Tablet"], supplements: [zinc], takenAt: [:])
    #expect(hints.first?.hours == 6)
}

@Test func doxycyclineWithIronIs4Hours() {
    let iron = supp("Iron", ["Iron"])
    let hints = SpacingRules.hints(rxNames: [UUID(): "doxycycline hyclate 100 MG"], supplements: [iron], takenAt: [:])
    #expect(hints.first?.hours == 4)
}

@Test func alendronateBlocksEverythingForHalfAnHour() {
    let fish = supp("Fish Oil", ["Fish Oil"])
    let hints = SpacingRules.hints(rxNames: [UUID(): "alendronate sodium 70 MG"], supplements: [fish], takenAt: [:])
    #expect(hints.first?.hours == 0.5)
}

@Test func calciumWaitsTwoHoursAfterIron() {
    let iron = supp("Iron", ["Iron"])
    let cal = supp("Calcium", ["Calcium"])
    let t = Date(timeIntervalSince1970: 0)
    let hints = SpacingRules.hints(rxNames: [:], supplements: [cal, iron], takenAt: [iron.id: t])
    #expect(hints == [SpacingHint(blockedItem: cal.id, byItemName: "Iron", hours: 2, notBefore: t.addingTimeInterval(7200))])
}

@Test func itemsContainingBothIronAndCalciumDoNotBlockEachOther() {
    let multi = supp("Multi", ["Iron", "Calcium"])
    let iron = supp("Iron", ["Iron"])
    #expect(SpacingRules.hints(rxNames: [:], supplements: [multi, iron], takenAt: [:]).isEmpty)
}

@Test func warfarinWithFishOilIsADoctorFlag() {
    let fish = supp("Fish Oil", ["Fish Oil"])
    let rx = UUID()
    let flags = SpacingRules.doctorFlags(rxNames: [rx: "warfarin sodium 5 MG"], supplements: [fish])
    #expect(flags.count == 1)
    #expect(flags.first?.text.hasPrefix("Ask your doctor:") == true)
    #expect(flags.first?.itemIDs == [rx, fish.id])
}

@Test func stJohnsWortWithAnyRxIsADoctorFlag() {
    let sjw = supp("Mood Support", ["St. John's Wort"])
    #expect(SpacingRules.doctorFlags(rxNames: [UUID(): "lisinopril 10 MG"], supplements: [sjw]).count == 1)
    #expect(SpacingRules.doctorFlags(rxNames: [:], supplements: [sjw]).isEmpty)
}

@Test func calciumIsSuggestedOppositeSlotFromLevothyroxine() {
    let cal = supp("Calcium", ["Calcium"])
    #expect(SpacingRules.suggestedSlot(for: cal, rxNames: [levo: levoName], rxSlots: [levo: .am]) == .pm)
    #expect(SpacingRules.suggestedSlot(for: supp("Fish", ["Fish Oil"]), rxNames: [levo: levoName], rxSlots: [levo: .am]) == nil)
}
