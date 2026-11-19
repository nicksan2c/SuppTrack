/// Barcode helpers for looking products up in the NIH DSLD.
public enum UPC {
    /// Returns a 12-digit UPC-A, or nil if the input isn't one.
    /// Accepts spaces/dashes and a 13-digit EAN that starts with 0.
    public static func normalize(_ raw: String) -> String? {
        let digits = raw.filter(\.isNumber)
        if digits.count == 12 { return digits }
        if digits.count == 13, digits.first == "0" { return String(digits.dropFirst()) }
        return nil
    }

    /// DSLD stores UPCs as "0 31604 02616 5".
    public static func spaced(_ upc12: String) -> String {
        let c = Array(upc12)
        return "\(c[0]) \(String(c[1...5])) \(String(c[6...10])) \(c[11])"
    }

    /// The quoted search text that finds a UPC in DSLD's search-filter endpoint.
    public static func dsldQuery(_ upc12: String) -> String {
        "\"\(spaced(upc12))\""
    }
}
