import Foundation

// The length of the morning window is the one part of it the user chooses — its start is the alarm
// and stays that way. Three fixed steps rather than a free number or a slider: every value has
// to clear the 30-minute product minimum MorningBlockWindow clamps to, and an open field would
// invite exactly the five-minute window that clamp exists to refuse.
enum MorningBlockDuration: Int, CaseIterable, Sendable {
    case thirty = 30
    case fortyFive = 45
    case sixty = 60

    var minutes: Int { rawValue }

    var duration: Duration { .seconds(minutes * 60) }

    var label: String { String(localized: "\(minutes) Minuten") }
}

// Same App-Group suite and the same injectable-defaults shape as WakeAlarmStore and BedtimeStore.
enum MorningBlockDurationStore {
    private static let selectedMinutesKey = "morningBlockDurationMinutes"

    private nonisolated static var defaults: UserDefaults {
        UserDefaults(suiteName: TuckIdentifiers.appGroupSuiteName) ?? .standard
    }

    // Falls back to .thirty for an absent key and for a number this build does not know. An install
    // from before this setting existed has no key and ran on 30 minutes, so "absent" has to resolve
    // to exactly what that install already did — nobody's mornings change without being asked.
    nonisolated static func selected(in defaults: UserDefaults = Self.defaults) -> MorningBlockDuration {
        MorningBlockDuration(rawValue: defaults.integer(forKey: selectedMinutesKey)) ?? .thirty
    }

    nonisolated static func store(_ duration: MorningBlockDuration, in defaults: UserDefaults = Self.defaults) {
        defaults.set(duration.rawValue, forKey: selectedMinutesKey)
    }
}
