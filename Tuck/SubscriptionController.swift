import Foundation
import Observation
import StoreKit

// Same honesty discipline as Shared/ShieldApplication.swift, for the same reason: a state that was
// not confirmed must never be displayed as if it were. `purchase()` returning `.success` is not a
// confirmed entitlement — the payload can still be unverified, and Ask to Buy can hold it for days
// — so `tier` is written from Transaction.currentEntitlements and from nowhere else. Anything the
// purchase call itself reports lands in `notice`, which never overwrites a confirmed entitlement.
@MainActor
@Observable
final class SubscriptionController {
    enum Entitlement: Equatable {
        case unresolved
        case notSubscribed
        case active(SubscriptionTier)
        case expired(SubscriptionTier)
    }

    enum Notice: Equatable {
        case awaitingApproval
        case unverified
        case failed(String)
    }

    private(set) var entitlement: Entitlement = .unresolved
    private(set) var products: [Product] = []
    private(set) var isWorking = false
    var notice: Notice?

    private var updatesTask: Task<Void, Never>?

    init() {
        // Has to run for the whole app lifetime rather than only while the paywall is on screen: a
        // renewal, a revocation, a family-approved Ask-to-Buy and a purchase made on another device
        // all arrive here and nowhere else, and each one makes the cached tier stale.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refreshEntitlement()
            }
        }
    }

    // `isolated deinit` (SE-0371) rather than a plain one: `updatesTask` is main-actor isolated and
    // a nonisolated deinit cannot touch it.
    isolated deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: SubscriptionPlan.allProductIDs)
            products = loaded.sorted { $0.price < $1.price }
        } catch {
            notice = .failed(error.localizedDescription)
        }
    }

    func refreshEntitlement() async {
        var entitled: Set<SubscriptionTier> = []
        var revoked = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  let tier = SubscriptionTier(productID: transaction.productID)
            else { continue }
            if transaction.revocationDate == nil {
                entitled.insert(tier)
            } else {
                revoked = true
            }
        }

        // Asked only where the answer can change anything, exactly as the branch used to be
        // ordered: a confirmed entitlement needs no second StoreKit round trip.
        let lapsed = entitled.isEmpty ? await lapsedTier() : nil
        apply(EntitlementResolution.resolve(entitled: entitled.first, revoked: revoked, lapsed: lapsed))
    }

    private func apply(_ outcome: EntitlementResolution.Outcome) {
        entitlement = outcome.entitlement
        switch outcome.cache {
        case .store(let tier): SubscriptionTierStore.store(tier)
        case .clear: SubscriptionTierStore.clear()
        case .leaveAlone: break
        }
    }

    func purchase(_ product: Product) async {
        notice = nil
        isWorking = true
        defer { isWorking = false }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                case .unverified:
                    // Signature check failed. Finishing it would bury the problem and reading a
                    // tier out of it would be exactly the optimistic claim this file refuses.
                    notice = .unverified
                }
            case .pending:
                notice = .awaitingApproval
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            notice = .failed(error.localizedDescription)
        }

        await refreshEntitlement()
    }

    func restore() async {
        notice = nil
        isWorking = true
        defer { isWorking = false }

        do {
            try await AppStore.sync()
        } catch {
            notice = .failed(error.localizedDescription)
        }

        await refreshEntitlement()
    }

    func product(for plan: SubscriptionPlan) -> Product? {
        products.first { $0.id == plan.productID }
    }

    // currentEntitlements drops a lapsed subscription entirely, so "expired" is only distinguishable
    // from "never bought" through the last transaction of the product itself.
    private func lapsedTier() async -> SubscriptionTier? {
        for plan in SubscriptionPlan.allCases {
            guard let latest = await Transaction.latest(for: plan.productID),
                  case .verified(let transaction) = latest,
                  let expiration = transaction.expirationDate,
                  expiration <= .now
            else { continue }
            return plan.tier
        }
        return nil
    }
}

// The whole decision of refreshEntitlement, with StoreKit left outside: three answers in, one state
// and one cache write out, nothing read and nothing written. The StoreKit calls above are not
// testable in the Simulator (StoreKitTest ships for iPhoneOS only, see SubscriptionTierTests) —
// this is the part that carries the money rule, so it is the part that does not have to share that
// fate. Extracted without a behaviour change; the eight input combinations are pinned in
// EntitlementResolutionTests.
extension SubscriptionController {
    enum EntitlementResolution {
        enum CacheWrite: Equatable {
            case store(SubscriptionTier)
            case clear
            case leaveAlone
        }

        struct Outcome: Equatable {
            let entitlement: Entitlement
            let cache: CacheWrite
        }

        // `entitled` is a verified, unrevoked current entitlement; `revoked` says a verified current
        // entitlement carried a revocationDate; `lapsed` is the tier of a latest transaction whose
        // expiration is in the past. All three can be absent at once, and that case is the reason
        // this function exists.
        //
        // Only a proven negative clears the cache. currentEntitlements coming back empty is not
        // evidence that a subscription is gone — it is also what a slow or failed lookup looks
        // like, and the old unconditional write meant a paying user momentarily dropped to the free
        // ceiling. An expired transaction or a revocation is proof; nothing else is, and leaving
        // the cache alone costs at most one stale grant against wrongly taking a paid one away.
        static func resolve(
            entitled: SubscriptionTier?,
            revoked: Bool,
            lapsed: SubscriptionTier?
        ) -> Outcome {
            // A live entitlement outranks both negatives: a revoked transaction of one period and a
            // lapsed transaction of the other are exactly what an upgrade or a re-subscription
            // leaves behind, and neither may take away what StoreKit currently confirms.
            if let entitled {
                return Outcome(entitlement: .active(entitled), cache: .store(entitled))
            }
            if let lapsed {
                return Outcome(entitlement: .expired(lapsed), cache: .clear)
            }
            return Outcome(entitlement: .notSubscribed, cache: revoked ? .clear : .leaveAlone)
        }
    }
}
