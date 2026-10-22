import Foundation

// The tier no longer buys a higher unlock ceiling (superseded, see docs/product-decisions-2026-09-02.md).
// There is one paid tier, and what it removes is the counter itself — the
// friction that carries the product is the delay plus the reason, and that is identical on every
// tier, which is a product invariant.
//
// Deliberately no StoreKit import: this type is what UnlockQuotaStore reads, and that store has to
// stay resolvable from the App-Group container alone, so an extension can consult the quota
// without linking a purchase stack to learn whether a ceiling applies at all. Today that reader is
// TuckShield alone, read-only, through OverrideContext.current() — TuckShieldAction
// compiles neither this file nor UnlockQuotaStore, and the only caller of consumeUnlock is the app.
// Both extensions do declare the App Group in their .entitlements (wired via CODE_SIGN_ENTITLEMENTS
// in project.yml); what is still missing is the provisioned group itself, which needs a paid Apple
// developer account.
enum SubscriptionTier: String, CaseIterable, Sendable {
    case plus

    var displayName: String {
        switch self {
        case .plus: "Plus"
        }
    }

    // An identifier the app does not know resolves to nothing rather than to the paid tier: an
    // unrecognised entitlement is not evidence of any tier.
    init?(productID: String) {
        guard let plan = SubscriptionPlan(productID: productID) else { return nil }
        self = plan.tier
    }
}

// The purchase options, kept apart from the tier they grant: one subscription group, two periods
// today, and a third (a lifetime purchase) is an explicit later addition — which is why nothing
// here is written against there being exactly two.
enum SubscriptionPlan: String, CaseIterable, Sendable {
    case plusMonthly
    case plusYearly

    static let allProductIDs: [String] = allCases.map(\.productID)

    var productID: String {
        switch self {
        case .plusMonthly: "com.example.tuck.plus.monthly"
        case .plusYearly: "com.example.tuck.plus.yearly"
        }
    }

    var tier: SubscriptionTier {
        switch self {
        case .plusMonthly, .plusYearly: .plus
        }
    }

    var displayName: String {
        switch self {
        case .plusMonthly: "Monatlich"
        case .plusYearly: "Jährlich"
        }
    }

    init?(productID: String) {
        guard let plan = Self.allCases.first(where: { $0.productID == productID }) else { return nil }
        self = plan
    }
}

// The cache the quota reads. StoreKit is asked at launch and whenever Transaction.updates fires,
// never on a quota check: an extension has no way to await an entitlement lookup before it draws a
// shield, and a slow or failing lookup must not decide whether a morning is counted.
enum SubscriptionTierStore {
    private static let resolvedTierKey = "resolvedSubscriptionTier"

    private nonisolated static var defaults: UserDefaults {
        UserDefaults(suiteName: TuckIdentifiers.appGroupSuiteName) ?? .standard
    }

    // The fallback is the last entitlement StoreKit actually confirmed, never a hardcoded floor.
    // The previous version returned `.standard` for an absent key, which read a "not answered yet"
    // as a decided tier; the mirror-image bug was on the write side, where any lookup that came
    // back empty cleared the cache — a paying user on a slow network lost Plus for as long as the
    // answer took. Only a resolution that proved something writes here (SubscriptionController),
    // so nil means nothing was ever confirmed, not that nothing is owed.
    nonisolated static func cachedTier(in defaults: UserDefaults = Self.defaults) -> SubscriptionTier? {
        guard let raw = defaults.string(forKey: resolvedTierKey) else { return nil }
        return SubscriptionTier(rawValue: raw)
    }

    nonisolated static func store(_ tier: SubscriptionTier, in defaults: UserDefaults = Self.defaults) {
        defaults.set(tier.rawValue, forKey: resolvedTierKey)
    }

    // Separate from `store` on purpose: clearing is the one write that takes access away, and it
    // may only happen where a negative was proven. A single optional-taking setter would make the
    // dangerous case look like the harmless one at the call site.
    nonisolated static func clear(in defaults: UserDefaults = Self.defaults) {
        defaults.removeObject(forKey: resolvedTierKey)
    }
}
