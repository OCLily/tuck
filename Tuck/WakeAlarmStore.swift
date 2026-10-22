import Foundation

enum WakeAlarmStore {
    struct ScheduledAlarm {
        let id: UUID
        let fireDate: Date
        let blockWindowStart: DateComponents
        let blockWindowEnd: DateComponents
    }

    private static let alarmIDKey = "wakeAlarmID"
    private static let fireDateKey = "wakeAlarmFireDate"
    private static let windowStartKey = "morningBlockWindowStartSecondOfDay"
    private static let windowEndKey = "morningBlockWindowEndSecondOfDay"
    private static let dismissedAtKey = "wakeAlarmDismissedAt"
    private static let blockRegistrationKey = "morningBlockRegistrationSucceeded"

    // Morning state lives in the App-Group suite (docs/product-decisions-2026-09-02.md) so
    // the Shield-Action extension can read it once the entitlement lands. Without the
    // entitlement this is simply a private per-app container — NSUserDefaults documents nil only
    // for the bundle identifier and NSGlobalDomain, not for an unentitled group — so the switch
    // is safe today and becomes cross-process later without further code changes.
    private nonisolated static var defaults: UserDefaults {
        UserDefaults(suiteName: TuckIdentifiers.appGroupSuiteName) ?? .standard
    }

    static func store(id: UUID, fireDate: Date, window: MorningBlockWindow, in defaults: UserDefaults = Self.defaults) {
        defaults.set(id.uuidString, forKey: alarmIDKey)
        defaults.set(fireDate, forKey: fireDateKey)
        defaults.set(secondOfDay(window.start), forKey: windowStartKey)
        defaults.set(secondOfDay(window.end), forKey: windowEndKey)
        defaults.removeObject(forKey: dismissedAtKey)
        // A newly stored window is unregistered until proven otherwise — without this reset the
        // previous window's successful registration would vouch for this one.
        defaults.set(false, forKey: blockRegistrationKey)
    }

    // The duration setting replaces the window of an alarm that itself stays where it is, so this
    // writes the two ends and the registration flag and nothing else. Deliberately not
    // store(id:fireDate:window:): that one also clears dismissedAt, and losing the dismissal anchor
    // mid-morning makes isFirstDismissal count the same morning a second time.
    static func updateBlockWindow(_ window: MorningBlockWindow, in defaults: UserDefaults = Self.defaults) {
        defaults.set(secondOfDay(window.start), forKey: windowStartKey)
        defaults.set(secondOfDay(window.end), forKey: windowEndKey)
        defaults.set(false, forKey: blockRegistrationKey)
    }

    static func clear(in defaults: UserDefaults = Self.defaults) {
        defaults.removeObject(forKey: alarmIDKey)
        defaults.removeObject(forKey: fireDateKey)
        defaults.removeObject(forKey: windowStartKey)
        defaults.removeObject(forKey: windowEndKey)
        defaults.removeObject(forKey: dismissedAtKey)
        defaults.removeObject(forKey: blockRegistrationKey)
    }

    // Whether the DeviceActivity registration for the stored window actually went through. The
    // stored window only proves the user's intent: a MonitoringError is transient in the setup
    // sheet but outlives it in the store, and every later relaunch would otherwise show the calm
    // "Sperrfenster bis HH:MM" for a window nothing is monitoring.
    nonisolated static func blockRegistrationSucceeded(in defaults: UserDefaults = Self.defaults) -> Bool {
        defaults.bool(forKey: blockRegistrationKey)
    }

    nonisolated static func recordBlockRegistration(succeeded: Bool, in defaults: UserDefaults = Self.defaults) {
        defaults.set(succeeded, forKey: blockRegistrationKey)
    }

    nonisolated static func scheduledAlarm(in defaults: UserDefaults = Self.defaults) -> ScheduledAlarm? {
        guard let idString = defaults.string(forKey: alarmIDKey),
              let id = UUID(uuidString: idString),
              let fireDate = defaults.object(forKey: fireDateKey) as? Date,
              defaults.object(forKey: windowStartKey) != nil,
              defaults.object(forKey: windowEndKey) != nil
        else { return nil }

        return ScheduledAlarm(
            id: id,
            fireDate: fireDate,
            blockWindowStart: timeComponents(defaults.integer(forKey: windowStartKey)),
            blockWindowEnd: timeComponents(defaults.integer(forKey: windowEndKey))
        )
    }

    nonisolated static func dismissedAt(in defaults: UserDefaults = Self.defaults) -> Date? {
        defaults.object(forKey: dismissedAtKey) as? Date
    }

    nonisolated static func recordDismissal(at date: Date, in defaults: UserDefaults = Self.defaults) {
        defaults.set(date, forKey: dismissedAtKey)
    }

    // Idempotency for the streak: the stop intent can be delivered more than once for one ringing
    // (system retry, duplicate delivery, a future snooze path), and each delivery would otherwise
    // count another morning. A dismissal that falls into the same block-window occurrence as the
    // previously recorded one is the same morning.
    // Falls back to "first" when there is nothing to compare against (no earlier dismissal, no
    // scheduled window, uncomputable anchor) — that keeps a real morning from being dropped.
    // Must be read before recordDismissal(at:) overwrites the previous value.
    // Known, accepted hole: rescheduling between two deliveries of the same morning runs
    // clear()/store(), both of which remove dismissedAtKey, so the anchor comparison never runs
    // and that morning is counted twice. Over-counting, never under-counting — the "never
    // punish" side. Pinned by wakeTimeChangedBetweenDuplicateDeliveriesCountsTheMorningTwice.
    // Acceptable only because this gate no longer reaches the unlock quota: the quota resets off
    // a calendar day nothing here can move (UnlockQuotaStore.quotaAnchorDay). Anything the
    // user can edit must stay on the streak side of that line.
    nonisolated static func isFirstDismissal(
        ofMorningContaining date: Date,
        calendar: Calendar = .current,
        in defaults: UserDefaults = Self.defaults
    ) -> Bool {
        guard let previous = dismissedAt(in: defaults),
              let windowStart = scheduledAlarm(in: defaults)?.blockWindowStart,
              let anchor = MorningBlockWindow.mostRecentStart(of: windowStart, atOrBefore: date, calendar: calendar),
              let previousAnchor = MorningBlockWindow.mostRecentStart(of: windowStart, atOrBefore: previous, calendar: calendar)
        else { return true }

        return anchor != previousAnchor
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
