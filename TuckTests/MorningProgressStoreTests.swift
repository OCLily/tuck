import Testing
import Foundation
@testable import Tuck

struct MorningProgressStoreTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
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

    // Throwaway suite per test, so nothing here can touch the App-Group container the app and
    // the Shield-Action extension actually use.
    // Takes the body instead of returning the suite so the cleanup can be deferred here: a
    // returning helper would leave one plist behind per test run.
    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suite = "MorningProgressStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        body(defaults)
    }

    // Reproduces one full morning as the app runs it: the alarm rings and the stop intent counts it
    // through the ledger, which is where both counting paths meet. The streak — not the
    // quota — follows from it.
    private func scheduleAndDismiss(wakeHour: Int, wakeMinute: Int, at moment: Date, in defaults: UserDefaults) {
        let fireDate = date(hour: wakeHour, minute: wakeMinute)
        let window = MorningBlockWindow(alarmTime: fireDate, duration: .seconds(30 * 60), calendar: calendar)
        WakeAlarmStore.store(id: UUID(), fireDate: fireDate, window: window, in: defaults)

        CompletedMorningLedger.recordAlarmDismissal(at: moment, calendar: calendar, in: defaults)
    }

    @Test func freshInstallHasNoCompletedMorningsAndTheFullUnlockQuota() {
        withDefaults { defaults in
            #expect(MorningProgressStore.completedMornings(in: defaults) == 0)
            #expect(UnlockQuotaStore.morning.remainingUnlocks(in: defaults) == UnlockQuotaStore.morning.freeUnlockMaximum)
        }
    }

    @Test func aDismissedAlarmCountsOneMoreCompletedMorning() {
        withDefaults { defaults in
            MorningProgressStore.recordCompletedMorning(in: defaults)

            #expect(MorningProgressStore.completedMornings(in: defaults) == 1)
        }
    }

    @Test func completedMorningsAccumulateAcrossMornings() {
        withDefaults { defaults in
            for _ in 0..<5 {
                MorningProgressStore.recordCompletedMorning(in: defaults)
            }

            #expect(MorningProgressStore.completedMornings(in: defaults) == 5)
        }
    }

    @Test func usingAnUnlockLeavesOneFewerForTheRestOfTheMorning() {
        withDefaults { defaults in
            UnlockQuotaStore.morning.consumeUnlock(in: defaults)

            #expect(UnlockQuotaStore.morning.remainingUnlocks(in: defaults) == UnlockQuotaStore.morning.freeUnlockMaximum - 1)
        }
    }

    // The quota stops at zero instead of going negative - a negative balance would survive
    // into the next morning's reset arithmetic and quietly hand out extra unlocks.
    @Test func anExhaustedQuotaStaysAtZero() {
        withDefaults { defaults in
            for _ in 0..<(UnlockQuotaStore.morning.freeUnlockMaximum + 3) {
                UnlockQuotaStore.morning.consumeUnlock(in: defaults)
            }

            #expect(UnlockQuotaStore.morning.remainingUnlocks(in: defaults) == 0)
        }
    }

    @Test func theNextDayRestoresTheFullQuota() {
        withDefaults { defaults in
            let morning = date(hour: 7, minute: 10)
            UnlockQuotaStore.morning.consumeUnlock(now: morning, calendar: calendar, in: defaults)
            UnlockQuotaStore.morning.consumeUnlock(now: morning, calendar: calendar, in: defaults)

            #expect(UnlockQuotaStore.morning.remainingUnlocks(now: morning, calendar: calendar, in: defaults) == 0)
            #expect(UnlockQuotaStore.morning.remainingUnlocks(now: date(hour: 7, minute: 10, day: 2), calendar: calendar, in: defaults)
                == UnlockQuotaStore.morning.freeUnlockMaximum)
        }
    }

    // The spent quota has to survive the whole day it was spent in, not just the morning window.
    @Test func aSpentQuotaStaysSpentForTheRestOfTheDay() {
        withDefaults { defaults in
            UnlockQuotaStore.morning.consumeUnlock(now: date(hour: 7, minute: 10), calendar: calendar, in: defaults)

            #expect(UnlockQuotaStore.morning.remainingUnlocks(now: date(hour: 23, minute: 55), calendar: calendar, in: defaults)
                == UnlockQuotaStore.morning.freeUnlockMaximum - 1)
        }
    }

    // The second of the two constants that separate the merged quotas: the morning turns at
    // midnight, so a spent morning unlock is back at 03:00 — where the evening's 06:00 rollover
    // would still be holding it.
    @Test func theMorningQuotaTurnsAtMidnightNotAtTheEveningsSixOClock() {
        withDefaults { defaults in
            UnlockQuotaStore.morning.consumeUnlock(now: date(hour: 7, minute: 10), calendar: calendar, in: defaults)

            #expect(UnlockQuotaStore.morning.remainingUnlocks(now: date(hour: 3, minute: 0, day: 2), calendar: calendar, in: defaults)
                == UnlockQuotaStore.morning.freeUnlockMaximum)
        }
    }

    // An unlock is a paid, intended option - a morning it was used in still counts.
    @Test func usingUnlocksNeverReducesCompletedMornings() {
        withDefaults { defaults in
            MorningProgressStore.recordCompletedMorning(in: defaults)
            MorningProgressStore.recordCompletedMorning(in: defaults)
            UnlockQuotaStore.morning.consumeUnlock(in: defaults)
            UnlockQuotaStore.morning.consumeUnlock(in: defaults)
            UnlockQuotaStore.morning.consumeUnlock(in: defaults)
            MorningProgressStore.recordCompletedMorning(in: defaults)

            #expect(MorningProgressStore.completedMornings(in: defaults) == 3)
        }
    }

    // Regression, the morning half of the bug already fixed for the evening: the quota used to
    // be refilled by the dismissal whenever it fell into a fresh occurrence of the stored block
    // window. Spend the day's unlocks, move the wake time a few minutes out, let it ring, dismiss —
    // and the quota was full again, once per reschedule and without limit.
    @Test func reschedulingTheWakeAlarmDoesNotHandBackASpentQuota() {
        withDefaults { defaults in
            let morning = date(hour: 7, minute: 5)
            scheduleAndDismiss(wakeHour: 7, wakeMinute: 0, at: morning, in: defaults)
            UnlockQuotaStore.morning.consumeUnlock(now: morning, calendar: calendar, in: defaults)
            UnlockQuotaStore.morning.consumeUnlock(now: morning, calendar: calendar, in: defaults)
            #expect(UnlockQuotaStore.morning.remainingUnlocks(now: morning, calendar: calendar, in: defaults) == 0)

            let later = date(hour: 7, minute: 35)
            scheduleAndDismiss(wakeHour: 7, wakeMinute: 30, at: later, in: defaults)

            #expect(UnlockQuotaStore.morning.remainingUnlocks(now: later, calendar: calendar, in: defaults) == 0)
        }
    }

    // The other direction of the same edit: moving the wake time BACKWARDS, before the dismissal
    // that already happened, must not read as a fresh morning for the quota either.
    @Test func reschedulingTheWakeAlarmBackwardsDoesNotHandBackASpentQuota() {
        withDefaults { defaults in
            let morning = date(hour: 7, minute: 5)
            scheduleAndDismiss(wakeHour: 7, wakeMinute: 0, at: morning, in: defaults)
            UnlockQuotaStore.morning.consumeUnlock(now: morning, calendar: calendar, in: defaults)
            UnlockQuotaStore.morning.consumeUnlock(now: morning, calendar: calendar, in: defaults)

            let later = date(hour: 7, minute: 20)
            scheduleAndDismiss(wakeHour: 6, wakeMinute: 30, at: later, in: defaults)

            #expect(UnlockQuotaStore.morning.remainingUnlocks(now: later, calendar: calendar, in: defaults) == 0)
        }
    }

    // The full farming loop: reschedule, let it ring, dismiss, take whatever is on offer. Ten
    // rounds must not buy more than the unlocks the day actually grants.
    @Test func alternatingTheWakeTimeAllMorningCannotBuyMoreThanTheQuota() {
        withDefaults { defaults in
            let morning = date(hour: 7, minute: 45)
            var spent = 0

            for round in 0..<10 {
                scheduleAndDismiss(
                    wakeHour: 7,
                    wakeMinute: round.isMultiple(of: 2) ? 0 : 30,
                    at: morning,
                    in: defaults
                )
                while UnlockQuotaStore.morning.remainingUnlocks(now: morning, calendar: calendar, in: defaults) > 0 {
                    UnlockQuotaStore.morning.consumeUnlock(now: morning, calendar: calendar, in: defaults)
                    spent += 1
                }
                #expect(UnlockQuotaStore.morning.remainingUnlocks(now: morning, calendar: calendar, in: defaults) == 0)
            }

            #expect(spent == UnlockQuotaStore.morning.freeUnlockMaximum)
        }
    }

    // The overcorrection guard for the tests above: a morning full of rescheduling must not freeze
    // the quota either — the next real morning still starts full.
    @Test func theQuotaStillResetsTheNextMorningAfterAMorningOfRescheduling() {
        withDefaults { defaults in
            let morning = date(hour: 7, minute: 45)
            for round in 0..<10 {
                scheduleAndDismiss(
                    wakeHour: 7,
                    wakeMinute: round.isMultiple(of: 2) ? 0 : 30,
                    at: morning,
                    in: defaults
                )
                UnlockQuotaStore.morning.consumeUnlock(now: morning, calendar: calendar, in: defaults)
            }

            let nextMorning = date(hour: 7, minute: 5, day: 2)
            scheduleAndDismiss(wakeHour: 7, wakeMinute: 0, at: nextMorning, in: defaults)

            #expect(UnlockQuotaStore.morning.remainingUnlocks(now: nextMorning, calendar: calendar, in: defaults)
                == UnlockQuotaStore.morning.freeUnlockMaximum)
        }
    }

    // The streak keeps its own gate (over-count rather than under-count), and that gate is
    // exactly what must no longer reach the quota. Both halves in one place so a future change
    // cannot quietly re-couple them.
    @Test func reschedulingStillCountsTheStreakWhileTheQuotaStaysSpent() {
        withDefaults { defaults in
            let morning = date(hour: 7, minute: 5)
            scheduleAndDismiss(wakeHour: 7, wakeMinute: 0, at: morning, in: defaults)
            UnlockQuotaStore.morning.consumeUnlock(now: morning, calendar: calendar, in: defaults)
            UnlockQuotaStore.morning.consumeUnlock(now: morning, calendar: calendar, in: defaults)

            let later = date(hour: 7, minute: 35)
            scheduleAndDismiss(wakeHour: 7, wakeMinute: 30, at: later, in: defaults)

            #expect(MorningProgressStore.completedMornings(in: defaults) == 2)
            #expect(UnlockQuotaStore.morning.remainingUnlocks(now: later, calendar: calendar, in: defaults) == 0)
        }
    }

    @Test func progressAndQuotaSurviveANewStoreLookupOnTheSameSuite() {
        let suite = "MorningProgressStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        MorningProgressStore.recordCompletedMorning(in: defaults)
        UnlockQuotaStore.morning.consumeUnlock(in: defaults)

        let reopened = UserDefaults(suiteName: suite)!
        #expect(MorningProgressStore.completedMornings(in: reopened) == 1)
        #expect(UnlockQuotaStore.morning.remainingUnlocks(in: reopened) == UnlockQuotaStore.morning.freeUnlockMaximum - 1)

        defaults.removePersistentDomain(forName: suite)
    }
}

struct MascotStageProgressionTests {
    @Test func stageFollowsTheThresholdsDefinedOnMascotStage() {
        for stage in MascotStage.allCases {
            #expect(MascotStage.stage(forCompletedMornings: stage.completedMornings) == stage)
        }
    }

    @Test func morningsBelowTheNextThresholdKeepThePreviousStage() {
        #expect(MascotStage.stage(forCompletedMornings: MascotStage.warmGeworden.completedMornings - 1) == .start)
        #expect(MascotStage.stage(forCompletedMornings: MascotStage.eingespielt.completedMornings - 1) == .warmGeworden)
    }

    @Test func morningsBeyondTheLastThresholdStayAtTheLastStage() {
        #expect(MascotStage.stage(forCompletedMornings: MascotStage.eingespielt.completedMornings + 500) == .eingespielt)
    }
}
