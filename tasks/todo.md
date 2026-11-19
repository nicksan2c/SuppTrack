# SuppTrack Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** a universal iPhone + iPad app that scans supplement barcodes, totals overlapping ingredients against upper limits, and shows an AM/PM checklist with prescription spacing rules. It imports from Apple Health and syncs through iCloud.

**Architecture:** all the logic lives in a local Swift package, `SuppTrackCore`. That covers parsing, overlap math, rules and the HTTP clients, and it's tested with `swift test` without needing a simulator. A thin SwiftUI app target holds SwiftData models and views, and calls into the Core package. XcodeGen generates the Xcode project from `project.yml`.

**Tech stack:** Swift 6, SwiftUI, SwiftData (+ CloudKit), VisionKit `DataScannerViewController`, HealthKit Medications API, Swift Testing, XcodeGen. No third-party Swift packages.

**Spec:** `docs/spec.md` (read it with this plan). Intent: `docs/intent.md`. Mockup: `docs/mockups/home-screen-v2.html`.

## Global Constraints
- iOS/iPadOS deployment target 26.0. The device family covers iPhone and iPad. Built with Xcode 27.2.
- Every SwiftData `@Model` property is optional or has a default. There are no `@Attribute(.unique)` and no required relationships (CloudKit rules).
- Every major view gets a unique `.accessibilityIdentifier("<screen>-<element>")`.
- Disclaimer text, exactly: "Not medical advice. Consult a nutritionally informed physician."
- Rule text begins "Commonly recommended:" or "Ask your doctor:".
- A total is never shown as complete when any contributing amount is unknown.
- DSLD base URL `https://api.ods.od.nih.gov/dsld/v9/`, RxNorm `https://rxnav.nlm.nih.gov/REST/`, Open Food Facts `https://world.openfoodfacts.org/api/v2/`. User-Agent `SuppTrack/0.1 (personal use)`.
- After each task: append to `docs/activity.md`, commit, and `git push`.

## Review Focus
1. **Barcode typed or scanned as 13-digit EAN with a leading 0, or with spaces or dashes.** It must normalize to the same `"0 31604 02616 5"` form (Task 2 test).
2. **A DSLD label with empty `servingSizes`, empty `quantity` arrays, or a `{Calories}`/`%DV` unit.** It's parsed without crashing, the amount becomes `nil`, and it's shown as "can't total" (Tasks 2 and 3 tests).
3. **No network, an HTTP 5xx, or zero hits.** The scan flow falls through to name search and then manual entry, with a message and no crash (Task 5 test and Task 7 manual check).
4. **The app is left open across midnight.** Today's checks reset based on the calendar day of `takenAt`, not app launch (Task 8 test on `DoseLog` day filtering).
5. **The same ingredient appears in one item with a known amount and one blend member with an unknown amount.** The result is the "can't be calculated" info line, plus an over-limit warning if the known part alone is over (Task 3 test).

---

### Task 1: Project scaffold, app shell, disclaimer and age setting
**Files:**
- Create: `project.yml`, `Packages/SuppTrackCore/Package.swift`, `Packages/SuppTrackCore/Sources/SuppTrackCore/AgeGroup.swift`, `Packages/SuppTrackCore/Tests/SuppTrackCoreTests/SmokeTests.swift`
- Create: `SuppTrack/SuppTrackApp.swift`, `SuppTrack/RootTabView.swift`, `SuppTrack/DisclaimerView.swift`, `SuppTrack/SettingsView.swift`
- Update: `CLAUDE.md` (repo root, created via `/init`-style trimming: build and test commands only)

**Interfaces, produces:**
- `public enum AgeGroup: String, Codable, CaseIterable { case adult19to50, adult51plus }`
- `@AppStorage("ageGroup")`, `@AppStorage("disclaimerAccepted")`, and `@AppStorage("healthImportEnabled")` (default `false`)

- [ ] Install XcodeGen with `brew install xcodegen`. Expected: `xcodegen --version` prints a version.
- [ ] Write `project.yml`:
  - an app target `SuppTrack` (iOS 26.0, `TARGETED_DEVICE_FAMILY: "1,2"`, bundle id `com.nicksan.supptrack`) that depends on the local package `SuppTrackCore`;
  - Info.plist keys `NSCameraUsageDescription` = "Scan supplement barcodes", `NSHealthShareUsageDescription` = "Read your medications and doses from Apple Health".
- [ ] Write the `RootTabView`, with tabs Today, Scan and My Bottles (placeholder views) and a gear button that opens `SettingsView`.
  - `DisclaimerView` is shown as a full-screen cover while `disclaimerAccepted == false`. It shows the disclaimer text, an `AgeGroup` picker, and an "I understand" button.
- [ ] Write the smoke test `AgeGroup.allCases.count == 2`.
- [ ] Run `swift test --package-path Packages/SuppTrackCore`. Expected: PASS.
- [ ] Run `xcodegen && xcodebuild -project SuppTrack.xcodeproj -scheme SuppTrack -destination 'generic/platform=iOS Simulator' build`. Expected: `BUILD SUCCEEDED`.
- [ ] Launch in the iOS Simulator. The disclaimer appears, then the three tabs.
- [ ] Commit "feat: project scaffold, tabs, disclaimer" and push.

### Task 2: UPC normalization and DSLD label parsing (blends included)
**Files:**
- Create: `Sources/SuppTrackCore/UPC.swift`, `Sources/SuppTrackCore/Ingredient.swift`, `Sources/SuppTrackCore/DSLDLabelParser.swift`
- Create: `Tests/SuppTrackCoreTests/Fixtures/label-8955.json`, `label-78540.json`, `search-031604026165.json` (saved with `curl` from the live API: label 8955 is a plain label, 78540 is a blend, and the search uses the spaced quoted UPC)
- Test: `Tests/SuppTrackCoreTests/UPCTests.swift`, `DSLDLabelParserTests.swift`

**Interfaces, produces:**
- `public enum UPC { static func normalize(_ raw: String) -> String? /* 12 digits */; static func dsldQuery(_ upc12: String) -> String /* "\"0 31604 02616 5\"" */ }`
- `public struct Amount: Codable, Hashable { var value: Double; var unit: String }`
- `public struct Ingredient: Codable, Hashable { var name: String; var group: String; var amount: Amount?; var blendName: String?; var blendTotal: Amount? }`
- `public struct LabelInfo: Codable { var dsldId: Int; var name: String; var brand: String; var upc: String; var servingUnit: String; var servingQuantity: Double; var entryDate: String; var ingredients: [Ingredient] }`
- `public enum DSLDLabelParser { static func parse(_ data: Data) throws -> LabelInfo }`

- [ ] Write the failing tests:
  - `UPC.normalize("0031604026165") == "031604026165"`
  - `UPC.normalize("0 31604-02616 5") == "031604026165"`
  - `UPC.normalize("123") == nil`
  - `UPC.dsldQuery("031604026165") == "\"0 31604 02616 5\""`
  - label 8955 gives an ingredient with group "Vitamin D" and `amount == Amount(value: 200, unit: "IU")`
  - label 78540 gives two ingredients with `amount == nil`, `blendName == "LOWAT Proprietary Blend"` and `blendTotal == Amount(value: 300, unit: "mg")`
  - a row with empty `quantity` gives `amount == nil` (inline JSON)
- [ ] Run `swift test`. Expected: FAIL.
- [ ] Implement. The parser uses `quantity[0]`, maps unit `"NP"` or a quantity of 0 in a blend member to `nil`, flattens `nestedRows` of `category == "blend"` rows, and keeps non-blend `nestedRows` (for example, under "Total Fat") out of the list.
- [ ] Run `swift test`. Expected: PASS.
- [ ] Commit and push.

### Task 3: Units, upper limits and overlap calculator
**Files:**
- Create: `Sources/SuppTrackCore/UnitConverter.swift`, `UpperLimits.swift`, `OverlapCalculator.swift`
- Test: `Tests/SuppTrackCoreTests/OverlapCalculatorTests.swift`

**Interfaces:**
- Consumes `Ingredient` and `Amount` (Task 2), and `AgeGroup` (Task 1).
- Produces:
  - `public struct ItemSnapshot { var id: UUID; var name: String; var isRx: Bool; var dailyServings: Double; var ingredients: [Ingredient] }`
  - `public struct UpperLimit { var group: String; var amount: Amount; var supplementsOnly: Bool }`
  - `UpperLimits.limit(for group: String, age: AgeGroup) -> UpperLimit?` (the section 7 table, matched case-insensitively)
  - `UnitConverter.convert(_ a: Amount, to unit: String, group: String) -> Amount?` (mg, mcg and g, plus IU for Vitamin D, A and E as in spec section 7)
  - `public enum OverlapFinding: Hashable { case overLimit(group: String, total: Amount, limit: UpperLimit), unknownAmounts(group: String, itemCount: Int, unknownCount: Int), sharedUnderLimit(group: String, itemCount: Int), missingIngredients(itemCount: Int) }`
  - `OverlapCalculator.findings(_ items: [ItemSnapshot], age: AgeGroup) -> [OverlapFinding]`

- [ ] Write the failing tests:
  - 2 items with Magnesium 400 mg × 1 and 120 mg × 1 give `.overLimit(group: "Magnesium", total: 520 mg, …)` with `limit.amount == 350 mg`
  - Vitamin D 2,000 IU plus 50 mcg gives a total of 100 mcg and no warning (equal to the limit is not over)
  - Calcium 2,200 mg is over for `.adult51plus` and not over for `.adult19to50`
  - Magnesium 400 mg plus a blend member Magnesium with an unknown amount gives both `.overLimit` and `.unknownAmounts(itemCount: 2, unknownCount: 1)`
  - Zinc 10 mg plus 5 mg gives `.sharedUnderLimit`
  - an item with no ingredients and `isRx == false` gives `.missingIngredients(itemCount: 1)`
  - Vitamin E in `"{Calories}"` units is reported as unknown, not converted
- [ ] Run `swift test`. Expected: FAIL.
- [ ] Implement. Group by `Ingredient.group`, multiply by `dailyServings`, and skip `isRx` items.
- [ ] Run `swift test`. Expected: PASS.
- [ ] Commit and push.

### Task 4: Timing defaults, spacing rules and doctor flags
**Files:**
- Create: `Sources/SuppTrackCore/Slot.swift`, `TimingRules.swift`, `SpacingRules.swift`
- Test: `Tests/SuppTrackCoreTests/TimingRulesTests.swift`, `SpacingRulesTests.swift`

**Interfaces:**
- Consumes `ItemSnapshot` (Task 3).
- Produces:
  - `public enum Slot: String, Codable { case am, pm }`
  - `TimingRules.defaults(for groups: [String], name: String) -> (slot: Slot, note: String?)` (the spec section 8 lists; the item name is also checked for "multivitamin", "fish oil", "probiotic")
  - `public struct SpacingHint: Hashable { var blockedItem: UUID; var byItemName: String; var hours: Double; var notBefore: Date? }`
  - `SpacingRules.hints(rxNames: [UUID: String], supplements: [ItemSnapshot], slotOf: [UUID: Slot], slot: Slot, takenAt: [UUID: Date]) -> [SpacingHint]`
  - `public struct DoctorFlag: Hashable { var text: String; var itemIDs: [UUID] }`
  - `SpacingRules.doctorFlags(rxNames: [UUID: String], supplements: [ItemSnapshot]) -> [DoctorFlag]`
  - `SpacingRules.suggestedSlot(for supplement: ItemSnapshot, rxNames: [UUID: String], rxSlots: [UUID: Slot]) -> Slot?` (the opposite slot when there's a conflict)

- [ ] Write the failing tests:
  - groups ["Magnesium"] give `.pm`; groups ["Vitamin D"] give `.am` with the note "with food"
  - "levothyroxine sodium 0.1 MG Oral Tablet" in AM, with a multivitamin containing Calcium in AM, gives `hours == 4`
  - the same pair taken at 06:30 gives `notBefore == 10:30`
  - the Rx in AM and the supplement in PM give no hint
  - "ciprofloxacin 500 MG" with Zinc gives `hours == 6`; doxycycline gives `hours == 4`
  - "alendronate" with any supplement gives `hours == 0.5`
  - Iron and Calcium supplements in the same slot give `hours == 2`
  - "warfarin" with Fish Oil gives a `DoctorFlag` starting "Ask your doctor:"
  - St. John's Wort with any Rx gives a `DoctorFlag`
  - `suggestedSlot` for Calcium with levothyroxine in AM is `.pm`
- [ ] Run `swift test`. Expected: FAIL.
- [ ] Implement. The rule table is data, a static array of `(rxSubstrings, groups, hours)`, taken from the spec section 8 table.
- [ ] Run `swift test`. Expected: PASS.
- [ ] Commit and push.

### Task 5: HTTP clients (DSLD, Open Food Facts, RxNorm)
**Files:**
- Create: `Sources/SuppTrackCore/LookupClient.swift`
- Test: `Tests/SuppTrackCoreTests/LookupClientTests.swift` (with a `URLProtocol` stub serving the Task 2 fixtures)

**Interfaces:**
- Consumes `UPC` and `DSLDLabelParser` (Task 2).
- Produces:
  - `public struct RxDrug: Codable, Hashable { var rxcui: String; var name: String }`
  - `public struct LabelHit: Hashable { var dsldId: Int; var name: String; var brand: String }`
  - `public final class LookupClient { init(session: URLSession = .shared); func label(forBarcode raw: String) async throws -> LabelInfo?; func searchLabels(_ text: String) async throws -> [LabelHit]; func label(id: Int) async throws -> LabelInfo; func productName(forBarcode raw: String) async throws -> String? /* OFF "brand name" */; func searchRx(_ text: String) async throws -> [RxDrug] /* tty SCD or SBD */ }`
  - `public enum LookupError: Error { case badBarcode, network, server(Int) }`

- [ ] Write the failing tests:
  - `label(forBarcode: "031604026165")` returns the label whose `upc == "0 31604 02616 5"`, choosing the newer `entryDate` of 2 matches
  - zero hits return `nil`
  - an HTTP 503 throws `.server(503)`
  - `searchRx("levothyroxine")` returns only SCD/SBD entries (inline fixture)
- [ ] Run `swift test`. Expected: FAIL.
- [ ] Implement with `URLSession` async APIs, set the User-Agent header, and use a 15 s timeout.
- [ ] Run `swift test`. Expected: PASS.
- [ ] Commit and push.

### Task 6: SwiftData models and My Bottles (list, detail, manual entry)
**Files:**
- Create: `SuppTrack/Models/Item.swift`, `SuppTrack/Models/DoseLog.swift`, `SuppTrack/Bottles/BottlesView.swift`, `BottleDetailView.swift`, `ManualEntryView.swift`

**Interfaces:**
- Consumes `Ingredient`, `ItemSnapshot` and `OverlapCalculator` (Tasks 2–3).
- Produces:
  - `@Model final class Item { var id: UUID = UUID(); var name: String = ""; var brand: String = ""; var isRx: Bool = false; var upc: String?; var dsldId: Int?; var rxcui: String?; var healthConceptID: String?; var amServings: Double = 0; var pmServings: Double = 0; var doseText: String = ""; var note: String?; var isHidden: Bool = false; var isActive: Bool = true; var ingredientsJSON: Data = Data(); var ingredients: [Ingredient] { get set } /* JSON-coded */; var snapshot: ItemSnapshot }`
  - `@Model final class DoseLog { var itemID: UUID = UUID(); var slotRaw: String = "am"; var takenAt: Date = .now }`

- [ ] Write the `Item` and `DoseLog` models. Ingredients are stored as a JSON `Data` blob, which keeps CloudKit simple.
- [ ] Write a Core-free unit test target `SuppTrackTests` with `ItemTests`. It checks that `ingredients` round-trips through JSON, and that `snapshot.dailyServings == amServings + pmServings`.
- [ ] `BottlesView`: a `NavigationSplitView` (iPad: list plus detail; iPhone: push). It lists active, non-hidden items, with an "Rx" tag and a "No ingredients yet" badge.
- [ ] `BottleDetailView`: shows ingredients, and blend members read "amount not listed (part of X · Y total)". It has `.sharedUnderLimit` info lines, AM/PM servings steppers, a note field, and Delete (which hides imported items and deletes the rest).
- [ ] `ManualEntryView`: name, brand, Rx toggle, and ingredient rows (name, optional amount, unit picker mg/mcg/g/IU). The group equals the typed name.
- [ ] Build and run in the simulator. Add a manual item with Magnesium 400 mg and see it in the list and detail.
- [ ] Commit and push.

### Task 7: Scan tab (scanner, typed barcode, lookup flow, confirm, Rx add)
**Files:**
- Create: `SuppTrack/Scan/ScanView.swift`, `BarcodeScannerView.swift` (a `UIViewControllerRepresentable` around `DataScannerViewController`, `.barcode(symbologies: [.upce, .ean13, .ean8])`), `ConfirmItemView.swift`, `RxSearchView.swift`

**Interfaces:**
- Consumes `LookupClient` (Task 5), `TimingRules` and `SpacingRules.suggestedSlot` (Task 4), and `Item` (Task 6).

- [ ] `ScanView` holds the scanner (hidden when `DataScannerViewController.isSupported == false`, as in the simulator), a "type barcode" field, a "Search by name" field, and "Add prescription."
- [ ] The lookup chain follows spec section 6: `label(forBarcode:)`, then OFF `productName` into `searchLabels` with a pick list, then manual entry. Each fallback shows why ("Not found in NIH database").
- [ ] `ConfirmItemView` shows the name, brand and ingredients. AM/PM servings are prefilled from `TimingRules.defaults`, and swapped to `suggestedSlot` if there's a conflict. Saving inserts an `Item`.
- [ ] `RxSearchView` uses `searchRx`, and picking a result inserts `Item(isRx: true, rxcui:, name:)`. It warns on save if `SpacingRules.doctorFlags` is non-empty.
- [ ] In the simulator, type `031604026165`. The confirm screen shows Nature Made CoQ10 200 mg. Save it. Type `000000000000` and confirm it falls through to manual entry. Turn on airplane-style failure (stop the network with Link Conditioner or disconnect Wi-Fi) and confirm a message appears with no crash.
- [ ] Commit and push.

### Task 8: Today tab
**Files:**
- Create: `SuppTrack/Today/TodayView.swift`, `SuppTrack/Today/TodayModel.swift`
- Test: `SuppTrackTests/TodayModelTests.swift`

**Interfaces:**
- Consumes `OverlapCalculator`, `SpacingRules`, `Item` and `DoseLog`.
- Produces: `struct TodayModel { static func rows(items: [Item], logs: [DoseLog], slot: Slot, now: Date, calendar: Calendar) -> [TodayRow]; static func defaultSlot(now: Date, calendar: Calendar) -> Slot }`, where `TodayRow` has `item`, `isChecked`, `hint: SpacingHint?`.

- [ ] Write the failing tests:
  - `defaultSlot` at 11:59 is `.am`, and at 12:00 is `.pm`
  - a `DoseLog` from yesterday 23:59 does not check today's row
  - an item with `amServings == 1` and `pmServings == 1` appears in both slots, with independent checks
- [ ] Run `xcodebuild test -scheme SuppTrack -destination 'platform=iOS Simulator,name=<installed iPhone>'`. Expected: FAIL. Implement, then run again. Expected: PASS.
- [ ] `TodayView` matches the mockup:
  - the AM/PM segmented control;
  - banners for `.overLimit`, `.unknownAmounts`, `.missingIngredients` and doctor flags;
  - rows with a checkbox, name, Rx tag, dose and note;
  - a dashed checkbox plus "after HH:MM · N hrs after X" on rows with a hint;
  - the disclaimer footer.
  - Checking a row inserts a `DoseLog`, and unchecking deletes today's log for that slot.
- [ ] In the simulator, the Magnesium 520 mg warning shows, and a levothyroxine-plus-multivitamin hint appears after levothyroxine is checked.
- [ ] Commit and push.

### Task 9: Apple Health import and iCloud sync (needs paid developer membership)
**Files:**
- Create: `SuppTrack/Health/HealthImporter.swift`
- Modify: `project.yml` (entitlements `com.apple.developer.healthkit`, iCloud CloudKit container `iCloud.com.nicksan.supptrack`, the `remote-notification` background mode, and `DEVELOPMENT_TEAM`), `SuppTrackApp.swift` (`ModelConfiguration(cloudKitDatabase: .private("iCloud.com.nicksan.supptrack"))`), `TodayModel.swift`, `SettingsView.swift`

**Interfaces:**
- Consumes `Item` and `TodayModel`.
- Produces: `@MainActor final class HealthImporter { func requestAccess() async throws; func importMedications(into context: ModelContext) async throws; func takenEvents(on day: Date) async throws -> [(conceptID: String, takenAt: Date)] }`

- [ ] Gate: Nick's paid membership is active and the team ID is in `project.yml`. Until then, skip this task.
- [ ] Settings gets the "Import from Apple Health" toggle, which calls `requestAccess()` (per-object authorization for `HKUserAnnotatedMedicationType`), and a "Refresh from Health" button.
- [ ] `importMedications` upserts by `healthConceptID`, skips `isHidden` items, marks archived medications `isActive = false`, and sets `isRx = true` when `relatedCodings` contains an RxNorm coding.
  - When a label is attached, merge with an existing item that has the same `dsldId` (spec section 11.2).
- [ ] `TodayModel.rows` also counts Health taken events, mapped to a slot by hour (< 12 is AM).
- [ ] On Nick's iPhone: add a medication in the Health app, import it, log it as taken in Health, and see it checked in SuppTrack. Note whether a supplement added in Health has an RxNorm code. Install on the iPad and confirm the items sync.
- [ ] Commit and push.

### Task 10: Install on devices and final check
- [ ] Run `swift test --package-path Packages/SuppTrackCore` and `xcodebuild test`. Both pass.
- [ ] Install on the iPhone and iPad from Xcode. Scan 3 real bottles from the GNC bags, and check each ingredient list against the label.
- [ ] Write the Review section below. Commit and push.

---

## Review
*(To be filled in after the build.)*
