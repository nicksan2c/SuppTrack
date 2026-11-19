import Testing
@testable import SuppTrackCore

@Test func normalizeDropsLeadingZeroOfEAN13() {
    #expect(UPC.normalize("0031604026165") == "031604026165")
}

@Test func normalizeStripsSpacesAndDashes() {
    #expect(UPC.normalize("0 31604-02616 5") == "031604026165")
}

@Test func normalizeRejectsShortCodes() {
    #expect(UPC.normalize("123") == nil)
}

@Test func normalizeRejectsEAN13NotStartingWithZero() {
    #expect(UPC.normalize("5012345678900") == nil)
}

@Test func dsldQueryIsSpacedAndQuoted() {
    #expect(UPC.dsldQuery("031604026165") == "\"0 31604 02616 5\"")
}

@Test func spacedFormMatchesDSLDUpcSku() {
    #expect(UPC.spaced("031604026165") == "0 31604 02616 5")
}
