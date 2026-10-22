import Testing
import Foundation
@testable import Tuck

// StoreKit's own Product/Transaction APIs are not reachable from here: StoreKitTest.framework, the
// only in-process way to drive a purchase, ships for iPhoneOS but not for iPhoneSimulator in this
// Xcode (26.6). What is testable is everything between an entitlement and a quota number, which is
// where the actual product rule lives.
struct SubscriptionTierTests {
    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suite = "SubscriptionTierTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        body(defaults)
    }

    // The settings row shows a checking state for exactly the window this test pins —
    // between the controller existing and StoreKit having answered, nothing is confirmed.
    @MainActor
    @Test func aFreshControllerHasNotResolvedAnEntitlementYet() {
        #expect(SubscriptionController().entitlement == .unresolved)
    }

    @Test func everyPlanRoundTripsThroughItsProductIdentifier() {
        for plan in SubscriptionPlan.allCases {
            #expect(SubscriptionPlan(productID: plan.productID) == plan)
            #expect(SubscriptionTier(productID: plan.productID) == plan.tier)
        }
    }

    // The single paid tier, sold in more than one period. A second plan may never become a second
    // set of capabilities — that is the feature-tier decoy the restructure removed.
    @Test func everyPlanGrantsTheSameSingleTier() {
        #expect(SubscriptionTier.allCases == [.plus])
        #expect(Set(SubscriptionPlan.allCases.map(\.tier)) == [.plus])
        #expect(Set(SubscriptionPlan.allProductIDs).count == SubscriptionPlan.allCases.count)
    }

    @Test func anUnknownProductIdentifierResolvesToNoTier() {
        #expect(SubscriptionTier(productID: "com.example.tuck.something.else") == nil)
        #expect(SubscriptionTier(productID: "") == nil)
        // The retired tier: its identifier must not resolve to anything at all.
        #expect(SubscriptionTier(productID: "com.example.tuck.standard.monthly") == nil)
    }

    // The permanent free baseline, not a fallback for an unresolved entitlement.
    @Test func theFreeBaselineIsOneUnlockPerDayInBothWindows() {
        #expect(UnlockQuotaStore.morning.freeUnlockMaximum == 1)
        #expect(UnlockQuotaStore.bedtime.freeUnlockMaximum == 1)
    }

    @Test func anEmptyCacheKnowsNoTierRatherThanGuessingOne() {
        withDefaults { defaults in
            #expect(SubscriptionTierStore.cachedTier(in: defaults) == nil)
            #expect(SubscriptionAccess.current(in: defaults) == .free)
            #expect(UnlockQuotaStore.morning.allowance(in: defaults) == .limited(1))
        }
    }

    @Test func aCachedTierSurvivesANewStoreLookupOnTheSameSuite() {
        let suite = "SubscriptionTierTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        SubscriptionTierStore.store(.plus, in: defaults)

        let reopened = UserDefaults(suiteName: suite)!
        #expect(SubscriptionTierStore.cachedTier(in: reopened) == .plus)

        defaults.removePersistentDomain(forName: suite)
    }

    // A fixed bug: a lookup that has not answered yet must leave the last confirmed
    // entitlement standing. Only `clear` takes it away, and only a proven negative calls it.
    @Test func theCachedTierIsTheFallbackUntilSomethingProvesOtherwise() {
        withDefaults { defaults in
            SubscriptionTierStore.store(.plus, in: defaults)
            #expect(SubscriptionTierStore.cachedTier(in: defaults) == .plus)
            #expect(UnlockQuotaStore.morning.allowance(in: defaults) == .unlimited)

            SubscriptionTierStore.clear(in: defaults)
            #expect(SubscriptionTierStore.cachedTier(in: defaults) == nil)
        }
    }

    // A tier this build does not know is not evidence of any tier either — it may not read as the
    // paid one, and it may not crash the quota.
    @Test func anUnknownCachedRawValueResolvesToNoTier() {
        withDefaults { defaults in
            defaults.set("standard", forKey: "resolvedSubscriptionTier")

            #expect(SubscriptionTierStore.cachedTier(in: defaults) == nil)
            #expect(UnlockQuotaStore.morning.allowance(in: defaults) == .limited(1))
        }
    }

    @Test func plusRemovesTheCounterInBothWindows() {
        withDefaults { defaults in
            SubscriptionTierStore.store(.plus, in: defaults)

            #expect(UnlockQuotaStore.morning.allowance(in: defaults) == .unlimited)
            #expect(UnlockQuotaStore.bedtime.allowance(in: defaults) == .unlimited)
        }
    }

    // "Unlimited" has to mean the counter is not consulted at all — a Plus user who spends unlocks
    // all morning must never arrive at an exhausted state.
    @Test func spendingUnlocksOnPlusNeverExhaustsAnything() {
        withDefaults { defaults in
            SubscriptionTierStore.store(.plus, in: defaults)

            for _ in 0..<50 {
                UnlockQuotaStore.morning.consumeUnlock(in: defaults)
                #expect(UnlockQuotaStore.morning.allowance(in: defaults) == .unlimited)
            }
            #expect(UnlockQuotaStore.morning.allowance(in: defaults).isExhausted == false)
        }
    }

    // The counter is not kept warm in the background either: nothing was written while unlimited,
    // so a lapse lands on a full free day rather than on a balance spent under Plus.
    @Test func aLapseAfterSpendingOnPlusLandsOnTheFullFreeQuota() {
        withDefaults { defaults in
            SubscriptionTierStore.store(.plus, in: defaults)
            for _ in 0..<5 { UnlockQuotaStore.morning.consumeUnlock(in: defaults) }

            SubscriptionTierStore.clear(in: defaults)
            #expect(UnlockQuotaStore.morning.allowance(in: defaults) == .limited(1))
        }
    }

    // The no-re-arm rule still holds on the free side: an unlock spent today is gone until the next anchor day.
    @Test func theFreeQuotaIsSpentOnceAndStaysSpentForTheDay() {
        withDefaults { defaults in
            #expect(UnlockQuotaStore.morning.allowance(in: defaults) == .limited(1))

            UnlockQuotaStore.morning.consumeUnlock(in: defaults)
            #expect(UnlockQuotaStore.morning.allowance(in: defaults) == .limited(0))
            #expect(UnlockQuotaStore.morning.allowance(in: defaults).isExhausted)

            let nextDay = Date.now.addingTimeInterval(60 * 60 * 24)
            #expect(UnlockQuotaStore.morning.allowance(now: nextDay, in: defaults) == .limited(1))
        }
    }
}
