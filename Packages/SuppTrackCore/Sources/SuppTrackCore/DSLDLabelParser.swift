import Foundation

/// Turns a DSLD `label/{id}` JSON response into a `LabelInfo`.
public enum DSLDLabelParser {
    public static func parse(_ data: Data) throws -> LabelInfo {
        let raw = try JSONDecoder().decode(RawLabel.self, from: data)
        let serving = raw.servingSizes?.first
        return LabelInfo(
            dsldId: raw.id,
            name: raw.fullName ?? "",
            brand: raw.brandName ?? "",
            upc: raw.upcSku ?? "",
            servingUnit: serving?.unit ?? "serving",
            servingQuantity: serving?.minQuantity ?? 1,
            entryDate: raw.entryDate ?? "",
            ingredients: (raw.ingredientRows ?? []).flatMap(ingredients(from:))
        )
    }

    private static func ingredients(from row: RawRow) -> [Ingredient] {
        let name = row.name ?? ""
        let own = amount(row.quantity)
        let members = row.nestedRows ?? []
        guard row.category == "blend", !members.isEmpty else {
            return [Ingredient(name: name, group: row.ingredientGroup ?? name, amount: own)]
        }
        return members.map { m in
            let mName = m.name ?? m.description ?? ""
            return Ingredient(name: mName, group: m.ingredientGroup ?? mName,
                              amount: amount(m.quantity), blendName: name, blendTotal: own)
        }
    }

    /// First listed quantity; nil when missing, "NP" (not provided) or zero.
    private static func amount(_ q: [RawQuantity]?) -> Amount? {
        guard let first = q?.first, let value = first.quantity, let unit = first.unit,
              unit != "NP", value > 0 else { return nil }
        return Amount(value: value, unit: unit)
    }

    private struct RawLabel: Decodable {
        var id: Int
        var fullName: String?
        var brandName: String?
        var upcSku: String?
        var entryDate: String?
        var servingSizes: [RawServing]?
        var ingredientRows: [RawRow]?
    }

    private struct RawServing: Decodable {
        var minQuantity: Double?
        var unit: String?
    }

    private struct RawRow: Decodable {
        var name: String?
        var description: String?
        var ingredientGroup: String?
        var category: String?
        var quantity: [RawQuantity]?
        var nestedRows: [RawRow]?
    }

    private struct RawQuantity: Decodable {
        var quantity: Double?
        var unit: String?
    }
}
