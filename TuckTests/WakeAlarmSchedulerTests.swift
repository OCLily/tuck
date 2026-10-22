import DeviceActivity
import Foundation
import Testing
@testable import Tuck

// The two halves of scheduling a wake alarm fail independently, and both were being flattened: the
// registration outcome vanished from the status the sheet reads, and the recovery half of Apple's
// own error was thrown away. Neither needs a device to check.
struct WakeAlarmSchedulerTests {
    private struct BothHalves: LocalizedError {
        var errorDescription: String? { "Das Fenster ließ sich nicht überwachen." }
        var recoverySuggestion: String? { "Erlaube den Bildschirmzeit-Zugriff." }
    }

    private struct DescriptionOnly: LocalizedError {
        var errorDescription: String? { "Das Fenster ließ sich nicht überwachen." }
    }

    @Test func theRecoverySuggestionSurvivesAlongsideTheDescription() {
        let reason = WakeAlarmScheduler.reason(for: BothHalves())

        #expect(reason.contains("Das Fenster ließ sich nicht überwachen."))
        #expect(reason.contains("Erlaube den Bildschirmzeit-Zugriff."))
    }

    @Test func anErrorWithoutASuggestionReadsExactlyAsItDidBefore() {
        let error = DescriptionOnly()

        #expect(WakeAlarmScheduler.reason(for: error) == error.localizedDescription)
    }

    // Against the real SDK rather than a stand-in: MonitoringError is the error this path catches,
    // .unauthorized is what every Simulator run produces, and it is a LocalizedError with both
    // halves declared. Whatever Apple fills in has to reach the sentence the user reads.
    @Test func theRealMonitoringErrorKeepsBothHalvesApplePopulates() {
        let error = DeviceActivityCenter.MonitoringError.unauthorized
        let reason = WakeAlarmScheduler.reason(for: error)

        #expect(reason.contains(error.localizedDescription))
        if let suggestion = error.recoverySuggestion {
            #expect(reason.contains(suggestion))
        }
    }

    // The auto-dismiss keys on this. With a bare `case .scheduled` it closed the sheet 1,2 s after a
    // registration that threw, taking the only statement of the reason with it.
    @MainActor
    @Test func onlyAnArmedWindowMayCloseTheSheet() {
        let fireDate = Date(timeIntervalSince1970: 1_772_000_000)

        #expect(WakeAlarmScheduler.Status.scheduled(fireDate, blockWindowArmed: true).isScheduledWithArmedWindow)
        #expect(!WakeAlarmScheduler.Status.scheduled(fireDate, blockWindowArmed: false).isScheduledWithArmedWindow)
        for status in [WakeAlarmScheduler.Status.idle, .working, .denied, .unavailable("—")] {
            #expect(!status.isScheduledWithArmedWindow)
        }
    }
}
