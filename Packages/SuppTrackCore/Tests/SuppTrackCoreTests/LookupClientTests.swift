import Foundation
import Testing
@testable import SuppTrackCore

/// Serves canned responses so the client is tested without the network.
final class StubProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (Int, Data))?
    nonisolated(unsafe) static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lastRequest = request
        do {
            let (status, data) = try Self.handler!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}

private func makeClient(_ handler: @escaping (URLRequest) throws -> (Int, Data)) -> LookupClient {
    StubProtocol.handler = handler
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubProtocol.self]
    return LookupClient(session: URLSession(configuration: config))
}

private let empty = Data(#"{"hits":[],"stats":{"count":0}}"#.utf8)

@Suite(.serialized) struct LookupClientTests {
    @Test func barcodeFindsNewestMatchingLabel() async throws {
        let client = makeClient { req in
            let url = req.url!.absoluteString
            if url.contains("search-filter") { return (200, try fixture("search-031604026165")) }
            if url.hasSuffix("label/255113") { return (200, try fixture("label-255113")) }
            if url.hasSuffix("label/179676") { return (200, try fixture("label-179676")) }
            return (404, Data())
        }
        let label = try await client.label(forBarcode: "0031604026165")
        #expect(label?.dsldId == 255113)
        #expect(label?.upc == "0 31604 02616 5")
    }

    @Test func barcodeSearchSendsQuotedSpacedUPCAndUserAgent() async throws {
        let client = makeClient { _ in (200, empty) }
        _ = try await client.label(forBarcode: "031604026165")
        let req = try #require(StubProtocol.lastRequest)
        let q = URLComponents(url: req.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "q" }?.value
        #expect(q == "\"0 31604 02616 5\"")
        #expect(req.value(forHTTPHeaderField: "User-Agent") == "SuppTrack/0.1 (personal use)")
    }

    @Test func zeroHitsReturnsNil() async throws {
        let client = makeClient { _ in (200, empty) }
        #expect(try await client.label(forBarcode: "000000000000") == nil)
    }

    @Test func serverErrorThrows() async {
        let client = makeClient { _ in (503, Data()) }
        await #expect(throws: LookupError.server(503)) {
            _ = try await client.label(forBarcode: "031604026165")
        }
    }

    @Test func badBarcodeThrows() async {
        let client = makeClient { _ in (200, empty) }
        await #expect(throws: LookupError.badBarcode) {
            _ = try await client.label(forBarcode: "123")
        }
    }

    @Test func searchLabelsReturnsHits() async throws {
        let client = makeClient { _ in (200, try fixture("search-031604026165")) }
        let hits = try await client.searchLabels("coq10")
        #expect(hits.first == LabelHit(dsldId: 255113, name: "CoQ10 200 mg", brand: "Nature Made"))
    }

    @Test func productNameFromOpenFoodFacts() async throws {
        let json = #"{"code":"0031604026165","product":{"brands":"Nature Made","product_name":"CoQ10"},"status":1}"#
        let client = makeClient { _ in (200, Data(json.utf8)) }
        #expect(try await client.productName(forBarcode: "031604026165") == "Nature Made CoQ10")
    }

    @Test func productNameMissingReturnsNil() async throws {
        let client = makeClient { _ in (200, Data(#"{"status":0}"#.utf8)) }
        #expect(try await client.productName(forBarcode: "031604026165") == nil)
    }

    @Test func searchRxKeepsOnlyClinicalAndBrandedDrugs() async throws {
        let json = """
        {"drugGroup":{"name":"levothyroxine","conceptGroup":[
          {"tty":"IN","conceptProperties":[{"rxcui":"10582","name":"levothyroxine","tty":"IN"}]},
          {"tty":"SCD","conceptProperties":[{"rxcui":"892246","name":"levothyroxine sodium 0.1 MG Oral Tablet","tty":"SCD"}]},
          {"tty":"SBD","conceptProperties":[{"rxcui":"966247","name":"levothyroxine sodium 0.1 MG Oral Tablet [Synthroid]","tty":"SBD"}]},
          {"tty":"BPCK"}]}}
        """
        let client = makeClient { _ in (200, Data(json.utf8)) }
        let drugs = try await client.searchRx("levothyroxine")
        #expect(drugs.map(\.rxcui) == ["892246", "966247"])
    }
}
