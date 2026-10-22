import Testing
import Foundation
import DeviceActivity
@testable import Tuck

// What is testable without a device: that the registration call site is reached, that its failure
// is a catchable MonitoringError rather than a trap, and that a failed registration still leaves
// the app in a coherent state. Whether a shield actually goes up cannot be checked here — Family
// Controls does not work in the Simulator, so .unauthorized is the expected outcome of every run.
struct BlockWindowMonitorTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    @Test func registrationEitherSucceedsOrFailsAsACatchableMonitoringError() {
        let bedtime = calendar.date(from: DateComponents(
            calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 9, day: 1, hour: 22, minute: 30
        ))!
        let window = MorningBlockWindow.centeredOn(bedtime, halfDuration: .seconds(30 * 60), calendar: calendar)

        do {
            try BlockWindowMonitor.register(.bedtimeBlock, shielding: .bedtimeBlock, window: window)
        } catch let error as DeviceActivityCenter.MonitoringError {
            #expect(error == .unauthorized || error == .intervalTooShort || error == .invalidDateComponents)
        } catch {
            Issue.record("startMonitoring threw something other than MonitoringError: \(error)")
        }

        BlockWindowMonitor.cancel(.bedtimeBlock, shielding: .bedtimeBlock)
    }

    // Cancelling something that was never registered is the ordinary case (first launch, or a
    // Simulator run where registration never succeeded) and must stay a no-op.
    @Test func cancellingAnUnregisteredWindowIsHarmless() {
        BlockWindowMonitor.cancel(.bedtimeBlock, shielding: .bedtimeBlock)
        BlockWindowMonitor.cancel(.morningBlock, shielding: .morningBlock)
    }

    @MainActor
    @Test func aBedtimeIsPersistedEvenWhenItsRegistrationFails() {
        let scheduler = BedtimeScheduler()
        let bedtime = calendar.date(from: DateComponents(
            calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 9, day: 1, hour: 22, minute: 30
        ))!

        scheduler.setBedtime(bedtime, calendar: calendar)

        // Either outcome is correct here; the point is that neither is a crash and both leave the
        // user's stated bedtime on disk so a later authorization can re-arm it.
        switch scheduler.status {
        case .scheduled, .unavailable:
            break
        default:
            Issue.record("setBedtime left an unexpected status: \(scheduler.status)")
        }

        let stored = BedtimeStore.bedtime()
        #expect(stored?.time.hour == 22)
        #expect(stored?.blockWindowStart.hour == 22)
        #expect(stored?.blockWindowStart.minute == 0)
        #expect(stored?.blockWindowEnd.hour == 23)

        scheduler.clearBedtime()
        #expect(BedtimeStore.bedtime() == nil)
        #expect(scheduler.status == .cleared)
    }
}
