import Testing
import Foundation
@testable import Tuck

struct WakeAlarmStoreIdempotencyTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    private func date(
        year: Int = 2026,
        month: Int = 9,
        day: Int = 1,
        hour: Int,
        minute: Int,
        second: Int = 0
    ) -> Date {
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        )
        return calendar.date(from: components)!
    }

    // Throwaway suite per test, so nothing here can touch the App-Group container the app and
    // the Shield-Action extension actually use.
    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suite = "WakeAlarmStoreIdempotencyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        body(defaults)
    }

    private func scheduleAlarm(at fireDate: Date, in defaults: UserDefaults) {
        let window = MorningBlockWindow(alarmTime: fireDate, duration: .seconds(30 * 60), calendar: calendar)
        WakeAlarmStore.store(id: UUID(), fireDate: fireDate, window: window, in: defaults)
    }

    // Mirrors StopWakeAlarmIntent.perform(): read the guard BEFORE recordDismissal overwrites
    // the value it compares against. A swapped order here would make the guard permanently inert.
    private func dismiss(at moment: Date, in defaults: UserDefaults) -> Bool {
        let isFirst = WakeAlarmStore.isFirstDismissal(ofMorningContaining: moment, calendar: calendar, in: defaults)
        WakeAlarmStore.recordDismissal(at: moment, in: defaults)
        return isFirst
    }

    @Test func aRetrySecondsLaterCountsTheSameMorningOnlyOnce() {
        withDefaults { defaults in
            scheduleAlarm(at: date(hour: 7, minute: 0), in: defaults)

            #expect(dismiss(at: date(hour: 7, minute: 0, second: 2), in: defaults) == true)
            #expect(dismiss(at: date(hour: 7, minute: 0, second: 9), in: defaults) == false)
        }
    }

    @Test func threeConsecutiveMorningsEachCountOnce() {
        withDefaults { defaults in
            scheduleAlarm(at: date(hour: 7, minute: 0), in: defaults)

            #expect(dismiss(at: date(day: 1, hour: 7, minute: 1), in: defaults) == true)
            #expect(dismiss(at: date(day: 2, hour: 7, minute: 1), in: defaults) == true)
            #expect(dismiss(at: date(day: 3, hour: 7, minute: 1), in: defaults) == true)
        }
    }

    @Test func aWindowWrappingPastMidnightStillCountsOneMorningPerDay() {
        withDefaults { defaults in
            scheduleAlarm(at: date(day: 1, hour: 23, minute: 50), in: defaults)

            #expect(dismiss(at: date(day: 2, hour: 0, minute: 5), in: defaults) == true)
            #expect(dismiss(at: date(day: 2, hour: 0, minute: 12), in: defaults) == false)
            #expect(dismiss(at: date(day: 3, hour: 0, minute: 7), in: defaults) == true)
        }
    }

    @Test func theFirstEverDismissalIsNeverSwallowed() {
        withDefaults { defaults in
            #expect(WakeAlarmStore.dismissedAt(in: defaults) == nil)
            #expect(WakeAlarmStore.scheduledAlarm(in: defaults) == nil)

            #expect(dismiss(at: date(hour: 7, minute: 0), in: defaults) == true)
        }
    }

    // Pins the known, accepted hole documented at WakeAlarmStore.isFirstDismissal: rescheduling
    // between two deliveries of one morning runs clear()/store(), both of which remove the stored
    // dismissedAt, so the anchor comparison never runs. Over-counts, never under-counts.
    // The acceptance covers the streak and only the streak. It once covered the unlock quota too,
    // where the same gate meant an unlimited refill — that half is closed, and the quota now keys
    // off the calendar day (MorningProgressStoreTests.reschedulingTheWakeAlarmDoesNotHandBackASpentQuota).
    @Test func wakeTimeChangedBetweenDuplicateDeliveriesCountsTheMorningTwice() {
        withDefaults { defaults in
            scheduleAlarm(at: date(hour: 7, minute: 0), in: defaults)
            #expect(dismiss(at: date(hour: 7, minute: 0, second: 2), in: defaults) == true)

            WakeAlarmStore.clear(in: defaults)
            scheduleAlarm(at: date(hour: 8, minute: 0), in: defaults)

            #expect(dismiss(at: date(hour: 7, minute: 0, second: 9), in: defaults) == true)
        }
    }
}
