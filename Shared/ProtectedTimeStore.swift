import Foundation

// What the APP has done, never what the user has been like: the sum of the block-window time that
// was registered and ran all the way through. Deliberately not "blocked screen time" — a
// ManagedSettings write is silent and non-throwing, so nothing here may claim a shield ever stood
// (see docs/design/design-system.md), and how much screen time would have happened without the window
// is a counterfactual nobody has.
//
// Exactly two keys, and that is the mechanism rather than a rule: with no day, week, history or
// anchor key there is no time-range API to derive a comparison from — a comparison is not forbidden
// here, it is inexpressible. Pinned by ProtectedTimeStoreTests.theSuiteCarriesExactlyTheseTwoKeys.
//
// The parallel to MorningProgressStore is on purpose and stops at the shape: that one counts the
// user's mornings and feeds MilestoneStore, this one counts the app's windows and feeds nothing.
// Nothing here may reach MascotMilestone, no milestone may read this value and no bubble may
// mention it — a number that unlocks something is a goal, and this one has none. That is a review
// rule and this comment, not a test: everything in the app target is module-wide visible.
//
// Unlocks change nothing (a fixed product decision): every registered window that ran through counts,
// whether or not it was unlocked. Same line as the mornings counter's own footer, "Jeder
// abgeschlossene Morgen zählt, auch die mit einer Freischaltung." A counter that reacts to unlock
// behaviour would be a judgement of the user again, which the never-punish principle refuses.
enum ProtectedTimeStore {
    private static let totalKey = "protectedSecondsTotal"
    private static let countedThroughKey = "protectedTimeCountedThrough"
    private static let clockJumpTolerance: TimeInterval = 24 * 60 * 60

    private nonisolated static var defaults: UserDefaults {
        UserDefaults(suiteName: TuckIdentifiers.appGroupSuiteName) ?? .standard
    }

    // Read and write in one function, like UnlockQuotaStore's lazy refill and for the same reason:
    // the evening has no user action to hang a callback on, and the one system callback that knows
    // about a window's end comes from the monitor extension, where counting is forbidden. So the
    // accrual is computed on read — and, because a window can change under it, also right before
    // every mutation of a window. Idempotent, so an extra call is a no-op and never a second entry.
    //
    // The one rule every call site follows: only a span whose registration demonstrably stayed
    // alive throughout is credited. Where that is doubtful the span is skipped, but countedThrough
    // moves past it anyway. Under-count rather than over-count — the same direction as the claim
    // at the top of this file.
    //
    // Only the app process writes here, all on the MainActor, so no lock is needed today. The
    // read-modify-write still lives in one function so it cannot lose that unnoticed; if this ever
    // moves into an extension a lock becomes mandatory (UnlockQuotaStore.withQuotaLock is the
    // reusable shape, private today).
    @discardableResult
    nonisolated static func accrue(
        now: Date = .now,
        calendar: Calendar = .current,
        in defaults: UserDefaults = Self.defaults
    ) -> Int {
        let total = defaults.integer(forKey: totalKey)

        // First run ever: anchor and nothing else. Time before the first pass is never counted,
        // because nothing here knows whether a window was registered back then.
        guard let countedThrough = defaults.object(forKey: countedThroughKey) as? Date else {
            defaults.set(now, forKey: countedThroughKey)
            return total
        }

        // An anchor that far ahead cannot have been written by a clock this one shares: a device
        // set a year forward once, then set back, used to leave countedThrough a year in the future
        // and every later pass a no-op — the counter frozen for good, with no path back. The two
        // one legitimate way the anchor gets ahead of `now` stays well inside a day:
        // skipRunningOccurrence books it to the end of the running occurrence, hours away at most.
        // (A time-zone change is not one of them — both values are absolute instants.) Beyond a
        // day, re-anchor on the clock that is actually running and credit nothing for the jump.
        //
        // The one place this file gives up its under-count discipline, deliberately: past the
        // tolerance, occurrences credited before the jump can be credited again after it. Bounded
        // by the size of the jump, reachable only by setting the clock by hand — against a counter
        // that was dead for a year with no way back. Strict monotonicity here would need a third
        // key, which is the one thing this store may not have.
        if countedThrough > now.addingTimeInterval(clockJumpTolerance) {
            defaults.set(now, forKey: countedThroughKey)
            return total
        }

        // Clock moved backwards (time zone, manual change), or the same frozen `now` arriving a
        // second time from reconcile()'s tail call: nothing happens, no negative difference, no
        // step back. The counter stays frozen until real time catches up with countedThrough —
        // that is the price of monotonicity, documented rather than repaired.
        guard now > countedThrough else { return total }

        var added = 0
        for armed in armedWindows(in: defaults, calendar: calendar) {
            added += Self.seconds(
                of: armed.window,
                endingIn: countedThrough,
                through: now,
                calendar: calendar,
                applies: armed.applies
            )
        }

        // Always, including for the windows this pass skipped and for the DST nil case. Without it a
        // window that is armed again later would be credited for the days it demonstrably was not.
        defaults.set(now, forKey: countedThroughKey)

        guard added > 0 else { return total }
        let updated = total + added
        defaults.set(updated, forKey: totalKey)
        return updated
    }

    // The second writer, and the only other one there will be. It never touches the sum: it moves
    // countedThrough forward and nothing else, so it is not a second read path.
    //
    // Why it exists: arming a window in the middle of its own running occurrence would have the
    // next accrual credit that occurrence with its full durationSeconds, although at most part of
    // it was monitored and often none. Bedtime set to 23:00 at 22:45, or the morning length changed
    // from 30 to 60 minutes at 07:45 — the new 07:00-08:00 window contains 07:45. The occurrence is
    // skipped whole rather than counted pro rata: this counter has no partial occurrences.
    //
    // Runs after accrue, never before. Before it, countedThrough would sit in the future and accrue
    // would be a no-op until `end` — the same frozen state a backwards clock produces.
    nonisolated static func skipRunningOccurrence(
        endingAt end: Date?,
        in defaults: UserDefaults = Self.defaults
    ) {
        guard let end else { return }
        if let countedThrough = defaults.object(forKey: countedThroughKey) as? Date, end <= countedThrough {
            return
        }
        defaults.set(end, forKey: countedThroughKey)
    }

    // Pure, reads nothing and writes nothing: the absolute end of the occurrence that is running at
    // `now`, or nil if the window is not running or the wall-clock start does not exist that day.
    // Both nil cases mean "do not write" — the DST one is the single place in this counter where an
    // over-count by one occurrence stays possible, and it costs less than a stuck counter.
    //
    // countedThrough is one key for both windows, so a skip can swallow an end of the OTHER window
    // that falls into (now, end] — only possible if morning and evening overlap, at most one
    // occurrence, in the intended direction. Named, not fixed: fixing it costs a third key.
    nonisolated static func runningOccurrenceEnd(
        of window: MorningBlockWindow,
        at now: Date,
        calendar: Calendar
    ) -> Date? {
        guard window.contains(now, calendar: calendar),
              let start = MorningBlockWindow.mostRecentStart(of: window.start, atOrBefore: now, calendar: calendar)
        else { return nil }
        return start.addingTimeInterval(TimeInterval(window.durationSeconds))
    }

    // A window that nothing monitors carried nothing, so the registration flag decides, not the
    // stored window. Both windows read out of the same injected suite as everything else.
    //
    // The registration flag alone is no longer the whole answer for the morning: the schedule is
    // registered on all seven days (DeviceActivitySchedule has no weekday parameter), and the
    // monitor extension lets the days nobody chose go by without shielding. Crediting them anyway
    // would give a Mo-Fr user roughly 29% protected time the app deliberately did not protect —
    // over-count, in the one direction this file says it never goes. Same decision function as the
    // monitor's guard, so the two cannot drift apart.
    //
    // The evening window has no weekday selection, so it applies on every day it is armed.
    private nonisolated static func armedWindows(
        in defaults: UserDefaults,
        calendar: Calendar
    ) -> [(window: MorningBlockWindow, applies: (Date) -> Bool)] {
        var windows: [(window: MorningBlockWindow, applies: (Date) -> Bool)] = []
        if let alarm = WakeAlarmStore.scheduledAlarm(in: defaults),
           WakeAlarmStore.blockRegistrationSucceeded(in: defaults) {
            windows.append((
                MorningBlockWindow(start: alarm.blockWindowStart, end: alarm.blockWindowEnd),
                { WakeAlarmWeekdayStore.morningBlockApplies(on: $0, calendar: calendar, in: defaults) }
            ))
        }
        if let bedtime = BedtimeStore.bedtime(in: defaults),
           BedtimeStore.blockRegistrationSucceeded(in: defaults) {
            windows.append((
                MorningBlockWindow(start: bedtime.blockWindowStart, end: bedtime.blockWindowEnd),
                { _ in true }
            ))
        }
        return windows
    }

    // Fully elapsed occurrences only, no partial pieces: the calendar-day distance between the most
    // recent window END at or before countedThrough and the most recent one at or before now.
    // mostRecentStart is built for exactly this question and stays correct for windows that wrap
    // past midnight, unlike comparing the bare time of day — applied to the end components here.
    //
    // nil from either call is the spring-forward hour, where that wall-clock time does not exist
    // that day: skip this window in this pass and credit nothing, but let the caller move
    // countedThrough anyway. An early return here would freeze the accrual permanently, because
    // countedThrough would never advance and every later pass would fail at the same place.
    //
    // The cost, measured: a window whose END falls into the spring-forward gap loses TWO occurrences
    // per year, not one — the anchor resolves forward on the transition day and back on the day
    // after, so neither day shows a distance of one. Under-count, the intended direction.
    private nonisolated static func seconds(
        of window: MorningBlockWindow,
        endingIn countedThrough: Date,
        through now: Date,
        calendar: Calendar,
        applies: (Date) -> Bool
    ) -> Int {
        guard let previous = MorningBlockWindow.mostRecentStart(
                  of: window.end, atOrBefore: countedThrough, calendar: calendar
              ),
              let latest = MorningBlockWindow.mostRecentStart(
                  of: window.end, atOrBefore: now, calendar: calendar
              )
        else { return 0 }

        let occurrences = max(0, calendar.dateComponents([.day], from: previous, to: latest).day ?? 0)

        // Walked one occurrence at a time rather than multiplied, because each one has to be asked
        // about its own weekday. The ends are the daily repeats of window.end between previous
        // (exclusive) and latest (inclusive); the day a window belongs to is the day it STARTS on,
        // which for a window that wraps past midnight is not the day it ends on.
        var seconds = 0
        for step in 0..<occurrences {
            guard let end = calendar.date(byAdding: .day, value: -step, to: latest) else { continue }
            if applies(end.addingTimeInterval(-TimeInterval(window.durationSeconds))) {
                seconds += window.durationSeconds
            }
        }
        return seconds
    }
}
