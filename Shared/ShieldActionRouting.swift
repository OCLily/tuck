import ManagedSettings

// The shield opens the app (docs/product-decisions-2026-09-02.md). Everything the shield
// can offer routes there — the override is a combination of delay AND justification, and the shield
// can carry neither half on its own (no timer, no animation, no time display). A submenu item
// that resolved anything by itself would be justification without delay, which breaks a product
// invariant.
//
// Split out of the extension so it can be tested at all: TuckShieldAction is a system
// extension the Simulator never launches, the app target compiles this same file, and
// TuckTests reaches it through the app.
enum ShieldActionRouting {
    // Everything except the primary "Ich lass es" is a request to finish the override in the app,
    // including each of the three submenu items — the reason is chosen, the delay still is not.
    static func routesToApp(_ action: ShieldAction) -> Bool {
        switch action {
        case .primaryButtonPressed:
            false
        case .secondaryButtonPressed,
             .firstSecondarySubmenuItemPressed,
             .secondSecondarySubmenuItemPressed,
             .thirdSecondarySubmenuItemPressed:
            true
        @unknown default:
            false
        }
    }

    // Verified in the 26.5 SDK, not assumed: ManagedSettings.swiftinterface:199 puts
    // .openParentalControlsApp behind @available(iOS 26.5, *), which the deployment target now is.
    static func response(for action: ShieldAction) -> ShieldActionResponse {
        routesToApp(action) ? .openParentalControlsApp : .close
    }

    // The three submenu cases map onto OverrideReason.allCases by position — the same order
    // ShieldConfigurationExtension feeds into secondaryButtonSubmenuItems, and the only thing that
    // ties a pressed index back to a label.
    static func reason(for action: ShieldAction) -> OverrideReason? {
        let index: Int? = switch action {
        case .firstSecondarySubmenuItemPressed: 0
        case .secondSecondarySubmenuItemPressed: 1
        case .thirdSecondarySubmenuItemPressed: 2
        default: nil
        }
        guard let index, index < OverrideReason.allCases.count else { return nil }
        return OverrideReason.allCases[index]
    }
}
