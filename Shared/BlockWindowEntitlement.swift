import DeviceActivity

// The gate's second half. BlockWindowReconciler.bedtimeWindowAction closes the evening window
// in the app process, but only when the app comes forward — an install whose trial ran out while
// nobody opened it keeps a registration iOS goes on firing, and the monitor extension used to shield
// on every one of those callbacks. So the same question is asked again at the last point before the
// shield is written, in the process that writes it.
//
// Pure, and in Shared rather than in the extension, for the reason ShieldActionRouting is: the
// Simulator never launches an app extension, so a decision that lives in TuckMonitor is a decision
// no test can reach.
//
// The morning is never gated. It is what the app is for and it is free (docs/SSOT.md) — a bug here
// must not be able to take it away.
enum BlockWindowEntitlement {
    enum Action: Equatable {
        case shield
        case release
    }

    static func action(for activity: DeviceActivityName, access: SubscriptionAccess) -> Action {
        activity == .bedtimeBlock && !access.hasPlusAccess ? .release : .shield
    }
}
