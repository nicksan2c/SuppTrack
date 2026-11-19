import Foundation
import Testing
@testable import SuppTrackCore

func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

@Test func parsesPlainLabel() throws {
    let label = try DSLDLabelParser.parse(fixture("label-8955"))
    #expect(label.dsldId == 8955)
    #expect(label.brand == "Nature Made")
    #expect(label.servingQuantity == 1)
    #expect(label.servingUnit == "Tablet(s)")
    let vitD = try #require(label.ingredients.first { $0.group == "Vitamin D" })
    #expect(vitD.amount == Amount(value: 200, unit: "IU"))
    #expect(vitD.blendName == nil)
}

@Test func parsesBlendMembersWithUnknownAmounts() throws {
    let label = try DSLDLabelParser.parse(fixture("label-78540"))
    let members = label.ingredients.filter { $0.blendName == "LOWAT Proprietary Blend" }
    #expect(members.count == 2)
    for m in members {
        #expect(m.amount == nil)
        #expect(m.blendTotal == Amount(value: 300, unit: "mg"))
    }
    #expect(!label.ingredients.contains { $0.name == "LOWAT Proprietary Blend" })
}

@Test func parsesUpcSku() throws {
    let label = try DSLDLabelParser.parse(fixture("label-255113"))
    #expect(label.upc == "0 31604 02616 5")
    #expect(label.entryDate == "2021-08-23")
}

@Test func emptyQuantityGivesNilAmount() throws {
    let json = """
    {"id": 1, "fullName": "X", "brandName": "B", "upcSku": "", "entryDate": "2020-01-01",
     "servingSizes": [],
     "ingredientRows": [{"name": "Zinc", "ingredientGroup": "Zinc", "category": "mineral",
                         "quantity": [], "nestedRows": []}]}
    """
    let label = try DSLDLabelParser.parse(Data(json.utf8))
    #expect(label.ingredients == [Ingredient(name: "Zinc", group: "Zinc", amount: nil)])
    #expect(label.servingQuantity == 1)
}

@Test func nonBlendNestedRowsAreNotListed() throws {
    let json = """
    {"id": 2, "fullName": "Fish", "brandName": "B", "upcSku": "", "entryDate": "2020-01-01",
     "servingSizes": [{"minQuantity": 2, "unit": "Softgel(s)"}],
     "ingredientRows": [{"name": "Total Fat", "ingredientGroup": "Fat", "category": "fat",
                         "quantity": [{"quantity": 2, "unit": "Gram(s)"}],
                         "nestedRows": [{"name": "Saturated Fat", "quantity": [{"quantity": 0.5, "unit": "Gram(s)"}]}]}]}
    """
    let label = try DSLDLabelParser.parse(Data(json.utf8))
    #expect(label.ingredients.map(\.name) == ["Total Fat"])
    #expect(label.servingQuantity == 2)
}
