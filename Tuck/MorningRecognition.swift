import Foundation

// App-target only for now — no extension reads it, so it stays out of Shared/ and out of
// project.yml. Move it once one does.
enum MorningRecognition {
    enum Kind: Hashable { case sameMorning, nextMorning, afterGap }

    private static let lastSeenKey = "lastSeenMorningAnchor"

    private nonisolated static var defaults: UserDefaults {
        UserDefaults(suiteName: TuckIdentifiers.appGroupSuiteName) ?? .standard
    }

    @discardableResult
    nonisolated static func check(now: Date,
                                  alarm: WakeAlarmStore.ScheduledAlarm?,
                                  calendar: Calendar = .current,
                                  in defaults: UserDefaults = Self.defaults) -> Kind {
        let startComponents = alarm?.blockWindowStart ?? DateComponents(hour: 0, minute: 0, second: 0)
        guard let anchor = MorningBlockWindow.mostRecentStart(of: startComponents,
                                                             atOrBefore: now,
                                                             calendar: calendar)
        else { return .nextMorning }

        let previous = defaults.object(forKey: lastSeenKey) as? Date
        defaults.set(anchor, forKey: lastSeenKey)

        guard let previous else { return .nextMorning }
        if previous == anchor { return .sameMorning }
        let days = calendar.dateComponents([.day], from: previous, to: anchor).day ?? 1
        return days >= 3 ? .afterGap : .nextMorning
    }
}
