# Activity Log

## 2026-11-18: Planning session (Plan and Design stages)

**Prompt 1:** "using the ai sdlc at https://claude.com/resources/articles/the-ai-native-sdlc-playbook. i'm building a ios app. here is my idea: I need a way to track supplements and find out if there's overlap and which ones need to be taken in the morning or the PM for effectiveness or their intended use. Describe your scenario. I have many bottles of supplements, and I'd like to be able to scan the barcode and have that UPC code looked up and find the ingredients."
- Read the AI-native SDLC playbook. Its six stages are Plan → Design → Build → Test → Deploy → Maintain, with artifacts `intent.md` → `spec.md` → `plan.md`.
- Inspected the repo: it was empty, with remote `origin` on GitHub. Found that Xcode wasn't the active developer tool.

**Prompt 2:** "I am installed/updating to the latest xcode standby"
- Gave the `xcode-select` command.

**Prompt 3 (terminal):** `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
- Verified Xcode 27.2 is active. No iOS simulator runtime was installed.

**Prompt 4 (terminal):** `xcodebuild -downloadPlatform iOS`
- The iOS 27.2 Simulator download (8.32 GB) started.

**Prompt 5:** "checking which supplements overlap and which to take morning or night"

**Prompt 6:** "show total magnesium and warn if it's too much"
- Proposed NIH upper limits as the "too much" line.

**Prompt 7:** "just me for now"
- Single user, data on the phone, no App Store.

**Prompt 8:** "my AM supplements to take and checkboxes"

**Prompt 9:** "yes show me mockups"
- Started the brainstorm mockup server. Showed 3 Today-screen layouts (A simple list, B AM/PM switch, C timeline) in `.superpowers/brainstorm/`.

**Prompt 10:** "A with the AM/PM toggle from B. also need to consider this: what is the recommended practice for taking prescription and vitamins/supplements. How far apart do these need to be taken? Disclaimer: this is not medical advice. One should consult with a nutritionally informed physician."
- Built mockup v2 (A plus the AM/PM switch, a sample Rx, an "after 10:30 AM" spacing hint, and the disclaimer).
- Explained absorption conflicts (spacing helps) versus effect conflicts (spacing doesn't help).

**Prompt 11:** "yes, track prescriptions too"
- Played back the full concept.

**Prompt 12:** "looks right, write the plan. Also consider that some proprietary blends may not list the amount of each ingredient."
- Verified live: NIH DSLD finds products by UPC when the code is written in spaced form (`"0 31604 02616 5"`). Blends have a total amount, and their member ingredients are marked `NP` (not provided). Open Food Facts works as a name fallback. RxNorm `drugs.json` works with no key.
- Wrote `docs/intent.md` and `docs/spec.md`.

**Prompt 13:** "So on Friday, I went to GNC and I took 4 bags of supplements, and they identified that 3 bags of supplements should no longer be taken once they are finished. So what I'd like to do is find, when there's a multitude of supplements, to find out what's a more cost-effective way of getting the equivalent supplementation."
- Proposed cost per day, a "finish, then stop" flag, a "paying twice" check, and replacement suggestions.

**Prompt 14:** "I would like to also have integration with the Apple Health medications reminders, and I would like to have this also work on an iPad and watchOS, so 3 target platforms: iPhone, iPad, and watchOS."
- Proposed: Health keeps the reminders, SuppTrack imports from it, sync goes through iCloud, and the work is split into two phases.

**Prompt 15:** "Use Amazon.com for general product pricing, GNC for GNC specific pricing, consider iHerb.com."
- No public price APIs exist for GNC or iHerb, and Amazon's requires an Associates account. Decided on store search links plus prices Nick enters, with no scraping.

**Prompt 16:** "no, I don't have a paid developer membership, but I am willing to get one."
- Verified in Apple's docs that the HealthKit Medications API (iOS/iPadOS/watchOS 26+) is read-only.
- Updated the spec: phases, Health import, iCloud sync, a minimum of iOS 26, and Phase 2 outlines for the Watch and cost features.
- Ran an independent builder review of the spec.
- Sorted the builder questions (AM+PM doses, Health merge, age group, spacing direction) into spec section 11 as Claude's calls.
- Wrote `tasks/todo.md`: the Phase 1 plan, with 10 tasks.
- Committed and pushed planning docs.

**Prompt 17:** "control my browser and fix the gh auth login"
- Found that the saved gh token had become a fine-grained PAT without push rights (403). Ran `gh auth setup-git` and started `gh auth login --web`.

**Prompt 18:** "Done, test it"
- The login was still waiting for Enter, so the push was still refused.

**Prompt 19:** "Pressed Enter"
- gh login completed with a standard OAuth token (repo scope). The push test passed.

**Prompt 20:** "Approve, build it"
- Build started on branch `phase-1`. Created the SuppTrackCore Swift package (AgeGroup).
- Task 2: barcode normalization (UPC/EAN to the DSLD spaced form) and the DSLD label parser, including proprietary blends (members with "not provided" amounts become unknown). 12 tests pass.
- Task 3: unit conversion (mg/mcg/g, IU for vitamins A/D/E), the adult upper-limit table with the age-based calcium limit, and the overlap calculator (over limit, unknown amounts from blends, shared under limit, missing ingredients). 22 tests pass.
- Task 4: default AM/PM slot and how-to-take notes, prescription spacing rules (thyroid, antibiotics, osteoporosis drugs), the iron/calcium 2-hour rule, and "Ask your doctor" flags (warfarin, St. John's wort). 40 tests pass.
- Task 5: LookupClient for NIH DSLD (barcode lookup choosing the newest matching label, name search), Open Food Facts (product-name fallback) and RxNorm (prescription search, SCD/SBD only). Errors: bad barcode, network, server status. 49 tests pass.
- Task 1: XcodeGen project (universal iPhone + iPad, iOS 26), app shell with Today / Scan / My Bottles tabs, first-launch disclaimer with an age-group picker, a Settings screen, and a repo CLAUDE.md. Built and launched in the iPhone 17 simulator.
- Task 6: SwiftData models (Item with AM/PM servings and JSON ingredients, DoseLog), an app test target, FindingText warning wording in Core, and the My Bottles list/detail (split view on iPad), manual entry, and delete (hides Health imports). Checked in the simulator: Magnesium 400 mg defaults to night and shows the over-limit warning.
- Task 7: Scan tab: camera barcode scanner (VisionKit, hidden in the simulator), typed barcode, name search, the lookup chain (NIH by barcode, then Open Food Facts name to NIH search, then manual entry), the confirm screen (prefilled AM/PM, moved away from a conflicting Rx), and prescription search (RxNorm, with "Ask your doctor" alert). Verified live in the simulator: 031604026165 found Nature Made CoQ10 200 mg; an unknown code fell through to "Add by hand"; levothyroxine search listed tablets. Rx results are now sorted by name. 55 Core tests pass.
- Task 8: Today screen (AM/PM switch defaulting by time of day, warning banners for overlaps and doctor flags, a checkbox per item with an Rx tag, dose and note, a dashed box plus "after HH:MM · N hrs after X" for spacing, disclaimer footer). TodayModel has 6 tests (noon switch, midnight reset, AM+PM independence, levothyroxine timing, hidden/inactive, no hint once checked). Verified in the simulator: checking levothyroxine set the multivitamin to "after" 4 hours later.
- Final review by an independent reviewer: fixed Today keeping yesterday's checks after midnight, the Open Food Facts 404 shown as "service down", false Calories/CFU warnings plus "can't total (unit X)" wording, doctor flags missing from My Bottles, rescanning the same barcode, folic acid/folate not totalled together, and "at least" for totals with unknown parts. 63 Core + 10 app tests pass. Filled in the Review section of tasks/todo.md.
