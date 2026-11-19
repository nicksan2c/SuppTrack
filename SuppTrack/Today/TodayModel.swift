import Foundation
import SuppTrackCore

struct TodayRow: Identifiable {
    let item: Item
    let isChecked: Bool
    /// Shown only while the row is unchecked.
    let hint: SpacingHint?

    var id: UUID { item.id }
}

/// Decides what Today shows for one slot. Pure, so it's unit-tested.
enum TodayModel {
    static func defaultSlot(now: Date, calendar: Calendar) -> Slot {
        calendar.component(.hour, from: now) < 12 ? .am : .pm
    }

    static func rows(items: [Item], logs: [DoseLog], slot: Slot, now: Date, calendar: Calendar) -> [TodayRow] {
        let inSlot = items
            .filter { !$0.isHidden && $0.isActive && $0.servings(in: slot) > 0 }
            .sorted { ($0.isRx ? 0 : 1, $0.createdAt) < ($1.isRx ? 0 : 1, $1.createdAt) }

        var takenAt: [UUID: Date] = [:]
        for log in logs where log.slot == slot && calendar.isDate(log.takenAt, inSameDayAs: now) {
            takenAt[log.itemID] = log.takenAt
        }

        let rx = inSlot.filter(\.isRx)
        let hints = SpacingRules.hints(
            rxNames: Dictionary(uniqueKeysWithValues: rx.map { ($0.id, $0.name) }),
            supplements: inSlot.filter { !$0.isRx }.map(\.snapshot),
            takenAt: takenAt
        )

        return inSlot.map { item in
            let checked = takenAt[item.id] != nil
            let hint = checked ? nil : hints
                .filter { $0.blockedItem == item.id }
                .max { ($0.notBefore ?? .distantPast) < ($1.notBefore ?? .distantPast) }
            return TodayRow(item: item, isChecked: checked, hint: hint)
        }
    }
}
