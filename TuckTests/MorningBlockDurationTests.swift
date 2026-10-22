import Testing
import Foundation
@testable import Tuck

struct MorningBlockDurationTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    // Throwaway suite per test, so nothing here touches the App-Group container the app and the
    // Monitor extension actually use.
    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suite = "MorningBlockDurationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        body(defaults)
    }

    private func alarmTime(hour: Int, minute: Int) -> Date {
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

    // The whole point of the default: an install from before this setting existed has no key and
    // ran on 30 minutes. If an empty store resolved to anything else, every existing user's morning
    // would change length without anyone touching a control.
    @Test func anEmptyStoreIsThirtyMinutes() {
        withDefaults { defaults in
            #expect(MorningBlockDurationStore.selected(in: defaults) == .thirty)
        }
    }

    @Test func aStoredChoiceSurvives() {
        withDefaults { defaults in
            for duration in MorningBlockDuration.allCases {
                MorningBlockDurationStore.store(duration, in: defaults)
                #expect(MorningBlockDurationStore.selected(in: defaults) == duration)
            }
        }
    }

    // A number this build does not know is not evidence of any choice — a downgrade, or a value
    // written by a later version, falls back to the same 30 minutes an empty store does.
    @Test func anUnknownStoredNumberFallsBackToThirty() {
        withDefaults { defaults in
            defaults.set(37, forKey: "morningBlockDurationMinutes")
            #expect(MorningBlockDurationStore.selected(in: defaults) == .thirty)
        }
    }

    // Every option has to clear MorningBlockWindow's product minimum on its own: an option the
    // clamp silently rewrites would show one length in Settings and block for another.
    @Test func noOptionIsRewrittenByTheProductMinimumClamp() {
        for duration in MorningBlockDuration.allCases {
            let window = MorningBlockWindow(
                alarmTime: alarmTime(hour: 7, minute: 0),
                duration: duration.duration,
                calendar: calendar
            )
            #expect(window.durationSeconds == duration.minutes * 60)
        }
    }

    @Test func eachOptionEndsAtItsOwnWallClockTime() {
        let expected: [(MorningBlockDuration, Int, Int)] = [
            (.thirty, 7, 30),
            (.fortyFive, 7, 45),
            (.sixty, 8, 0)
        ]
        for (duration, hour, minute) in expected {
            let window = MorningBlockWindow(
                alarmTime: alarmTime(hour: 7, minute: 0),
                duration: duration.duration,
                calendar: calendar
            )
            #expect(window.start.hour == 7)
            #expect(window.start.minute == 0)
            #expect(window.end.hour == hour)
            #expect(window.end.minute == minute)
        }
    }

    // The longer options wrap past midnight the same way the 30-minute one always did.
    @Test func theLongestOptionStillWrapsPastMidnight() {
        let window = MorningBlockWindow(
            alarmTime: alarmTime(hour: 23, minute: 50),
            duration: MorningBlockDuration.sixty.duration,
            calendar: calendar
        )

        #expect(window.end.hour == 0)
        #expect(window.end.minute == 50)
        #expect(window.durationSeconds == 60 * 60)
    }

    // The screen-time threshold is two thirds of the window, so it moves with the setting instead
    // of staying pinned to the 20 minutes the fixed window produced. Every option stays above the
    // SDK's fifteen-minute floor, i.e. none of them drops the event.
    @Test func theScreenTimeThresholdFollowsTheChosenLength() {
        let expected: [(MorningBlockDuration, Int)] = [(.thirty, 20), (.fortyFive, 30), (.sixty, 40)]
        for (duration, minutes) in expected {
            #expect(ScreenTimeNotice.thresholdMinutes(forWindowSeconds: duration.minutes * 60) == minutes)
        }
    }

    // The re-registration path rebuilds the window around the stored fire date and writes it back.
    // Only the end moves: the start is the alarm, and the dismissal anchor hangs off it.
    @Test func reapplyingALengthMovesOnlyTheEndOfTheStoredWindow() {
        withDefaults { defaults in
            let fireDate = alarmTime(hour: 6, minute: 30)
            let window = MorningBlockWindow(alarmTime: fireDate, duration: .seconds(30 * 60), calendar: calendar)
            WakeAlarmStore.store(id: UUID(), fireDate: fireDate, window: window, in: defaults)
            WakeAlarmStore.recordBlockRegistration(succeeded: true, in: defaults)

            let longer = MorningBlockWindow(
                alarmTime: fireDate,
                duration: MorningBlockDuration.sixty.duration,
                calendar: calendar
            )
            WakeAlarmStore.updateBlockWindow(longer, in: defaults)

            let stored = WakeAlarmStore.scheduledAlarm(in: defaults)
            #expect(stored?.blockWindowStart.hour == 6)
            #expect(stored?.blockWindowStart.minute == 30)
            #expect(stored?.blockWindowEnd.hour == 7)
            #expect(stored?.blockWindowEnd.minute == 30)
            // The new window is unregistered until startMonitoring says otherwise — the previous
            // success may not vouch for a window of a different length.
            #expect(WakeAlarmStore.blockRegistrationSucceeded(in: defaults) == false)
        }
    }

    // Rewriting the window may not cost the dismissal anchor: store(id:fireDate:window:) clears it,
    // which would let the same morning be counted twice. That is why this path has its own writer.
    @Test func reapplyingALengthKeepsTheDismissalAnchor() {
        withDefaults { defaults in
            let fireDate = alarmTime(hour: 6, minute: 30)
            let window = MorningBlockWindow(alarmTime: fireDate, duration: .seconds(30 * 60), calendar: calendar)
            WakeAlarmStore.store(id: UUID(), fireDate: fireDate, window: window, in: defaults)

            let dismissal = alarmTime(hour: 6, minute: 35)
            WakeAlarmStore.recordDismissal(at: dismissal, in: defaults)
            WakeAlarmStore.updateBlockWindow(
                MorningBlockWindow(
                    alarmTime: fireDate,
                    duration: MorningBlockDuration.fortyFive.duration,
                    calendar: calendar
                ),
                in: defaults
            )

            #expect(WakeAlarmStore.dismissedAt(in: defaults) == dismissal)
            #expect(!WakeAlarmStore.isFirstDismissal(
                ofMorningContaining: alarmTime(hour: 6, minute: 40),
                calendar: calendar,
                in: defaults
            ))
        }
    }

    // The shield-clearing path is BlockWindowMonitor.cancel, reachable only from inside
    // BlockWindowReconciler's register(_:shielding:window:) — and every one of its callers writes
    // the registration flag from its return value, which in the Simulator (Family Controls
    // unauthorized, always) is false. A flag that is still true after the change therefore proves
    // that register, and with it stopMonitoring plus ShieldRelease.clear, never ran: the
    // running block keeps standing, and the morning screen keeps confirming a window that is
    // actually applied. The untouched window end is the second half of the same proof.
    @MainActor
    @Test func aLengthChangeDuringTheRunningWindowLeavesTheRegistrationAlone() {
        withDefaults { defaults in
            let fireDate = alarmTime(hour: 6, minute: 30)
            let window = MorningBlockWindow(alarmTime: fireDate, duration: .seconds(30 * 60), calendar: calendar)
            WakeAlarmStore.store(id: UUID(), fireDate: fireDate, window: window, in: defaults)
            WakeAlarmStore.recordBlockRegistration(succeeded: true, in: defaults)
            MorningBlockDurationStore.store(.sixty, in: defaults)

            BlockWindowReconciler.applyPendingMorningDuration(
                now: alarmTime(hour: 6, minute: 45),
                calendar: calendar,
                in: defaults
            )

            let stored = WakeAlarmStore.scheduledAlarm(in: defaults)
            #expect(stored?.blockWindowEnd.hour == 7)
            #expect(stored?.blockWindowEnd.minute == 0)
            #expect(WakeAlarmStore.blockRegistrationSucceeded(in: defaults))
            // The choice itself is never the thing that gets dropped — only its registration waits.
            #expect(MorningBlockDurationStore.selected(in: defaults) == .sixty)
        }
    }

    // The other half: outside the window the same call does the whole job it always did. Only the
    // stored end is asserted — whether startMonitoring accepts the schedule is device-only.
    @MainActor
    @Test func aLengthChangeOutsideTheWindowReachesTheStoredWindow() {
        withDefaults { defaults in
            let fireDate = alarmTime(hour: 6, minute: 30)
            let window = MorningBlockWindow(alarmTime: fireDate, duration: .seconds(30 * 60), calendar: calendar)
            WakeAlarmStore.store(id: UUID(), fireDate: fireDate, window: window, in: defaults)
            MorningBlockDurationStore.store(.sixty, in: defaults)

            BlockWindowReconciler.applyPendingMorningDuration(
                now: alarmTime(hour: 12, minute: 0),
                calendar: calendar,
                in: defaults
            )

            let stored = WakeAlarmStore.scheduledAlarm(in: defaults)
            #expect(stored?.blockWindowStart.hour == 6)
            #expect(stored?.blockWindowStart.minute == 30)
            #expect(stored?.blockWindowEnd.hour == 7)
            #expect(stored?.blockWindowEnd.minute == 30)
        }
    }

    // The window is half-open at both ends of this decision: its own start is still inside it, its
    // own end is already over. A change at 07:00 sharp may therefore land immediately.
    @MainActor
    @Test func theWindowsOwnEndAlreadyCountsAsOver() {
        withDefaults { defaults in
            let fireDate = alarmTime(hour: 6, minute: 30)
            let window = MorningBlockWindow(alarmTime: fireDate, duration: .seconds(30 * 60), calendar: calendar)
            WakeAlarmStore.store(id: UUID(), fireDate: fireDate, window: window, in: defaults)
            MorningBlockDurationStore.store(.fortyFive, in: defaults)

            BlockWindowReconciler.applyPendingMorningDuration(
                now: alarmTime(hour: 7, minute: 0),
                calendar: calendar,
                in: defaults
            )

            #expect(WakeAlarmStore.scheduledAlarm(in: defaults)?.blockWindowEnd.minute == 15)
        }
    }

    // The setting the user did not change may not cost a registration either: without this the
    // reconcile pass would re-register the morning window on every activation, and each of those
    // runs the same shield clear.
    @MainActor
    @Test func anUnchangedLengthRegistersNothing() {
        withDefaults { defaults in
            let fireDate = alarmTime(hour: 6, minute: 30)
            let window = MorningBlockWindow(alarmTime: fireDate, duration: .seconds(30 * 60), calendar: calendar)
            WakeAlarmStore.store(id: UUID(), fireDate: fireDate, window: window, in: defaults)
            WakeAlarmStore.recordBlockRegistration(succeeded: true, in: defaults)

            BlockWindowReconciler.applyPendingMorningDuration(
                now: alarmTime(hour: 12, minute: 0),
                calendar: calendar,
                in: defaults
            )

            #expect(WakeAlarmStore.blockRegistrationSucceeded(in: defaults))
        }
    }
}
