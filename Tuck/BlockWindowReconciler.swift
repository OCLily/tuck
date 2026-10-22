import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

// The re-arm half of the reconciliation check: a window is
// stored the moment the user sets it, but its registration throws .unauthorized while Family
// Controls has not been granted yet, and nothing else ever comes back to it. Both windows run
// through the same pass — the morning and the bedtime fail for exactly the same reason.
// Two entry points, one mechanism: reconcile() retries what never went through,
// applyPendingMorningDuration() re-registers what changed length, once that is safe.
@MainActor
enum BlockWindowReconciler {
    // One frozen `now` per pass, handed to every accrual, every skip and the tail call below. Without
    // it the tail call's own accrual would run against a clock that has moved by microseconds — small,
    // but it would slip past the idempotency guard at exactly the place that guard is for.
    //
    // The rule every accrual site here follows: only a span whose registration demonstrably stayed
    // alive throughout is credited. Where that is doubtful the span is skipped and countedThrough
    // moves past it anyway — under-count rather than over-count, never claiming more than is shown.
    static func reconcile(now: Date = .now, calendar: Calendar = .current) {
        // First of all, above the authorization guard: on a device restored from another one's
        // backup the stored selection carries tokens that resolve to nothing, and both branches
        // below would otherwise go on reasoning about a shield that cannot exist. Idempotent
        // — every pass after the first one on a device reads .leave.
        DeviceChangeGuard.run()

        guard AuthorizationCenter.shared.authorizationStatus == .approved else {
            // Access revoked in Settings after a registration that once went through: nothing is
            // monitoring either window any more, so their confirmations must go with it — otherwise
            // the calm "Sperrfenster bis HH:MM" keeps vouching for a block that is gone. The retry
            // below re-arms both once the access comes back.
            if WakeAlarmStore.scheduledAlarm() != nil {
                WakeAlarmStore.recordBlockRegistration(succeeded: false)
            }
            if BedtimeStore.bedtime() != nil {
                BedtimeStore.recordBlockRegistration(succeeded: false, at: now)
            }
            // After both flags, never before them. Before, they still read `true` — and the app does
            // not know WHEN the access was revoked, so it would credit exactly the occurrences that
            // fell after the revocation and carried nothing. With the flags cleared the doubtful span
            // is skipped and countedThrough still moves past it, so a later re-arm does not backfill
            // it either. The price is known and accepted: the occurrences that really were armed
            // before the revocation fall away with it.
            ProtectedTimeStore.accrue(now: now, calendar: calendar)
            return
        }

        // Before the re-arm block, never after it. After the two false -> true flips it would see a
        // `true` that has held for a millisecond and credit the whole skipped span. For the .disarm
        // branch below the same point is right for the opposite reason: up to here the registration
        // was alive, so that span is earned.
        ProtectedTimeStore.accrue(now: now, calendar: calendar)

        if let alarm = WakeAlarmStore.scheduledAlarm(), !WakeAlarmStore.blockRegistrationSucceeded() {
            let window = MorningBlockWindow(start: alarm.blockWindowStart, end: alarm.blockWindowEnd)
            let armed = register(.morningBlock, shielding: .morningBlock, window: window)
            WakeAlarmStore.recordBlockRegistration(succeeded: armed)
            if armed {
                // A retry that lands inside the window's own running occurrence: the elapsed half
                // was not monitored, so the occurrence is skipped whole rather than counted pro rata.
                ProtectedTimeStore.skipRunningOccurrence(
                    endingAt: ProtectedTimeStore.runningOccurrenceEnd(of: window, at: now, calendar: calendar)
                )
            }
        }

        if let bedtime = BedtimeStore.bedtime() {
            switch bedtimeWindowAction(
                access: SubscriptionAccess.current(),
                isArmed: BedtimeStore.blockRegistrationSucceeded()
            ) {
            case .arm:
                let window = MorningBlockWindow(start: bedtime.blockWindowStart, end: bedtime.blockWindowEnd)
                let armed = register(.bedtimeBlock, shielding: .bedtimeBlock, window: window)
                BedtimeStore.recordBlockRegistration(succeeded: armed, at: now)
                if armed {
                    ProtectedTimeStore.skipRunningOccurrence(
                        endingAt: ProtectedTimeStore.runningOccurrenceEnd(of: window, at: now, calendar: calendar)
                    )
                }
            // No skip here, nor in the revoked branch above: nothing is registered there, so nothing
            // is running that would have to be skipped — accrue already handles those over the flag.
            case .disarm:
                BlockWindowMonitor.cancel(.bedtimeBlock, shielding: .bedtimeBlock)
                BedtimeStore.recordBlockRegistration(succeeded: false, at: now)
            case .leave:
                break
            }
        }

        // Last, not first: if the retry above just re-armed the morning window, running this
        // before it would apply the pending length to the window that's about to be replaced,
        // costing a second stop/start pair in the same pass instead of zero. Ordering only saves
        // that redundant round-trip — there's no shield running outside the window either way.
        applyPendingMorningDuration(now: now, calendar: calendar)
    }

    enum BedtimeWindowAction: Equatable {
        case arm
        case disarm
        case leave
    }

    // The evening window is the one capability Plus gates, and the gate
    // has to reach the registration, not only the setup screen: a window that keeps firing after
    // the trial ends is a shield whose switch sits behind the same gate. So a lapse disarms it in
    // the same pass that re-arms it when Plus comes back. The stored bedtime is never touched —
    // it is the user's intent, not the entitlement, and it is what the re-arm reads.
    //
    // Pure, so the gate is testable without DeviceActivity: the pass above owns the system calls.
    static func bedtimeWindowAction(access: SubscriptionAccess, isArmed: Bool) -> BedtimeWindowAction {
        guard access.hasPlusAccess else { return isArmed ? .disarm : .leave }
        return isArmed ? .leave : .arm
    }

    // Second entry point, same mechanism: the length setting changes a window that is already
    // stored and possibly already registered, while the alarm and its fire date stay put. So the
    // job is to rebuild the window around the same anchor and register it again — startMonitoring
    // is the only place a new length can take effect, the stored end alone changes nothing the
    // system reads.
    //
    // But not while that window is running. Re-registering goes through BlockWindowMonitor.cancel,
        // whose shield clear is deliberate (fail-open) and here would drop a running block for
    // free: no unlock quota spent, no 30 seconds of breathing, and a re-registration that succeeds
    // afterwards would leave the morning screen confirming a block that is no longer applied. So a
    // change during the window is stored and nothing else, exactly what the settings footer
    // promises — the next pass, once the window is over, carries it into the registration.
    // Whether that later registration reaches DeviceActivity at all stays the open device question.
    static func applyPendingMorningDuration(
        now: Date = .now,
        calendar: Calendar = .current,
        in defaults: UserDefaults = UserDefaults(suiteName: TuckIdentifiers.appGroupSuiteName) ?? .standard
    ) {
        // Unconditional and before the guard: this is the only way to updateBlockWindow, so it is
        // the last moment the length the registration actually lived with is still readable. In the
        // no-op cases it costs one idempotent round (guard now > countedThrough) and saves having
        // the same call twice under the guard. Called a second time from reconcile()'s tail with the
        // same frozen `now`, where that guard makes it a guaranteed no-op.
        ProtectedTimeStore.accrue(now: now, calendar: calendar, in: defaults)

        guard let alarm = WakeAlarmStore.scheduledAlarm(in: defaults) else { return }

        let stored = MorningBlockWindow(start: alarm.blockWindowStart, end: alarm.blockWindowEnd)
        let selected = MorningBlockDurationStore.selected(in: defaults)
        guard stored.durationSeconds != selected.minutes * 60,
              !stored.contains(now, calendar: calendar)
        else { return }

        let window = MorningBlockWindow(
            alarmTime: alarm.fireDate,
            duration: selected.duration,
            calendar: calendar
        )
        WakeAlarmStore.updateBlockWindow(window, in: defaults)
        // A failed registration leaves the window stored and unconfirmed, exactly like the retry
        // path above, and reconcile() picks it up on the next activation.
        let armed = register(.morningBlock, shielding: .morningBlock, window: window)
        WakeAlarmStore.recordBlockRegistration(succeeded: armed, in: defaults)
        if armed {
            // The 07:45 case: the guard above checks the OLD window (07:00-07:30, over), while the
            // new 07:00-08:00 one contains 07:45. Without this skip that occurrence would be
            // credited with its full new length although it was armed halfway through.
            ProtectedTimeStore.skipRunningOccurrence(
                endingAt: ProtectedTimeStore.runningOccurrenceEnd(of: window, at: now, calendar: calendar),
                in: defaults
            )
        }
    }

    private static func register(
        _ activity: DeviceActivityName,
        shielding storeName: ManagedSettingsStore.Name,
        window: MorningBlockWindow
    ) -> Bool {
        do {
            try BlockWindowMonitor.register(activity, shielding: storeName, window: window)
            return true
        } catch {
            // A retry that fails again leaves the window exactly as it was: still stored, still
            // unconfirmed, and still honestly labelled as such. The next activation tries again.
            return false
        }
    }
}
