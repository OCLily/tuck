import SwiftUI
import Testing
import UIKit
@testable import Tuck

// The shield is drawn by a system process from a ShieldConfiguration, so there is no view
// to snapshot and no Simulator run that shows it — Family Controls does not even authorize there.
// The values it is handed are all this screen can be checked against, which makes a computed WCAG
// ratio over the resolved UIColors the verification, the same way AccentColorTests verifies the
// accent by resolving it rather than by trusting the catalog.
//
// The bar is 4.5:1 and not 3:1: ShieldConfiguration.Label has no font parameter, iOS picks size and
// weight, so this is the one label in the app that cannot reach the large-text exception of the
// contrast rule and has to clear AA for small text on its own. The shield resolves per
// appearance, so every ratio below is asserted in both — the rule holds over
// both appearances, not a light-mode rule with a dark-mode exemption.
struct ShieldContrastTests {
    @Test func theShieldPrimaryButtonLabelReachesAAForSmallTextInBothAppearances() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let ratio = Appearance.contrastRatio(
                Appearance.resolve(ShieldPalette.primaryButtonLabel, style),
                on: Appearance.resolve(ShieldPalette.primaryButtonBackground, style)
            )

            #expect(ratio >= 4.5, "\(style.rawValue): \(ratio)")
        }
    }

    // The two pairings the one above resolves to, as equalities rather than as a threshold — a
    // palette change has to move these numbers, not quietly erode them towards the bar.
    @Test func bothPrimaryButtonPairingsKeepTheirDocumentedRatio() {
        #expect(Self.buttonRatio(.light) == 4.53)
        #expect(Self.buttonRatio(.dark) == 5.21)
    }

    // The pairing this replaced, kept as the reason the one above exists: charcoal on full sage is
    // 3.40:1 — below even the 3:1 non-text threshold's large-text sibling once the font is unknown.
    @Test func theSagePlateItReplacedCouldNotHaveReachedThatBar() {
        let ratio = Appearance.contrastRatio(
            UIColor(Color.LightPalette.charcoalGreen),
            on: UIColor(Color.LightPalette.sage)
        )

        #expect(ratio < 3.5)
    }

    // The standing deviation: title, subtitle and the secondary button carry no colourable
    // surface, so in light they sit at the app-wide body ratio and miss the 4.5 the buttons clear.
    // Dark is the appearance where that deviation disappears on its own.
    @Test func theShieldTitleKeepsTheAppWideBodyRatio() {
        #expect(Self.titleRatio(.light) == 3.96)
        #expect(Self.titleRatio(.dark) == 10.93)
    }

    // Non-text, and the reason the dark button needs a plate at all: the fill has to separate from
    // the page or the button stops looking like one. Dark buys its label ratio with a flatter plate.
    @Test func theButtonPlateStaysDistinguishableFromThePage() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let ratio = Appearance.contrastRatio(
                Appearance.resolve(ShieldPalette.primaryButtonBackground, style),
                on: Appearance.resolve(ShieldPalette.background, style)
            )

            #expect(ratio >= 2.0, "\(style.rawValue): \(ratio)")
        }
    }

    private static func buttonRatio(_ style: UIUserInterfaceStyle) -> Double {
        Appearance.rounded(Appearance.contrastRatio(
            Appearance.resolve(ShieldPalette.primaryButtonLabel, style),
            on: Appearance.resolve(ShieldPalette.primaryButtonBackground, style)
        ))
    }

    private static func titleRatio(_ style: UIUserInterfaceStyle) -> Double {
        Appearance.rounded(Appearance.contrastRatio(
            Appearance.resolve(ShieldPalette.text, style),
            on: Appearance.resolve(ShieldPalette.background, style)
        ))
    }
}

// The shield's four colours resolve per appearance. Its light
// column has to stay byte-identical to what shipped first — the dark phase may not move a light pixel
// on the one screen a blocked user has no choice but to read.
struct ShieldPaletteAppearanceTests {
    @Test func everyShieldColourResolvesToItsDocumentedPair() {
        let expected: [(String, Color, UInt32, UInt32)] = [
            ("background", ShieldPalette.background, 0xF5EFE6, 0x17201B),
            ("text", ShieldPalette.text, 0x6B7A6E, 0xCDD3C9),
            ("primaryButtonBackground", ShieldPalette.primaryButtonBackground, 0x6B7A6E, 0x47544C),
            ("primaryButtonLabel", ShieldPalette.primaryButtonLabel, 0xFFFFFF, 0xCDD3C9)
        ]
        for (name, color, light, dark) in expected {
            #expect(Appearance.hex(color, .light) == light, "\(name) light")
            #expect(Appearance.hex(color, .dark) == dark, "\(name) dark")
        }
    }

    // The one place the shield refuses the house token. In dark the button is exactly the app's
    // primary button; in light it cannot be, because cream on charcoal is 3.96:1 and this
    // is the screen where the large-text exception does not exist. Asserting the divergence keeps a
    // future "unify the tokens" tidy-up from silently reopening it.
    @Test func onlyTheLightLabelDivergesFromTheAppsOwnPrimaryButton() {
        #expect(Appearance.hex(ShieldPalette.primaryButtonLabel, .light)
                != Appearance.hex(.tuckPrimaryPlateLabel, .light))
        #expect(Appearance.hex(ShieldPalette.primaryButtonLabel, .dark)
                == Appearance.hex(.tuckPrimaryPlateLabel, .dark))
        #expect(Appearance.hex(ShieldPalette.primaryButtonBackground, .dark)
                == Appearance.hex(.tuckPrimaryPlate, .dark))
    }
}

// The property the whole dark shield rests on, and the one nothing documents: a ShieldConfiguration
// crosses into another process, and it crosses as an archive.
//
// Verified against the shipped frameworks, not assumed: ManagedSettingsUI encodes each colour with
// `NSKeyedArchiver.archivedData(withRootObject:requiringSecureCoding: true)` into MOShieldConfiguration's
// `…ColorData` fields, and ScreenTimeUI's STBlockingViewController decodes them with
// `unarchivedObjectOfClass:UIColor fromData:` and assigns the result straight to `setTextColor:`,
// `setBackgroundColor:` and `setBaseForegroundColor:` — it never calls `resolvedColor(with:)`. So
// the only question that decides whether the shield can have a dark mode at all is whether that
// exact round trip preserves the dynamism, and these tests are that question.
//
// It does: a dynamic UIColor archives as a baked per-trait table rather than as a resolved value.
// The consequence is the part worth keeping in mind — because the colour arrives still dynamic, the
// *host* re-resolves it, so the shield follows the system setting live without iOS ever re-asking
// the data source. There is no re-invocation hook in ShieldConfigurationDataSource and none is
// needed.
struct ShieldPaletteArchiveTests {
    @Test func aShieldColourSurvivesTheArchiveStillResolvingPerAppearance() throws {
        for color in [ShieldPalette.background, ShieldPalette.text,
                      ShieldPalette.primaryButtonBackground, ShieldPalette.primaryButtonLabel] {
            let restored = try Self.roundTrip(UIColor(color))

            #expect(Self.hex(restored, .light) == Appearance.hex(color, .light))
            #expect(Self.hex(restored, .dark) == Appearance.hex(color, .dark))
        }
    }

    // The failure this would look like if the archive ever started flattening: both appearances
    // collapsing onto whichever one happened to be current in the extension process. Stated
    // separately because the assertions above would still pass in light and only fail in dark, and
    // the shield is a screen no test run ever renders.
    @Test func theArchiveDoesNotFlattenTheColourToTheCurrentAppearance() throws {
        let restored = try Self.roundTrip(UIColor(ShieldPalette.background))

        #expect(Self.hex(restored, .light) != Self.hex(restored, .dark))
    }

    // The subclass that carries the table. `unarchivedObjectOfClass: UIColor` is what the host asks
    // for, and it accepts the subclass — if a future UIKit returned a plain UIColor here, the
    // dynamism would be gone and the two tests above would be the ones to say so.
    @Test func theRestoredColourIsStillADynamicUIColor() throws {
        let restored = try Self.roundTrip(UIColor(ShieldPalette.text))

        #expect(String(describing: type(of: restored)).contains("Dynamic"))
    }

    private static func roundTrip(_ color: UIColor) throws -> UIColor {
        let data = try NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true)
        return try #require(try NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data))
    }

    private static func hex(_ color: UIColor, _ style: UIUserInterfaceStyle) -> UInt32 {
        let resolved = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return [red, green, blue].reduce(UInt32(0)) { $0 << 8 | UInt32(($1 * 255).rounded()) }
    }
}
