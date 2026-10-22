import SwiftUI
import Testing
import UIKit
@testable import Tuck

// The three pairings the brand layer is allowed to make, pinned as exact equalities the
// way the design system's own table is — not with an `accuracy:` band, because the point of the lock is that a
// palette edit has to break it visibly. `Appearance.rounded` is the house rounding: (r*100).rounded()
// / 100, rounded and not truncated.
//
// The numbers are recomputed here, not copied. The figures first claimed for these three pairs
// were 5,0 / 5,2 / 2,9; two independent recalculations put them at 4,94 / 5,36 / 2,96, and the
// third of those is the one that matters — it is the forbidden pairing, and 2,9 vs 2,96 is the
// difference between a number someone measured and a number someone rounded off in prose. Every
// further figure of that kind is a claim until it is measured.
//
// Both BrandPalette values are static colours, so the trait collection is immaterial; `.light` is
// passed because `Appearance.resolve` requires one.
struct BrandPaletteContrastTests {
    private static func ratio(_ foreground: Color, on background: Color) -> Double {
        Appearance.rounded(
            Appearance.contrastRatio(
                Appearance.resolve(foreground, .light),
                on: Appearance.resolve(background, .light)
            )
        )
    }

    // Without this the three ratios below would still pass while being about different colours —
    // this project's own failure class, a green test that measured the wrong thing. Night Ink is
    // named rather than written out for the same reason the icon's gradient names it: #17201B is
    // one value with one meaning, not a brand literal that happens to coincide.
    @Test func theFourColoursUnderTheRatiosAreTheOnesThatWereMeasured() {
        #expect(Appearance.hex(Color.BrandPalette.dawnRed, .light) == 0xE0674C)
        #expect(Appearance.hex(Color.BrandPalette.dawnRedDeep, .light) == 0xA84028)
        #expect(Appearance.hex(Color.DarkPalette.nightInk, .light) == 0x17201B)
        #expect(Appearance.hex(Color.LightPalette.cream, .light) == 0xF5EFE6)
    }

    @Test func nightInkOnMorgenrotCarriesSmallTextAtFourPointNineFour() {
        #expect(Self.ratio(Color.DarkPalette.nightInk, on: Color.BrandPalette.dawnRed) == 4.94)
    }

    @Test func morgenrotTiefOnCreamCarriesSmallTextAtFivePointThreeSix() {
        #expect(Self.ratio(Color.BrandPalette.dawnRedDeep, on: Color.LightPalette.cream) == 5.36)
    }

    // The forbidden pairing, and the reason the other two exist: cream on Morgenrot is 2,96:1 and
    // stays under the 4,5:1 floor for this brand layer — it may not carry text at any
    // size, small or large (it misses the 3:1 large-text bar too). The equality already enforces
    // that; the name says it so a reader does not have to know which side of 4,5 the number is on.
    @Test func creamOnMorgenrotStaysUnderTheFourPointFiveFloorAndCarriesNoText() {
        #expect(Self.ratio(Color.LightPalette.cream, on: Color.BrandPalette.dawnRed) == 2.96)
    }
}
