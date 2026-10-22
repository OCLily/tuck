import Testing
@testable import Tuck

// The one rule in this app that costs money in both directions: clearing the cached tier on a
// lookup that proved nothing drops a paying user to the free ceiling, and never clearing it leaves
// Plus standing forever after a real cancellation. Both mistakes are one `if` apart, so all eight
// combinations of the three inputs are written out rather than derived — a table that generates its
// own expectation would only re-state whatever the implementation does.
private typealias Resolution = SubscriptionController.EntitlementResolution

struct EntitlementResolutionTests {
    private func resolve(
        entitled: SubscriptionTier?,
        revoked: Bool,
        lapsed: SubscriptionTier?
    ) -> Resolution.Outcome {
        Resolution.resolve(entitled: entitled, revoked: revoked, lapsed: lapsed)
    }

    // 1/8 — nothing at all. The dangerous case: an empty currentEntitlements is also what a slow
    // network, a signed-out App Store account and a failed lookup look like, so it is not proof of
    // anything and the cache keeps whatever StoreKit last confirmed.
    @Test func noAnswerAtAllLeavesTheCachedTierAlone() {
        #expect(resolve(entitled: nil, revoked: false, lapsed: nil)
            == .init(entitlement: .notSubscribed, cache: .leaveAlone))
    }

    // 2/8 — a revocation and nothing else: refund or family removal. Proof of a negative, so the
    // cache goes. The displayed state stays notSubscribed rather than expired, because a revoked
    // purchase never reached an expiration.
    @Test func aRevocationAloneIsProofAndClearsTheCache() {
        #expect(resolve(entitled: nil, revoked: true, lapsed: nil)
            == .init(entitlement: .notSubscribed, cache: .clear))
    }

    // 3/8 — an expired transaction and nothing else: the ordinary cancellation at period end. Proof
    // of a negative, cache cleared, and the state carries the tier so the paywall can say "expired"
    // instead of "never bought".
    @Test func aLapsedSubscriptionIsProofAndClearsTheCache() {
        #expect(resolve(entitled: nil, revoked: false, lapsed: .plus)
            == .init(entitlement: .expired(.plus), cache: .clear))
    }

    // 4/8 — both negatives at once: a refunded purchase whose period had also run out. Same
    // outcome as 3/8; expiry is the more specific of the two and names the tier.
    @Test func aLapsedAndRevokedSubscriptionReadsAsExpired() {
        #expect(resolve(entitled: nil, revoked: true, lapsed: .plus)
            == .init(entitlement: .expired(.plus), cache: .clear))
    }

    // 5/8 — the plain paying user.
    @Test func aLiveEntitlementIsActiveAndWritesTheCache() {
        #expect(resolve(entitled: .plus, revoked: false, lapsed: nil)
            == .init(entitlement: .active(.plus), cache: .store(.plus)))
    }

    // 6/8 — a live entitlement next to a revoked transaction: what a refund of the monthly plan
    // followed by a fresh yearly purchase leaves behind. The revocation may not outrank what
    // StoreKit currently confirms, or the buyer would lose access they just paid for.
    @Test func aLiveEntitlementOutranksARevokedTransaction() {
        #expect(resolve(entitled: .plus, revoked: true, lapsed: nil)
            == .init(entitlement: .active(.plus), cache: .store(.plus)))
    }

    // 7/8 — a live entitlement next to an expired one: the re-subscription after a lapse, and the
    // upgrade from monthly to yearly. Same reason as 6/8.
    @Test func aLiveEntitlementOutranksALapsedTransaction() {
        #expect(resolve(entitled: .plus, revoked: false, lapsed: .plus)
            == .init(entitlement: .active(.plus), cache: .store(.plus)))
    }

    // 8/8 — a live entitlement with both negatives beside it. Nothing in the history can take away
    // a currently confirmed entitlement.
    @Test func aLiveEntitlementOutranksBothNegativesTogether() {
        #expect(resolve(entitled: .plus, revoked: true, lapsed: .plus)
            == .init(entitlement: .active(.plus), cache: .store(.plus)))
    }

    // The property behind the eight rows, stated once: exactly the three cases with proof clear the
    // cache, and no other input combination does. Written as an enumeration over all eight inputs so
    // a ninth case cannot be added without this failing.
    @Test func exactlyTheProvenNegativesClearTheCacheAndNothingElse() {
        var cleared: Set<String> = []
        var seen = 0
        for entitled in [nil, SubscriptionTier.plus] {
            for revoked in [false, true] {
                for lapsed in [nil, SubscriptionTier.plus] {
                    seen += 1
                    let key = "\(entitled == nil ? "-" : "E")\(revoked ? "R" : "-")\(lapsed == nil ? "-" : "L")"
                    switch resolve(entitled: entitled, revoked: revoked, lapsed: lapsed).cache {
                    case .clear:
                        cleared.insert(key)
                    case .store(let tier):
                        #expect(entitled == tier)
                    case .leaveAlone:
                        #expect(key == "---")
                    }
                }
            }
        }

        #expect(seen == 8)
        #expect(cleared == ["-R-", "--L", "-RL"])
    }
}
