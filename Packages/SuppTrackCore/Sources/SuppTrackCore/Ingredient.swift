public struct Amount: Codable, Hashable, Sendable {
    public var value: Double
    public var unit: String

    public init(value: Double, unit: String) {
        self.value = value
        self.unit = unit
    }
}

/// One ingredient of a product. `amount` is nil when the label doesn't list it
/// (for example, a member of a proprietary blend).
public struct Ingredient: Codable, Hashable, Sendable {
    public var name: String
    public var group: String
    public var amount: Amount?
    public var blendName: String?
    public var blendTotal: Amount?

    public init(name: String, group: String, amount: Amount?, blendName: String? = nil, blendTotal: Amount? = nil) {
        self.name = name
        self.group = group
        self.amount = amount
        self.blendName = blendName
        self.blendTotal = blendTotal
    }
}

public struct LabelInfo: Codable, Hashable, Sendable {
    public var dsldId: Int
    public var name: String
    public var brand: String
    public var upc: String
    public var servingUnit: String
    public var servingQuantity: Double
    public var entryDate: String
    public var ingredients: [Ingredient]
}
