import Testing
import Foundation
import ManagedSettings
@testable import Tuck

struct OverrideContextTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suite = "OverrideContextTests.\(UUID().uuidString)"
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

    // A morning window as the app leaves it once DeviceActivity accepted it: stored plus the
    // registration flag the reconciler writes.
    private func armMorningWindow(at alarmTime: Date, in defaults: UserDefaults) {
        let window = MorningBlockWindow(alarmTime: alarmTime, duration: .seconds(60 * 60), calendar: calendar)
        WakeAlarmStore.store(id: UUID(), fireDate: alarmTime, window: window, in: defaults)
        WakeAlarmStore.recordBlockRegistration(succeeded: true, in: defaults)
    }

    private func storeBedtime(hour: Int, minute: Int, in defaults: UserDefaults) {
        let bedtime = date(hour: hour, minute: minute)
        let window = MorningBlockWindow.centeredOn(bedtime, halfDuration: .seconds(30 * 60), calendar: calendar)
        BedtimeStore.store(bedtime: bedtime, window: window, calendar: calendar, in: defaults)
    }

    @Test func withoutABedtimeEveryOverrideIsAMorningOne() {
        withDefaults { defaults in
            #expect(OverrideContext.current(now: date(hour: 22, minute: 10), calendar: calendar, in: defaults) == .morning)
        }
    }

    @Test func insideTheBedtimeWindowTheOverrideSpendsTheEveningQuota() {
        withDefaults { defaults in
            storeBedtime(hour: 22, minute: 30, in: defaults)

            #expect(OverrideContext.current(now: date(hour: 22, minute: 10), calendar: calendar, in: defaults) == .bedtime)
        }
    }

    // The fallback outside every window is unchanged: the shield's manual open can land here.
    @Test func outsideTheBedtimeWindowTheOverrideFallsBackToTheMorning() {
        withDefaults { defaults in
            storeBedtime(hour: 22, minute: 30, in: defaults)

            #expect(OverrideContext.current(now: date(hour: 21, minute: 30), calendar: calendar, in: defaults) == .morning)
            #expect(OverrideContext.current(now: date(hour: 23, minute: 30), calendar: calendar, in: defaults) == .morning)
        }
    }

    @Test func aWindowWrappingPastMidnightStillClassifiesAsBedtime() {
        withDefaults { defaults in
            storeBedtime(hour: 23, minute: 50, in: defaults)

            #expect(OverrideContext.current(now: date(hour: 0, minute: 10, day: 2), calendar: calendar, in: defaults) == .bedtime)
        }
    }

    // Whether a shield actually comes down cannot be observed here — ManagedSettings writes report
    // nothing back and Family Controls does not work in the Simulator at all (same boundary as
    // BlockWindowMonitorTests). What is testable, and what was missing entirely, is that the
    // confirmed override reaches the clear at all, for the window it belongs to. Unconditionally:
    // the clear is what a shield outliving its interval is reached by, so it may not depend on a
    // window running.
    @Test func aConfirmedOverrideClearsTheShieldOfTheWindowItBelongsTo() {
        withDefaults { defaults in
            var cleared: [ManagedSettingsStore.Name] = []

            _ = OverrideContext.morning.unlock(now: date(hour: 15, minute: 0), calendar: calendar, in: defaults) {
                cleared.append($0)
            }
            #expect(cleared == [.morningBlock])

            _ = OverrideContext.bedtime.unlock(now: date(hour: 15, minute: 0), calendar: calendar, in: defaults) {
                cleared.append($0)
            }
            #expect(cleared == [.morningBlock, .bedtimeBlock])
        }
    }

    @Test func anOverrideInsideTheRunningWindowSpendsTheUnlockItClearsTheShieldFor() {
        withDefaults { defaults in
            armMorningWindow(at: date(hour: 7, minute: 0), in: defaults)

            let spent = OverrideContext.morning.unlock(
                now: date(hour: 7, minute: 10), calendar: calendar, in: defaults
            ) { _ in }

            #expect(spent)
            #expect(OverrideContext.morning.quota.remainingUnlocks(
                now: date(hour: 7, minute: 20), calendar: calendar, in: defaults
            ) == UnlockQuotaStore.morning.freeUnlockMaximum - 1)
            #expect(OverrideContext.bedtime.quota.remainingUnlocks(
                now: date(hour: 7, minute: 20), calendar: calendar, in: defaults
            ) == UnlockQuotaStore.bedtime.freeUnlockMaximum)
        }
    }

    // The delay and the reason still run outside the window — that friction is the product —
    // but there is no block to buy off, so the counter stays where it is. The harmful tap is not the
    // one at 15:00 (the day's slot has no use left anyway) but the one between midnight and the
    // window's start, which used to burn the unlock the morning was going to need.
    @Test func anOverrideWithNoWindowRunningSpendsNothing() {
        withDefaults { defaults in
            armMorningWindow(at: date(hour: 7, minute: 0), in: defaults)

            let spent = OverrideContext.morning.unlock(
                now: date(hour: 3, minute: 0), calendar: calendar, in: defaults
            ) { _ in }

            #expect(!spent)
            #expect(OverrideContext.morning.quota.remainingUnlocks(
                now: date(hour: 3, minute: 10), calendar: calendar, in: defaults
            ) == UnlockQuotaStore.morning.freeUnlockMaximum)
        }
    }

    // The same two predicates the reconciler arms on, so a window that is stored but never accepted
    // by DeviceActivity is not a shield either — it is exactly the state the status lines refuse to
    // call armed.
    @Test func aStoredButUnregisteredWindowIsNoShieldToPayFor() {
        withDefaults { defaults in
            armMorningWindow(at: date(hour: 7, minute: 0), in: defaults)
            WakeAlarmStore.recordBlockRegistration(succeeded: false, in: defaults)

            #expect(!OverrideContext.morning.shieldIsStanding(
                now: date(hour: 7, minute: 10), calendar: calendar, in: defaults
            ))
        }
    }

    // The evening runs the same check on its own two stores, and it is the context an override
    // inside the bedtime window resolves to.
    @Test func theEveningWindowIsCheckedAgainstItsOwnRegistration() {
        withDefaults { defaults in
            storeBedtime(hour: 22, minute: 30, in: defaults)
            let now = date(hour: 22, minute: 10)
            #expect(OverrideContext.current(now: now, calendar: calendar, in: defaults) == .bedtime)
            #expect(!OverrideContext.bedtime.shieldIsStanding(now: now, calendar: calendar, in: defaults))

            BedtimeStore.recordBlockRegistration(succeeded: true, in: defaults)
            let spent = OverrideContext.bedtime.unlock(now: now, calendar: calendar, in: defaults) { _ in }

            #expect(spent)
            #expect(OverrideContext.bedtime.quota.remainingUnlocks(now: now, calendar: calendar, in: defaults)
                == UnlockQuotaStore.bedtime.freeUnlockMaximum - 1)
        }
    }

    // The rollover is derived from `now` alone (UnlockQuotaStore.quotaAnchorDay) and the window
    // check may not enter it: a spent unlock still comes back the next day, and a day on which
    // nothing was spent still starts full.
    @Test func theQuotaRolloverIsUnchangedByTheWindowCheck() {
        withDefaults { defaults in
            armMorningWindow(at: date(hour: 7, minute: 0), in: defaults)

            _ = OverrideContext.morning.unlock(
                now: date(hour: 7, minute: 10), calendar: calendar, in: defaults
            ) { _ in }
            #expect(OverrideContext.morning.quota.remainingUnlocks(
                now: date(hour: 7, minute: 20), calendar: calendar, in: defaults
            ) == UnlockQuotaStore.morning.freeUnlockMaximum - 1)

            #expect(OverrideContext.morning.quota.remainingUnlocks(
                now: date(hour: 7, minute: 10, day: 2), calendar: calendar, in: defaults
            ) == UnlockQuotaStore.morning.freeUnlockMaximum)
        }
    }

    // Regression, same root cause as the quota anchor: the classification used to be measured from
    // the stored window start, so an edit that pushed that start past `now` reclassified an evening
    // override as a morning one — spending the wrong quota. Every edit here keeps `now` inside the
    // window, so the answer must not move with the start.
    @Test func editingTheBedtimeAcrossNowKeepsAnEveningOverrideAnEveningOne() {
        withDefaults { defaults in
            let now = date(hour: 22, minute: 10)
            storeBedtime(hour: 22, minute: 30, in: defaults)
            #expect(OverrideContext.current(now: now, calendar: calendar, in: defaults) == .bedtime)

            // Window 21:50-22:50: the start moves to before `now`.
            storeBedtime(hour: 22, minute: 20, in: defaults)
            #expect(OverrideContext.current(now: now, calendar: calendar, in: defaults) == .bedtime)

            // Window 22:10-23:10: the start crosses back onto `now` itself.
            storeBedtime(hour: 22, minute: 40, in: defaults)
            #expect(OverrideContext.current(now: now, calendar: calendar, in: defaults) == .bedtime)
        }
    }
}
