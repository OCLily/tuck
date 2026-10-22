import Foundation

// The streak, and only the streak (docs/product-decisions-2026-09-02.md). The unlock quota that
// used to live here is now UnlockQuotaStore.morning — it was structurally identical to the evening's
// down to two constants. Same App-Group suite either way, same container and same shape as
// WakeAlarmStore.
enum MorningProgressStore {
    private static let completedMorningsKey = "completedMornings"

    private nonisolated static var defaults: UserDefaults {
        UserDefaults(suiteName: TuckIdentifiers.appGroupSuiteName) ?? .standard
    }

    nonisolated static func completedMornings(in defaults: UserDefaults = Self.defaults) -> Int {
        defaults.integer(forKey: completedMorningsKey)
    }

    // A morning counts regardless of whether its unlocks were used — this only ever adds.
    // Deliberately does not touch the quota: the streak may be over-counted rather than
    // under-counted, the quota may not.
    nonisolated static func recordCompletedMorning(in defaults: UserDefaults = Self.defaults) {
        defaults.set(completedMornings(in: defaults) + 1, forKey: completedMorningsKey)
    }
}
