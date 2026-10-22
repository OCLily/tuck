import Foundation
import ManagedSettings
import Testing
@testable import Tuck

// The step between the 30 seconds and the unlock: the chosen reason mirrored back, and two equally
// weighted choices. What is testable of it is the phase decision, the booking the unlock branch
// performs, and the copy rules the mirrored line has to hold.
struct ReconsiderStepTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suite = "ReconsiderStepTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        body(defaults)
    }

    private func date(hour: Int, minute: Int) -> Date {
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

    private func armMorningWindow(at alarmTime: Date, in defaults: UserDefaults) {
        let window = MorningBlockWindow(alarmTime: alarmTime, duration: .seconds(60 * 60), calendar: calendar)
        WakeAlarmStore.store(id: UUID(), fireDate: alarmTime, window: window, in: defaults)
        WakeAlarmStore.recordBlockRegistration(succeeded: true, in: defaults)
    }

    // The behaviour change against the auto-unlock this replaces, and the decision that no reason
    // gets an exception: an exempt "Notfall" would be the first mechanical reason to always pick it.
    @Test func everyReasonLeavesTheTimerOnTheReconsiderStepRatherThanUnlocked() {
        for reason in OverrideReason.allCases {
            #expect(FlowPhase.afterBreathing(reason: reason) == .reconsider(reason))
        }
    }

    // The reason chosen before the timer is the one the unlock is booked for.
    @Test func theReasonSurvivesTheTimer() {
        #expect(FlowPhase.afterBreathing(reason: .arbeit) != .reconsider(.notfall))
    }

    // The unlock branch has to do what the old auto-path did in one step: spend the unlock, ask
    // the shield to come down, and read the allowance back — the confirmation screen renders that
    // second half, so a booking that skips it reports yesterday's number.
    @Test func theUnlockBranchSpendsTheQuotaClearsTheShieldAndReadsTheAllowanceBack() {
        withDefaults { defaults in
            armMorningWindow(at: date(hour: 7, minute: 0), in: defaults)
            var cleared: [ManagedSettingsStore.Name] = []

            let booking = OverrideContext.morning.bookUnlock(
                now: date(hour: 7, minute: 10), calendar: calendar, in: defaults
            ) { cleared.append($0) }

            #expect(booking.spentUnlock)
            #expect(cleared == [.morningBlock])
            #expect(booking.allowance == .limited(UnlockQuotaStore.morning.freeUnlockMaximum - 1))
        }
    }

    // The window-less case survives the new call site: outside every registered window the booking still runs, still
    // clears, and still costs nothing — the allowance it hands back is the untouched one.
    @Test func theUnlockBranchOutsideEveryWindowCostsNothing() {
        withDefaults { defaults in
            armMorningWindow(at: date(hour: 7, minute: 0), in: defaults)
            var cleared: [ManagedSettingsStore.Name] = []

            let booking = OverrideContext.morning.bookUnlock(
                now: date(hour: 3, minute: 0), calendar: calendar, in: defaults
            ) { cleared.append($0) }

            #expect(!booking.spentUnlock)
            #expect(cleared == [.morningBlock])
            #expect(booking.allowance == .limited(UnlockQuotaStore.morning.freeUnlockMaximum))
        }
    }

    // "Ich lass es doch" dismisses and books nothing at all. The branch has no call to pin, so what
    // is pinned is its effect: after a timer that ran out without a booking the quota is where it
    // was and no shield was asked to come down.
    @Test func theDismissBranchLeavesTheQuotaAndTheShieldUntouched() {
        withDefaults { defaults in
            armMorningWindow(at: date(hour: 7, minute: 0), in: defaults)
            let now = date(hour: 7, minute: 10)

            #expect(FlowPhase.afterBreathing(reason: .anderes) == .reconsider(.anderes))

            #expect(OverrideContext.morning.quota.allowance(now: now, calendar: calendar, in: defaults)
                == .limited(UnlockQuotaStore.morning.freeUnlockMaximum))
            #expect(OverrideContext.morning.shieldIsStanding(now: now, calendar: calendar, in: defaults))
        }
    }

    // Every reason has its own line, all three are distinct, and each one names the reason that was
    // actually picked — a mirror that shows the wrong word is worse than none.
    @Test func everyReasonHasItsOwnLineAndTheLineNamesThatReason() {
        let lines = ReconsiderCopy.reasonReflections
        #expect(lines.count == OverrideReason.allCases.count)
        #expect(Set(lines).count == OverrideReason.allCases.count)
        for reason in OverrideReason.allCases {
            #expect(ReconsiderCopy.reasonReflection(for: reason).contains(reason.displayName))
        }
    }

    // The vocabulary ban the shield subtitle carries, now on the line that stands where the fact
    // pool stood: it names the reason, it never addresses or grades the reader. And it is never a
    // question — a retrospective-evaluative prompt raised measurable shame in the field study this
    // design draws on, and shame is what the app rejects.
    @Test func noReflectionAddressesTheReaderOrRaisesItsVoice() {
        let banned: Set<String> = ["du", "dir", "dich", "dein", "deine", "deinem", "deinen",
                                   "deiner", "deines", "solltest", "sollst", "musst", "müsstest"]
        for line in ReconsiderCopy.reasonReflections {
            #expect(!line.contains("!"))
            #expect(!line.contains("?"))
            let words = line.lowercased().split(whereSeparator: { !$0.isLetter })
            for word in words {
                #expect(!banned.contains(String(word)), "\(line) spricht den Nutzer an: \(word)")
            }
        }
    }

    // The line mirrors the reason, it does not weigh it — no verdict on the reason and no claim
    // about what follows from it. The old pool was checked against "beweist" for source fidelity;
    // the same word list applies here for a different reason: nothing on this screen may argue.
    @Test func noReflectionJudgesTheReasonOrClaimsProof() {
        for line in ReconsiderCopy.reasonReflections.map({ $0.lowercased() }) {
            for word in ["beweist", "beweisen", "gerechtfertigt", "wirklich", "trotzdem",
                         "immer", "jeder", "besser", "schlechter", "zu viel", "zu oft"] {
                #expect(!line.contains(word), "\(line) bewertet den Grund über \"\(word)\"")
            }
        }
    }

    // Both choices are one line each and neither shouts — the dismiss word stays the house word the
    // shield uses, one step further ("Ich lass es" → "Ich lass es doch"), and the unlock word is
    // bare. "Trotzdem freischalten" presupposed that what stands above argues against unlocking,
    // which is the screen taking a side; the two ways carry the same weight.
    @Test func bothChoicesAreQuietAndNeitherPresupposesTheOther() {
        for choice in [ReconsiderCopy.dismissChoice, ReconsiderCopy.unlockChoice] {
            #expect(!choice.contains("!"))
            #expect(!choice.contains { $0.isNumber })
        }
        #expect(ReconsiderCopy.dismissChoice == "Ich lass es doch")
        #expect(ReconsiderCopy.unlockChoice == "Freischalten")
    }
}
