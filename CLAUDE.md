# SuppTrack

iPhone + iPad SwiftUI app that tracks supplements and prescriptions. Spec: `docs/spec.md`. Plan: `tasks/todo.md`. Activity log: `docs/activity.md`.

## Commands
- Logic tests (fast, no simulator): `swift test --package-path Packages/SuppTrackCore`
- Regenerate the Xcode project after adding or removing files: `xcodegen`
- Build: `xcodebuild -project SuppTrack.xcodeproj -scheme SuppTrack -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath .build/DD build`
- App tests: same as Build, with `test` in place of `build`

## Conventions
- Logic goes in `Packages/SuppTrackCore` with tests. The app target holds only SwiftData models and views.
- Every major view gets a unique `.accessibilityIdentifier("<screen>-<element>")`.
- SwiftData models must be CloudKit-safe: every property is optional or has a default, with no unique constraints.
- Warning text starts "Commonly recommended:" or "Ask your doctor:". Never show a total as complete when an amount is unknown.
