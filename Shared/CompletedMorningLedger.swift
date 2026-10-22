import Foundation

// Until this file existed,
// StopWakeAlarmIntent.perform() was the ONLY place a morning was ever counted — and that intent is
// AlarmKit's stop callback, which is reported not to be delivered when the alarm is dismissed on an
// already-unlocked screen or when the Live Activity is swiped away. For a user who is awake before
// the alarm rings, the mascot would then never grow: a silent failure of the entire retention
// promise, on the one screen they look at every day.
//
// So there are two paths now, and exactly one gate between them. Both ask the same question — which
// morning occurrence does this moment belong to — and both answer it against the same stored anchor,
// so whichever arrives first counts and the other one finds the morning already claimed. The anchor
// is a real Date, the most recent occurrence of the block window's start at or before the moment,
// which is what makes it correct for a window that wraps past midnight; the same anchor
// WakeAlarmStore.isFirstDismissal already compares two dismissals with.
//
// Same idea as UnlockQuotaStore's quotaAnchorDay — one derived day key, claimed once — and
// deliberately NOT the same key. The quota's day may not be movable by the wake-time picker,
// because moving it hands out unlocks; the streak's may, because the worst it does is count a
// morning twice, which is the "over-count rather than under-count" side of never punishing.
//
// App target only, like MorningProgressStore and MilestoneStore, which it writes: no extension
// counts a morning, and the intent runs in the app process.
enum CompletedMorningLedger {
    private static let countedAnchorKey = "lastCountedMorningAnchor"

    private nonisolated static var defaults: UserDefaults {
        UserDefaults(suiteName: TuckIdentifiers.appGroupSuiteName) ?? .standard
    }

    // The one definition of "which morning is this" both paths use. nil where the question cannot be
    // answered at all: no alarm stored, an uncomputable anchor, or an occurrence that has not
    // happened yet — an alarm set at 22:00 for 07:00 tomorrow has its most recent 07:00 in the past,
    // but that one belongs to a morning this alarm was never set for.
    nonisolated static func countableMorning(
        now: Date,
        calendar: Calendar = .current,
        in defaults: UserDefaults = Self.defaults
    ) -> Date? {
        guard let alarm = WakeAlarmStore.scheduledAlarm(in: defaults),
              let anchor = MorningBlockWindow.mostRecentStart(
                  of: alarm.blockWindowStart,
                  atOrBefore: now,
                  calendar: calendar
              ),
              anchor >= alarm.fireDate
        else { return nil }
        return anchor
    }

    nonisolated static func lastCountedMorning(in defaults: UserDefaults = Self.defaults) -> Date? {
        defaults.object(forKey: countedAnchorKey) as? Date
    }

    // Path one: the alarm's stop intent. Keeps its own delivery guard — the intent can be delivered
    // more than once for one ringing — and adds the cross-path claim on top of it.
    @discardableResult
    nonisolated static func recordAlarmDismissal(
        at date: Date = .now,
        calendar: Calendar = .current,
        in defaults: UserDefaults = Self.defaults
    ) -> Bool {
        let anchor = countableMorning(now: date, calendar: calendar, in: defaults)
        // Must be read before recordDismissal overwrites the value it compares against.
        let isFirstDelivery = WakeAlarmStore.isFirstDismissal(
            ofMorningContaining: date,
            calendar: calendar,
            in: defaults
        )
        WakeAlarmStore.recordDismissal(at: date, in: defaults)

        // Both are evaluated, neither is short-circuited: the claim has to be written even when the
        // delivery guard already refused, or an upgrade that lands mid-morning — dismissal recorded
        // by the old build, ledger still empty — would leave this morning unclaimed for path two to
        // count a second time.
        let claimed = claim(anchor, in: defaults)
        guard isFirstDelivery, claimed else { return false }

        countMorning(in: defaults)
        return true
    }

    // Path two: the app comes to the front after an occurrence that has rung. No `dismissedAt`
    // condition of its own — the claim above is the authority on whether this morning was counted,
    // and a dismissal that did not reach the ledger did not count anything either.
    //
    // Deliberately not gated on the window still running, and deliberately not backfilled: someone
    // who opens the app at noon gets the morning that rang that day, and someone who was away for a
    // week gets one morning, not seven. The alarm rang and the window ran either way.
    @discardableResult
    nonisolated static func recordForegroundEntry(
        now: Date = .now,
        calendar: Calendar = .current,
        in defaults: UserDefaults = Self.defaults
    ) -> Bool {
        guard let anchor = countableMorning(now: now, calendar: calendar, in: defaults),
              claim(anchor, in: defaults)
        else { return false }

        countMorning(in: defaults)
        return true
    }

    // nil anchor claims nothing and refuses nothing: there is no morning to compare against, and
    // swallowing a real dismissal would be the one failure the never-punish principle rules out.
    // Reachable only from path one, which fires because an alarm actually rang.
    private nonisolated static func claim(_ anchor: Date?, in defaults: UserDefaults) -> Bool {
        guard let anchor else { return true }
        guard lastCountedMorning(in: defaults) != anchor else { return false }
        defaults.set(anchor, forKey: countedAnchorKey)
        return true
    }

    // Latches the milestone ratchet on the morning that earned it instead of on the next read: a
    // reward whose counter is lost before anyone looks would otherwise never have been reached at
    // all.
    private nonisolated static func countMorning(in defaults: UserDefaults) {
        MorningProgressStore.recordCompletedMorning(in: defaults)
        MilestoneStore.reachedMornings(in: defaults)
    }
}
