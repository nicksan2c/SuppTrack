import Foundation
import SuppTrackCore
import Testing
@testable import SuppTrack

@MainActor
struct TodayModelTests {
    let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }()

    func at(_ hour: Int, _ minute: Int, dayOffset: Int = 0) -> Date {
        let base = cal.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: hour, minute: minute))!
        return cal.date(byAdding: .day, value: dayOffset, to: base)!
    }

    func supplement(_ name: String, _ groups: [String], am: Double = 1, pm: Double = 0) -> Item {
        let i = Item(name: name)
        i.ingredients = groups.map { Ingredient(name: $0, group: $0, amount: nil) }
        i.amServings = am
        i.pmServings = pm
        return i
    }

    @Test func defaultSlotSwitchesAtNoon() {
        #expect(TodayModel.defaultSlot(now: at(11, 59), calendar: cal) == .am)
        #expect(TodayModel.defaultSlot(now: at(12, 0), calendar: cal) == .pm)
    }

    @Test func yesterdaysLogDoesNotCheckToday() {
        let item = supplement("D3", ["Vitamin D"])
        let log = DoseLog(itemID: item.id, slot: .am, takenAt: at(23, 59, dayOffset: -1))
        let rows = TodayModel.rows(items: [item], logs: [log], slot: .am, now: at(8, 0), calendar: cal)
        #expect(rows.count == 1)
        #expect(rows[0].isChecked == false)
    }

    @Test func itemTakenTwiceADayHasIndependentChecks() {
        let item = supplement("Mag", ["Magnesium"], am: 1, pm: 1)
        let log = DoseLog(itemID: item.id, slot: .am, takenAt: at(8, 0))
        let am = TodayModel.rows(items: [item], logs: [log], slot: .am, now: at(9, 0), calendar: cal)
        let pm = TodayModel.rows(items: [item], logs: [log], slot: .pm, now: at(21, 0), calendar: cal)
        #expect(am.map(\.isChecked) == [true])
        #expect(pm.map(\.isChecked) == [false])
    }

    @Test func checkedThyroidPillSetsMultivitaminTime() {
        let levo = Item(name: "levothyroxine sodium 0.1 MG Oral Tablet")
        levo.isRx = true
        levo.amServings = 1
        let multi = supplement("Multivitamin", ["Calcium"])
        let log = DoseLog(itemID: levo.id, slot: .am, takenAt: at(6, 30))
        let rows = TodayModel.rows(items: [multi, levo], logs: [log], slot: .am, now: at(7, 0), calendar: cal)
        #expect(rows.map(\.item.name) == [levo.name, "Multivitamin"])
        #expect(rows[1].hint?.notBefore == at(10, 30))
        #expect(rows[0].hint == nil)
    }

    @Test func hiddenAndInactiveItemsAreLeftOut() {
        let hidden = supplement("A", ["Zinc"])
        hidden.isHidden = true
        let inactive = supplement("B", ["Zinc"])
        inactive.isActive = false
        #expect(TodayModel.rows(items: [hidden, inactive], logs: [], slot: .am, now: at(8, 0), calendar: cal).isEmpty)
    }

    @Test func checkedRowShowsNoHint() {
        let levo = Item(name: "levothyroxine")
        levo.isRx = true
        levo.amServings = 1
        let cal2 = supplement("Calcium", ["Calcium"])
        let log = DoseLog(itemID: cal2.id, slot: .am, takenAt: at(7, 0))
        let rows = TodayModel.rows(items: [levo, cal2], logs: [log], slot: .am, now: at(8, 0), calendar: cal)
        #expect(rows[1].isChecked)
        #expect(rows[1].hint == nil)
    }
}
