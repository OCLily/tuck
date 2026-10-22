@preconcurrency import DeviceActivity
import Foundation
@preconcurrency import ManagedSettings

enum TuckIdentifiers {
    static let appGroupSuiteName = "group.com.example.tuck"
    static let familyActivitySelectionDefaultsKey = "familyActivitySelectionData"

    // The one question the `UserDefaults(suiteName:) ?? .standard` fallback at twenty-two call
    // sites cannot answer for itself. Without the provisioned group that initialiser still hands
    // back a usable suite — a private per-app plist — so every store writes, reads back what it
    // wrote, and the app looks perfect while no extension ever sees a single value: no window is
    // armed, no shield goes up, no morning is counted from the intent's process.
    // The container URL is the same probe UnlockQuotaStore already uses to place its lock file;
    // there it only picks a fallback directory, here it is the diagnosis itself.
    static var appGroupIsProvisioned: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupSuiteName) != nil
    }

    // The same suite and the same fallback every store reaches for, named once so the @AppStorage
    // properties that need a `store:` argument cannot each name their own container: three views
    // holding one key have to be holding one container, or the onboarding state drifts between them.
    // Computed rather than a stored static, like the `defaults` in every store: UserDefaults is not
    // Sendable, so a `static let` is a concurrency error under Swift 6. Separate instances of the
    // same suite address the same container.
    nonisolated static var appGroupDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupSuiteName) ?? .standard
    }

    // Shared/SharedCopy.xcstrings, shipped into the app bundle and into both shield bundles. The
    // copy the shield and the app must state identically is looked up in this one table
    // instead of in each target's own Localizable.xcstrings, where two entries could drift apart.
    // The lookups themselves pass the name as a literal — see ShieldCopy — so this constant is for
    // the tests that read the table back out of the built bundles.
    static let sharedCopyTable = "SharedCopy"
}

extension ManagedSettingsStore.Name {
    static let morningBlock = Self("morningBlock")
    static let bedtimeBlock = Self("bedtimeBlock")
}

extension DeviceActivityName {
    static let morningBlock = Self("morningBlock")
    static let bedtimeBlock = Self("bedtimeBlock")
}

extension DeviceActivityEvent.Name {
    static let screenTimeInWindow = Self("screenTimeInWindow")
}
