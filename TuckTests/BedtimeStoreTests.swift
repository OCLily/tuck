import Testing
import Foundation
@testable import Tuck

struct BedtimeStoreTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    // Throwaway suite per test, so nothing here touches the App-Group container the app and the
    // Monitor extension actually use.
    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suite = "BedtimeStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        body(defaults)
    }

    private func date(hour: Int, minute: Int, day: Int = 1) -> Date {
        calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 9,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }

    @Test func noBedtimeIsSetOnAFreshInstall() {
        withDefaults { defaults in
            #expect(BedtimeStore.bedtime(in: defaults) == nil)
        }
    }

    @Test func aStoredBedtimeSurvivesAsTimeOfDayWithItsCenteredWindow() {
        withDefaults { defaults in
            let bedtime = date(hour: 22, minute: 30)
            let window = MorningBlockWindow.centeredOn(bedtime, halfDuration: .seconds(30 * 60), calendar: calendar)
            BedtimeStore.store(bedtime: bedtime, window: window, calendar: calendar, in: defaults)

            let stored = BedtimeStore.bedtime(in: defaults)
            #expect(stored?.time.hour == 22)
            #expect(stored?.time.minute == 30)
            #expect(stored?.blockWindowStart.hour == 22)
            #expect(stored?.blockWindowStart.minute == 0)
            #expect(stored?.blockWindowEnd.hour == 23)
            #expect(stored?.blockWindowEnd.minute == 0)
        }
    }

    @Test func clearingRemovesTheBedtimeCompletely() {
        withDefaults { defaults in
            let bedtime = date(hour: 22, minute: 30)
            let window = MorningBlockWindow.centeredOn(bedtime, halfDuration: .seconds(30 * 60), calendar: calendar)
            BedtimeStore.store(bedtime: bedtime, window: window, calendar: calendar, in: defaults)
            BedtimeStore.clear(in: defaults)

            #expect(BedtimeStore.bedtime(in: defaults) == nil)
        }
    }

    @Test func restoringABedtimeThatWrapsPastMidnightKeepsBothEnds() {
        withDefaults { defaults in
            let bedtime = date(hour: 23, minute: 50)
            let window = MorningBlockWindow.centeredOn(bedtime, halfDuration: .seconds(30 * 60), calendar: calendar)
            BedtimeStore.store(bedtime: bedtime, window: window, calendar: calendar, in: defaults)

            let stored = BedtimeStore.bedtime(in: defaults)
            #expect(stored?.blockWindowStart.hour == 23)
            #expect(stored?.blockWindowStart.minute == 20)
            #expect(stored?.blockWindowEnd.hour == 0)
            #expect(stored?.blockWindowEnd.minute == 20)
        }
    }
}

struct BedtimeUnlockQuotaTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suite = "BedtimeUnlockQuotaTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        body(defaults)
    }

    private func date(hour: Int, minute: Int, day: Int = 1) -> Date {
        calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 9,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }

    private func storeBedtime(hour: Int, minute: Int, in defaults: UserDefaults) {
        let bedtime = date(hour: hour, minute: minute)
        let window = MorningBlockWindow.centeredOn(bedtime, halfDuration: .seconds(30 * 60), calendar: calendar)
        BedtimeStore.store(bedtime: bedtime, window: window, calendar: calendar, in: defaults)
    }

    // The evening no longer has to undercut the morning, because the
    // morning's free number came down to one. What still has to hold is that it is its own counter
    // on its own two keys and its own rollover hour — spending an evening unlock may not touch the
    // morning's.
    @Test func theEveningQuotaIsItsOwnCounterNotAShareOfTheMornings() {
        withDefaults { defaults in
            #expect(UnlockQuotaStore.bedtime.freeUnlockMaximum == UnlockQuotaStore.morning.freeUnlockMaximum)

            UnlockQuotaStore.bedtime.consumeUnlock(now: date(hour: 22, minute: 10), calendar: calendar, in: defaults)

            #expect(UnlockQuotaStore.bedtime.remainingUnlocks(now: date(hour: 22, minute: 40), calendar: calendar, in: defaults) == 0)
            #expect(UnlockQuotaStore.morning.remainingUnlocks(now: date(hour: 22, minute: 40), calendar: calendar, in: defaults)
                == UnlockQuotaStore.morning.freeUnlockMaximum)
        }
    }

    @Test func freshInstallHasTheFullEveningQuota() {
        withDefaults { defaults in
            #expect(UnlockQuotaStore.bedtime.remainingUnlocks(now: date(hour: 22, minute: 30), calendar: calendar, in: defaults)
                == UnlockQuotaStore.bedtime.freeUnlockMaximum)
        }
    }

    @Test func usingAnUnlockLeavesOneFewerInTheSameWindow() {
        withDefaults { defaults in
            storeBedtime(hour: 22, minute: 30, in: defaults)
            UnlockQuotaStore.bedtime.consumeUnlock(now: date(hour: 22, minute: 10), calendar: calendar, in: defaults)

            #expect(UnlockQuotaStore.bedtime.remainingUnlocks(now: date(hour: 22, minute: 40), calendar: calendar, in: defaults)
                == UnlockQuotaStore.bedtime.freeUnlockMaximum - 1)
        }
    }

    @Test func anExhaustedEveningQuotaStaysAtZero() {
        withDefaults { defaults in
            storeBedtime(hour: 22, minute: 30, in: defaults)
            for _ in 0..<(UnlockQuotaStore.bedtime.freeUnlockMaximum + 3) {
                UnlockQuotaStore.bedtime.consumeUnlock(now: date(hour: 22, minute: 10), calendar: calendar, in: defaults)
            }

            #expect(UnlockQuotaStore.bedtime.remainingUnlocks(now: date(hour: 22, minute: 40), calendar: calendar, in: defaults) == 0)
        }
    }

    // The lazy reset: no callback fires between the two reads, only the clock moves on.
    @Test func theNextEveningStartsWithAFullQuotaWithoutAnyCallback() {
        withDefaults { defaults in
            storeBedtime(hour: 22, minute: 30, in: defaults)
            UnlockQuotaStore.bedtime.consumeUnlock(now: date(hour: 22, minute: 10), calendar: calendar, in: defaults)

            #expect(UnlockQuotaStore.bedtime.remainingUnlocks(now: date(hour: 22, minute: 10, day: 2), calendar: calendar, in: defaults)
                == UnlockQuotaStore.bedtime.freeUnlockMaximum)
        }
    }

    // A window that wraps past midnight is one occurrence, so the quota must not refill at 00:00
    // in the middle of it.
    @Test func aWindowSpanningMidnightDoesNotRefillTheQuotaHalfwayThrough() {
        withDefaults { defaults in
            storeBedtime(hour: 23, minute: 50, in: defaults)
            UnlockQuotaStore.bedtime.consumeUnlock(now: date(hour: 23, minute: 55), calendar: calendar, in: defaults)

            #expect(UnlockQuotaStore.bedtime.remainingUnlocks(now: date(hour: 0, minute: 10, day: 2), calendar: calendar, in: defaults)
                == UnlockQuotaStore.bedtime.freeUnlockMaximum - 1)
        }
    }

    // The rollover sits at 06:00, not at midnight, so the night belongs to the evening it started
    // in — and the quota is back long before the next evening.
    @Test func theQuotaComesBackAfterTheEarlyMorningRollover() {
        withDefaults { defaults in
            storeBedtime(hour: 23, minute: 50, in: defaults)
            UnlockQuotaStore.bedtime.consumeUnlock(now: date(hour: 23, minute: 55), calendar: calendar, in: defaults)

            #expect(UnlockQuotaStore.bedtime.remainingUnlocks(now: date(hour: 5, minute: 0, day: 2), calendar: calendar, in: defaults) == 0)
            #expect(UnlockQuotaStore.bedtime.remainingUnlocks(now: date(hour: 6, minute: 5, day: 2), calendar: calendar, in: defaults)
                == UnlockQuotaStore.bedtime.freeUnlockMaximum)
        }
    }

    // Regression: the anchor used to be the window occurrence itself, so moving the bedtime by a
    // single minute moved the anchor and read as a fresh occurrence — handing back the unlock that
    // was already spent, as often as the user cared to nudge the picker.
    @Test func nudgingTheBedtimeDoesNotHandBackASpentUnlock() {
        withDefaults { defaults in
            storeBedtime(hour: 22, minute: 30, in: defaults)
            UnlockQuotaStore.bedtime.consumeUnlock(now: date(hour: 22, minute: 10), calendar: calendar, in: defaults)

            storeBedtime(hour: 22, minute: 31, in: defaults)

            #expect(UnlockQuotaStore.bedtime.remainingUnlocks(now: date(hour: 22, minute: 40), calendar: calendar, in: defaults)
                == UnlockQuotaStore.bedtime.freeUnlockMaximum - 1)
        }
    }

    // The other direction of the same fix: an edit must not freeze the quota either.
    @Test func aNudgedBedtimeStillRefillsTheQuotaTheNextEvening() {
        withDefaults { defaults in
            storeBedtime(hour: 22, minute: 30, in: defaults)
            UnlockQuotaStore.bedtime.consumeUnlock(now: date(hour: 22, minute: 10), calendar: calendar, in: defaults)
            storeBedtime(hour: 22, minute: 31, in: defaults)

            #expect(UnlockQuotaStore.bedtime.remainingUnlocks(now: date(hour: 22, minute: 40, day: 2), calendar: calendar, in: defaults)
                == UnlockQuotaStore.bedtime.freeUnlockMaximum)
        }
    }

    // The direction the day-keyed anchor still got wrong: moving the bedtime FORWARD past `now`
    // pushed the window's most recent start onto the previous calendar day, so the freshly computed
    // anchor no longer matched the stored one and the spent unlock came back.
    @Test func nudgingTheBedtimeForwardAcrossNowDoesNotHandBackASpentUnlock() {
        withDefaults { defaults in
            let now = date(hour: 22, minute: 10)
            storeBedtime(hour: 22, minute: 30, in: defaults)
            UnlockQuotaStore.bedtime.consumeUnlock(now: now, calendar: calendar, in: defaults)

            storeBedtime(hour: 23, minute: 30, in: defaults)

            #expect(UnlockQuotaStore.bedtime.remainingUnlocks(now: now, calendar: calendar, in: defaults) == 0)
        }
    }

    // The same edit, repeated: one nudge back and forth per round, an unlock taken whenever one is
    // offered. Ten rounds must not buy more than the one the evening actually grants.
    @Test func alternatingTheBedtimeAllEveningCannotBuyMoreThanTheQuota() {
        withDefaults { defaults in
            let now = date(hour: 22, minute: 10)
            var spent = 0

            for round in 0..<10 {
                storeBedtime(hour: round.isMultiple(of: 2) ? 22 : 23, minute: 30, in: defaults)
                if UnlockQuotaStore.bedtime.remainingUnlocks(now: now, calendar: calendar, in: defaults) > 0 {
                    UnlockQuotaStore.bedtime.consumeUnlock(now: now, calendar: calendar, in: defaults)
                    spent += 1
                }
                #expect(UnlockQuotaStore.bedtime.remainingUnlocks(now: now, calendar: calendar, in: defaults) == 0)
            }

            #expect(spent == UnlockQuotaStore.bedtime.freeUnlockMaximum)
        }
    }

    // The overcorrection guard for the test above: all that alternating must not freeze the quota
    // either — the next evening still starts full.
    @Test func theQuotaStillResetsTheNextEveningAfterAnEveningOfAlternating() {
        withDefaults { defaults in
            let now = date(hour: 22, minute: 10)
            for round in 0..<10 {
                storeBedtime(hour: round.isMultiple(of: 2) ? 22 : 23, minute: 30, in: defaults)
                UnlockQuotaStore.bedtime.consumeUnlock(now: now, calendar: calendar, in: defaults)
            }

            #expect(UnlockQuotaStore.bedtime.remainingUnlocks(now: date(hour: 22, minute: 10, day: 2), calendar: calendar, in: defaults)
                == UnlockQuotaStore.bedtime.freeUnlockMaximum)
        }
    }

    // The anchor is independent of the bedtime by construction: setting one for the first time
    // after the unlock was already spent must not reset anything either.
    @Test func settingABedtimeAfterSpendingTheUnlockDoesNotHandItBack() {
        withDefaults { defaults in
            let now = date(hour: 22, minute: 10)
            UnlockQuotaStore.bedtime.consumeUnlock(now: now, calendar: calendar, in: defaults)

            storeBedtime(hour: 22, minute: 30, in: defaults)

            #expect(UnlockQuotaStore.bedtime.remainingUnlocks(now: now, calendar: calendar, in: defaults) == 0)
        }
    }

    // The bedtime window never touches morning progress, in either direction.
    @Test func spendingAnEveningUnlockLeavesMorningProgressAndQuotaUntouched() {
        withDefaults { defaults in
            storeBedtime(hour: 22, minute: 30, in: defaults)
            UnlockQuotaStore.bedtime.consumeUnlock(now: date(hour: 22, minute: 10), calendar: calendar, in: defaults)

            #expect(MorningProgressStore.completedMornings(in: defaults) == 0)
            #expect(UnlockQuotaStore.morning.remainingUnlocks(in: defaults) == UnlockQuotaStore.morning.freeUnlockMaximum)
        }
    }

    // MARK: - The moment the window became real

    // The evening's substitute for the morning's fireDate: without it a bedtime stored at 23:00 for
    // 22:00 immediately reports a missing callback for the 21:30 occurrence, which nothing was
    // monitoring when it passed.
    @Test func anOccurrenceFromBeforeTheRegistrationIsNotCountable() {
        withDefaults { defaults in
            storeBedtime(hour: 22, minute: 30, in: defaults)
            BedtimeStore.recordBlockRegistration(succeeded: true, at: date(hour: 23, minute: 0), in: defaults)

            #expect(BedtimeStore.countableOccurrence(
                now: date(hour: 23, minute: 30),
                calendar: calendar,
                in: defaults
            ) == nil)

            // The next evening's occurrence is after the registration and is countable.
            #expect(BedtimeStore.countableOccurrence(
                now: date(hour: 22, minute: 30, day: 2),
                calendar: calendar,
                in: defaults
            ) == date(hour: 22, minute: 0, day: 2))
        }
    }

    @Test func aFailedRegistrationRemovesTheTimestamp() {
        withDefaults { defaults in
            storeBedtime(hour: 22, minute: 30, in: defaults)
            BedtimeStore.recordBlockRegistration(succeeded: true, at: date(hour: 20, minute: 0), in: defaults)
            #expect(BedtimeStore.blockRegisteredAt(in: defaults) == date(hour: 20, minute: 0))

            BedtimeStore.recordBlockRegistration(succeeded: false, at: date(hour: 21, minute: 0), in: defaults)

            #expect(BedtimeStore.blockRegisteredAt(in: defaults) == nil)
            #expect(BedtimeStore.countableOccurrence(
                now: date(hour: 22, minute: 30),
                calendar: calendar,
                in: defaults
            ) == nil)
        }
    }

    @Test func clearRemovesTheRegistrationTimestamp() {
        withDefaults { defaults in
            storeBedtime(hour: 22, minute: 30, in: defaults)
            BedtimeStore.recordBlockRegistration(succeeded: true, at: date(hour: 20, minute: 0), in: defaults)

            BedtimeStore.clear(in: defaults)

            #expect(BedtimeStore.blockRegisteredAt(in: defaults) == nil)
        }
    }

    // The reconciler freezes one `now` per pass and hands it to every accrual and every skip. The
    // bedtime registration stamp is written in that same pass, so it has to carry the same moment —
    // a default `.now` would break the rule in the very passage that set it up. The morning's three
    // call sites deliberately take no `at:` at all: only the evening lacks a fireDate.
    @Test func theReconcilerStampsTheBedtimeRegistrationWithItsFrozenNow() throws {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Tuck/BlockWindowReconciler.swift")
        let lines = try String(contentsOf: source, encoding: .utf8).components(separatedBy: "\n")

        let bedtimeStamps = lines.filter { $0.contains("BedtimeStore.recordBlockRegistration(") }
        #expect(bedtimeStamps.count == 3)
        for line in bedtimeStamps {
            #expect(line.contains("at: now"), "\(line) writes the stamp off an unfrozen clock")
        }

        let morningStamps = lines.filter { $0.contains("WakeAlarmStore.recordBlockRegistration(") }
        #expect(!morningStamps.isEmpty)
        for line in morningStamps {
            #expect(!line.contains("at: "), "\(line) grew a stamp the morning does not need")
        }
    }
}
