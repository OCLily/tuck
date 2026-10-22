import Testing
import ManagedSettings
@testable import Tuck

// TuckShieldAction is a system extension (com.apple.ManagedSettings.shield-action-service)
// that the Simulator never launches, so nothing here proves the extension is reached at all — only
// that the mapping it applies is the one the unlock-path decision asks for.
struct ShieldActionRoutingTests {
    // The dismiss option is a first-class exit, not a failure: primary closes the blocked app and
    // that is the end of it.
    @Test func thePrimaryButtonJustClosesAndNeverOpensTheApp() {
        #expect(ShieldActionRouting.response(for: .primaryButtonPressed) == .close)
        #expect(ShieldActionRouting.routesToApp(.primaryButtonPressed) == false)
    }

    // The regression this whole pass exists for: the secondary button used to return .defer, so no
    // shield tap ever reached the app.
    @Test func theSecondaryButtonRoutesTowardTheApp() {
        #expect(ShieldActionRouting.routesToApp(.secondaryButtonPressed))
        #expect(ShieldActionRouting.response(for: .secondaryButtonPressed) != .close)
    }

    // The whole reason the deployment target was raised to 26.5: this case exists on every runtime
    // the app can now be installed on, so there is no version left in which the answer is .defer.
    @Test func theResponseIsOpenParentalControlsApp() {
        #expect(ShieldActionRouting.response(for: .secondaryButtonPressed) == .openParentalControlsApp)
    }

    @Test func aPressWithoutASubmenuCarriesNoReason() {
        #expect(ShieldActionRouting.reason(for: .primaryButtonPressed) == nil)
        #expect(ShieldActionRouting.reason(for: .secondaryButtonPressed) == nil)
    }

    // Positional, and the position is the only thing tying a pressed index back to a label.
    @Test func theSubmenuOrderTheShieldIsGivenIsTheOrderTheCasesAreMappedIn() {
        #expect(OverrideReason.allCases.map(\.rawValue) == ["Notfall", "Arbeit", "Anderes"])
    }
}

struct ShieldSubmenuRoutingTests {
    // The hard constraint: a submenu item picks the justification, never the whole override — so
    // it has to lead to the app, where the delay still runs, and may not resolve anything itself.
    @Test func everySubmenuItemRoutesTowardTheAppRatherThanResolvingAnything() {
        let submenuActions: [ShieldAction] = [
            .firstSecondarySubmenuItemPressed,
            .secondSecondarySubmenuItemPressed,
            .thirdSecondarySubmenuItemPressed
        ]

        for action in submenuActions {
            #expect(ShieldActionRouting.routesToApp(action))
            #expect(ShieldActionRouting.response(for: action) != .close)
            #expect(ShieldActionRouting.response(for: action) == ShieldActionRouting.response(for: .secondaryButtonPressed))
        }
    }

    // The three items used to arrive
    // indistinguishable, all three returning .close.
    @Test func eachSubmenuItemResolvesToItsOwnReason() {
        let submenuActions: [ShieldAction] = [
            .firstSecondarySubmenuItemPressed,
            .secondSecondarySubmenuItemPressed,
            .thirdSecondarySubmenuItemPressed
        ]

        #expect(ShieldActionRouting.reason(for: .firstSecondarySubmenuItemPressed) == .notfall)
        #expect(ShieldActionRouting.reason(for: .secondSecondarySubmenuItemPressed) == .arbeit)
        #expect(ShieldActionRouting.reason(for: .thirdSecondarySubmenuItemPressed) == .anderes)
        #expect(Set(submenuActions.compactMap(ShieldActionRouting.reason(for:))).count == 3)
    }
}
