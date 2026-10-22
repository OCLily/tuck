import Testing
import Foundation
@testable import Tuck

struct ShieldOverrideRequestTests {
    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suite = "ShieldOverrideRequestTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        body(defaults)
    }

    private let now = Date(timeIntervalSince1970: 1_788_000_000)

    @Test func aSubmenuChoiceArrivesInTheApp() {
        withDefaults { defaults in
            ShieldOverrideRequest.record(reason: .arbeit, now: now, in: defaults)

            #expect(ShieldOverrideRequest.take(now: now, in: defaults) == .init(reason: .arbeit))
        }
    }

    // The secondary button without a submenu still has to bring the user to the override screen —
    // it just arrives without a reason chosen.
    @Test func aPressWithoutAReasonIsStillARequest() {
        withDefaults { defaults in
            ShieldOverrideRequest.record(reason: nil, now: now, in: defaults)

            #expect(ShieldOverrideRequest.take(now: now, in: defaults) == .init(reason: nil))
        }
    }

    @Test func nothingRecordedMeansNothingToOpen() {
        withDefaults { defaults in
            #expect(ShieldOverrideRequest.take(now: now, in: defaults) == nil)
        }
    }

    // Reading answers the request. Without this the override sheet would reappear on every
    // foregrounding for as long as the entry stayed valid.
    @Test func aRequestIsConsumedByTheFirstRead() {
        withDefaults { defaults in
            ShieldOverrideRequest.record(reason: .notfall, now: now, in: defaults)

            #expect(ShieldOverrideRequest.take(now: now, in: defaults) != nil)
            #expect(ShieldOverrideRequest.take(now: now, in: defaults) == nil)
        }
    }

    @Test func aStaleRequestDoesNotOpenAnything() {
        withDefaults { defaults in
            ShieldOverrideRequest.record(reason: .notfall, now: now, in: defaults)

            #expect(ShieldOverrideRequest.take(now: now.addingTimeInterval(299), in: defaults) != nil)

            ShieldOverrideRequest.record(reason: .notfall, now: now, in: defaults)
            #expect(ShieldOverrideRequest.take(now: now.addingTimeInterval(301), in: defaults) == nil)
        }
    }

    // A clock moved backwards behind the app's back must not resurrect a request either.
    @Test func aRequestFromTheFutureIsIgnored() {
        withDefaults { defaults in
            ShieldOverrideRequest.record(reason: .notfall, now: now, in: defaults)

            #expect(ShieldOverrideRequest.take(now: now.addingTimeInterval(-1), in: defaults) == nil)
        }
    }

    // A read that answered "nothing to open" did not consume anything, so it may not delete
    // anything either. The clear used to be a `defer` and ran on this path too; the next `record`
    // overwrites both keys anyway, so what an expired entry costs is two stale keys, against a
    // request the app could otherwise erase before it ever managed to read it.
    @Test func aStaleRequestIsLeftWhereItIs() {
        withDefaults { defaults in
            ShieldOverrideRequest.record(reason: .notfall, now: now, in: defaults)
            _ = ShieldOverrideRequest.take(now: now.addingTimeInterval(600), in: defaults)

            #expect(defaults.object(forKey: "shieldOverrideRequestedAt") != nil)
            #expect(defaults.object(forKey: "shieldOverrideRequestReason") != nil)
        }
    }

    // The five minutes are a retry window, not a single shot: a read that misses the write — a cold
    // launch against a value cfprefsd has not propagated yet, or a clock that moved backwards —
    // must leave the request intact for the next foregrounding inside its validity.
    @Test func aReadThatFoundNothingLeavesTheRequestForTheNextOne() {
        withDefaults { defaults in
            ShieldOverrideRequest.record(reason: .arbeit, now: now, in: defaults)

            #expect(ShieldOverrideRequest.take(now: now.addingTimeInterval(-1), in: defaults) == nil)
            #expect(ShieldOverrideRequest.take(now: now, in: defaults) == .init(reason: .arbeit))
        }
    }
}
