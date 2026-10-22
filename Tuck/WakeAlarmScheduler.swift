import AlarmKit
import Foundation
import Observation
import SwiftUI

struct WakeAlarmMetadata: AlarmMetadata {}

@MainActor
@Observable
final class WakeAlarmScheduler {
    enum Status: Equatable {
        case idle
        case working
        // The alarm and its block window are scheduled in one call and fail independently, so the
        // success case carries both answers: without the second one, a run whose registration threw
        // was indistinguishable from a clean one, and the sheet closed itself over the reason.
        case scheduled(Date, blockWindowArmed: Bool)
        case denied
        case unavailable(String)

        var isScheduledWithArmedWindow: Bool {
            if case .scheduled(_, blockWindowArmed: true) = self { return true }
            return false
        }
    }

    private(set) var status: Status = .idle
    private(set) var authorizationState: AlarmManager.AuthorizationState = .notDetermined
    // The reason stays apart from `status` on purpose — the outcome rides along in .scheduled, the
    // wording does not. A MonitoringError (.unauthorized while Family Controls is not granted)
    // leaves the alarm scheduled, and folding that into .unavailable would tell the user the alarm
    // was not set, which is false.
    private(set) var blockRegistrationError: String?

    func refreshAuthorizationState() async {
        authorizationState = await AlarmKitBridge.authorizationState()
    }

    // A clock rather than a date: the authorization prompt below can hold this flow for minutes, and
    // everything that books time has to run on the time it actually runs at, not on the time this
    // call started. Still injectable, which a bare Date.now would not be.
    func scheduleWakeAlarm(
        wakeTime: Date,
        weekdays: Set<WakeAlarmWeekday> = WakeAlarmWeekdayStore.selected(),
        clock: @Sendable () -> Date = { .now },
        calendar: Calendar = .current
    ) async {
        status = .working
        blockRegistrationError = nil

        let days = WakeAlarmWeekdayStore.normalized(weekdays)

        guard let time = WakeAlarmDate.timeOfDay(forWakeTime: wakeTime, calendar: calendar),
              let fireDate = WakeAlarmDate.nextFireDate(
                  forWakeTime: wakeTime,
                  after: clock(),
                  weekdays: days,
                  calendar: calendar
              )
        else {
            status = .unavailable(String(localized: "Diese Weckzeit lässt sich im Kalender nicht auflösen."))
            return
        }

        do {
            let state = try await AlarmKitBridge.requestAuthorization()
            authorizationState = state
            guard state == .authorized else {
                status = .denied
                return
            }

            // Read once, here, and used by both the accrual and the skip below. The prompt above may
            // have taken minutes; a window end that fell into it belongs to this pass, and a window
            // that started during it has to be seen as running by the skip. One reading rather than
            // two calls to clock(), so accrual and skip cannot disagree about what time it is.
            let now = clock()

            // Every schedule() call needs a fresh id, so without this the previously scheduled
            // alarm stays armed forever, unreachable from the app, and eventually trips
            // AlarmManager.AlarmError.maximumLimitReached. The store is cleared right away: from
            // here on the old alarm is gone, whether or not the new one ends up being scheduled.
            // The last moment the old window is readable, so it is booked with the length it
            // actually ran under. The store() below needs no second call: with no previous id there
            // was no stored window to lose, and with one this call has already booked it.
            ProtectedTimeStore.accrue(now: now, calendar: calendar)

            if let previousID = WakeAlarmStore.scheduledAlarm()?.id {
                await AlarmKitBridge.cancel(id: previousID)
                WakeAlarmStore.clear()
            }

            let id = UUID()
            try await AlarmKitBridge.scheduleWakeAlarm(
                id: id,
                hour: time.hour,
                minute: time.minute,
                weekdays: days.localeWeekdays
            )

            // After the schedule call, never before it: the stored selection is what the monitor
            // extension gates the shield on, and writing it on the denied or failed path would
            // narrow the block window to days the still-live previous alarm does not ring on.
            WakeAlarmWeekdayStore.store(days)

            // The block window is anchored to the alarm's scheduled fire date and
            // computed right here, at scheduling time (docs/product-decisions-2026-09-02.md) — not
            // from a stopIntent callback, whose reliability is unverified.
            let window = MorningBlockWindow(
                alarmTime: fireDate,
                duration: MorningBlockDurationStore.selected().duration,
                calendar: calendar
            )
            WakeAlarmStore.store(id: id, fireDate: fireDate, window: window)

            // Same calm degradation as the AlarmKit catch below, but scoped: a MonitoringError
            // means the block window is not armed, not that the alarm failed.
            var blockWindowArmed = true
            do {
                try BlockWindowMonitor.register(.morningBlock, shielding: .morningBlock, window: window)
                WakeAlarmStore.recordBlockRegistration(succeeded: true)
                // An alarm set so that its window is already running: the elapsed part of that
                // occurrence was not monitored, so the occurrence is skipped whole.
                ProtectedTimeStore.skipRunningOccurrence(
                    endingAt: ProtectedTimeStore.runningOccurrenceEnd(of: window, at: now, calendar: calendar)
                )
            } catch {
                WakeAlarmStore.recordBlockRegistration(succeeded: false)
                blockRegistrationError = Self.reason(for: error)
                blockWindowArmed = false
            }

            status = .scheduled(fireDate, blockWindowArmed: blockWindowArmed)
        } catch {
            status = .unavailable(error.localizedDescription)
        }
    }

    // Until this existed, AlarmKitBridge.cancel
    // was reachable from exactly one place — the replacement inside scheduleWakeAlarm — so a set
    // alarm could be moved but never taken back.
    //
    // The three steps are one operation and the order is the point. The shield cancel is not
    // optional bookkeeping: DeviceActivityCenter keeps the morning registration until it is stopped
    // by name, so clearing the store alone would leave a repeating window armed for an alarm that
    // no longer exists — the shield would go up every morning with nothing in the app left to
    // explain it, and no stored window for the reconciler to reason about. ShieldRelease.clear
    // rides along inside BlockWindowMonitor.cancel, which is the fail-open half of the design.
    func cancelWakeAlarm(clock: @Sendable () -> Date = { .now }, calendar: Calendar = .current) async {
        status = .working
        blockRegistrationError = nil

        // The last moment the window is readable, same as in scheduleWakeAlarm above: clear() takes
        // its two ends away, and time already served would otherwise never be booked.
        ProtectedTimeStore.accrue(now: clock(), calendar: calendar)

        if let id = WakeAlarmStore.scheduledAlarm()?.id {
            await AlarmKitBridge.cancel(id: id)
        }
        WakeAlarmStore.clear()
        BlockWindowMonitor.cancel(.morningBlock, shielding: .morningBlock)

        status = .idle
    }

    // DeviceActivityCenter.MonitoringError is a LocalizedError with two halves —
    // `errorDescription` and `recoverySuggestion`, both declared in DeviceActivity.swiftinterface —
    // while `localizedDescription` returns the first one alone. The second is the half that says
    // what to do about it, and it was being thrown away at the one place it exists.
    nonisolated static func reason(for error: Error) -> String {
        let description = error.localizedDescription
        guard let suggestion = (error as? LocalizedError)?.recoverySuggestion, !suggestion.isEmpty
        else { return description }
        return "\(description) \(suggestion)"
    }
}

// AlarmManager is a non-Sendable class behind a static `shared`. Same shape as
// FamilyControlsAuthorization: touch `.shared` only inside a nonisolated async context so the
// instance never crosses an isolation boundary.
private enum AlarmKitBridge {
    nonisolated static func authorizationState() async -> AlarmManager.AuthorizationState {
        AlarmManager.shared.authorizationState
    }

    nonisolated static func requestAuthorization() async throws -> AlarmManager.AuthorizationState {
        try await AlarmManager.shared.requestAuthorization()
    }

    // cancel(id:) throws for an alarm that already fired or is otherwise unknown to the system —
    // the ordinary case the morning after. That must not stop the next alarm from being set.
    nonisolated static func cancel(id: UUID) async {
        try? AlarmManager.shared.cancel(id: id)
    }

    nonisolated static func scheduleWakeAlarm(
        id: UUID,
        hour: Int,
        minute: Int,
        weekdays: [Locale.Weekday]
    ) async throws {
        let alert = AlarmPresentation.Alert(title: "Guten Morgen")
        let attributes = AlarmAttributes(
            presentation: AlarmPresentation(alert: alert),
            metadata: WakeAlarmMetadata(),
            // Pinned to the light literal rather than the appearance-resolving token: this colour
            // is encoded into AlarmAttributes and rendered by the system's alarm UI, outside
            // SwiftUI's environment, where a dynamic UIColor has no defined resolution. Same class
            // of surface as the shield.
            tintColor: Color.LightPalette.charcoalGreen
        )
        // Alarm.Schedule.Relative is the only recurring form AlarmKit offers, and its Recurrence
        // enum only knows .weekly([Locale.Weekday]) and .never — "daily" is all seven weekdays, and
        // a real subset is the same call with fewer of them.
        let schedule = Alarm.Schedule.Relative(
            time: Alarm.Schedule.Relative.Time(hour: hour, minute: minute),
            repeats: .weekly(weekdays)
        )
        let configuration = AlarmManager.AlarmConfiguration.alarm(
            schedule: .relative(schedule),
            attributes: attributes,
            stopIntent: StopWakeAlarmIntent()
        )

        _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
    }
}
