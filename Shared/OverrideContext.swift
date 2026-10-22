import Foundation
import ManagedSettings

// Which window an override session belongs to. Same philosophy either way — delay plus
// justification — only the quota differs (the evening has its own, smaller one).
//
// Shared rather than app-local: the shield-configuration extension has to answer
// the same question before it can tell whether the quota it should report on is the morning's or
// the evening's. `unlock()` deliberately stayed in the app target — it spends the quota and
// clears a ManagedSettings store through ShieldRelease, which the shield-configuration extension
// neither compiles (project.yml lists ShieldRelease.swift for Tuck and TuckMonitor only) nor may
// do: an extension that only draws the block screen must not book anybody's override.
enum OverrideContext: Equatable, Sendable {
    case morning
    case bedtime

    // The one override button routes itself: inside the bedtime window it spends the evening
    // quota, everywhere else the morning one — including outside every window, which the shield's
    // manual open can reach. Asks whether `now` actually falls in [start, end) rather than
    // measuring from the most recent start: the anchor version read the stored window start, and
    // that start moves with every edit of the bedtime picker.
    static func current(
        now: Date = .now,
        calendar: Calendar = .current,
        in defaults: UserDefaults = UserDefaults(suiteName: TuckIdentifiers.appGroupSuiteName) ?? .standard
    ) -> OverrideContext {
        guard let bedtime = BedtimeStore.bedtime(in: defaults),
              MorningBlockWindow(start: bedtime.blockWindowStart, end: bedtime.blockWindowEnd)
                  .contains(now, calendar: calendar)
        else { return .morning }

        return .bedtime
    }

    var quota: UnlockQuotaStore {
        switch self {
        case .morning: .morning
        case .bedtime: .bedtime
        }
    }

    // The same two names BlockWindowMonitor registers under and the Monitor extension shields.
    var shieldStoreName: ManagedSettingsStore.Name {
        switch self {
        case .morning: .morningBlock
        case .bedtime: .bedtimeBlock
        }
    }
}
