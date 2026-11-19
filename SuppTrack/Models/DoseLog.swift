import Foundation
import SuppTrackCore
import SwiftData

/// A checkbox tick on Today: item, slot and when it was taken.
@Model
final class DoseLog {
    var itemID: UUID = UUID()
    var slotRaw: String = Slot.am.rawValue
    var takenAt: Date = Date.now

    init(itemID: UUID, slot: Slot, takenAt: Date = .now) {
        self.itemID = itemID
        self.slotRaw = slot.rawValue
        self.takenAt = takenAt
    }

    var slot: Slot { Slot(rawValue: slotRaw) ?? .am }
}
