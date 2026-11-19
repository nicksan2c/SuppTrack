public enum Slot: String, Codable, CaseIterable, Sendable {
    case am, pm

    public var opposite: Slot { self == .am ? .pm : .am }
}
