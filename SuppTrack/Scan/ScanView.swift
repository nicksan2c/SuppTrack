import SuppTrackCore
import SwiftUI

/// Scan tab: camera, typed barcode, name search, and "Add prescription".
struct ScanView: View {
    @State private var barcode = ""
    @State private var searchText = ""
    @State private var hits: [LabelHit] = []
    @State private var message: String?
    @State private var isLoading = false
    @State private var confirm: ConfirmTarget?
    @State private var manualName: String?
    @State private var showRx = false

    private let client = LookupClient()

    struct ConfirmTarget: Identifiable {
        let id = UUID()
        let label: LabelInfo
        let barcode: String?
    }

    var body: some View {
        NavigationStack {
            Form {
                if BarcodeScannerView.isAvailable {
                    Section {
                        BarcodeScannerView { code in
                            barcode = code
                            Task { await lookUp(code) }
                        }
                        .frame(height: 220)
                        .listRowInsets(EdgeInsets())
                    }
                    .accessibilityIdentifier("scan-camera")
                }

                Section("Type a barcode") {
                    HStack {
                        TextField("e.g. 031604026165", text: $barcode)
                            .keyboardType(.numberPad)
                            .accessibilityIdentifier("scan-barcode-field")
                        Button("Look up") { Task { await lookUp(barcode) } }
                            .disabled(barcode.isEmpty || isLoading)
                            .accessibilityIdentifier("scan-barcode-button")
                    }
                }
                .accessibilityIdentifier("scan-barcode")

                Section("Search by name") {
                    HStack {
                        TextField("e.g. Nature Made CoQ10", text: $searchText)
                            .accessibilityIdentifier("scan-search-field")
                        Button("Search") { Task { await search(searchText) } }
                            .disabled(searchText.isEmpty || isLoading)
                            .accessibilityIdentifier("scan-search-button")
                    }
                }
                .accessibilityIdentifier("scan-search")

                if isLoading {
                    ProgressView("Looking it up…")
                }

                if let message {
                    Section {
                        Text(message)
                        Button("Add by hand") { manualName = searchText }
                            .accessibilityIdentifier("scan-manual-button")
                    }
                    .accessibilityIdentifier("scan-message")
                }

                if !hits.isEmpty {
                    Section("Pick the matching product") {
                        ForEach(hits, id: \.dsldId) { hit in
                            Button {
                                Task { await pick(hit) }
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(hit.name).foregroundStyle(.primary)
                                    Text(hit.brand).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .accessibilityIdentifier("scan-results")
                }

                Section {
                    Button("Add prescription", systemImage: "cross.case") { showRx = true }
                        .accessibilityIdentifier("scan-rx-button")
                }
            }
            .navigationTitle("Scan")
            .sheet(item: $confirm) { t in ConfirmItemView(label: t.label, barcode: t.barcode) }
            .sheet(isPresented: Binding(get: { manualName != nil }, set: { if !$0 { manualName = nil } })) {
                ManualEntryView(initialName: manualName ?? "")
            }
            .sheet(isPresented: $showRx) { RxSearchView() }
        }
        .accessibilityIdentifier("scan-screen")
    }

    /// Spec section 6: DSLD by barcode, then Open Food Facts name → DSLD search, then manual entry.
    private func lookUp(_ code: String) async {
        start()
        defer { isLoading = false }
        do {
            if let label = try await client.label(forBarcode: code) {
                confirm = ConfirmTarget(label: label, barcode: UPC.normalize(code))
                return
            }
            if let name = try await client.productName(forBarcode: code) {
                searchText = name
                hits = try await client.searchLabels(name)
                message = hits.isEmpty
                    ? "Not found in the NIH database. Try a shorter name, or add it by hand."
                    : "Not found by barcode in the NIH database. Is it one of these?"
                return
            }
            message = "Not found in the NIH database. Search by name, or add it by hand."
        } catch {
            message = Self.describe(error)
        }
    }

    private func search(_ text: String) async {
        start()
        defer { isLoading = false }
        do {
            hits = try await client.searchLabels(text)
            if hits.isEmpty { message = "No matches. Try fewer words, or add it by hand." }
        } catch {
            message = Self.describe(error)
        }
    }

    private func pick(_ hit: LabelHit) async {
        start()
        defer { isLoading = false }
        do {
            confirm = ConfirmTarget(label: try await client.label(id: hit.dsldId), barcode: UPC.normalize(barcode))
        } catch {
            message = Self.describe(error)
        }
    }

    private func start() {
        isLoading = true
        message = nil
        hits = []
    }

    static func describe(_ error: Error) -> String {
        switch error as? LookupError {
        case .badBarcode: "That doesn't look like a UPC barcode (12 digits)."
        case .network: "Couldn't reach the internet. Check your connection and try again."
        case let .server(code): "The lookup service isn't responding (error \(code)). Try again later."
        case nil: "Something went wrong reading the result. You can add it by hand."
        }
    }
}
