import Testing
import Foundation
@testable import Tuck

struct BlockRegistrationFlagTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suite = "BlockRegistrationFlagTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        body(defaults)
    }

    private func date(hour: Int, minute: Int) -> Date {
        calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 9,
            day: 1,
            hour: hour,
            minute: minute
        ))!
    }

    private func storeAlarm(hour: Int, minute: Int, in defaults: UserDefaults) {
        let fireDate = date(hour: hour, minute: minute)
        let window = MorningBlockWindow(alarmTime: fireDate, duration: .seconds(30 * 60), calendar: calendar)
        WakeAlarmStore.store(id: UUID(), fireDate: fireDate, window: window, in: defaults)
    }

    private func storeBedtime(hour: Int, minute: Int, in defaults: UserDefaults) {
        let bedtime = date(hour: hour, minute: minute)
        let window = MorningBlockWindow.centeredOn(bedtime, halfDuration: .seconds(30 * 60), calendar: calendar)
        BedtimeStore.store(bedtime: bedtime, window: window, calendar: calendar, in: defaults)
    }

    @Test func aFreshInstallHasNoConfirmedMorningRegistration() {
        withDefaults { defaults in
            #expect(WakeAlarmStore.blockRegistrationSucceeded(in: defaults) == false)
        }
    }

    @Test func aStoredAlarmAloneDoesNotConfirmItsRegistration() {
        withDefaults { defaults in
            storeAlarm(hour: 7, minute: 0, in: defaults)

            #expect(WakeAlarmStore.scheduledAlarm(in: defaults) != nil)
            #expect(WakeAlarmStore.blockRegistrationSucceeded(in: defaults) == false)
        }
    }

    @Test func aSucceededMorningRegistrationReadsBackAsConfirmed() {
        withDefaults { defaults in
            storeAlarm(hour: 7, minute: 0, in: defaults)
            WakeAlarmStore.recordBlockRegistration(succeeded: true, in: defaults)

            #expect(WakeAlarmStore.blockRegistrationSucceeded(in: defaults) == true)
        }
    }

    // The reset in store() is the point: an armed window from yesterday must not vouch for the
    // window a new wake time just produced.
    @Test func aNewWakeTimeDropsThePreviousConfirmation() {
        withDefaults { defaults in
            storeAlarm(hour: 7, minute: 0, in: defaults)
            WakeAlarmStore.recordBlockRegistration(succeeded: true, in: defaults)

            storeAlarm(hour: 8, minute: 0, in: defaults)

            #expect(WakeAlarmStore.blockRegistrationSucceeded(in: defaults) == false)
        }
    }

    @Test func clearingTheAlarmRemovesItsConfirmation() {
        withDefaults { defaults in
            storeAlarm(hour: 7, minute: 0, in: defaults)
            WakeAlarmStore.recordBlockRegistration(succeeded: true, in: defaults)
            WakeAlarmStore.clear(in: defaults)

            #expect(WakeAlarmStore.blockRegistrationSucceeded(in: defaults) == false)
        }
    }

    @Test func aFreshInstallHasNoConfirmedBedtimeRegistration() {
        withDefaults { defaults in
            #expect(BedtimeStore.blockRegistrationSucceeded(in: defaults) == false)
        }
    }

    @Test func aStoredBedtimeAloneDoesNotConfirmItsRegistration() {
        withDefaults { defaults in
            storeBedtime(hour: 22, minute: 30, in: defaults)

            #expect(BedtimeStore.bedtime(in: defaults) != nil)
            #expect(BedtimeStore.blockRegistrationSucceeded(in: defaults) == false)
        }
    }

    @Test func aNewBedtimeDropsThePreviousConfirmation() {
        withDefaults { defaults in
            storeBedtime(hour: 22, minute: 30, in: defaults)
            BedtimeStore.recordBlockRegistration(succeeded: true, in: defaults)

            storeBedtime(hour: 22, minute: 31, in: defaults)

            #expect(BedtimeStore.blockRegistrationSucceeded(in: defaults) == false)
        }
    }

    @Test func clearingTheBedtimeRemovesItsConfirmation() {
        withDefaults { defaults in
            storeBedtime(hour: 22, minute: 30, in: defaults)
            BedtimeStore.recordBlockRegistration(succeeded: true, in: defaults)
            BedtimeStore.clear(in: defaults)

            #expect(BedtimeStore.blockRegistrationSucceeded(in: defaults) == false)
        }
    }

    // The two windows fail independently: a bedtime that never registered says nothing about the
    // morning, and the flags must not be read as one shared "is the shield on" bit.
    @Test func theTwoWindowsCarryTheirOwnConfirmation() {
        withDefaults { defaults in
            storeAlarm(hour: 7, minute: 0, in: defaults)
            storeBedtime(hour: 22, minute: 30, in: defaults)
            WakeAlarmStore.recordBlockRegistration(succeeded: true, in: defaults)

            #expect(WakeAlarmStore.blockRegistrationSucceeded(in: defaults) == true)
            #expect(BedtimeStore.blockRegistrationSucceeded(in: defaults) == false)
        }
    }
}
