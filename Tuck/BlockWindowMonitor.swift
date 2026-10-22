import DeviceActivity
import Foundation
import ManagedSettings

// The single DeviceActivity call site for both windows. Registration is idempotent by
// construction: the previous registration for that name is stopped before the new one starts, the
// same way WakeAlarmScheduler cancels the previous AlarmKit alarm before scheduling a new one.
// Without it a changed schedule leaves an orphaned registration nothing can reach anymore.
enum BlockWindowMonitor {
    // Throws MonitoringError (.unauthorized on every Simulator run, and on device until Family
    // Controls is granted). Callers surface it, they do not swallow it.
    static func register(
        _ activity: DeviceActivityName,
        shielding storeName: ManagedSettingsStore.Name,
        window: MorningBlockWindow
    ) throws {
        cancel(activity, shielding: storeName)
        let schedule = DeviceActivitySchedule(
            intervalStart: window.start,
            intervalEnd: window.end,
            // Both windows sit at a fixed time of day (docs/product-decisions-2026-09-02.md),
            // so the schedule re-arms itself daily instead of needing the app to be opened.
            repeats: true
        )
        try DeviceActivityCenter().startMonitoring(activity, during: schedule, events: events(for: activity, window: window))
        // After the throw, never before it: the count that the observation compares against is
        // "windows iOS accepted", and a registration that threw is exactly the case a count of
        // attempts would hide. Per window, so a bedtime that never got registered cannot hide
        // behind the morning's number. A name this build does not own counts nowhere.
        switch activity {
        case .morningBlock: BlockDiagnostics.record(.morningWindowsRegistered)
        case .bedtimeBlock: BlockDiagnostics.record(.bedtimeWindowsRegistered)
        default: break
        }
    }

    // Built here rather than handed in by the caller: startMonitoring overwrites the schedule AND
    // the events of that activity, so any call site that forgot to pass them would silently delete
    // them again. Both morning call sites (WakeAlarmScheduler, BlockWindowReconciler) go through
    // this one function, so the event cannot get lost by omission.
    //
    // Only the morning carries one. The notice has exactly one surface — the Guten-Morgen screen —
    // and an evening threshold has nowhere honest to land, while still adding scheduled work to a
    // process startMonitoring's documentation warns about overloading: too many concurrent
    // activities (.excessiveActivities, documented max 20) and activities that are too tightly
    // scheduled.
    private static func events(
        for activity: DeviceActivityName,
        window: MorningBlockWindow
    ) -> [DeviceActivityEvent.Name: DeviceActivityEvent] {
        guard activity == .morningBlock,
              let thresholdMinutes = ScreenTimeNotice.thresholdMinutes(forWindowSeconds: window.durationSeconds)
        else { return [:] }
        // All three target sets stay empty, which the SDK reads as "all activity"
        // (DeviceActivityEvent.includesAllActivity). That is the whole measurement: total frontmost
        // time in the window, not the blocked selection — see ScreenTimeNotice.
        //
        // Deliberately the iOS 15 initialiser, not the 17.4 one with includesPastActivity: that
        // flag rounds the retroactive part down to the full hour, so a window hanging off an
        // arbitrary wake time would count usage from before the window ever started.
        let event = DeviceActivityEvent(
            threshold: DateComponents(minute: thresholdMinutes)
        )
        return [.screenTimeInWindow: event]
    }

    // Clearing the shield along with the registration is the fail-open half of the design:
    // if the window is replaced while its shield is applied,
    // the intervalDidEnd that would have cleared it belongs to a schedule that no longer exists.
    // A missed block costs one window, a stranded shield blocks forever.
    static func cancel(_ activity: DeviceActivityName, shielding storeName: ManagedSettingsStore.Name) {
        // The empty-array default means "all activities" — both names must always be explicit.
        DeviceActivityCenter().stopMonitoring([activity])
        ShieldRelease.clear(storeName)
    }
}
