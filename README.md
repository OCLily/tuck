# Tuck

A native iOS app that locks the apps you pick (suggestions include social media) for at least 30 minutes after the morning alarm and shows a calm good-morning screen instead. An optional bedtime window (60 minutes centred on a set bedtime, free during the 14-day trial and paid afterwards) works on the same mechanism with its own shield screen.

## Status

Core flows implemented with automated tests; planned parts (snooze, app-side fallback, shield-action fail-open) not built; not verified on a real device. Never released.

- The working documents in `docs/` date from September 2026. The App Store submission items are still listed as open in `docs/SSOT.md`, section 7.
- The core flows are implemented and have automated tests. Snooze ("Mitschlummern") is designed but not built (`docs/SSOT.md`, section 3).
- Known gaps are listed in `docs/SSOT.md`, section 7: no app-side fallback if the DeviceActivity callback never fires, no fail-open in the shield action, and no full day on a real device yet (called the largest open risk there).
- The Screen Time APIs (Family Controls, DeviceActivity, ManagedSettings) cannot be exercised or verified in the simulator, and AlarmKit never authorizes there. The monitor and shield extensions are never launched there either: their shared logic is unit-tested, but nothing executes the extension entry points; their wiring is checked by source-text tests, and the built bundles' privacy manifests and localizations are checked.
- The planned next step was a real-device run ("Phase 0" in `docs/SSOT.md`, section 8).

## How it was built

Statements about the private history (here, tool use) come from the author's private repository and cannot be verified in this export. Outside `docs/`, the only full dates (year-month-day) in the tree are calendar and daylight-saving fixtures in the tests and the names of dated documents that comments refer to.

- Claude Code was the main implementation tool.
- Decisions and fixes are logged in `docs/audit-log.md`.
- The history was squashed for this export; the original commits are private.

## What this repository shows

- A multi-target SwiftUI app (main app, DeviceActivity monitor, shield and shield-action extensions) generated from `project.yml` with XcodeGen.
- Use of Screen Time APIs: Family Controls, DeviceActivity, ManagedSettings.
- StoreKit 2 subscriptions, Keychain storage, App Groups shared across targets, German and English localization.
- No third-party dependencies. No backend, no account, no own network layer. The only network traffic the app starts itself is StoreKit talking to Apple. The paywall also has two SwiftUI `Link` buttons (Apple's standard EULA and the privacy-policy placeholder); they open in the system browser only when tapped.
- Test volume: 75 app source files (about 11,000 physical lines, of which a third to two fifths are comments and blank lines) and 80 test files (about 14,000 physical lines, 750 `@Test` declarations). Counts taken from the source tree. The tests were not run for this export; `docs/SSOT.md`, section 3, records a full run of the same 750 tests with 0 failures in the private repository before the export edits. See the caveat below on what part of that is behavioural.
- Documented decisions: `docs/SSOT.md` (summary of the project state) and `docs/audit-log.md` (chronological log of fixes and decisions).

## What it does not show

- User traction, a store release, or behavior on real hardware.
- Behavioural coverage as large as the test count suggests: 35 of the 80 test files read repository source files (almost all of them Swift sources) as text via `#filePath` and assert on that text, for example wiring and containment checks. Several of these files also hold ordinary behaviour tests. One more test reads the checked-in icon PNG and one reads the built bundles' privacy manifests.
- A finished store listing: the privacy-policy link on the paywall is a placeholder (`example.com`, see `PaywallLegal` in `Tuck/PaywallView.swift`) and no policy page is hosted.

## Build

```sh
brew install xcodegen
xcodegen generate
open Tuck.xcodeproj
```

Needs an Xcode with the iOS 26.5 SDK (the deployment target is 26.5; `docs/build-plan-phase1.md` records Xcode 26.6). The build and the tests were not run for this export (identifiers were replaced). In the original setup the simulator ran the app and the tests, but not the Screen Time APIs, and AlarmKit never authorizes there. Running on a device needs a paid Apple developer account (App Groups, Family Controls capability); distributing the app additionally needs a Family Controls distribution entitlement for each of the four bundle IDs (`docs/SSOT.md`, section 5).

Before building with your own identity, change these placeholders:

- Team: `DEVELOPMENT_TEAM` (`YOUR_TEAM_ID`) in `project.yml`, set once per target.
- Bundle IDs: `bundleIdPrefix` and the four `PRODUCT_BUNDLE_IDENTIFIER` values in `project.yml` (`com.example.tuck*`). The test bundle takes its ID (`com.example.TuckTests`) from `bundleIdPrefix`.
- App Group `group.com.example.tuck`: in the four `*.entitlements` files and in `Shared/TuckIdentifiers.swift`. Two tests pin this literal (`TuckTests/AppGroupHealthTests.swift`, `TuckTests/OnboardingCompletionStorageTests.swift`) and fail until they are updated. Without a provisioned App Group the stores would fall back to the app's own defaults and the extensions would never see the app's state; Debug builds therefore stop at launch with an explanatory `fatalError`, and Release builds show a shared-storage status instead of claiming a block window.
- StoreKit product IDs `com.example.tuck.plus.monthly` and `com.example.tuck.plus.yearly`: in `Tuck.storekit` and `Shared/SubscriptionTier.swift`.
- Optional: the Keychain service name `com.example.tuck.device-identity` in `Tuck/DeviceIdentity.swift` uses the same prefix.

Tests: `scripts/test.sh` (iOS 26.5 simulator, iPhone 17).

Folders: `Tuck/` (app), `Shared/` (code shared by the targets), `TuckMonitor/` (DeviceActivity monitor extension), `TuckShield/` and `TuckShieldAction/` (shield and shield-action extensions), `TuckTests/`, `tools/` (icon and shield artwork rendering scripts), `docs/`. Code comments are English; a few German comments remain.

## Note on the documents

`docs/` contains working documents written in German during development. Some are stale: `docs/SSOT.md` records the project state at the time it was written, and later changes are not reflected in it. Some documents mention working files that are not part of this export, without a link target (such as the original spec, review notes, plans, research notes, store drafts, the design handoff and the mascot artwork); in some Swift comments a reference of that kind was removed instead. See `docs/README.md` for the entry points and for how these mentions are marked.

## License

MIT, see `LICENSE`.
