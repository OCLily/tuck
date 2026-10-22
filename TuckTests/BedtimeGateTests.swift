import Testing
import DeviceActivity
import Foundation
@testable import Tuck

// The evening window is the one capability Plus gates. Two halves, both
// derived from the same access state: the setup screen a free user sees instead of the picker, and
// the registration that may not outlive the access it was made under. Nothing here touches
// DeviceActivity or StoreKit — the gate is a decision, the system calls are what it decides about.
struct BedtimeGateTests {
    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suite = "BedtimeGateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        body(defaults)
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    private func date(day: Int, hour: Int = 20) -> Date {
        calendar.date(from: DateComponents(
            calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 9, day: day, hour: hour
        ))!
    }

    // Day one of a fresh install: reaching the bedtime step is itself what starts the trial
    // (TrialTriggerTests), so this is the state the step is actually entered in — the
    // picker, never the gate. The gate below is for the day it runs out.
    @Test func aRunningTrialOpensTheBedtimeWindow() {
        withDefaults { defaults in
            TrialStore.startIfNeeded(now: date(day: 1), in: defaults)

            let access = SubscriptionAccess.current(now: date(day: 1), in: defaults)
            #expect(access == .trial(daysRemaining: TrialStore.lengthInDays))
            #expect(access.hasPlusAccess)
        }
    }

    // Day fifteen, and nothing had to run for it: the same read that grants the window on day one
    // withholds it here.
    @Test func anExpiredTrialWithoutASubscriptionClosesIt() {
        withDefaults { defaults in
            TrialStore.startIfNeeded(now: date(day: 1), in: defaults)

            let access = SubscriptionAccess.current(now: date(day: 15), in: defaults)
            #expect(access == .free)
            #expect(!access.hasPlusAccess)
        }
    }

    @Test func anActiveSubscriptionOpensItPastTheTrial() {
        withDefaults { defaults in
            TrialStore.startIfNeeded(now: date(day: 1), in: defaults)
            SubscriptionTierStore.store(.plus, in: defaults)

            #expect(SubscriptionAccess.current(now: date(day: 15), in: defaults).hasPlusAccess)
            #expect(SubscriptionAccess.current(now: date(day: 90), in: defaults).hasPlusAccess)
        }
    }

    // A free user who never had a trial at all — the state the shield extensions read, where
    // nothing may start a trial by being looked at.
    @Test func anInstallWithoutATrialIsClosedTooAndStaysThatWay() {
        withDefaults { defaults in
            #expect(!SubscriptionAccess.current(now: date(day: 1), in: defaults).hasPlusAccess)
            #expect(TrialStore.startedAt(in: defaults) == nil)
        }
    }

    // The gate has to reach the registration, not only the screen: the setup screen is behind the
    // same gate, so a window that keeps firing after the access ended has no switch left.
    @MainActor
    @Test func aLapsedAccessDisarmsTheRegisteredWindow() {
        #expect(BlockWindowReconciler.bedtimeWindowAction(access: .free, isArmed: true) == .disarm)
    }

    // Once. A second pass may not spend another stopMonitoring plus shield clear on a window that
    // is already disarmed.
    @MainActor
    @Test func aWindowThatIsAlreadyDisarmedIsLeftAlone() {
        #expect(BlockWindowReconciler.bedtimeWindowAction(access: .free, isArmed: false) == .leave)
    }

    // The re-arm is the same path an unauthorized registration takes: the stored bedtime survives
    // the lapse, so returning to Plus needs no second setup.
    @MainActor
    @Test func returningToPlusReArmsTheStoredWindow() {
        for access in [SubscriptionAccess.trial(daysRemaining: 3), .subscribed(.plus)] {
            #expect(BlockWindowReconciler.bedtimeWindowAction(access: access, isArmed: false) == .arm)
            #expect(BlockWindowReconciler.bedtimeWindowAction(access: access, isArmed: true) == .leave)
        }
    }

    // Keeping the bedtime through a lapse is the decision, being unable to remove it was not.
    // The gate branch reaches the same clear the setup branch does, and it leaves nothing behind —
    // neither the time nor the registration flag that vouches for it.
    @MainActor
    @Test func aLockedUserCanRemoveTheStoredBedtimeCompletely() {
        withDefaults { defaults in
            storeBedtime(in: defaults)
            BedtimeStore.recordBlockRegistration(succeeded: true, in: defaults)
            #expect(BlockWindowReconciler.bedtimeWindowAction(access: .free, isArmed: true) == .disarm)

            BedtimeStore.clear(in: defaults)

            #expect(BedtimeStore.bedtime(in: defaults) == nil)
            #expect(!BedtimeStore.blockRegistrationSucceeded(in: defaults))
        }
    }

    // The surprise the removal exists to end: a forgotten trial bedtime used to arm itself again the
    // moment Plus came back. The re-arm decision itself is unchanged — it just has nothing to read.
    // Its guard is `if let bedtime = BedtimeStore.bedtime()` in reconcile(), which is what this pins
    // either side of the clear; the action below is what would run if that guard passed.
    @MainActor
    @Test func nothingReArmsAfterTheRemovalBecauseNothingIsStored() {
        withDefaults { defaults in
            storeBedtime(in: defaults)
            #expect(BedtimeStore.bedtime(in: defaults) != nil)

            BedtimeStore.clear(in: defaults)

            #expect(BedtimeStore.bedtime(in: defaults) == nil)
            #expect(BlockWindowReconciler.bedtimeWindowAction(access: .subscribed(.plus), isArmed: false) == .arm)
        }
    }

    // The half the reconciler cannot cover: iOS goes on firing a registration made under Plus
    // whether or not the app is ever opened again, so the monitor extension asks the same question
    // one more time, in the process that writes the shield.
    @Test func theMonitorShieldsTheEveningWindowWhilePlusHolds() {
        for access in [SubscriptionAccess.trial(daysRemaining: 1), .subscribed(.plus)] {
            #expect(BlockWindowEntitlement.action(for: .bedtimeBlock, access: access) == .shield)
        }
    }

    // The day after the trial: the callback still arrives, and what it must not do is draw a paid
    // block screen for free — nor leave one standing from an occurrence that never ended.
    @Test func theMonitorReleasesTheEveningWindowOnceAccessIsGone() {
        #expect(BlockWindowEntitlement.action(for: .bedtimeBlock, access: .free) == .release)
    }

    // The morning is free and stays free (docs/SSOT.md). A gate that ever reached it would take away
    // the whole product from every free user — which is why the check names the evening explicitly
    // instead of asking "which windows are paid".
    @Test func theMorningWindowIsNeverGated() {
        for access in [SubscriptionAccess.free, .trial(daysRemaining: 1), .subscribed(.plus)] {
            #expect(BlockWindowEntitlement.action(for: .morningBlock, access: access) == .shield)
        }
    }

    // An activity name this build does not own never reaches the gate — storeName(for:) drops it
    // first, and that guard is where an unknown name belongs. This pins that the entitlement check
    // does not quietly become a second, differently-shaped name filter.
    @Test func anUnknownActivityIsNotTreatedAsTheEveningWindow() {
        #expect(BlockWindowEntitlement.action(for: DeviceActivityName("somethingElse"), access: .free) == .shield)
    }

    private func storeBedtime(in defaults: UserDefaults) {
        let bedtime = date(day: 1, hour: 22)
        let window = MorningBlockWindow.centeredOn(bedtime, halfDuration: .seconds(30 * 60), calendar: calendar)
        BedtimeStore.store(bedtime: bedtime, window: window, calendar: calendar, in: defaults)
    }
}
