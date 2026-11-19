# Spec: SuppTrack v1

*Stage 2 (Design) of the AI-native SDLC. Reads from `docs/intent.md`. Date: 2026-11-18.*

Items marked **(my call)** were decided by Claude, not by Nick. Nick can overturn any of them.

## 1. Intent and why
Nick takes many supplements and some prescriptions. He wants to know (a) whether anything overlaps or adds up to too much, and (b) what to take in the morning versus at night, and how far apart from his prescriptions. The app is for Nick alone. Success means he opens it each morning and night, ticks off the list, and trusts its warnings.

## 1a. Phases
- **Phase 1 (this plan):** a universal iPhone + iPad app with goals 1–7 below, Apple Health import, and iCloud sync.
- **Phase 2 (later spec and plan):** an Apple Watch app (section 12) and cost features (section 13).

## 2. Goals
1. Add a supplement by scanning its barcode, with its ingredients and per-serving amounts looked up automatically.
2. Add a prescription by typing its name and picking it from a list.
3. Add up each ingredient across all items and warn when a daily total is above the adult upper limit.
4. Handle proprietary blends. Show the ingredients, say plainly when amounts aren't listed, and never pretend a total is known when it isn't.
5. Show a Today screen with an AM/PM switch, a checkbox per item, and the day's warnings.
6. Apply a small built-in set of spacing rules between prescriptions and supplements. Show "after 10:30 AM" style times, and flag combinations where spacing doesn't help.
7. Import the medications and supplements Nick already tracks in Apple Health, and mirror his Health "taken" logs (section 6a).

## 3. Non-goals (v1)
- Other users, our own accounts or servers, or App Store release. Sync uses Nick's own iCloud.
- Our own reminders or notifications. The Apple Health Medications app already reminds Nick, and third-party apps can't create Health reminders.
- Writing anything to Apple Health. The API is read-only for medications.
- A full drug-interaction database. Only the curated rules in section 8 are included.
- Counting nutrients from food.
- Pregnancy, child or teen limits.
- History charts or adherence stats. Only today's checkboxes are kept, plus a simple log.

## 4. Anti-goals (a failure even if it "works")
- Showing a computed total as if it were complete when some amounts are unknown (blends, manual entries without amounts).
- Any wording that reads as medical advice or a prescription. Rules say "commonly recommended" and point to a doctor or pharmacist.
- Losing Nick's list. Data must persist across app restarts and updates.

## 5. Screens
The app has three tabs: **Today**, **Scan**, and **My Bottles**. The approved mockup is `docs/mockups/home-screen-v2.html`.

**Today**
- AM/PM segmented switch. It defaults to AM before 12:00 local time, and PM after.
- An overlap warning banner at the top, one line per problem (for example, "Magnesium today: 520 mg. Upper limit from supplements is 350 mg.").
- One row per item in that slot. Each row has a checkbox, the name, an "Rx" tag for prescriptions, the dose ("2 softgels"), and a how-to-take note ("with food", "empty stomach").
- A row blocked by a spacing rule shows a dashed checkbox and "after HH:MM · N hrs after <drug>". It can still be checked.
- The disclaimer line at the bottom.
- Checks reset each day. Each check is saved as a log entry with its time.

**Scan**
- Live camera barcode scanner (VisionKit `DataScannerViewController`, UPC-A and EAN-13).
- A "type barcode" text field, because the simulator has no camera **(my call)**.
- A "Search by name" field and an "Add prescription" button.
- The result opens a confirm screen. It shows the product name, brand, and ingredient list with amounts. Nick sets servings per day, AM or PM (pre-filled by the rules), and saves.

**My Bottles**
- A list of all items. A detail screen shows ingredients with amounts. Blend members show "amount not listed (part of <blend> · <total> total)".
- Nick can edit servings per day, AM/PM, and notes, or delete the item.
- **Manual entry:** a name, plus ingredient rows (name, amount, unit, with amount optional). This is used when no lookup finds the product.

**First launch:** a one-time disclaimer screen with "Not medical advice. Consult a nutritionally informed physician." and an "I understand" button.

## 6. Lookups (verified live on 2026-11-18)
**Supplements: NIH DSLD API v9.** The base URL is `https://api.ods.od.nih.gov/dsld/v9/`, and no key is needed.
1. Normalize the scanned code to 12 digits (drop the leading 0 of an EAN-13 that starts with 0). Format it as `d ddddd ddddd d`, then search `search-filter?q="<formatted>"` (with the quotes, URL-encoded). Example: `031604026165` becomes `"0 31604 02616 5"`, which returns label ids 255113 and 179676 (Nature Made CoQ10).
2. Fetch each hit with `label/{id}`, and keep only labels whose `upcSku` equals the formatted code. If several match, use the one with the newest `entryDate`.
3. Read `fullName`, `brandName`, `servingSizes[0]` (`minQuantity`, `unit`, `maxDailyServings`), and `ingredientRows[]`. Each row has `name`, `ingredientGroup`, `category`, `quantity[0]` (`quantity`, `unit`), and `nestedRows[]`.
4. **Blends:** a row with `category == "blend"` has a total `quantity` (for example, 300 mg). Its `nestedRows` list members whose quantity unit is `"NP"` (not provided) with a quantity of 0. Store each member as an ingredient with a `nil` amount, plus the blend's name and total. A nested row that does have a real amount is stored with that amount.
5. **Fallback, in order:** (a) Open Food Facts `https://world.openfoodfacts.org/api/v2/product/<code>.json?fields=product_name,brands`. If found, search DSLD by `"<brand> <product_name>"`, let Nick pick a label, and check that it matches. (b) Search DSLD by name, with Nick typing. (c) Manual entry. A User-Agent of `SuppTrack/0.1 (personal use)` is used, with no personal details.

**Prescriptions: NLM RxNorm.** Use `https://rxnav.nlm.nih.gov/REST/drugs.json?name=<text>` (no key). Show `conceptGroup[].conceptProperties[]` entries with `tty` of SCD or SBD (name example: "levothyroxine sodium 0.1 MG Oral Tablet"). Store `rxcui` and `name`. Prescriptions have no ingredient amounts. They only feed the spacing rules.

## 6a. Apple Health medications (verified in Apple docs, 2026-11-18)
- **Requirements:** HealthKit Medications API, iOS/iPadOS/watchOS 26.0+. It's read-only. Request access with HealthKit per-object authorization for `HKUserAnnotatedMedicationType`. Nick picks which medications to share, and access to their dose events comes along automatically.
- **Import:** run `HKUserAnnotatedMedicationQueryDescriptor` (excluding `isArchived`). For each medication, take `nickname ?? medication.displayText`, `medication.generalForm`, and the RxNorm code from `medication.relatedCodings`. Each one becomes an item linked by `medication.identifier`.
  - If it has an RxNorm code, it's treated as a prescription, and its name feeds the section 8 rules.
  - Nick can re-mark any imported item as a supplement and attach a scanned label to it, to get its ingredients.
  - It's unverified whether supplements Nick added in Health carry RxNorm codes. The builder checks this on a real device.
- **Taken logs:** query today's `HKMedicationDoseEvent` samples. A dose with status "taken" for a linked medication shows that item as checked on Today, at the event's time, and that time feeds the spacing rules.
- **Checking off in SuppTrack:** this stays local, because Health can't be written to. Today shows an item as checked if either SuppTrack or Health says it was taken.
- **Settings toggle:** "Import from Apple Health." The app works fully without it. Also check `HKHealthStore.isHealthDataAvailable()`.

## 7. Overlap math
- Daily amount per item = per-serving `quantity` × servings per day.
- Group ingredients across items by DSLD `ingredientGroup` (for example, "Magnesium Oxide" falls under "Magnesium"). For manual entries, use the typed name, matched case-insensitively against the upper-limit table names.
- **Unit normalization (my call):** convert mg, mcg and g to each other. Vitamin D: 40 IU = 1 mcg. Vitamin A: 1 IU = 0.3 mcg RAE (the retinol factor, which errs high). Vitamin E: 1 IU = 0.67 mg (the natural factor, which errs high). Any other unit that can't be converted is shown as "can't total (unit X)".
- **Warning rules:**
  - If the known total is over the limit, show a warning: "<Nutrient> today: <total>. Upper limit<note> is <UL>."
  - If an ingredient appears in 2 or more items and any amount is unknown, show an info line: "<Nutrient> is in <n> items. <k> don't list the amount, so the total can't be calculated."
  - If an ingredient appears in 2 or more items and it's under the limit (or has no limit), show an info line on that ingredient in My Bottles only, not on Today.
- Totals count every active item regardless of AM/PM.

**Adult upper limits (19+, from NIH ODS fact sheets)** **(my call: adult defaults, see Open questions)**

| Nutrient | UL | Note |
|---|---|---|
| Vitamin A (preformed) | 3,000 mcg RAE | |
| Vitamin C | 2,000 mg | |
| Vitamin D | 100 mcg (4,000 IU) | |
| Vitamin E | 1,000 mg | from supplements |
| Niacin | 35 mg | from supplements |
| Vitamin B6 | 100 mg | |
| Folic acid | 1,000 mcg | from supplements |
| Choline | 3,500 mg | |
| Calcium | 2,500 mg (ages 19–50) / 2,000 mg (51+) | |
| Iron | 45 mg | |
| Magnesium | 350 mg | from supplements |
| Zinc | 40 mg | |
| Selenium | 400 mcg | |
| Copper | 10,000 mcg | |
| Iodine | 1,100 mcg | |
| Manganese | 11 mg | |
| Molybdenum | 2,000 mcg | |
| Phosphorus | 4,000 mg | |

For limits that count total intake, the warning adds: "Food adds more."

## 8. Timing and spacing rules (built-in, curated)
**Default slot and note by ingredient group (my call; Nick can override per item):**
- PM: Magnesium, Melatonin, Ashwagandha, Glycine, L-Theanine, Valerian.
- AM: B vitamins (B-complex, B6, B12, Niacin, Thiamin, Riboflavin), Iron (note: "empty stomach, or with vitamin C"), Vitamin D, Multivitamin, CoQ10, Probiotic (note: "empty stomach").
- Note "with food" for: Vitamin A, D, E, K, Fish Oil/Omega-3, CoQ10, Multivitamin, Turmeric/Curcumin.
- Anything else defaults to AM with no note.
- Prescriptions default to AM. Nick picks the slot.

**Spacing rules (prescription ↔ supplement), matched on a lowercase substring of the RxNorm name:**

| Rx contains | Separate from (ingredient groups) | Rule |
|---|---|---|
| levothyroxine, liothyronine | Calcium, Iron, Magnesium, Soy | supplement ≥ 4 h after Rx; Rx note "empty stomach, 30–60 min before breakfast" |
| doxycycline, minocycline, tetracycline | Calcium, Iron, Magnesium, Zinc | supplement ≥ 2 h before or ≥ 4 h after |
| ciprofloxacin, levofloxacin, moxifloxacin | Calcium, Iron, Magnesium, Zinc | supplement ≥ 2 h before or ≥ 6 h after |
| alendronate, risedronate, ibandronate | everything | ≥ 30 min after Rx, plain water only |

Supplement-to-supplement rule: Iron and Calcium should be taken at least 2 hours apart.

"After HH:MM" uses the actual time the blocking item was checked off today. If it hasn't been checked, it uses "N hrs after <drug>" with no clock time.

**Doctor flags (spacing doesn't help).** These show as a warning banner on Today and My Bottles:
- Rx contains warfarin: Vitamin K, Fish Oil/Omega-3, Vitamin E, Ginkgo, Turmeric/Curcumin. "May change how warfarin works. Ask your doctor."
- Any Rx at all, plus St. John's Wort: "St. John's wort interacts with many medications. Ask your doctor or pharmacist."

Every rule's text begins "Commonly recommended:" or "Ask your doctor:".

## 9. Constraints
- One universal SwiftUI app for iPhone and iPad (iPad uses a split view: list on the left, detail on the right), with iOS/iPadOS 26.0 minimum, since the Health Medications API requires it. Built with Xcode 27.2.
- SwiftData storage synced through CloudKit (Nick's private iCloud database) **(my call)**. CloudKit rules apply: every model property is optional or has a default, there are no unique constraints, and relationships are optional.
- A paid Apple Developer membership is needed for the CloudKit and HealthKit capabilities and for non-expiring installs. Nick is getting one. Until it's active, the app runs locally in the simulator, with sync and Health switched off.
- No third-party Swift packages **(my call)**. XcodeGen (`project.yml`) generates the Xcode project **(my call: keeps the project file reviewable)**.
- Domain logic (parsing, overlap, rules) goes in a local Swift package, `SuppTrackCore`, tested with `swift test` and needing no simulator **(my call)**.
- Every major view gets a unique `.accessibilityIdentifier`, so Nick can refer to it in prompts. This is the iOS version of the CLAUDE.md "unique div id" rule.
- Only public, no-key APIs. No personal data is sent. Only the barcode or the search text leaves the phone.
- Installed on Nick's phone straight from Xcode.

## 10. Left to the builder
File layout inside the package and the app, view styling within the mockup, error-message wording (keeping the anti-goals), and network timeouts and retries.

## 11. Decisions from the builder check (all my calls, Nick to confirm)
1. **AM and PM doses.** Each item has `amServings` and `pmServings`, either of which may be 0, instead of one slot. An item with both appears in both lists, each with its own checkbox. A Health "taken" event before 12:00 local time ticks AM, and one at or after 12:00 ticks PM. Daily amount = per-serving amount × (AM + PM servings).
2. **Health import merge.**
   - Import runs on launch and from a "Refresh from Health" button.
   - Items are matched by Health concept identifier.
   - Deleting an imported item in SuppTrack hides it (`isHidden`), so it won't come back on the next import.
   - A medication archived in Health becomes inactive in SuppTrack.
   - When Nick attaches a scanned label to an imported item and a scanned item with the same DSLD id already exists, the app offers to merge them, so nothing is counted twice.
   - A supplement with no ingredients shows a "No ingredients yet: scan the label" badge. Today shows an info line: "<n> items have no ingredient info, so totals may be incomplete."
3. **Age.** The first-launch screen asks for an age group (19–50 or 51+), and Settings can change it later. This drives the calcium limit (2,500 mg or 2,000 mg).
4. **Spacing behavior.**
   - Rules apply only when the prescription and the supplement are in the same slot (AM or PM).
   - The app always uses the "after" direction (for example, supplement ≥ 4 h after the Rx), since items have no planned times. This is the simpler, conservative choice.
   - The blocked row shows "N hrs after <drug>" until the Rx is checked, then "after HH:MM".
   - When a supplement that conflicts with a prescription is added, its default slot is set to the opposite one from the prescription.
   - Rules match on any ingredient group in the item (so a multivitamin containing calcium counts).

## 12. Phase 2: Apple Watch (outline only)
A watchOS 26 app that shows Today's AM/PM checklist, warnings and "after HH:MM" times, reading the same iCloud data. There's no scanning or editing on the Watch. Health reminders already appear on the Watch through Apple's Medications app.

## 13. Phase 2: Cost (outline only)
- **Per bottle:** count per bottle, plus price entries per store (Amazon, GNC, iHerb, Other), each with a price, count and date entered by Nick. From these the app shows cost per day and the date the bottle runs out.
- **"Finish, then stop":** a flag for bottles to retire. They stay on Today until the run-out date, then move to "Retired."
- **Paying twice:** "You're paying for Magnesium in 3 bottles."
- **Replacements:** for a selected group of bottles, search NIH DSLD for products covering the same ingredient groups at similar amounts (within ±25%, my call). For each, show "Search on Amazon / GNC / iHerb" buttons that open the store's search page in Safari. Nick enters the price he sees, and the app ranks the options by cost per day.
- **No price scraping.** Amazon's Product Advertising API is a possible later add-on if Nick ever qualifies as an Amazon Associate. It's unverified whether the API's current terms allow this.
