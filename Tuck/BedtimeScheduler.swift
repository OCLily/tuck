import Foundation
import Observation

// Mirrors WakeAlarmScheduler's status shape, minus everything AlarmKit: the bedtime window is a
// pure DeviceActivity registration with no alarm, no stopIntent and no authorization request of
// its own — Family Controls is asked for once in onboarding.
// Unlike the morning, DeviceActivity registration IS the whole operation here, so a MonitoringError
// legitimately becomes .unavailable rather than a side note.
@MainActor
@Observable
final class BedtimeScheduler {
    enum Status: Equatable {
        case idle
        case working
        case scheduled(Date)
        case cleared
        case unavailable(String)
    }

    private(set) var status: Status = .idle

    // 30 minutes before through 30 minutes after — the window is centered on the bedtime, not
    // a lead-in to it.
    static let halfWindow: Duration = .seconds(30 * 60)

    func setBedtime(_ bedtime: Date, now: Date = .now, calendar: Calendar = .current) {
        status = .working

        let window = MorningBlockWindow.centeredOn(bedtime, halfDuration: Self.halfWindow, calendar: calendar)
        // Booked before the store call: afterwards the old evening window and its length are gone.
        ProtectedTimeStore.accrue(now: now, calendar: calendar)
        // Persisted before registration: the bedtime is the user's stated intent and survives a
        // failed registration, so the next save (or a later authorization) can re-arm it.
        BedtimeStore.store(bedtime: bedtime, window: window, calendar: calendar)

        do {
            try BlockWindowMonitor.register(.bedtimeBlock, shielding: .bedtimeBlock, window: window)
            BedtimeStore.recordBlockRegistration(succeeded: true)
            // Bedtime set to 23:00 at 22:45: the 22:30-23:30 window is already running the moment it
            // is registered, so that occurrence is skipped whole rather than credited in full.
            ProtectedTimeStore.skipRunningOccurrence(
                endingAt: ProtectedTimeStore.runningOccurrenceEnd(of: window, at: now, calendar: calendar)
            )
            status = .scheduled(bedtime)
        } catch {
            BedtimeStore.recordBlockRegistration(succeeded: false)
            status = .unavailable(error.localizedDescription)
        }
    }

    // First statement, and nothing awaits in between, so this is the same point as "immediately
    // before BedtimeStore.clear()" and easier to read there: up to here the registration was alive,
    // so the span up to now is earned. No skip afterwards — nothing is registered here.
    func clearBedtime(now: Date = .now, calendar: Calendar = .current) {
        ProtectedTimeStore.accrue(now: now, calendar: calendar)
        BlockWindowMonitor.cancel(.bedtimeBlock, shielding: .bedtimeBlock)
        BedtimeStore.clear()
        status = .cleared
    }
}
