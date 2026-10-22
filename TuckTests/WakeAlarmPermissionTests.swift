import AlarmKit
import Testing
@testable import Tuck

// The wake screen reaches "the alarm permission is denied" on two paths, and until the onboarding
// gate they carried two different sentences — one of which promised that things continue anyway.
// AlarmKit never authorizes in the Simulator, so the resolution is a pure function, the same shape
// FamilyControlsAccessState has for the other permission.
@MainActor
struct WakeAlarmPermissionTests {
    @Test func aRefusalThatJustCameBackFromTheDialogIsDenied() {
        #expect(WakeAlarmPermission.isDenied(status: .denied, authorizationState: .notDetermined, hasStoredAlarm: false))
    }

    // The path a gated user actually sees: onboarding restarts at the welcome step on every launch,
    // so the screen is reached fresh, with the status back at idle and nothing ever stored.
    @Test func aFreshOpenAfterAnEarlierRefusalIsTheSameState() {
        #expect(WakeAlarmPermission.isDenied(status: .idle, authorizationState: .denied, hasStoredAlarm: false))
    }

    // Everything the alarm can still do outranks the permission state: a stored alarm means the
    // permission was granted at least once, and the line then belongs to the alarm, not the denial.
    @Test func aStoredAlarmIsNeverReportedAsDenied() {
        #expect(!WakeAlarmPermission.isDenied(status: .idle, authorizationState: .denied, hasStoredAlarm: true))
    }

    @Test func noOtherStatusReportsADenial() {
        let fireDate = Date(timeIntervalSince1970: 1_772_000_000)
        let statuses: [WakeAlarmScheduler.Status] = [
            .working,
            .scheduled(fireDate, blockWindowArmed: true),
            .scheduled(fireDate, blockWindowArmed: false),
            .unavailable("—")
        ]
        for status in statuses {
            #expect(!WakeAlarmPermission.isDenied(status: status, authorizationState: .denied, hasStoredAlarm: false))
        }
        #expect(!WakeAlarmPermission.isDenied(status: .idle, authorizationState: .authorized, hasStoredAlarm: false))
        #expect(!WakeAlarmPermission.isDenied(status: .idle, authorizationState: .notDetermined, hasStoredAlarm: false))
    }
}
