import Testing
@testable import Tuck

// ManagedSettings.Token has no public initializer, and real tokens need a granted Family-Controls
// authorization the Simulator does not have — so what is testable here is how the result of a
// refresh is turned into the set that gets shielded, with a stand-in element type. That the system
// call renews anything at all is device-only.
struct TokenRefreshTests {
    private struct RefreshFailed: Error {}

    @Test func anEmptySetIsNotHandedToTheSystemAtAll() {
        var called = false
        let result = TokenRefresh.refreshed(Set<Int>()) { _ in called = true }

        #expect(result.isEmpty)
        #expect(called == false)
    }

    @Test func renewedTokensReplaceTheOnesThatWentIn() {
        let result = TokenRefresh.refreshed([1, 2]) { tokens in tokens = [10, 20] }

        #expect(result == [10, 20])
    }

    @Test func aFailedRefreshKeepsTheTokensItWasGiven() {
        let result = TokenRefresh.refreshed([1, 2]) { _ in throw RefreshFailed() }

        #expect(result == [1, 2])
    }

    // The inout array can be mutated before the throw; that half-done state must not reach a shield.
    @Test func aPartialWriteBeforeAFailureIsDiscarded() {
        let result = TokenRefresh.refreshed([1, 2]) { tokens in
            tokens = [99]
            throw RefreshFailed()
        }

        #expect(result == [1, 2])
    }

    // A token the system can no longer resolve at all drops out, the rest still shields.
    @Test func tokensTheSystemDropsAreLeftBehind() {
        let result = TokenRefresh.refreshed([1, 2, 3]) { tokens in tokens = [1, 3] }

        #expect(result == [1, 3])
    }

    @Test func aRefreshThatEmptiesTheSetIsTreatedAsNoRefresh() {
        let result = TokenRefresh.refreshed([1, 2]) { tokens in tokens = [] }

        #expect(result == [1, 2])
    }

    @Test func duplicatesTheSystemHandsBackCollapseIntoOneToken() {
        let result = TokenRefresh.refreshed([1, 2]) { tokens in tokens = [7, 7] }

        #expect(result == [7])
    }
}
