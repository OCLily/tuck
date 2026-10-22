import Foundation

// Same shape and same App-Group suite as WakeAlarmStore, second-of-day integers rather than Dates:
// the bedtime is a time of day, not a moment, and nothing here should drift with the calendar day
// it was written on.
enum BedtimeStore {
    struct Bedtime {
        let time: DateComponents
        let blockWindowStart: DateComponents
        let blockWindowEnd: DateComponents
    }

    private static let bedtimeKey = "bedtimeSecondOfDay"
    private static let windowStartKey = "bedtimeBlockWindowStartSecondOfDay"
    private static let windowEndKey = "bedtimeBlockWindowEndSecondOfDay"
    private static let blockRegistrationKey = "bedtimeBlockRegistrationSucceeded"
    // The evening's substitute for the morning's fireDate. Without it an occurrence from before the
    // window was ever registered is askable: a bedtime stored at 23:00 for 22:00 has its most recent
    // 22:00 in the past, and auditing that one would report a missing callback for an occurrence
    // nothing was monitoring.
    private static let blockRegisteredAtKey = "bedtimeBlockRegisteredAt"

    private nonisolated static var defaults: UserDefaults {
        UserDefaults(suiteName: TuckIdentifiers.appGroupSuiteName) ?? .standard
    }

    static func store(
        bedtime: Date,
        window: MorningBlockWindow,
        calendar: Calendar = .current,
        in defaults: UserDefaults = Self.defaults
    ) {
        let components = calendar.dateComponents([.hour, .minute, .second], from: bedtime)
        defaults.set(secondOfDay(components), forKey: bedtimeKey)
        defaults.set(secondOfDay(window.start), forKey: windowStartKey)
        defaults.set(secondOfDay(window.end), forKey: windowEndKey)
        // A newly stored window is unregistered until proven otherwise — without this reset the
        // previous window's successful registration would vouch for this one.
        defaults.set(false, forKey: blockRegistrationKey)
    }

    static func clear(in defaults: UserDefaults = Self.defaults) {
        defaults.removeObject(forKey: bedtimeKey)
        defaults.removeObject(forKey: windowStartKey)
        defaults.removeObject(forKey: windowEndKey)
        defaults.removeObject(forKey: blockRegistrationKey)
        defaults.removeObject(forKey: blockRegisteredAtKey)
    }

    // Same seam as WakeAlarmStore.blockRegistrationSucceeded: the stored bedtime is the user's
    // intent, this is whether DeviceActivity accepted the window it produced.
    nonisolated static func blockRegistrationSucceeded(in defaults: UserDefaults = Self.defaults) -> Bool {
        defaults.bool(forKey: blockRegistrationKey)
    }

    // The timestamp is written here and nowhere else: a second writer is how the flag and the moment
    // it was set start disagreeing. A failed registration removes it — an unregistered window has no
    // moment from which its occurrences could be countable.
    nonisolated static func recordBlockRegistration(
        succeeded: Bool,
        at date: Date = .now,
        in defaults: UserDefaults = Self.defaults
    ) {
        defaults.set(succeeded, forKey: blockRegistrationKey)
        if succeeded {
            defaults.set(date, forKey: blockRegisteredAtKey)
        } else {
            defaults.removeObject(forKey: blockRegisteredAtKey)
        }
    }

    nonisolated static func blockRegisteredAt(in defaults: UserDefaults = Self.defaults) -> Date? {
        defaults.object(forKey: blockRegisteredAtKey) as? Date
    }

    // The evening's counterpart to CompletedMorningLedger.countableMorning, and it counts nothing
    // and claims nothing: the bedtime stays out of the mascot's growth entirely. All it answers
    // is which occurrence a moment belongs to, for the audit to ask about.
    nonisolated static func countableOccurrence(
        now: Date,
        calendar: Calendar = .current,
        in defaults: UserDefaults = Self.defaults
    ) -> Date? {
        guard let bedtime = bedtime(in: defaults),
              blockRegistrationSucceeded(in: defaults),
              let registeredAt = blockRegisteredAt(in: defaults),
              let anchor = MorningBlockWindow.mostRecentStart(
                  of: bedtime.blockWindowStart,
                  atOrBefore: now,
                  calendar: calendar
              ),
              anchor >= registeredAt
        else { return nil }
        return anchor
    }

    nonisolated static func bedtime(in defaults: UserDefaults = Self.defaults) -> Bedtime? {
        guard defaults.object(forKey: bedtimeKey) != nil,
              defaults.object(forKey: windowStartKey) != nil,
              defaults.object(forKey: windowEndKey) != nil
        else { return nil }

        return Bedtime(
            time: timeComponents(defaults.integer(forKey: bedtimeKey)),
            blockWindowStart: timeComponents(defaults.integer(forKey: windowStartKey)),
            blockWindowEnd: timeComponents(defaults.integer(forKey: windowEndKey))
        )
    }

    private static func secondOfDay(_ components: DateComponents) -> Int {
        (components.hour ?? 0) * 3600 + (components.minute ?? 0) * 60 + (components.second ?? 0)
    }

    private static func timeComponents(_ secondOfDay: Int) -> DateComponents {
        DateComponents(
            hour: secondOfDay / 3600,
            minute: (secondOfDay % 3600) / 60,
            second: secondOfDay % 60
        )
    }
}
