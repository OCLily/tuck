import Foundation
import Testing
@testable import Tuck

// The most load-bearing test file around the ledger. Until it existed, a morning was counted in
// exactly one place — AlarmKit's stop intent —
// and that intent is reported not to be delivered when the alarm is dismissed on an already-unlocked
// screen or when the Live Activity is swiped away. For anyone who wakes up before their alarm the
// mascot would then never grow at all.
//
// The second path can only be added safely if it is idempotent against the first one, so every
// interleaving of the two is pinned here, in both orders, over one morning and over several.
struct CompletedMorningLedgerTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    private func date(
        year: Int = 2026,
        month: Int = 9,
        day: Int = 1,
        hour: Int,
        minute: Int,
        second: Int = 0
    ) -> Date {
        calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        ))!
    }

    // Throwaway suite per test, so nothing here can touch the App-Group container the app and the
    // Shield-Action extension actually use.
    private func withDefaults(_ body: (UserDefaults) throws -> Void) rethrows {
        let suite = "CompletedMorningLedgerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults)
    }

    // The alarm as WakeAlarmScheduler stores it: the fire date is the NEXT occurrence at the moment
    // it was set, and the window hangs off that same time of day.
    @discardableResult
    private func scheduleAlarm(firingAt fireDate: Date, in defaults: UserDefaults) -> UUID {
        let id = UUID()
        let window = MorningBlockWindow(alarmTime: fireDate, duration: .seconds(30 * 60), calendar: calendar)
        WakeAlarmStore.store(id: id, fireDate: fireDate, window: window, in: defaults)
        return id
    }

    @discardableResult
    private func dismiss(at moment: Date, in defaults: UserDefaults) -> Bool {
        CompletedMorningLedger.recordAlarmDismissal(at: moment, calendar: calendar, in: defaults)
    }

    @discardableResult
    private func foreground(at moment: Date, in defaults: UserDefaults) -> Bool {
        CompletedMorningLedger.recordForegroundEntry(now: moment, calendar: calendar, in: defaults)
    }

    private func counted(in defaults: UserDefaults) -> Int {
        MorningProgressStore.completedMornings(in: defaults)
    }

    // MARK: - Path one, unchanged behaviour

    @Test func theStopIntentStillCountsTheMorningItIsDeliveredFor() {
        withDefaults { defaults in
            scheduleAlarm(firingAt: date(hour: 7, minute: 0), in: defaults)

            #expect(dismiss(at: date(hour: 7, minute: 0, second: 3), in: defaults) == true)
            #expect(counted(in: defaults) == 1)
        }
    }

    @Test func aSecondDeliveryOfTheSameRingingCountsNothingMore() {
        withDefaults { defaults in
            scheduleAlarm(firingAt: date(hour: 7, minute: 0), in: defaults)

            dismiss(at: date(hour: 7, minute: 0, second: 3), in: defaults)
            #expect(dismiss(at: date(hour: 7, minute: 0, second: 9), in: defaults) == false)
            #expect(counted(in: defaults) == 1)
        }
    }

    // The fallback that may never be lost: with no alarm stored there is no anchor to compare
    // against, and swallowing a real dismissal would be the one failure the never-punish principle rules out.
    @Test func aDismissalWithNothingToCompareAgainstIsNeverSwallowed() {
        withDefaults { defaults in
            #expect(WakeAlarmStore.scheduledAlarm(in: defaults) == nil)

            #expect(dismiss(at: date(hour: 7, minute: 0), in: defaults) == true)
            #expect(counted(in: defaults) == 1)
        }
    }

    // MARK: - Path two on its own

    // The case the whole file exists for: the alarm rang, the intent was never delivered, and the
    // user opens the app. Before the second path this morning was lost.
    @Test func aMorningTheIntentNeverReportedIsStillCountedOnTheNextForegroundEntry() {
        withDefaults { defaults in
            scheduleAlarm(firingAt: date(hour: 7, minute: 0), in: defaults)

            #expect(foreground(at: date(hour: 7, minute: 12), in: defaults) == true)
            #expect(counted(in: defaults) == 1)
        }
    }

    @Test func openingTheAppAgainAndAgainTheSameMorningCountsItOnce() {
        withDefaults { defaults in
            scheduleAlarm(firingAt: date(hour: 7, minute: 0), in: defaults)

            foreground(at: date(hour: 7, minute: 12), in: defaults)
            #expect(foreground(at: date(hour: 7, minute: 40), in: defaults) == false)
            #expect(foreground(at: date(hour: 19, minute: 5), in: defaults) == false)
            #expect(counted(in: defaults) == 1)
        }
    }

    // The alarm is set in the evening for tomorrow: the most recent 07:00 is in the past, but it
    // belongs to a morning this alarm was never set for.
    @Test func anOccurrenceThatHasNotHappenedYetCountsNothing() {
        withDefaults { defaults in
            scheduleAlarm(firingAt: date(day: 2, hour: 7, minute: 0), in: defaults)

            #expect(foreground(at: date(day: 1, hour: 22, minute: 30), in: defaults) == false)
            #expect(counted(in: defaults) == 0)
        }
    }

    @Test func withoutAStoredAlarmAForegroundEntryCountsNothing() {
        withDefaults { defaults in
            #expect(foreground(at: date(hour: 9, minute: 0), in: defaults) == false)
            #expect(counted(in: defaults) == 0)
        }
    }

    // The morning of the very first ringing counts on the day it rings, not one day later: the
    // anchor and the stored fire date are the same instant there, and a strict comparison would
    // have dropped exactly that morning.
    @Test func theFirstScheduledOccurrenceItselfIsCountable() {
        withDefaults { defaults in
            let fireDate = date(hour: 7, minute: 0)
            scheduleAlarm(firingAt: fireDate, in: defaults)

            #expect(CompletedMorningLedger.countableMorning(now: fireDate, calendar: calendar, in: defaults) == fireDate)
            #expect(foreground(at: fireDate, in: defaults) == true)
        }
    }

    // No backfill. Away for a week, one occurrence returned to, one morning.
    @Test func aWeekAwayFromTheAppYieldsOneMorningNotSeven() {
        withDefaults { defaults in
            scheduleAlarm(firingAt: date(day: 1, hour: 7, minute: 0), in: defaults)

            #expect(foreground(at: date(day: 8, hour: 9, minute: 0), in: defaults) == true)
            #expect(counted(in: defaults) == 1)
        }
    }

    // MARK: - The two paths against each other

    @Test func theIntentThenTheForegroundEntryCountsTheMorningOnce() {
        withDefaults { defaults in
            scheduleAlarm(firingAt: date(hour: 7, minute: 0), in: defaults)

            #expect(dismiss(at: date(hour: 7, minute: 0, second: 4), in: defaults) == true)
            #expect(foreground(at: date(hour: 7, minute: 20), in: defaults) == false)
            #expect(counted(in: defaults) == 1)
        }
    }

    // The other order, and the one that actually happens on a device: the app comes forward, counts,
    // and a late or duplicated intent delivery arrives afterwards.
    @Test func theForegroundEntryThenTheIntentCountsTheMorningOnce() {
        withDefaults { defaults in
            scheduleAlarm(firingAt: date(hour: 7, minute: 0), in: defaults)

            #expect(foreground(at: date(hour: 7, minute: 20), in: defaults) == true)
            #expect(dismiss(at: date(hour: 7, minute: 25), in: defaults) == false)
            #expect(counted(in: defaults) == 1)
        }
    }

    @Test func everyInterleavingOfBothPathsOverOneMorningCountsItOnce() {
        withDefaults { defaults in
            scheduleAlarm(firingAt: date(hour: 7, minute: 0), in: defaults)

            foreground(at: date(hour: 7, minute: 1), in: defaults)
            dismiss(at: date(hour: 7, minute: 2), in: defaults)
            foreground(at: date(hour: 7, minute: 3), in: defaults)
            dismiss(at: date(hour: 7, minute: 4), in: defaults)
            foreground(at: date(hour: 12, minute: 0), in: defaults)

            #expect(counted(in: defaults) == 1)
        }
    }

    // Three mornings, each reached on a different path, and one reached on both.
    @Test func consecutiveMorningsEachCountOnceWhicheverPathReachesThemFirst() {
        withDefaults { defaults in
            scheduleAlarm(firingAt: date(day: 1, hour: 7, minute: 0), in: defaults)

            dismiss(at: date(day: 1, hour: 7, minute: 1), in: defaults)
            foreground(at: date(day: 2, hour: 7, minute: 30), in: defaults)
            dismiss(at: date(day: 3, hour: 7, minute: 1), in: defaults)
            foreground(at: date(day: 3, hour: 8, minute: 0), in: defaults)

            #expect(counted(in: defaults) == 3)
        }
    }

    // Same wraparound the dismissal guard is pinned on, now for both paths: the anchor is a real
    // Date, so a 23:50 window's 00:10 belongs to the occurrence that started the evening before.
    @Test func aWindowWrappingPastMidnightIsOneMorningForBothPaths() {
        withDefaults { defaults in
            scheduleAlarm(firingAt: date(day: 1, hour: 23, minute: 50), in: defaults)

            #expect(foreground(at: date(day: 2, hour: 0, minute: 5), in: defaults) == true)
            #expect(dismiss(at: date(day: 2, hour: 0, minute: 12), in: defaults) == false)
            #expect(counted(in: defaults) == 1)

            #expect(foreground(at: date(day: 3, hour: 0, minute: 7), in: defaults) == true)
            #expect(counted(in: defaults) == 2)
        }
    }

    // MARK: - What the claim is made of

    @Test func theClaimNamesTheOccurrenceThatWasCountedNotTheMomentItWasCountedAt() {
        withDefaults { defaults in
            scheduleAlarm(firingAt: date(hour: 7, minute: 0), in: defaults)

            foreground(at: date(hour: 9, minute: 43), in: defaults)

            #expect(CompletedMorningLedger.lastCountedMorning(in: defaults) == date(hour: 7, minute: 0))
        }
    }

    // The claim lives outside WakeAlarmStore's keys, so clearing the alarm does not hand the day
    // back — and the wake-time picker cannot farm mornings by rescheduling within one occurrence.
    @Test func switchingTheAlarmOffAndOnAgainDoesNotRecountTheSameOccurrence() {
        withDefaults { defaults in
            scheduleAlarm(firingAt: date(hour: 7, minute: 0), in: defaults)
            foreground(at: date(hour: 7, minute: 20), in: defaults)

            WakeAlarmStore.clear(in: defaults)
            scheduleAlarm(firingAt: date(hour: 7, minute: 0), in: defaults)

            #expect(foreground(at: date(hour: 7, minute: 40), in: defaults) == false)
            #expect(counted(in: defaults) == 1)
        }
    }

    // The known, accepted hole documented at WakeAlarmStore.isFirstDismissal, restated for the
    // ledger: moving the wake time creates a genuinely different occurrence, and that occurrence is
    // countable. Over-counts, never under-counts — the "never punish" side, and unreachable for the
    // unlock quota, which keys off a calendar day nothing here can move.
    @Test func movingTheWakeTimeWithinTheSameMorningCanCountItTwice() {
        withDefaults { defaults in
            scheduleAlarm(firingAt: date(hour: 7, minute: 0), in: defaults)
            dismiss(at: date(hour: 7, minute: 2), in: defaults)

            WakeAlarmStore.clear(in: defaults)
            scheduleAlarm(firingAt: date(hour: 7, minute: 30), in: defaults)

            #expect(dismiss(at: date(hour: 7, minute: 35), in: defaults) == true)
            #expect(counted(in: defaults) == 2)
        }
    }

    // An update that lands mid-morning: the old build recorded the dismissal and counted it, the
    // ledger is empty. The morning may not be counted a second time by either path.
    @Test func anUpgradeAfterAMorningAlreadyCountedByTheOldBuildDoesNotRecountIt() {
        withDefaults { defaults in
            scheduleAlarm(firingAt: date(hour: 7, minute: 0), in: defaults)
            // Exactly what the intent did before the ledger existed, ledger untouched.
            WakeAlarmStore.recordDismissal(at: date(hour: 7, minute: 2), in: defaults)
            MorningProgressStore.recordCompletedMorning(in: defaults)
            #expect(CompletedMorningLedger.lastCountedMorning(in: defaults) == nil)

            #expect(dismiss(at: date(hour: 7, minute: 9), in: defaults) == false)
            #expect(foreground(at: date(hour: 7, minute: 30), in: defaults) == false)
            #expect(counted(in: defaults) == 1)
        }
    }

    // MARK: - What the second path has to carry with it

    // The mascot is the entire point of the second path, so the ratchet has to be latched on it too
    // — counting a morning that no reward ever follows would fix the number and not the promise.
    @Test func theMilestoneRatchetMovesOnTheForegroundPathAsWell() throws {
        try withDefaults { defaults in
            let first = try #require(MascotMilestone.allCases.first)
            let firstMorning = date(day: 1, hour: 7, minute: 30)
            scheduleAlarm(firingAt: date(day: 1, hour: 7, minute: 0), in: defaults)
            for offset in 0..<first.completedMornings {
                let morning = try #require(calendar.date(byAdding: .day, value: offset, to: firstMorning))
                foreground(at: morning, in: defaults)
            }

            #expect(counted(in: defaults) == first.completedMornings)
            #expect(MilestoneStore.reachedMornings(in: defaults) == counted(in: defaults))
            #expect(MilestoneStore.reachedMilestones(in: defaults).contains(first))
        }
    }

    // The line the foreground path must not cross: the streak may be counted from a second path, the unlock quota
    // may not be refilled by one. It resets off the calendar day alone (UnlockQuotaStore).
    @Test func theForegroundPathNeverHandsBackASpentUnlock() {
        withDefaults { defaults in
            scheduleAlarm(firingAt: date(hour: 7, minute: 0), in: defaults)
            let morning = date(hour: 7, minute: 20)
            while UnlockQuotaStore.morning.remainingUnlocks(now: morning, calendar: calendar, in: defaults) > 0 {
                UnlockQuotaStore.morning.consumeUnlock(now: morning, calendar: calendar, in: defaults)
            }

            #expect(foreground(at: morning, in: defaults) == true)

            #expect(UnlockQuotaStore.morning.remainingUnlocks(now: morning, calendar: calendar, in: defaults) == 0)
        }
    }

    // The wiring, the way MorningCelebrationWiringTests reads its own: everything above holds over
    // injected defaults and an injected clock, and none of it can see whether the screen ever calls
    // the second path — which is the only way it runs on a device.
    @Test func theMorningScreenRunsTheSecondPathOnBothOfItsEntryPoints() throws {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Tuck/GutenMorgenView.swift")
        let lines = try String(contentsOf: source, encoding: .utf8).components(separatedBy: "\n")

        let callSites = lines.indices.filter { lines[$0].contains("countThisMorningIfTheIntentDidNot()") }
        // Two calls plus the declaration: the cold launch through .task and the return from the
        // background through the scenePhase change — the same pair every other morning reaction
        // already runs on.
        #expect(callSites.count == 3)

        let coldLaunch = try #require(lines.firstIndex { $0.contains(".task {") })
        let foregrounding = try #require(lines.firstIndex { $0.contains(".onChange(of: scenePhase)") })
        #expect(callSites.contains { $0 > coldLaunch && $0 < foregrounding })
        #expect(callSites.contains { $0 > foregrounding })

        // ...and inside the helper the count is re-read after the claim, or the ring would show a
        // morning short until the next foregrounding.
        let helper = try #require(lines.firstIndex { $0.contains("private func countThisMorningIfTheIntentDidNot()") })
        let body = lines[helper...].prefix(5)
        let claim = try #require(body.firstIndex { $0.contains("CompletedMorningLedger.recordForegroundEntry()") })
        // Re-read through MilestoneStore's high-water mark since the stage ratchet, not through
        // MorningProgressStore: what this pins is the ORDER, claim before read, which is unchanged.
        let read = try #require(body.firstIndex { $0.contains("reachedMornings = MilestoneStore.reachedMornings()") })
        #expect(claim < read)

        // That assignment is what makes the count able to move during .task, which no other path
        // ever did — it reaches .onChange(of: displayedMornings) one render later, and without the
        // guard the morning's reaction is presented a second time: the running fill or sweep
        // cancelled, the mascot's beat flushed while the animal is still asleep.
        let observer = try #require(lines.firstIndex { $0.contains("private func moveRing(to new: Int)") })
        let observerBody = lines[observer...].prefix(30)
        #expect(observerBody.contains { $0.contains("guard presentedMornings != new else { return }") })
        // ...and the presenter is what records it, so the two cannot drift apart.
        let presenter = try #require(lines.firstIndex { $0.contains("private func presentCompletedMorning(for mornings: Int)") })
        #expect(lines[presenter + 1].contains("presentedMornings = mornings"))
        // The developer preview owns the ring while it is on, so clearing it must be free to put
        // the real value back.
        #expect(observerBody.contains { $0.contains("presentedMornings = nil") })
    }

    // The intent may not grow a second counting rule of its own: it goes through the ledger or the
    // two paths drift apart again.
    @Test func theStopIntentCountsThroughTheLedgerAndNowhereElse() throws {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Tuck/StopWakeAlarmIntent.swift")
        let text = try String(contentsOf: source, encoding: .utf8)

        #expect(text.contains("CompletedMorningLedger.recordAlarmDismissal()"))
        #expect(!text.contains("MorningProgressStore.recordCompletedMorning()"))
        #expect(!text.contains("MilestoneStore.reachedMornings()"))
    }
}
