import Foundation
import Testing
@testable import Tuck

// AlarmKit never authorizes in the Simulator and
// DeviceActivityCenter always throws .unauthorized there, so the operation itself cannot be run
// here — the same reason WakeAlarmPermission and FamilyControlsAccessState exist as pure functions.
// What can be pinned is the half that is pure store state, and the wiring of the half that is not,
// the way MorningCelebrationWiringTests reads its source through #filePath.
//
// The claim is narrow and is exactly the failure mode to guard against: dropping the alarm without
// stopping its DeviceActivity registration leaves a repeating window armed for an alarm that no
// longer exists — the shield goes up every morning with nothing left in the app to explain it.
struct WakeAlarmCancellationTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suite = "WakeAlarmCancellationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        body(defaults)
    }

    private func cancelWakeAlarmBody() throws -> [String] {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Tuck/WakeAlarmScheduler.swift")
        let lines = try String(contentsOf: source, encoding: .utf8).components(separatedBy: "\n")
        let start = try #require(lines.firstIndex { $0.contains("func cancelWakeAlarm(") })
        let end = try #require(lines[start...].dropFirst().firstIndex { $0 == "    }" })
        return Array(lines[start...end])
    }

    // The mandatory step. Without it the registration outlives the alarm.
    @Test func cancellingStopsTheMorningRegistrationAndItsShield() throws {
        let body = try cancelWakeAlarmBody()

        let shieldCancel = try #require(body.firstIndex {
            $0.contains("BlockWindowMonitor.cancel(.morningBlock, shielding: .morningBlock)")
        })
        let storeClear = try #require(body.firstIndex { $0.contains("WakeAlarmStore.clear()") })
        let alarmCancel = try #require(body.firstIndex { $0.contains("AlarmKitBridge.cancel(id:") })

        // The required order: the alarm first, then the state that describes it, then the
        // registration that was made from that state.
        #expect(alarmCancel < storeClear)
        #expect(storeClear < shieldCancel)
    }

    // The id has to be read before clear() removes it, or the AlarmKit alarm is orphaned in the
    // system with nothing left in the app that could ever name it again.
    @Test func theAlarmIdIsReadBeforeTheStoreIsCleared() throws {
        let body = try cancelWakeAlarmBody()

        let read = try #require(body.firstIndex { $0.contains("WakeAlarmStore.scheduledAlarm()?.id") })
        let clear = try #require(body.firstIndex { $0.contains("WakeAlarmStore.clear()") })

        #expect(read < clear)
    }

    // Same reason scheduleWakeAlarm books before it replaces: clear() takes the window's two ends
    // away, and an unbooked morning would be lost rather than merely uncounted.
    @Test func timeAlreadyServedIsBookedBeforeTheWindowIsForgotten() throws {
        let body = try cancelWakeAlarmBody()

        let accrue = try #require(body.firstIndex { $0.contains("ProtectedTimeStore.accrue(") })
        let clear = try #require(body.firstIndex { $0.contains("WakeAlarmStore.clear()") })

        #expect(accrue < clear)
    }

    // The store half, run for real: after the clear nothing is left that any screen could read as a
    // set alarm or an entered window — including the registration flag, which would otherwise vouch
    // for the next window before it was ever registered.
    @Test func aClearedStoreLeavesNoAlarmNoWindowAndNoRegistrationFlag() {
        withDefaults { defaults in
            let fireDate = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 7))!
            let window = MorningBlockWindow(alarmTime: fireDate, duration: .seconds(30 * 60), calendar: calendar)
            WakeAlarmStore.store(id: UUID(), fireDate: fireDate, window: window, in: defaults)
            WakeAlarmStore.recordBlockRegistration(succeeded: true, in: defaults)
            WakeAlarmStore.recordDismissal(at: fireDate, in: defaults)

            WakeAlarmStore.clear(in: defaults)

            #expect(WakeAlarmStore.scheduledAlarm(in: defaults) == nil)
            #expect(WakeAlarmStore.dismissedAt(in: defaults) == nil)
            #expect(WakeAlarmStore.blockRegistrationSucceeded(in: defaults) == false)
        }
    }

    // The button may only be offered where there is something to switch off, and it may not sit
    // beside a run that is still in flight.
    @Test func theOffSwitchIsOfferedOnlyForAStoredAlarmAndNotWhileWorking() throws {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Tuck/WakeAlarmSetupView.swift")
        let lines = try String(contentsOf: source, encoding: .utf8).components(separatedBy: "\n")
        let gate = try #require(lines.firstIndex { $0.contains("scheduler.status != .working, WakeAlarmStore.scheduledAlarm() != nil") })
        let button = try #require(lines[gate...].firstIndex { $0.contains("showCancelConfirmation = true") })

        #expect(button - gate <= 2)
        #expect(lines.contains { $0.contains("await scheduler.cancelWakeAlarm()") })
    }
}
