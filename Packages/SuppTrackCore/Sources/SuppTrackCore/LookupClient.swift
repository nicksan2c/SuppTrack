import Foundation

public struct RxDrug: Codable, Hashable, Sendable {
    public var rxcui: String
    public var name: String
}

public struct LabelHit: Hashable, Sendable {
    public var dsldId: Int
    public var name: String
    public var brand: String
}

public enum LookupError: Error, Equatable {
    case badBarcode
    case network
    case server(Int)
}

/// Talks to NIH DSLD (supplement labels), Open Food Facts (product names)
/// and NLM RxNorm (prescriptions). Only the barcode or search text is sent.
public final class LookupClient: Sendable {
    private let session: URLSession
    private static let dsld = "https://api.ods.od.nih.gov/dsld/v9/"
    private static let off = "https://world.openfoodfacts.org/api/v2/product/"
    private static let rxnorm = "https://rxnav.nlm.nih.gov/REST/drugs.json"

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// The DSLD label for a scanned barcode, or nil if DSLD doesn't have it.
    public func label(forBarcode raw: String) async throws -> LabelInfo? {
        guard let upc = UPC.normalize(raw) else { throw LookupError.badBarcode }
        let spaced = UPC.spaced(upc)
        let hits = try await search(UPC.dsldQuery(upc))
        var matches: [LabelInfo] = []
        for hit in hits {
            let info = try await label(id: hit.dsldId)
            if info.upc == spaced { matches.append(info) }
        }
        return matches.max { $0.entryDate < $1.entryDate }
    }

    public func searchLabels(_ text: String) async throws -> [LabelHit] {
        try await search(text)
    }

    public func label(id: Int) async throws -> LabelInfo {
        try DSLDLabelParser.parse(await get(Self.dsld + "label/\(id)"))
    }

    /// "Brand Product" from Open Food Facts, used to search DSLD by name.
    public func productName(forBarcode raw: String) async throws -> String? {
        guard let upc = UPC.normalize(raw) else { throw LookupError.badBarcode }
        let data: Data
        do {
            data = try await get(Self.off + upc + ".json", query: [URLQueryItem(name: "fields", value: "product_name,brands")])
        } catch LookupError.server(404) {
            return nil // Open Food Facts answers "product not found" with HTTP 404.
        }
        struct Response: Decodable {
            struct Product: Decodable { var brands: String?; var product_name: String? }
            var status: Int?
            var product: Product?
        }
        let r = try JSONDecoder().decode(Response.self, from: data)
        guard r.status == 1, let p = r.product else { return nil }
        let name = [p.brands, p.product_name].compactMap { $0 }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }

    /// Clinical (SCD) and branded (SBD) drug names matching the text.
    public func searchRx(_ text: String) async throws -> [RxDrug] {
        let data = try await get(Self.rxnorm, query: [URLQueryItem(name: "name", value: text)])
        struct Response: Decodable {
            struct Group: Decodable { var conceptGroup: [Concepts]? }
            struct Concepts: Decodable { var tty: String?; var conceptProperties: [RxDrug]? }
            var drugGroup: Group
        }
        let r = try JSONDecoder().decode(Response.self, from: data)
        return (r.drugGroup.conceptGroup ?? [])
            .filter { $0.tty == "SCD" || $0.tty == "SBD" }
            .flatMap { $0.conceptProperties ?? [] }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func search(_ q: String) async throws -> [LabelHit] {
        let data = try await get(Self.dsld + "search-filter", query: [URLQueryItem(name: "q", value: q)])
        struct Response: Decodable {
            struct Hit: Decodable { var _id: String; var _source: Source }
            struct Source: Decodable { var fullName: String?; var brandName: String? }
            var hits: [Hit]
        }
        return try JSONDecoder().decode(Response.self, from: data).hits.compactMap { h in
            Int(h._id).map { LabelHit(dsldId: $0, name: h._source.fullName ?? "", brand: h._source.brandName ?? "") }
        }
    }

    private func get(_ url: String, query: [URLQueryItem] = []) async throws -> Data {
        var components = URLComponents(string: url)!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!, timeoutInterval: 15)
        request.setValue("SuppTrack/0.1 (personal use)", forHTTPHeaderField: "User-Agent")
        let data: Data, response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw LookupError.network
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw LookupError.server(status) }
        return data
    }
}
