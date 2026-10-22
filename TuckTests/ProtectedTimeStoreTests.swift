import Foundation
import Testing
@testable import Tuck

struct ProtectedTimeStoreTests {
    // Throwaway suite per test, same shape as MilestoneStoreTests: nothing here may touch the
    // App-Group container the app actually uses.
    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suite = "ProtectedTimeStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        body(defaults)
    }

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int, month: Int = 6, year: Int = 2026) -> Date {
        Self.calendar.date(
            from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        )!
    }

    private func window(_ startHour: Int, _ startMinute: Int, _ endHour: Int, _ endMinute: Int) -> MorningBlockWindow {
        MorningBlockWindow(
            start: DateComponents(hour: startHour, minute: startMinute, second: 0),
            end: DateComponents(hour: endHour, minute: endMinute, second: 0)
        )
    }

    private func armMorning(_ window: MorningBlockWindow, succeeded: Bool = true, in defaults: UserDefaults) {
        WakeAlarmStore.store(id: UUID(), fireDate: date(1, 7, 0), window: window, in: defaults)
        WakeAlarmStore.recordBlockRegistration(succeeded: succeeded, in: defaults)
    }

    private func armBedtime(_ window: MorningBlockWindow, succeeded: Bool = true, in defaults: UserDefaults) {
        BedtimeStore.store(
            bedtime: date(1, 22, 30),
            window: window,
            calendar: Self.calendar,
            in: defaults
        )
        BedtimeStore.recordBlockRegistration(succeeded: succeeded, in: defaults)
    }

    @discardableResult
    private func accrue(_ now: Date, in defaults: UserDefaults) -> Int {
        ProtectedTimeStore.accrue(now: now, calendar: Self.calendar, in: defaults)
    }

    private func countedThrough(in defaults: UserDefaults) -> Date? {
        defaults.object(forKey: "protectedTimeCountedThrough") as? Date
    }

    // Same #filePath shape as TrialTriggerTests and MorningCelebrationWiringTests: a `@State`
    // initialiser only a constructed view runs, and this project has no view-inspection dependency.
    private func source(_ path: String) throws -> [String] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
        return try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n")
    }

    @Test func aFreshInstallOnlyAnchorsAndCountsNothing() {
        withDefaults { defaults in
            armMorning(window(7, 0, 7, 30), in: defaults)

            #expect(accrue(date(1, 9, 0), in: defaults) == 0)
            #expect(countedThrough(in: defaults) == date(1, 9, 0))
            #expect(defaults.object(forKey: "protectedSecondsTotal") == nil)
        }
    }

    @Test func anElapsedOccurrenceCountsInFullWhileARunningOneCountsNothing() {
        withDefaults { defaults in
            armMorning(window(7, 0, 7, 30), in: defaults)
            accrue(date(1, 6, 0), in: defaults)

            // 07:15 sits inside the occurrence: nothing has finished yet.
            #expect(accrue(date(1, 7, 15), in: defaults) == 0)
            // 08:00 is past its end, so the whole 30 minutes are credited at once.
            #expect(accrue(date(1, 8, 0), in: defaults) == 30 * 60)
        }
    }

    @Test func aWindowThatWrapsPastMidnightCountsItsThirtyMinutes() {
        withDefaults { defaults in
            armBedtime(window(23, 50, 0, 20), in: defaults)
            accrue(date(1, 23, 0), in: defaults)

            #expect(accrue(date(2, 0, 10), in: defaults) == 0)
            #expect(accrue(date(2, 0, 30), in: defaults) == 30 * 60)
        }
    }

    // Unchanged in substance, narrowed in range: a setback of hours still freezes the counter until
    // real time catches up. Only past a day does the clamp below take over.
    @Test func aClockThatMovesBackwardsWithinADayChangesNothingAndLeavesTheCounterFrozen() {
        withDefaults { defaults in
            armMorning(window(7, 0, 7, 30), in: defaults)
            accrue(date(1, 6, 0), in: defaults)
            #expect(accrue(date(5, 8, 0), in: defaults) == 5 * 30 * 60)

            // Clock set back: no negative difference, no step back, and countedThrough stays put.
            #expect(accrue(date(4, 20, 0), in: defaults) == 5 * 30 * 60)
            #expect(countedThrough(in: defaults) == date(5, 8, 0))

            // Frozen, not broken: every real pass is a no-op until real time catches up. The
            // occurrence in between is never credited — the documented price of monotonicity.
            #expect(accrue(date(5, 7, 0), in: defaults) == 5 * 30 * 60)
            #expect(countedThrough(in: defaults) == date(5, 8, 0))
            #expect(accrue(date(6, 8, 0), in: defaults) == 6 * 30 * 60)
        }
    }

    // The backwards-clock freeze above is bounded and documented; a clock set far into the future
    // was neither. It wrote an anchor a year ahead, and every later pass on the real clock failed
    // the `now > countedThrough` guard — the counter dead for a year, with nothing to bring it back.
    // A day of tolerance keeps the small legitimate lead skipRunningOccurrence writes.
    //
    // The price, named rather than hidden: past the tolerance the store gives up monotonicity, so
    // occurrences credited before the jump can be credited a second time after it. Bounded by the
    // size of the setback and only reachable by moving the clock by hand, against a counter that
    // was silently dead for as long as the jump lasted. A third key would buy the strict version
    // and is exactly what this store may not have (theSuiteCarriesExactlyTheTwoKeysOfThisStore).
    @Test func aClockSetAYearAheadReanchorsInsteadOfFreezingUntilThatYearArrives() {
        withDefaults { defaults in
            armMorning(window(7, 0, 7, 30), in: defaults)
            accrue(date(1, 6, 0), in: defaults)
            #expect(accrue(date(2, 8, 0), in: defaults) == 2 * 30 * 60)

            // Device clock set a year forward. What that pass credits is not the point here; the
            // anchor it leaves behind is.
            let afterJump = accrue(date(2, 8, 0, year: 2027), in: defaults)
            #expect(countedThrough(in: defaults) == date(2, 8, 0, year: 2027))

            // Clock set back to real time: the anchor comes with it, nothing is credited for the
            // jump, and the sum stands where it stood.
            #expect(accrue(date(3, 8, 0), in: defaults) == afterJump)
            #expect(countedThrough(in: defaults) == date(3, 8, 0))

            // The line the old version never reached: the next real occurrence counts again.
            #expect(accrue(date(4, 8, 0), in: defaults) == afterJump + 30 * 60)
        }
    }

    // The other side of the same tolerance: a lead of hours is what skipRunningOccurrence writes on
    // purpose, so it must still freeze the accrual until real time catches up rather than be read as
    // a clock jump and re-anchored — that would credit the occurrence the skip just excluded.
    @Test func anAnchorOnlyHoursAheadStaysUntouched() {
        withDefaults { defaults in
            armMorning(window(7, 0, 7, 30), in: defaults)
            accrue(date(1, 6, 0), in: defaults)
            ProtectedTimeStore.skipRunningOccurrence(endingAt: date(2, 7, 30), in: defaults)

            #expect(accrue(date(1, 20, 0), in: defaults) == 0)
            #expect(countedThrough(in: defaults) == date(2, 7, 30))
            #expect(accrue(date(2, 8, 0), in: defaults) == 0)
            #expect(accrue(date(3, 8, 0), in: defaults) == 30 * 60)
        }
    }

    // The property that makes six accrue call sites bearable: an extra call is a no-op, never a
    // second entry. The same-`now` case is also the test for reconcile()'s frozen clock, whose tail
    // call into applyPendingMorningDuration runs a second accrual with exactly that value.
    @Test func repeatedAccrualsCountEachOccurrenceExactlyOnce() {
        withDefaults { defaults in
            armMorning(window(7, 0, 7, 30), in: defaults)
            accrue(date(1, 6, 0), in: defaults)

            let now = date(1, 8, 0)
            #expect(accrue(now, in: defaults) == 30 * 60)
            #expect(accrue(now, in: defaults) == 30 * 60)
            #expect(accrue(now, in: defaults) == 30 * 60)

            // The real shape at the call sites: several passes in quick succession, each with a
            // clock that has moved by a hair.
            for second in 1...5 {
                #expect(accrue(now.addingTimeInterval(TimeInterval(second)), in: defaults) == 30 * 60)
            }
        }
    }

    // A deliberate decision rather than an oversight — the reasoning
    // sits on `SettingsView.protectedSeconds`, this is its evidence. That row reads the store from a
    // `@State` initialiser, and SwiftUI re-evaluates initialiser expressions on every reconstruction
    // of the struct, so this store is asked to settle up at moments nobody chose and far more often
    // than the sheet is opened. What makes that harmless is not how often it happens but the shape
    // of the write: `accrue` books the span that has elapsed and nothing else, where
    // `allowanceReachingTheCeiling` — the call that was moved out of an initialiser — starts a
    // fourteen-day clock whose FIRST caller fixes a date nobody can take back.
    //
    // Differential rather than absolute, because the failure has two directions: a burst of unchosen
    // reads across three occurrence ends has to land on exactly the sum one settled read produces.
    // Equality breaks from above if an extra pass credits a second time, and from below if a pass
    // moves the anchor past an occurrence without crediting it.
    @Test func aBurstOfUnchosenReadsLandsOnTheSameSumAsOneSettledRead() {
        let anchor = date(1, 6, 0)
        let end = date(4, 9, 0)

        var settled = 0
        withDefaults { defaults in
            armMorning(window(7, 0, 7, 30), in: defaults)
            accrue(anchor, in: defaults)
            settled = accrue(end, in: defaults)
        }

        var burst = 0
        withDefaults { defaults in
            armMorning(window(7, 0, 7, 30), in: defaults)
            accrue(anchor, in: defaults)
            // Every hour of the same three days: more reconstructions than a sheet ever sees, and
            // several of them land inside a running occurrence.
            for day in 1...4 {
                for hour in 0...23 {
                    let instant = date(day, hour, 0)
                    guard instant > anchor, instant <= end else { continue }
                    accrue(instant, in: defaults)
                }
            }
            burst = accrue(end, in: defaults)
        }

        #expect(settled == 4 * 30 * 60)
        #expect(burst == settled)
    }

    // The other half of the same decision: that the read is still where the reasoning says it is.
    // Same structural form as TrialTriggerTests.theBedtimeGateReadsItsAccessThroughTheTrigger, which
    // pins the other deliberate exception.
    @Test func theSettingsRowStillAccruesFromItsStateInitialiser() throws {
        let lines = try source("Tuck/SettingsView.swift")
        let declaration = try #require(lines.first { $0.contains("private var protectedSeconds") })

        #expect(declaration.contains("ProtectedTimeStore.accrue()"))
    }

    // Fresh install plus an immediate arm in the middle of the running occurrence — the order the
    // call sites run it in: accrue first (which only anchors here), skip second. Skipping before
    // accruing would leave countedThrough in the future and freeze the counter until `end`.
    @Test func armingIntoARunningOccurrenceSkipsItAndCountsTheNextOneInFull() {
        withDefaults { defaults in
            let morning = window(7, 0, 7, 30)
            armMorning(morning, in: defaults)

            let now = date(1, 7, 10)
            accrue(now, in: defaults)
            ProtectedTimeStore.skipRunningOccurrence(
                endingAt: ProtectedTimeStore.runningOccurrenceEnd(of: morning, at: now, calendar: Self.calendar),
                in: defaults
            )
            #expect(countedThrough(in: defaults) == date(1, 7, 30))

            #expect(accrue(date(1, 8, 0), in: defaults) == 0)
            #expect(accrue(date(2, 8, 0), in: defaults) == 30 * 60)
        }
    }

    // The scheduler's own shape, on the store for the same reason as the other skip tests: the
    // authorization prompt held the flow from 06:55 to 07:10, so the window is not running at the
    // time the call started and is running at the time the skip actually reaches the store. Booking
    // on the stale time leaves no skip behind and credits the whole occurrence the user never had.
    @Test func aPromptThatOutlastsTheWindowStartStillSkipsTheRunningOccurrence() {
        let morning = window(7, 0, 7, 30)
        let started = date(1, 6, 55)
        let armed = date(1, 7, 10)

        // What the stale reading did: at 06:55 nothing is running, so there is nothing to skip, and
        // the next pass credits the full 30 minutes of an occurrence that was armed halfway into.
        withDefaults { defaults in
            armMorning(morning, in: defaults)
            accrue(started, in: defaults)
            ProtectedTimeStore.skipRunningOccurrence(
                endingAt: ProtectedTimeStore.runningOccurrenceEnd(of: morning, at: started, calendar: Self.calendar),
                in: defaults
            )
            #expect(accrue(date(1, 8, 0), in: defaults) == 30 * 60)
        }

        withDefaults { defaults in
            armMorning(morning, in: defaults)
            accrue(armed, in: defaults)
            ProtectedTimeStore.skipRunningOccurrence(
                endingAt: ProtectedTimeStore.runningOccurrenceEnd(of: morning, at: armed, calendar: Self.calendar),
                in: defaults
            )

            #expect(countedThrough(in: defaults) == date(1, 7, 30))
            #expect(accrue(date(1, 8, 0), in: defaults) == 0)
            #expect(accrue(date(2, 8, 0), in: defaults) == 30 * 60)
        }
    }

    // The skip case's shape, run on the store rather than through applyPendingMorningDuration: there the skip
    // hangs on a registration that always fails in the Simulator, so a test through that path would
    // check something other than what its name says.
    @Test func aLengthChangeInsideTheNewWindowLeavesTheSumUntouchedUntilTheNextDay() {
        withDefaults { defaults in
            armMorning(window(7, 0, 7, 30), in: defaults)
            accrue(date(1, 6, 0), in: defaults)
            #expect(accrue(date(1, 7, 35), in: defaults) == 30 * 60)

            // 07:45, switched from 30 to 60 minutes: accrue before the mutation, then arm, then
            // skip. 07:00-08:00 contains 07:45, so that occurrence was never fully monitored.
            let changed = window(7, 0, 8, 0)
            let now = date(1, 7, 45)
            accrue(now, in: defaults)
            WakeAlarmStore.updateBlockWindow(changed, in: defaults)
            WakeAlarmStore.recordBlockRegistration(succeeded: true, in: defaults)
            ProtectedTimeStore.skipRunningOccurrence(
                endingAt: ProtectedTimeStore.runningOccurrenceEnd(of: changed, at: now, calendar: Self.calendar),
                in: defaults
            )

            #expect(accrue(date(1, 9, 0), in: defaults) == 30 * 60)
            #expect(accrue(date(2, 9, 0), in: defaults) == 30 * 60 + 60 * 60)
        }
    }

    @Test func theSkipNeverRaisesTheSumAndNeverMovesBackwards() {
        withDefaults { defaults in
            armMorning(window(7, 0, 7, 30), in: defaults)
            accrue(date(1, 6, 0), in: defaults)
            let total = accrue(date(1, 8, 0), in: defaults)

            ProtectedTimeStore.skipRunningOccurrence(endingAt: date(2, 7, 30), in: defaults)
            #expect(defaults.integer(forKey: "protectedSecondsTotal") == total)
            #expect(countedThrough(in: defaults) == date(2, 7, 30))

            // Backwards, and nil for the DST case: both no-ops.
            ProtectedTimeStore.skipRunningOccurrence(endingAt: date(1, 9, 0), in: defaults)
            ProtectedTimeStore.skipRunningOccurrence(endingAt: nil, in: defaults)
            #expect(countedThrough(in: defaults) == date(2, 7, 30))
            #expect(defaults.integer(forKey: "protectedSecondsTotal") == total)
        }
    }

    // The spring-forward pass, on a window whose END really falls into the gap — 02:30 does not
    // exist on 2026-03-29 in Europe/Berlin, where 02:00 jumps straight to 03:00. The earlier version
    // of this test used a 02:30–03:00 window, whose end at 03:00 exists that day and never touched
    // the edge it was named for.
    //
    // What the store guards against is a pass that returns early on an uncomputable wall-clock time:
    // countedThrough would never advance past it and every later pass would fail at the same place,
    // freezing the counter for good. So the property is what is pinned — the counter keeps moving —
    // and the cost is pinned with it rather than glossed.
    //
    // Measured, not assumed: the nil branch stays unreachable, because
    // Calendar.date(bySettingHour:minute:second:of:) defaults to matchingPolicy .nextTime and
    // resolves 02:30 forward to 03:00. The cost is TWO lost occurrences, not one: on the transition
    // day the anchor jumps forward from 02:30 to 03:00, and on the day after it drops back to 02:30,
    // so neither day shows a day-distance of 1. The guard stays because mostRecentStart returns an
    // Optional and a future matching policy is not this store's to assume.
    @Test func aSpringForwardPassKeepsTheCounterMovingAndCostsTwoOccurrences() {
        withDefaults { defaults in
            armMorning(window(2, 0, 2, 30), in: defaults)
            accrue(date(28, 12, 0, month: 3), in: defaults)

            #expect(accrue(date(29, 12, 0, month: 3), in: defaults) == 0)
            #expect(countedThrough(in: defaults) == date(29, 12, 0, month: 3))

            #expect(accrue(date(30, 12, 0, month: 3), in: defaults) == 0)
            #expect(countedThrough(in: defaults) == date(30, 12, 0, month: 3))

            // Moving again from the day after: the anchor is back on a wall-clock time that exists.
            #expect(accrue(date(31, 12, 0, month: 3), in: defaults) == 30 * 60)
        }
    }

    @Test func anUnarmedWindowCountsNothingAndIsNeverCaughtUpLater() {
        withDefaults { defaults in
            armMorning(window(7, 0, 7, 30), succeeded: false, in: defaults)
            accrue(date(1, 6, 0), in: defaults)

            #expect(accrue(date(4, 8, 0), in: defaults) == 0)
            // countedThrough moved anyway, so arming afterwards does not backfill those days.
            #expect(countedThrough(in: defaults) == date(4, 8, 0))
            WakeAlarmStore.recordBlockRegistration(succeeded: true, in: defaults)
            #expect(accrue(date(5, 8, 0), in: defaults) == 30 * 60)
        }
    }

    // Regression guard rather than mechanism: the exception was decided against (a fixed product decision),
    // and this is what keeps it from being reintroduced "out of honesty" later.
    @Test func anUnlockInsideTheOccurrenceChangesNothing() {
        withDefaults { defaults in
            armMorning(window(7, 0, 7, 30), in: defaults)
            accrue(date(1, 6, 0), in: defaults)

            UnlockQuotaStore.morning.consumeUnlock(now: date(1, 7, 10), calendar: Self.calendar, in: defaults)
            #expect(accrue(date(1, 8, 0), in: defaults) == 30 * 60)
        }
    }

    // The registration flag says the schedule is armed on all seven days, because
    // DeviceActivitySchedule cannot say anything narrower — the monitor extension is what lets the
    // unchosen days go by. Counting them here would credit a Mo-Fr user with the two mornings the
    // app deliberately did not protect: over-count, in the one direction this file says it never
    // goes. 2026-06-01 is a Monday, so day 6 is a Saturday and day 7 a Sunday.
    @Test func aWeekdayNobodyChoseIsNotProtectedTime() {
        withDefaults { defaults in
            armMorning(window(7, 0, 7, 30), in: defaults)
            WakeAlarmWeekdayStore.store([.monday, .tuesday, .wednesday, .thursday, .friday], in: defaults)
            accrue(date(5, 8, 0), in: defaults)

            // Saturday and Sunday pass, and Monday's occurrence is the only one credited.
            #expect(accrue(date(8, 8, 0), in: defaults) == 30 * 60)
        }
    }

    // The other direction, and the one every existing install is on: nothing stored means all seven
    // days, and a weekend counts exactly as it always did.
    @Test func withoutAStoredSelectionTheWeekendStillCounts() {
        withDefaults { defaults in
            armMorning(window(7, 0, 7, 30), in: defaults)
            accrue(date(5, 8, 0), in: defaults)

            #expect(accrue(date(8, 8, 0), in: defaults) == 3 * 30 * 60)
        }
    }

    // The evening window has no weekday selection and may not inherit the morning's: a Mo-Fr
    // wake selection would otherwise silently take the weekend off the bedtime tally too.
    @Test func theEveningWindowIsNotGatedByTheMorningsWeekdays() {
        withDefaults { defaults in
            armBedtime(window(22, 0, 23, 0), in: defaults)
            WakeAlarmWeekdayStore.store([.monday], in: defaults)
            accrue(date(5, 23, 30), in: defaults)

            #expect(accrue(date(7, 23, 30), in: defaults) == 2 * 60 * 60)
        }
    }

    @Test func bothWindowsFeedTheSameSumWithoutSeparateTallies() {
        withDefaults { defaults in
            armMorning(window(7, 0, 7, 30), in: defaults)
            armBedtime(window(22, 0, 23, 0), in: defaults)
            accrue(date(1, 6, 0), in: defaults)

            #expect(accrue(date(1, 8, 0), in: defaults) == 30 * 60)
            #expect(accrue(date(1, 23, 30), in: defaults) == 30 * 60 + 60 * 60)
        }
    }

    // Nailed down: the accrual is the first statement of applyPendingMorningDuration, before the
    // guard and before updateBlockWindow. Had it run after the mutation, the elapsed 06:30-07:00
    // occurrence would have been credited with the NEW 60 minutes; had it not run at all, the
    // cleared registration flag would have dropped it entirely. 30 minutes is the only outcome
    // that distinguishes the correct call site from both.
    //
    // The registration itself always fails here (Family Controls is unauthorized in the Simulator),
    // which is also why the skip case is unreachable from this path — see the note on the skip tests above.
    @MainActor
    @Test func theLengthChangeBooksTheOccurrenceWithTheLengthItActuallyRanUnder() {
        withDefaults { defaults in
            let fireDate = date(1, 6, 30)
            let window = MorningBlockWindow(alarmTime: fireDate, duration: .seconds(30 * 60), calendar: Self.calendar)
            WakeAlarmStore.store(id: UUID(), fireDate: fireDate, window: window, in: defaults)
            WakeAlarmStore.recordBlockRegistration(succeeded: true, in: defaults)
            accrue(date(1, 5, 0), in: defaults)

            MorningBlockDurationStore.store(.sixty, in: defaults)
            BlockWindowReconciler.applyPendingMorningDuration(
                now: date(1, 8, 0),
                calendar: Self.calendar,
                in: defaults
            )

            #expect(defaults.integer(forKey: "protectedSecondsTotal") == 30 * 60)
            #expect(WakeAlarmStore.scheduledAlarm(in: defaults)?.blockWindowEnd.minute == 30)

            // And the new length does not backfill the day it was not yet in force on.
            WakeAlarmStore.recordBlockRegistration(succeeded: true, in: defaults)
            #expect(accrue(date(1, 9, 0), in: defaults) == 30 * 60)
            #expect(accrue(date(2, 9, 0), in: defaults) == 30 * 60 + 60 * 60)
        }
    }

    // Condition 2 in its mechanical form. A day, week, history or anchor key cannot appear without
    // this test failing — which is the point: a history cannot grow here without somebody having to
    // come and change this line.
    @Test func theSuiteCarriesExactlyTheTwoKeysOfThisStore() {
        withDefaults { defaults in
            armMorning(window(7, 0, 7, 30), in: defaults)
            armBedtime(window(22, 0, 23, 0), in: defaults)
            UnlockQuotaStore.morning.consumeUnlock(now: date(1, 7, 10), calendar: Self.calendar, in: defaults)
            let baseline = Set(defaults.dictionaryRepresentation().keys)

            accrue(date(1, 6, 0), in: defaults)
            for day in 1...4 {
                accrue(date(day, 8, 0), in: defaults)
                accrue(date(day, 23, 30), in: defaults)
            }
            let changed = window(7, 0, 8, 0)
            accrue(date(5, 7, 45), in: defaults)
            WakeAlarmStore.updateBlockWindow(changed, in: defaults)
            WakeAlarmStore.recordBlockRegistration(succeeded: true, in: defaults)
            ProtectedTimeStore.skipRunningOccurrence(
                endingAt: ProtectedTimeStore.runningOccurrenceEnd(
                    of: changed, at: date(5, 7, 45), calendar: Self.calendar
                ),
                in: defaults
            )
            accrue(date(6, 9, 0), in: defaults)

            let written = Set(defaults.dictionaryRepresentation().keys).subtracting(baseline)
            #expect(written == ["protectedSecondsTotal", "protectedTimeCountedThrough"])
        }
    }
}
