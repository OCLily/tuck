import FamilyControls
import ManagedSettings

// Tokens in the persisted FamilyActivitySelection are kept forever, but they do not stay valid
// forever: iOS 26.5 added `ManagedSettingsStore.refresh(_:)` (ManagedSettings.swiftinterface:460,
// 466, 472 — one throwing static overload per token kind, taking `inout [Token]`) and a
// `.tokensDidExpire` message (Z. 94-107) precisely because they expire. An expired token simply
// stops matching: the shield write still succeeds, still reports nothing, and the apps the user
// picked are silently open again — the same silent-failure class as the non-throwing `shield`
// property in ShieldApplication.swift.
//
// Deliberately not observing `.tokensDidExpire`: it is a NotificationCenter.AsyncMessage, so
// receiving it needs a live process with a running observer. The Monitor extension is not alive
// between windows, and the app is not either — the one moment the token values actually matter is
// the shield write, and refreshing unconditionally right there covers every expiry regardless of
// when it happened. Two mechanisms for one problem would only add a second thing that can be wrong.
enum TokenRefresh {
    static func refreshed(_ selection: FamilyActivitySelection) -> FamilyActivitySelection {
        var refreshed = selection
        refreshed.applicationTokens = Self.refreshed(selection.applicationTokens, using: ManagedSettingsStore.refresh)
        refreshed.categoryTokens = Self.refreshed(selection.categoryTokens, using: ManagedSettingsStore.refresh)
        refreshed.webDomainTokens = Self.refreshed(selection.webDomainTokens, using: ManagedSettingsStore.refresh)
        return refreshed
    }

    // Generic over Hashable rather than over ManagedSettings.Token: Token has no public initializer
    // (only `init(from:)`), so a test can never build one — over Hashable the branch logic below is
    // reachable from TuckTests with a stand-in element type.
    //
    // Kept per kind, not per selection: a category refresh that fails must not cost the app tokens.
    static func refreshed<Token: Hashable>(
        _ tokens: Set<Token>,
        using refresh: (inout [Token]) throws -> Void
    ) -> Set<Token> {
        guard !tokens.isEmpty else { return tokens }

        var candidates = Array(tokens)
        do {
            try refresh(&candidates)
        } catch {
            // `inout` may have been mutated before the throw, so the partial result is discarded
            // rather than applied. Stale tokens shield either the right apps or nothing; a half
            // refreshed array could shield the wrong ones.
            return tokens
        }

        // A refresh that empties a non-empty set would turn into `shield.applications = nil`, i.e.
        // an unshielded window, on an API whose empty-result semantics cannot be checked anywhere
        // but on a real device. Treated as "no refresh happened" until it is. A partial loss is
        // kept: those tokens are the ones the system still resolves.
        return candidates.isEmpty ? tokens : Set(candidates)
    }
}
