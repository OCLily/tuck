import Testing
import Foundation
@testable import Tuck

// Where the fourteen days start. They used to start at launch, which is not a use of
// Plus and not even a use of the app: the clock ran for people who declined the Screen Time prompt
// and came back a month later to a trial that had expired without ever having granted them anything.
// It now starts at the first Plus boundary the user actually reaches.
//
// Two boundaries, not one. Tying it to the bedtime gate alone — the shape this change was first
// proposed in — would have left the daily unlock ceiling with no trigger at all, and the ceiling is
// the boundary the paywall is mostly about ("Freischaltungen ohne Tageslimit" is its first line).
// Somebody who never opens the bedtime screen would then be held at one unlock a day for good while
// every screen that mentions the trial describes something unreachable.
struct TrialTriggerTests {
    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suite = "TrialTriggerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        body(defaults)
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    private func date(day: Int, hour: Int = 8) -> Date {
        calendar.date(from: DateComponents(
            calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 9, day: day, hour: hour
        ))!
    }

    private func source(_ path: String) throws -> [String] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
        return try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n")
    }

    // MARK: - the trigger itself

    @Test func theFirstBoundaryContactStartsTheClock() {
        withDefaults { defaults in
            #expect(TrialStore.startedAt(in: defaults) == nil)

            let access = TrialTrigger.plusBoundaryReached(now: date(day: 1), in: defaults)

            #expect(access == .trial(daysRemaining: TrialStore.lengthInDays))
            #expect(access.hasPlusAccess)
            #expect(TrialStore.startedAt(in: defaults) == date(day: 1))
        }
    }

    // Both call sites sit in a View initialiser and run on every appearance of their screen, so this
    // is not a nicety: without it, opening the bedtime screen twice would be two trials.
    @Test func everyLaterContactReturnsTheFirstOnesTimestamp() {
        withDefaults { defaults in
            TrialTrigger.plusBoundaryReached(now: date(day: 1), in: defaults)

            for day in 2...13 {
                let access = TrialTrigger.plusBoundaryReached(now: date(day: day), in: defaults)
                #expect(access == .trial(daysRemaining: TrialStore.lengthInDays - (day - 1)))
                #expect(TrialStore.startedAt(in: defaults) == date(day: 1))
            }

            // And past the end it is the same write that does not happen: contact on day twenty
            // finds an expired trial, not a second one.
            #expect(TrialTrigger.plusBoundaryReached(now: date(day: 20), in: defaults) == .free)
            #expect(TrialStore.startedAt(in: defaults) == date(day: 1))
        }
    }

    // MARK: - the two boundaries

    // The unlock ceiling. One free unlock a day, so the boundary is met on the second attempt of a
    // day — and meeting it is what turns the answer from "no" into the fourteen days.
    @Test func theExhaustedUnlockCeilingStartsIt() {
        withDefaults { defaults in
            let context = OverrideContext.morning
            #expect(context.allowanceReachingTheCeiling(now: date(day: 1), calendar: calendar, in: defaults) == .limited(1))
            #expect(TrialStore.startedAt(in: defaults) == nil)

            context.quota.consumeUnlock(now: date(day: 1), calendar: calendar, in: defaults)
            #expect(context.quota.allowance(now: date(day: 1), calendar: calendar, in: defaults) == .limited(0))

            #expect(context.allowanceReachingTheCeiling(now: date(day: 1), calendar: calendar, in: defaults) == .unlimited)
            #expect(TrialStore.startedAt(in: defaults) == date(day: 1))
        }
    }

    // The evening window, on both quotas: the bedtime context has a ceiling of its own, and a user
    // who reaches the bedtime screen is at the boundary whether or not they ever spent an unlock.
    @Test func theBedtimeWindowIsTheOtherBoundaryAndOpensOnTheSameCall() {
        withDefaults { defaults in
            #expect(!SubscriptionAccess.current(now: date(day: 1), in: defaults).hasPlusAccess)

            let access = TrialTrigger.plusBoundaryReached(now: date(day: 1), in: defaults)

            #expect(access.hasPlusAccess)
            #expect(UnlockQuotaStore.morning.allowance(now: date(day: 1), calendar: calendar, in: defaults) == .unlimited)
            #expect(UnlockQuotaStore.bedtime.allowance(now: date(day: 1), calendar: calendar, in: defaults) == .unlimited)
        }
    }

    // An override with a slot left is not a refusal: nothing was denied, so there is nothing for a
    // trial to argue about, and the day's one free unlock is spent as a free unlock.
    @Test func anOverrideThatStillHasASlotStartsNothing() {
        withDefaults { defaults in
            for context in [OverrideContext.morning, .bedtime] {
                #expect(context.allowanceReachingTheCeiling(now: date(day: 1), calendar: calendar, in: defaults) == .limited(1))
            }
            #expect(TrialStore.startedAt(in: defaults) == nil)
        }
    }

    // The reason the ceiling read is its own function rather than a line inside `allowance`: the
    // shield's configuration extension calls the plain read on every block screen it draws, and a
    // system process may not be what starts somebody's fourteen days.
    @Test func thePlainAllowanceReadTheShieldUsesStillStartsNothing() {
        withDefaults { defaults in
            UnlockQuotaStore.morning.consumeUnlock(now: date(day: 1), calendar: calendar, in: defaults)

            for day in 1...20 {
                _ = UnlockQuotaStore.morning.allowance(now: date(day: day), calendar: calendar, in: defaults)
                _ = UnlockQuotaStore.bedtime.allowance(now: date(day: day), calendar: calendar, in: defaults)
            }

            #expect(TrialStore.startedAt(in: defaults) == nil)
        }
    }

    // MARK: - the installs that already exist

    // Nobody gets a second trial out of this change. The timestamp is one key in one App-Group suite
    // and both rules write it through the same idempotent call, so an install that started its
    // fourteen days under the launch rule keeps exactly the start it had.
    @Test func aTrialStartedUnderTheLaunchRuleKeepsItsOwnStart() {
        withDefaults { defaults in
            TrialStore.startIfNeeded(now: date(day: 1), in: defaults)

            let access = TrialTrigger.plusBoundaryReached(now: date(day: 4), in: defaults)

            #expect(access == .trial(daysRemaining: 11))
            #expect(TrialStore.startedAt(in: defaults) == date(day: 1))
        }
    }

    // The direction that would actually cost money: an expired trial may not come back because the
    // user opened the bedtime screen for the first time after updating.
    @Test func anExpiredTrialIsNotReGrantedByTheNewTrigger() {
        withDefaults { defaults in
            TrialStore.startIfNeeded(now: date(day: 1), in: defaults)

            let access = TrialTrigger.plusBoundaryReached(now: date(day: 40), in: defaults)

            #expect(access == .free)
            #expect(!access.hasPlusAccess)
            #expect(TrialStore.startedAt(in: defaults) == date(day: 1))
            #expect(UnlockQuotaStore.morning.allowance(now: date(day: 40), calendar: calendar, in: defaults) == .limited(1))
        }
    }

    // A subscriber crossing a boundary reads as subscribed, not as a trial: the entitlement outranks
    // the clock exactly as it did before, and the trigger changes nothing about that order.
    @Test func anEntitlementStillOutranksWhateverTheTriggerWrote() {
        withDefaults { defaults in
            SubscriptionTierStore.store(.plus, in: defaults)

            #expect(TrialTrigger.plusBoundaryReached(now: date(day: 1), in: defaults) == .subscribed(.plus))
            #expect(TrialTrigger.plusBoundaryReached(now: date(day: 300), in: defaults) == .subscribed(.plus))
        }
    }

    // MARK: - the wiring

    // Both triggers live in `@State` initialisers that only a constructed view runs, and this project
    // has no view-inspection dependency — so the structural half reads the source through #filePath,
    // the way MorningCelebrationWiringTests and AppIconAssetTests do. The claims are narrow and are
    // exactly the two shapes this change is: gone from the launch path, present at both boundaries.

    @Test func theLaunchPathNoLongerStartsATrial() throws {
        let lines = try source("Tuck/TuckApp.swift")
        let code = lines.filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }

        #expect(!code.contains { $0.contains("TrialStore.") })
        #expect(!code.contains { $0.contains("TrialTrigger.") })
    }

    @Test func theBedtimeGateReadsItsAccessThroughTheTrigger() throws {
        let lines = try source("Tuck/BedtimeSetupView.swift")
        let declaration = try #require(lines.first { $0.contains("private var access") })

        #expect(declaration.contains("TrialTrigger.plusBoundaryReached()"))
    }

    // The one that keeps the second boundary from quietly reverting to a plain `quota.allowance()`:
    // the phase this view opens in is computed from this value, so a read that never asks the
    // ceiling question is a user parked on the exhausted screen with no trial and no way to one.
    //
    // The question is asked from `.task` rather than from the initialiser: SwiftUI
    // re-evaluates initialiser expressions whenever the parent re-evaluates, so a write there runs
    // at moments nobody chose. Both halves are pinned — gone from the initialiser, present in a
    // task — because either one alone is satisfied by the shape this change came from.
    @Test func theOverrideFlowAsksTheCeilingQuestionFromATaskRatherThanFromItsInitialiser() throws {
        let lines = try source("Tuck/OverrideFlowView.swift")
        let start = try #require(lines.firstIndex { $0.contains("init(context: OverrideContext") })
        let end = try #require(lines[start...].dropFirst().firstIndex { $0 == "    }" })
        let initialiser = Array(lines[start...end])

        #expect(!initialiser.contains { $0.contains("allowanceReachingTheCeiling") })
        #expect(initialiser.contains { $0.contains("context.quota.allowance()") })

        let question = try #require(lines.firstIndex { $0.contains("context.allowanceReachingTheCeiling()") })
        let enclosing = try #require(lines[..<question].lastIndex {
            $0.contains(".task {") || $0.contains("init(context: OverrideContext")
        })
        #expect(lines[enclosing].contains(".task {"))
    }
}

// The three sentences the fourteen days get. Until now a trial started, ran and ended in
// silence: the countdown existed on the paywall and in one settings row, i.e. exactly where somebody
// already knows what they are looking at, and the one screen where a user is at the boundary — the
// exhausted override — was "Schließen" and nothing else.
//
// What every test here also guards is the shape rather than the presence: shown once, never to a
// subscriber, never describing a state that has already passed, and never a countdown.
struct TrialNoticeTests {
    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suite = "TrialNoticeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        body(defaults)
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    private func date(day: Int, hour: Int = 8) -> Date {
        calendar.date(from: DateComponents(
            calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 9, day: day, hour: hour
        ))!
    }

    private func source(_ path: String) throws -> [String] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
        return try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n")
    }

    // MARK: - which notice is due

    // A fresh install has no trial and therefore nothing to report. Reading has to stay free of side
    // effects for the same reason `TrialStore.state` does: the boundary is what starts the clock,
    // not a screen asking whether it has anything to say.
    @Test func anUnstartedTrialHasNothingToSayAndNothingToWrite() {
        withDefaults { defaults in
            for day in 1...20 {
                #expect(TrialNotice.due(now: date(day: day), calendar: calendar, in: defaults) == nil)
                #expect(TrialNotice.consume(now: date(day: day), calendar: calendar, in: defaults) == nil)
            }
            #expect(TrialStore.startedAt(in: defaults) == nil)
        }
    }

    @Test func theFirstDayOfAStartedTrialIsTheStartNotice() {
        withDefaults { defaults in
            TrialTrigger.plusBoundaryReached(now: date(day: 1), in: defaults)

            #expect(TrialNotice.due(now: date(day: 1), calendar: calendar, in: defaults) == .started)
        }
    }

    // Day twelve of fourteen, expressed in the unit the app counts in: TrialStore rounds up, so the
    // remaining count first reaches three there. Pinned as a day rather than as the constant, or the
    // test would only restate the implementation.
    @Test func theHintArrivesAroundDayTwelveAndNotBefore() {
        withDefaults { defaults in
            TrialTrigger.plusBoundaryReached(now: date(day: 1), in: defaults)
            _ = TrialNotice.consume(now: date(day: 1), calendar: calendar, in: defaults)

            for day in 2...11 {
                #expect(TrialNotice.due(now: date(day: day), calendar: calendar, in: defaults) == nil,
                        "day \(day) shows something")
            }
            #expect(TrialNotice.due(now: date(day: 12), calendar: calendar, in: defaults) == .nearingEnd)
            #expect(TrialNotice.due(now: date(day: 14), calendar: calendar, in: defaults) == .nearingEnd)
        }
    }

    @Test func theExpiryHasItsOwnNoticeAndItSurvivesTheDayItHappens() {
        withDefaults { defaults in
            TrialTrigger.plusBoundaryReached(now: date(day: 1), in: defaults)

            #expect(TrialNotice.due(now: date(day: 15), calendar: calendar, in: defaults) == .ended)
            #expect(TrialNotice.due(now: date(day: 40), calendar: calendar, in: defaults) == .ended)
        }
    }

    // MARK: - the shape

    // The whole difference between a notice and a nag: consumed once, gone afterwards. Both call
    // sites run on every appearance of their screen, so this is the only thing standing between one
    // calm sentence and a line that greets the user at every unlock for fourteen days.
    @Test func everyNoticeIsShownExactlyOnce() {
        withDefaults { defaults in
            TrialTrigger.plusBoundaryReached(now: date(day: 1), in: defaults)

            #expect(TrialNotice.consume(now: date(day: 1), calendar: calendar, in: defaults) == .started)
            for _ in 1...5 {
                #expect(TrialNotice.consume(now: date(day: 1), calendar: calendar, in: defaults) == nil)
                #expect(TrialNotice.due(now: date(day: 1), calendar: calendar, in: defaults) == nil)
            }

            #expect(TrialNotice.consume(now: date(day: 12), calendar: calendar, in: defaults) == .nearingEnd)
            #expect(TrialNotice.consume(now: date(day: 13), calendar: calendar, in: defaults) == nil)

            #expect(TrialNotice.consume(now: date(day: 15), calendar: calendar, in: defaults) == .ended)
            #expect(TrialNotice.consume(now: date(day: 16), calendar: calendar, in: defaults) == nil)
        }
    }

    // A notice may not describe a state that has passed. Somebody whose first gated screen is on day
    // twelve gets the ending, never a welcome to fourteen days that are nearly over — and the start
    // notice they skipped does not queue up behind it.
    @Test func aLaterStateOutranksAnEarlierOneThatWasNeverShown() {
        withDefaults { defaults in
            TrialTrigger.plusBoundaryReached(now: date(day: 1), in: defaults)

            #expect(TrialNotice.consume(now: date(day: 12), calendar: calendar, in: defaults) == .nearingEnd)
            #expect(!TrialNotice.hasBeenShown(.started, in: defaults))
            #expect(TrialNotice.due(now: date(day: 13), calendar: calendar, in: defaults) == nil)
        }
    }

    // The direction that would be embarrassing: telling a paying subscriber their trial is over.
    // Their access came from the entitlement and outranks the clock, so the clock has nothing to
    // announce — this is also the one place where a notice would read as a sales pitch.
    @Test func aSubscriberIsNeverToldAnythingAboutTheTrial() {
        withDefaults { defaults in
            TrialTrigger.plusBoundaryReached(now: date(day: 1), in: defaults)
            SubscriptionTierStore.store(.plus, in: defaults)

            for day in [1, 12, 15, 40] {
                #expect(TrialNotice.due(now: date(day: day), calendar: calendar, in: defaults) == nil,
                        "day \(day) speaks to a subscriber")
            }
        }
    }

    // Checked on the copy rather than only intended: no exclamation mark, no urgency, no
    // judgement about how the trial was used, and no number in the two lines about its end — a count
    // that reappears by itself is a countdown, which the design system rules out on the paywall and which has
    // even less business on a screen the user did not open to look at prices.
    @Test func noNoticeShoutsHurriesOrCountsDown() throws {
        let lines = try source("Tuck/PaywallView.swift")
        let start = try #require(lines.firstIndex { $0.contains("struct TrialNoticeBanner") })
        let copy = lines[start...].filter { $0.contains("String(localized:") }

        #expect(copy.count == 6, "the banner no longer carries three titles and three details")
        for line in copy {
            #expect(!line.contains("!"))
            for word in ["nur noch", "jetzt", "endlich", "wieder mal", "verpass", "letzte chance",
                         "läuft ab", "schade"] {
                #expect(!line.lowercased().contains(word), "\(line) hurries or judges via \(word)")
            }
        }

        // The one number the two end lines may carry is the free ceiling, and it comes from the
        // quota rather than from the copy — no digit is written into any of the six lines.
        for line in copy {
            let quoted = line.drop { $0 != "\"" }.dropFirst().prefix { $0 != "\"" }
            #expect(!quoted.contains { $0.isNumber }, "\(quoted) writes a number into the copy")
        }
    }

    // MARK: - the wiring

    // The exhausted screen was "Schließen" and nothing else — the single moment in the app
    // where somebody has a concrete use for Plus in front of them, and it was a dead end. What is
    // pinned is the way out and the re-read behind it: a purchase made from here has to lift the
    // refusal without a relaunch.
    @Test func theExhaustedScreenOffersAWayToThePaywall() throws {
        let lines = try source("Tuck/OverrideFlowView.swift")
        let start = try #require(lines.firstIndex { $0.contains("private var exhausted:") })
        let end = try #require(lines[start...].dropFirst().firstIndex { $0 == "    }" })
        let screen = Array(lines[start...end])

        #expect(screen.contains { $0.contains("showPaywall = true") })
        #expect(screen.contains { $0.contains("Plus ansehen") })
        // Still a way out, not a wall: the dismiss word stays on the screen next to it.
        // The shorthand `Button("Schließen")` became a label closure — the word is
        // what this pins, and it now sits in the label the 44 pt frame hangs on.
        #expect(screen.contains { $0.contains("Text(\"Schließen\")") })
        #expect(screen.contains { $0.contains("dismiss()") })

        #expect(lines.contains { $0.contains("PaywallView()") })
        #expect(lines.contains { $0.contains("onDismiss: { adopt(context.quota.allowance()) }") })
    }

    // Both Plus boundaries draw the notice, and both consume it rather than read it.
    // A screen that only read would show the same line on every visit, which is the nag this is not.
    @Test func bothBoundaryScreensConsumeTheNoticeExactlyOnce() throws {
        for path in ["Tuck/OverrideFlowView.swift", "Tuck/BedtimeSetupView.swift"] {
            let lines = try source(path)
            #expect(lines.contains { $0.contains("trialNotice = TrialNotice.consume()") }, "\(path)")
            #expect(lines.contains { $0.contains("TrialNoticeBanner(notice: trialNotice)") }, "\(path)")
            #expect(!lines.contains { $0.contains("TrialNotice.due(") }, "\(path) reads without consuming")
        }
    }

    // The 30 seconds and the reconsider screen stay clear of it: a sentence about a subscription
    // arriving in the middle of the ritual is the interruption the ritual exists without.
    @Test func theBreathingAndReconsiderPhasesCarryNoTrialLine() throws {
        let lines = try source("Tuck/OverrideFlowView.swift")
        let banner = try #require(lines.firstIndex { $0.contains("TrialNoticeBanner(notice:") })
        let phase = try #require(lines[..<banner].lastIndex { $0.contains("case .") })

        #expect(lines[phase].contains("case .chooseReason"))
    }
}
