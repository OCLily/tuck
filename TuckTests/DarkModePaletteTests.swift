import SwiftUI
import Testing
import UIKit
@testable import Tuck

// The tokens are dynamic UIColors behind a Color, which means nothing about them
// is visible to a grep and nothing fails to compile if one of them silently stops resolving — the
// same argument AccentColorTests makes for the colorset. Resolving each one against both trait
// collections is the only check there is.
//
// It also pins the one thing this whole mechanism rests on and that no documentation guarantees:
// that Color keeps the dynamism when SwiftUI hands it back as a UIColor, and that Color.mix does
// too. MorningSky mixes two tokens at the call site on every frame; if mix resolved eagerly the sky
// would freeze at whatever appearance happened to be current when the view was built.
struct DarkPaletteResolutionTests {
    @Test func everyTokenResolvesToItsOwnValuePerAppearance() {
        let expected: [(String, Color, UInt32, UInt32)] = [
            ("sage", .tuckSage, 0xD8E2D3, 0x2A3830),
            ("cream", .tuckCream, 0xF5EFE6, 0x17201B),
            ("dustyRose", .tuckDustyRose, 0xE8C4B8, 0xE4C9A0),
            ("charcoalGreen", .tuckCharcoalGreen, 0x6B7A6E, 0xCDD3C9),
            ("ink", .tuckInk, 0x5A665C, 0xCDD3C9),
            ("primaryPlate", .tuckPrimaryPlate, 0x6B7A6E, 0x47544C),
            ("primaryPlateLabel", .tuckPrimaryPlateLabel, 0xF5EFE6, 0xCDD3C9),
            ("floatingPlate", .tuckFloatingPlate, 0xFFFFFF, 0x47544C),
            ("mascotCatchlight", .tuckMascotCatchlight, 0xFFFFFF, 0x17201B),
            ("mascotBody", .tuckMascotBody, 0xD8E2D3, 0x3A4A40),
            ("dustyBlue", .tuckDustyBlue, 0x6C7A85, 0xBCD5E8),
            ("warmSand", .tuckWarmSand, 0x8A7A6B, 0xE7CCB3),
            ("softLavender", .tuckSoftLavender, 0x7A6E85, 0xDBC6F0)
        ]
        for (name, token, light, dark) in expected {
            #expect(Appearance.hex(token, .light) == light, "\(name) light")
            #expect(Appearance.hex(token, .dark) == dark, "\(name) dark")
        }
    }

    // The three dawn tones are mixes, so their value is whatever Color.mix produces in the
    // perceptual space rather than a channel average — recorded here, not derived by hand.
    @Test func theDerivedDawnTonesResolvePerAppearanceToo() {
        #expect(Appearance.hex(.tuckDawnShadow, .light) == 0xB6C2B3)
        #expect(Appearance.hex(.tuckDawnShadow, .dark) == 0x24312A)
        #expect(Appearance.hex(.tuckDawnGlow, .light) == 0xEDD3C8)
        #expect(Appearance.hex(.tuckDawnGlow, .dark) == 0x95896E)
        #expect(Appearance.hex(.tuckDaySky, .light) == 0xF9F5EF)
        #expect(Appearance.hex(.tuckDaySky, .dark) == 0x3B4940)
    }

    @Test func mixingTwoTokensKeepsBothAppearances() {
        let mixed = Color.tuckDawnShadow.mix(with: .tuckDaySky, by: 1.0)

        #expect(Appearance.hex(mixed, .light) == Appearance.hex(.tuckDaySky, .light))
        #expect(Appearance.hex(mixed, .dark) == Appearance.hex(.tuckDaySky, .dark))
    }

    // One surface is still handed to a process outside SwiftUI's environment and still reads the
    // light literal: the AlarmKit tint, which is encoded into AlarmAttributes — an ActivityKit type
    // whose real interface declares `encode(to:)`, and Color's Codable conformance writes resolved
    // components rather than a per-appearance table. The shield is no longer in this category:
    // its transport is NSKeyedArchiver, which does carry the table (ShieldPaletteArchiveTests).
    @Test func theAlarmKitTintStaysPinnedToLight() {
        #expect(Appearance.hex(.LightPalette.charcoalGreen, .light)
                == Appearance.hex(.LightPalette.charcoalGreen, .dark))
        #expect(Appearance.hex(.LightPalette.charcoalGreen, .dark)
                != Appearance.hex(.tuckCharcoalGreen, .dark))
    }
}

// The dark half of the contrast table in design-system.md, computed the same way the table and
// ShieldContrastTests are: WCAG 2.1, sRGB, against the resolved values, with translucent
// surfaces composited over the page first because that is what the eye gets.
struct DarkContrastTests {
    @Test func everyTextGroundKeepsItsDocumentedRatio() {
        let page = Appearance.resolve(.tuckCream, .dark)
        let grounds: [(String, UIColor, Double)] = [
            ("Seite", page, 10.93),
            ("passive Fläche", Appearance.composite(.tuckSage, alpha: 0.25, over: page, style: .dark), 10.21),
            ("Aktionsfläche", Appearance.composite(.tuckSage, alpha: 0.5, over: page, style: .dark), 9.48),
            ("Aufmerksamkeit", Appearance.composite(.tuckDustyRose, alpha: 0.45, over: page, style: .dark), 3.42),
            ("Sage 100 %", Appearance.resolve(.tuckSage, .dark), 8.06),
            ("Primärbutton", Appearance.resolve(.tuckPrimaryPlate, .dark), 5.21),
            ("Sprechblase", Appearance.composite(.tuckFloatingPlate, alpha: 0.9, over: page, style: .dark), 5.65)
        ]
        let ink = Appearance.resolve(.tuckCharcoalGreen, .dark)
        for (name, ground, ratio) in grounds {
            #expect(Appearance.rounded(Appearance.contrastRatio(ink, on: ground)) == ratio, "\(name)")
        }
    }

    // The label reads on the plate and the plate reads on the page — the pair the role split of
    // tuckCharcoalGreen exists for. A blind swap of the fill to the text value would have
    // made the first number meaningless and the second one 1.0.
    @Test func theFilledPrimaryButtonReadsBothWays() {
        let plate = Appearance.resolve(.tuckPrimaryPlate, .dark)
        let label = Appearance.resolve(.tuckPrimaryPlateLabel, .dark)

        #expect(Appearance.rounded(Appearance.contrastRatio(label, on: plate)) == 5.21)
        #expect(Appearance.rounded(Appearance.contrastRatio(plate, on: Appearance.resolve(.tuckCream, .dark))) == 2.10)
    }

    // The sky is the worst text ground of the light app (2.44:1 to 4.16:1, so under the 3:1
    // over part of the screen). In dark its worst point is 3.36:1, above that bar rather than below
    // it — so this is the one ground dark mode improves, and the test is here to keep it that way.
    // The light counterpart is LightSkyContrastTests below: the range is a decided
    // tradeoff rather than an open question, so it can be pinned like this one.
    @Test func theSkyGradientStaysAboveTheNonTextThresholdAtEveryProgress() {
        let ink = Appearance.resolve(.tuckCharcoalGreen, .dark)
        var worst = Double.infinity
        for step in 0...100 {
            let progress = Double(step) / 100
            for stop in MorningSky.stops(progress: progress) {
                worst = min(worst, Appearance.contrastRatio(ink, on: Appearance.resolve(stop, .dark)))
            }
        }

        #expect(Appearance.rounded(worst) == 3.36)
    }
}

// The light half of the same gradient, by the same method as the dark test above — but it pins an
// accepted floor, not a passed bar. 2.44:1 is under the 3:1 the contrast rule relies on; it was accepted
// as a fixed product decision for status text at accessibility sizes and nothing else. The test is here
// so the accepted number is mechanical rather than prose: if the palette or the gradient moves, the
// acceptance has to be granted again instead of drifting along.
struct LightSkyContrastTests {
    @Test func theSkyGradientsLightRangeIsTheAcceptedOneAndItsFloorIsUnderTheThreshold() {
        let ink = Appearance.resolve(.tuckCharcoalGreen, .light)
        var worst = Double.infinity
        var best = -Double.infinity
        for step in 0...100 {
            let progress = Double(step) / 100
            for stop in MorningSky.stops(progress: progress) {
                let ratio = Appearance.contrastRatio(ink, on: Appearance.resolve(stop, .light))
                worst = min(worst, ratio)
                best = max(best, ratio)
            }
        }

        #expect(Appearance.rounded(worst) == 2.44)
        #expect(Appearance.rounded(best) == 4.16)
        #expect(worst < 3.0)
    }
}

// Light. The dusty-rose notice card is the worst text ground of the app, and its number used to
// live in six places of prose and in none of the tests. Prose is what
// drifted — or rather, prose is what could not say which of two arithmetics it meant: 3,42 is the
// hex hand calculation, 3,41 is the runtime one, and the design system now declares the runtime one binding.
// This is the mechanism behind that declaration on the light side, the same way DarkContrastTests
// is on the dark one.
//
// Resolved through `Appearance.composite(…, style: .light)`. The explicit style is not decoration:
// without it the shared helper composites the DARK dusty rose (Moon Glow) over light cream and
// returns a believable, wrong number — see the comment on `Appearance.composite`.
struct NoticeCardLightContrastTests {
    private static var ground: UIColor {
        Appearance.composite(.tuckDustyRose,
                             alpha: 0.45,
                             over: Appearance.resolve(.tuckCream, .light),
                             style: .light)
    }

    private static func ratio(of ink: Color) -> Double {
        Appearance.contrastRatio(Appearance.resolve(ink, .light), on: ground)
    }

    // The title of the card, at weight 700, bought back by the large-text path — 3:1 is the bar
    // it has to clear, and it clears it by four hundredths. That is the whole reason this number is
    // worth a mechanical pin rather than a sentence.
    @Test func theNoticeCardsWorstInkIsTheDocumentedOne() {
        #expect(Appearance.rounded(Self.ratio(of: .tuckCharcoalGreen)) == 3.41)
        #expect(Self.ratio(of: .tuckCharcoalGreen) > 3.0)
    }

    // The detail line, on the body-ink token. Already pinned as part of
    // BodyInkContrastTests' table; repeated here so the card's two inks stand next to each other
    // and the hex/runtime difference can be read off one place.
    @Test func theNoticeCardsDetailInkClearsAAForSmallText() {
        #expect(Appearance.rounded(Self.ratio(of: .tuckInk)) == 4.53)
        #expect(Self.ratio(of: .tuckInk) >= 4.5)
    }
}

// The body-ink token exists for exactly one number: 4.5:1, AA for small
// text, on every surface the app sets running text on. Charcoal green reaches that on none of them,
// which is why the contrast rule buys each body line back with the large-text exception and why the app's running
// text is set at weight 700. These assertions are that promise — the threshold as a bar, and each
// ground as an equality so a palette change has to move the number rather than erode it.
//
// Light only. In dark the token *is* tuckCharcoalGreen (Moon Sage), the ratios are the 10.93/10.21/
// 9.48 DarkContrastTests already pins, and the last test below is what says so.
struct BodyInkContrastTests {
    @Test func theBodyInkClearsAAForSmallTextOnEveryTextGroundOfTheApp() {
        for (name, ground) in Self.lightGrounds {
            let ratio = Self.ratio(on: ground)
            #expect(ratio >= 4.5, "\(name): \(ratio)")
        }
    }

    @Test func everyLightTextGroundKeepsItsDocumentedInkRatio() {
        let expected = ["Seite": 5.26, "passive Fläche": 5.07, "Aktionsfläche": 4.88,
                        "Aufmerksamkeit": 4.53, "Sprechblase": 5.94,
                        "Onboarding-Verlauf": 4.80]
        for (name, ground) in Self.lightGrounds where expected[name] != nil {
            #expect(Appearance.rounded(Self.ratio(on: ground)) == expected[name], "\(name)")
        }
    }

    // The reason the fix is a token and not a darker palette: charcoal green keeps every value it
    // had. It is the app icon, the darkest stop of the sky, the filled plate and the mascot outline,
    // and not one of those had the problem this token solves.
    @Test func theBrandTokenIsUntouchedAndTheDarkHalfIsDeliberatelyIdentical() {
        #expect(Appearance.hex(.tuckCharcoalGreen, .light) == 0x6B7A6E)
        #expect(Appearance.hex(.tuckInk, .light) != Appearance.hex(.tuckCharcoalGreen, .light))
        #expect(Appearance.hex(.tuckInk, .dark) == Appearance.hex(.tuckCharcoalGreen, .dark))
    }

    // Same hue and same saturation as charcoal green, only darker — the token is a sibling of the
    // brand colour, not a second one. Without this a future nudge could drift it off the family and
    // still pass every ratio above.
    @Test func theInkStaysInTheBrandsOwnHueAndSaturationBand() {
        let (inkHue, inkSaturation) = Self.hueSaturation(Appearance.resolve(.tuckInk, .light))
        let (brandHue, brandSaturation) = Self.hueSaturation(Appearance.resolve(.tuckCharcoalGreen, .light))

        #expect(abs(inkHue - brandHue) < 0.01, "\(inkHue) vs \(brandHue)")
        #expect(abs(inkSaturation - brandSaturation) < 0.03, "\(inkSaturation) vs \(brandSaturation)")
        #expect(inkSaturation <= 0.25)
    }

    private static var lightGrounds: [(String, UIColor)] {
        let page = Appearance.resolve(.tuckCream, .light)
        return [
            ("Seite", page),
            ("passive Fläche", Appearance.composite(.tuckSage, alpha: 0.25, over: page, style: .light)),
            ("Aktionsfläche", Appearance.composite(.tuckSage, alpha: 0.5, over: page, style: .light)),
            ("Aufmerksamkeit", Appearance.composite(.tuckDustyRose, alpha: 0.45, over: page, style: .light)),
            ("Sprechblase", Appearance.composite(.tuckFloatingPlate, alpha: 0.9, over: page, style: .light)),
            // Added with the sweep that put four onboarding body lines on this token:
            // the flow's own gradient ends on sage 0.6 over cream, a ground the contrast table never listed
            // because until then nothing but charcoal green at weight 700 stood on it. It is the
            // worst ink ground of the flow, so it is the one worth pinning.
            ("Onboarding-Verlauf", Appearance.composite(.tuckSage, alpha: 0.6, over: page, style: .light))
        ]
    }

    private static func ratio(on ground: UIColor) -> Double {
        Appearance.contrastRatio(Appearance.resolve(.tuckInk, .light), on: ground)
    }

    private static func hueSaturation(_ color: UIColor) -> (CGFloat, CGFloat) {
        var (hue, saturation, brightness, alpha) = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0))
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return (hue, saturation)
    }
}

// The mascot inks in dark. Same three rules as MascotColorVariantContrastTests, against the dark ground: the
// inks are non-text and are drawn on the mascot's own body, which is Midnight Sage there.
struct DarkMascotColorVariantContrastTests {
    // REPOINTED, and the repoint is the point of the line. It used to resolve
    // `.tuckSage`, which was the mascot's body only for as long as the mascot had no token of its
    // own. Left as it was it would have stayed green while measuring a colour the animal no longer
    // wears: the "lautloser Ausfall" class this project guards against, a test reporting success about
    // something it is no longer looking at.
    @Test func everyVariantClearsTheNonTextThresholdOnTheMascotsOwnBody() {
        let body = Appearance.resolve(.tuckMascotBody, .dark)
        for variant in MascotColorVariant.allCases {
            let ratio = Appearance.contrastRatio(Appearance.resolve(variant.color, .dark), on: body)
            #expect(ratio >= 3.0, "\(variant.rawValue) on the dark mascot body: \(ratio)")
        }
    }

    // The four values as exact equalities rather than as "above 3". Recomputed independently a
    // third time before they were written down, and the third pass moved one of them: Moon Dusty
    // Blue is 6,18827..., which is 6,1883 at four places and had been carried as 6,1882.
    @Test func theFourInksKeepTheirMeasuredRatioOnTheDarkBody() {
        let body = Appearance.resolve(.tuckMascotBody, .dark)
        let expected: [(MascotColorVariant, Double)] = [
            (.charcoalGreen, 6.1595),
            (.dustyBlue, 6.1883),
            (.warmSand, 6.1277),
            (.softLavender, 5.9764)
        ]
        #expect(expected.count == MascotColorVariant.allCases.count)
        for (variant, ratio) in expected {
            let measured = Appearance.contrastRatio(Appearance.resolve(variant.color, .dark), on: body)
            #expect(Self.roundedToFour(measured) == ratio, "\(variant.rawValue): \(measured)")
        }
    }

    // Why the token exists at all, as a number: the body used to be Midnight Sage, the same value
    // the settings rows and the secondary plates are filled with, and it stood on the page at
    // 1,3558:1. The animal now separates from the night it sits in.
    @Test func theDarkBodySeparatesFromThePageBetterThanTheSurfaceTokenDid() {
        let page = Appearance.resolve(.tuckCream, .dark)
        let before = Appearance.contrastRatio(Appearance.resolve(.tuckSage, .dark), on: page)
        let after = Appearance.contrastRatio(Appearance.resolve(.tuckMascotBody, .dark), on: page)

        #expect(Self.roundedToFour(before) == 1.3558)
        #expect(Self.roundedToFour(after) == 1.7742)
        #expect(after > before)
    }

    // Light is unchanged to the byte. A separate light body that was proposed earlier was turned down
    // on measured numbers, and this token does not bring it back through a side door.
    @Test func theLightBodyIsStillSageAndStillNotTheRejectedValue() {
        #expect(Appearance.hex(.tuckMascotBody, .light) == Appearance.hex(.tuckSage, .light))
        #expect(Appearance.hex(.tuckMascotBody, .light) != 0xC8D6C2)
        #expect(Appearance.hex(.tuckMascotBody, .dark) != Appearance.hex(.tuckSage, .dark))
    }

    // One animal, one colour. The six fills of the rig (two ears, body, stem, bud, leaves) all read
    // the token, and a source scan is the only thing that can say so: a leftover surface token
    // would draw a sage-eared animal on a darker body, and no assertion about colour values would
    // ever see it.
    @Test func theWholeAnimalIsFilledFromTheOneToken() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Tuck/MascotPose.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        #expect(!source.contains("Color.tuckSage"),
                "Tuck/MascotPose.swift still fills part of the rig from the surface token")
        #expect(source.components(separatedBy: "Color.tuckMascotBody").count - 1 == 6,
                "the rig has six fills and all six have to read the body token")
    }

    private static func roundedToFour(_ ratio: Double) -> Double { (ratio * 10_000).rounded() / 10_000 }

    // The rule is equal luminance, not equal HSB brightness — that distinction does no work in
    // light mode, where the four inks are near-neutral and low, and all the work in dark, where the
    // same brightness at these hues spreads the rig's weight three times as far.
    @Test func noVariantIsFartherFromTheOriginalThanTheOriginalIsFromTheBody() {
        let original = Appearance.relativeLuminance(Appearance.resolve(.tuckCharcoalGreen, .dark))
        for variant in MascotColorVariant.allCases {
            let luminance = Appearance.relativeLuminance(Appearance.resolve(variant.color, .dark))
            #expect(abs(luminance - original) < 0.04, "\(variant.rawValue): \(luminance)")
        }
    }

    // The catchlight is a position in the pair, not a colour: it has to be the far pole from the
    // pupil, which is the ink. Left as the plain `.white` it was a white dot on a Moon Sage pupil
    // and rendered nothing at all — the only element of the app that the first dark palette made invisible.
    // A ratio per variant rather than a fixed pair, because the pupil is whichever ink is unlocked.
    @Test func theEyeCatchlightSeparatesFromEveryPupilInBothAppearances() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let catchlight = Appearance.resolve(.tuckMascotCatchlight, style)
            for variant in MascotColorVariant.allCases {
                let ratio = Appearance.contrastRatio(catchlight, on: Appearance.resolve(variant.color, style))
                #expect(ratio >= 3.0, "\(variant.rawValue) @\(style.rawValue): \(ratio)")
            }
        }
    }

    @Test func noVariantLeavesThePalettesLowSaturationBand() {
        for variant in MascotColorVariant.allCases {
            #expect(Appearance.saturation(Appearance.resolve(variant.color, .dark)) <= 0.25, "\(variant.rawValue)")
        }
    }
}

// The disabled pair, in both appearances. It exists because the previous mechanism died on iOS
// 26.5: `.buttonStyle(.plain)` no longer suppresses the framework's disabled dimming, which
// took the gated "Weiter" to 1.37:1 — measured, not inferred. The pair replaces that with a look the
// app paints itself, and these numbers are the reason it is allowed to: the app owns them now, so
// they are pinned rather than described.
struct DisabledPairContrastTests {
    @Test func theDisabledPairClearsTheLargeTextBarInBothAppearances() {
        let expected: [(UIUserInterfaceStyle, Double)] = [(.light, 3.40), (.dark, 8.06)]
        for (style, ratio) in expected {
            let plate = Appearance.resolve(.tuckDisabledPlate, style)
            let ink = Appearance.resolve(.tuckDisabledPlateLabel, style)
            let measured = Appearance.contrastRatio(ink, on: plate)

            #expect(Appearance.rounded(measured) == ratio, "@\(style.rawValue)")
            #expect(measured >= 3.0, "@\(style.rawValue): \(measured)")
        }
    }

    // The other half of "reads as disabled": the plate has to give up presence against the page, or
    // the label ratio above would just be an enabled button in different colours. Light 3.96 → 1.17,
    // dark 2.10 → 1.36, both against the same page the enabled plate is measured on.
    @Test func theDisabledPlateRecedesTowardsThePageInBothAppearances() {
        let expected: [(UIUserInterfaceStyle, Double, Double)] = [(.light, 3.96, 1.17), (.dark, 2.10, 1.36)]
        for (style, enabled, disabled) in expected {
            let page = Appearance.resolve(.tuckCream, style)
            let on = Appearance.contrastRatio(Appearance.resolve(.tuckPrimaryPlate, style), on: page)
            let off = Appearance.contrastRatio(Appearance.resolve(.tuckDisabledPlate, style), on: page)

            #expect(Appearance.rounded(on) == enabled, "@\(style.rawValue)")
            #expect(Appearance.rounded(off) == disabled, "@\(style.rawValue)")
            #expect(off < on, "@\(style.rawValue): \(off) is not less present than \(on)")
        }
    }

    // A disabled control may not be a repaint of an enabled one — the whole point of taking the
    // appearance away from the framework was to draw the state, not to hide it. The plate carries
    // that in both appearances; the ink only in light, where the plate overtakes the cream label and
    // the label has to fall back to the charcoal ink. In dark the ink is already the light half of
    // the pair and moving it would only cost contrast, so it stays Moon Sage — asserted here as the
    // deliberate asymmetry it is rather than left as a coincidence.
    @Test func theDisabledPlateNeverMatchesTheEnabledOneAndTheInkOnlyMovesWhereItMust() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            #expect(Appearance.hex(.tuckDisabledPlate, style) != Appearance.hex(.tuckPrimaryPlate, style))
        }

        #expect(Appearance.hex(.tuckDisabledPlateLabel, .light) != Appearance.hex(.tuckPrimaryPlateLabel, .light))
        #expect(Appearance.hex(.tuckDisabledPlateLabel, .dark) == Appearance.hex(.tuckPrimaryPlateLabel, .dark))
    }
}

enum Appearance {
    static func resolve(_ color: Color, _ style: UIUserInterfaceStyle) -> UIColor {
        UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
    }

    static func hex(_ color: Color, _ style: UIUserInterfaceStyle) -> UInt32 {
        let (red, green, blue) = components(resolve(color, style))
        return [red, green, blue].reduce(UInt32(0)) { $0 << 8 | UInt32(($1 * 255).rounded()) }
    }

    // `style:` is keyword-only and has NO default on purpose. This function used to
    // resolve its top colour in `.dark` unconditionally — it was written for DarkContrastTests and
    // used nowhere else — and BodyInkContrastTests carried a private copy of the same arithmetic for
    // the light side. Two functions, one of them silently appearance-bound, is a trap with a very
    // plausible failure: `composite(.tuckDustyRose, alpha: 0.45, over: cream)` reads as "dusty rose
    // over cream" and returns MOON GLOW over cream. The result is a believable, wrong number, and
    // the obvious repair is to write that number into the expectation — a mechanically pinned
    // falsehood in test and doc at once. A parameter without a default makes the question
    // unskippable at every call site.
    static func composite(_ color: Color, alpha: Double, over background: UIColor,
                          style: UIUserInterfaceStyle) -> UIColor {
        let top = components(resolve(color, style))
        let bottom = components(background)
        return UIColor(
            red: top.0 * alpha + bottom.0 * (1 - alpha),
            green: top.1 * alpha + bottom.1 * (1 - alpha),
            blue: top.2 * alpha + bottom.2 * (1 - alpha),
            alpha: 1
        )
    }

    static func rounded(_ ratio: Double) -> Double {
        (ratio * 100).rounded() / 100
    }

    static func saturation(_ color: UIColor) -> CGFloat {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return saturation
    }

    static func contrastRatio(_ foreground: UIColor, on background: UIColor) -> Double {
        let lighter = max(relativeLuminance(foreground), relativeLuminance(background))
        let darker = min(relativeLuminance(foreground), relativeLuminance(background))
        return (lighter + 0.05) / (darker + 0.05)
    }

    static func relativeLuminance(_ color: UIColor) -> Double {
        let (red, green, blue) = components(color)
        let channels = [red, green, blue].map { channel -> Double in
            let value = Double(channel)
            return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
    }

    private static func components(_ color: UIColor) -> (CGFloat, CGFloat, CGFloat) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (red, green, blue)
    }
}
