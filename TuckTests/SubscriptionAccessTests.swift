import Testing
import Foundation
@testable import Tuck

// The 14-day trial (docs/product-decisions-2026-09-02.md): a new user
// gets full Plus and falls back to the free tier without anything having to run at the moment it
// ends. Everything here is derived from `now` against one stored timestamp, so there is no
// expiration callback that can fail to fire.
struct SubscriptionAccessTests {
    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suite = "SubscriptionAccessTests.\(UUID().uuidString)"
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

    @Test func afreshInstallHasNoTrialAndNoAccess() {
        withDefaults { defaults in
            #expect(TrialStore.startedAt(in: defaults) == nil)
            #expect(TrialStore.state(in: defaults) == .expired)
            #expect(SubscriptionAccess.current(in: defaults) == .free)
        }
    }

    // The timestamp is written on the first contact with a Plus boundary and never again — both
    // call sites run on every appearance of their screen (TrialTriggerTests), so an idempotent write
    // is the whole guarantee that the trial cannot be extended by going back to that screen.
    @Test func theTrialStartIsWrittenExactlyOnce() {
        withDefaults { defaults in
            let first = TrialStore.startIfNeeded(now: date(day: 1), in: defaults)
            #expect(first == date(day: 1))

            for day in 2...5 {
                #expect(TrialStore.startIfNeeded(now: date(day: day), in: defaults) == date(day: 1))
            }
            #expect(TrialStore.startedAt(in: defaults) == date(day: 1))
        }
    }

    @Test func aStartedTrialGrantsFullPlusAccess() {
        withDefaults { defaults in
            TrialStore.startIfNeeded(now: date(day: 1), in: defaults)

            let access = SubscriptionAccess.current(now: date(day: 1), in: defaults)
            #expect(access == .trial(daysRemaining: TrialStore.lengthInDays))
            #expect(access.hasPlusAccess)
            #expect(UnlockQuotaStore.morning.allowance(now: date(day: 1), calendar: calendar, in: defaults) == .unlimited)
            #expect(UnlockQuotaStore.bedtime.allowance(now: date(day: 1), calendar: calendar, in: defaults) == .unlimited)
        }
    }

    // The last partial day still reads as one day rather than as zero: a countdown that reaches
    // zero while access is still granted is the same overclaim as one that never reaches it.
    @Test func theRemainingDaysCountDownAndNeverReachZeroWhileActive() {
        withDefaults { defaults in
            TrialStore.startIfNeeded(now: date(day: 1), in: defaults)

            for day in 1...14 {
                let state = TrialStore.state(now: date(day: day), calendar: calendar, in: defaults)
                #expect(state == .active(daysRemaining: TrialStore.lengthInDays - (day - 1)))
            }
            #expect(TrialStore.state(now: date(day: 14, hour: 23), calendar: calendar, in: defaults) == .active(daysRemaining: 1))
        }
    }

    // The whole point of deriving it from `now`: nothing has to run on day fifteen for the trial to
    // be over, and the free ceiling is back without a single write.
    @Test func theTrialRevertsToTheFreeTierWithoutAnythingHavingToRun() {
        withDefaults { defaults in
            TrialStore.startIfNeeded(now: date(day: 1), in: defaults)

            let expiry = date(day: 15)
            #expect(TrialStore.state(now: expiry, calendar: calendar, in: defaults) == .expired)
            #expect(SubscriptionAccess.current(now: expiry, in: defaults) == .free)
            #expect(UnlockQuotaStore.morning.allowance(now: expiry, calendar: calendar, in: defaults) == .limited(1))
        }
    }

    // A trial that was already spent down does not hand the free day back: the free day has its own
    // anchor, and an unlock spent on the expiry day stays spent.
    @Test func anUnlockSpentOnTheDayTheTrialEndsStaysSpent() {
        withDefaults { defaults in
            TrialStore.startIfNeeded(now: date(day: 1), in: defaults)
            let expiry = date(day: 15)

            UnlockQuotaStore.morning.consumeUnlock(now: expiry, calendar: calendar, in: defaults)
            #expect(UnlockQuotaStore.morning.allowance(now: expiry, calendar: calendar, in: defaults) == .limited(0))
        }
    }

    // Subscribing during the trial has to outlive it: the entitlement wins over the clock, and the
    // timestamp is never touched by a purchase.
    @Test func anEntitlementOutranksAndOutlivesTheTrial() {
        withDefaults { defaults in
            TrialStore.startIfNeeded(now: date(day: 1), in: defaults)
            SubscriptionTierStore.store(.plus, in: defaults)

            #expect(SubscriptionAccess.current(now: date(day: 3), in: defaults) == .subscribed(.plus))
            #expect(SubscriptionAccess.current(now: date(day: 30), in: defaults) == .subscribed(.plus))
            #expect(TrialStore.startedAt(in: defaults) == date(day: 1))
        }
    }

    // The shield extensions call `state`, and a system process drawing a block screen may not be
    // what starts somebody's fourteen days.
    @Test func readingTheTrialStateNeverStartsOne() {
        withDefaults { defaults in
            for day in 1...20 {
                _ = TrialStore.state(now: date(day: day), calendar: calendar, in: defaults)
                _ = SubscriptionAccess.current(now: date(day: day), in: defaults)
                _ = UnlockQuotaStore.morning.allowance(now: date(day: day), calendar: calendar, in: defaults)
            }

            #expect(TrialStore.startedAt(in: defaults) == nil)
        }
    }

    @Test func theTrialStartSurvivesANewStoreLookupOnTheSameSuite() {
        let suite = "SubscriptionAccessTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        TrialStore.startIfNeeded(now: date(day: 1), in: defaults)

        let reopened = UserDefaults(suiteName: suite)!
        #expect(TrialStore.startedAt(in: reopened) == date(day: 1))

        defaults.removePersistentDomain(forName: suite)
    }
}

// Guideline 3.1.2, the single most common rejection reason for subscription apps: the screen that
// takes the money has to carry the length of the period, the automatic renewal, the way out, and a
// working link to both the terms and the privacy policy. All four are view literals with no pool
// behind them, so they are read out of the source the way TrialTriggerTests and
// MorningCelebrationWiringTests read theirs — this project has no view-inspection dependency.
//
// Beside the trial tests rather than in a file of their own: both describe the rules of the one
// paid surface, and adding a file would mean regenerating the checked-in project file.
struct PaywallLegalTests {
    private func source(_ path: String) throws -> [String] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
        return try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n")
    }

    // The one thing a force-unwrap would have caught at launch and the `if let` in the view will
    // not: a malformed literal silently removes a mandatory element from the screen instead of
    // crashing. So it is checked here rather than there.
    @Test func bothLegalDestinationsParseAsURLs() throws {
        for string in [PaywallLegal.termsOfUse, PaywallLegal.privacyPolicy] {
            let url = try #require(URL(string: string), "unparseable: \(string)")
            #expect(url.scheme == "https")
            #expect(url.host() != nil)
        }
    }

    // Apple's standard EULA is the licence that applies when a developer supplies none, so this half
    // of 3.1.2 is genuinely done rather than stubbed — the pin exists because "we will host our own
    // terms" is exactly the change that would silently leave a broken link behind.
    @Test func theTermsLinkPointsAtApplesOwnStandardEULA() {
        #expect(PaywallLegal.termsOfUse == "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
    }

    // The tripwire that survives being fixed: while the URL is still the placeholder there has to be
    // a TODO in the source saying so, and once it is real it has to be a hosted https page that is
    // not example.com. Both states pass, neither state passes silently.
    @Test func thePrivacyPolicyIsEitherHostedOrCarriesTheTodoThatSaysItIsNot() throws {
        let lines = try source("Tuck/PaywallView.swift")
        let declaration = try #require(lines.firstIndex { $0.contains("static let privacyPolicy =") })

        if PaywallLegal.privacyPolicyIsPlaceholder {
            let comment = lines[max(0, declaration - 8)..<declaration]
            #expect(comment.contains { $0.contains("TODO:") },
                    "the placeholder privacy URL has no TODO above it")
            // RFC 2606 keeps this domain reserved, so an unfixed placeholder can never resolve to
            // somebody else's page.
            #expect(PaywallLegal.privacyPolicy.contains("example.com"))
        } else {
            #expect(PaywallLegal.privacyPolicy.hasPrefix("https://"))
            #expect(!PaywallLegal.privacyPolicy.contains("example"))
        }
    }

    // What Review actually reads: the period, that it renews, when the charge happens, and where the
    // cancel button is. Pinned as fragments rather than as one sentence so a reworded clause that
    // still says all four keeps passing.
    @Test func theAutoRenewalClauseNamesThePeriodTheRenewalAndTheWayOut() throws {
        let lines = try source("Tuck/PaywallView.swift")
        let clause = try #require(lines.first { $0.contains("verlängert sich zum selben Preis") })

        for fragment in ["einen Monat oder ein Jahr", "24 Stunden", "gekündigt",
                         "Apple-ID", "Kündigen", "Abo verwalten"] {
            #expect(clause.contains(fragment), "the renewal clause does not say \(fragment)")
        }
        // The tone rules hold on the legal copy too: it states what the subscription is, it does not sell it.
        #expect(!clause.contains("!"))
        for word in ["nur noch", "jetzt", "spare", "verpass"] {
            #expect(!clause.lowercased().contains(word), "the renewal clause sells via \(word)")
        }
    }

    // Both links have to be on the paywall itself — two taps away in Settings is the arrangement
    // 3.1.2 rejects — and both have to be Links rather than Buttons, so VoiceOver announces where
    // they lead.
    // Both carry a 44 pt label closure instead of the shorthand title, so what is checked
    // is the pair: the label is there, and a `Link(destination:` — never a Button — opens it.
    @Test func bothLegalLinksAreRenderedOnThePaywallItself() throws {
        let lines = try source("Tuck/PaywallView.swift")

        for label in ["Nutzungsbedingungen", "Datenschutzerklärung"] {
            let title = try #require(lines.firstIndex { $0.contains("Text(\"\(label)\")") },
                                     "\(label) is not on the paywall at all")
            #expect(lines[..<title].suffix(2).contains { $0.contains("Link(destination:") },
                    "\(label) is not opened by a Link")
            #expect(!lines.contains { $0.contains("Button(\"\(label)\"") })
        }
        #expect(lines.contains { $0.trimmingCharacters(in: .whitespaces) == "legalSection" })
    }
}
