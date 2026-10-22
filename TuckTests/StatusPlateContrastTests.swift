import SwiftUI
import Testing
import UIKit
@testable import Tuck

// The design system accepts that the light sky falls under 3:1 across its upper band, and
// names what the acceptance is FOR: "als akzeptierter Tradeoff für Statustext bei
// Accessibility-Textgrößen". From .accessibility1 upwards that text now has a ground of its own —
// the same floating step the speech bubble carries — and this file is the number under it.
//
// WHY 4,29 AND NOT 5,69. The block renders charcoal green, not `tuckInk`, and says so two comments
// above its own `.foregroundStyle`. An equality pinned on an ink the surface does not carry is the
// "does it measure what I think it measures?" class — the same one that had
// MascotMilestoneTests resolving the mascot's body through `.tuckSage` long after the animal had a
// token of its own. 5,69 is what `tuckInk` WOULD read there; it stays documentation, without a pin.
//
// It is also the more robust half. Recomputed three ways:
//
//   Dawn Shadow unrounded, composition unrounded (the method the tests use)  4,2860 -> 4,29
//   Dawn Shadow as #B6C2B3, composition unrounded                            4,2869 -> 4,29
//   Dawn Shadow as #B6C2B3, composition rounded to #F8F9F7 (pure hex)        4,2909 -> 4,29
//
// 4,29 on all three. `tuckInk` gives 5,6914 / 5,6926 / 5,6979 — that one tips to 5,70 on the third
// path, which is exactly the kind of number a hand calculation can "disprove". So the pinned value
// is resolved through the tokens rather than through a hex constant, and the fragile one is prose.
//
// WORST CASE, NOT THE VALUE AT THE BLOCK'S OWN y: Dawn Shadow is the top stop at progress = 0, the
// darkest ground the sky ever puts under this text. The documentation says "mindestens", and so
// does this test's name.
struct StatusPlateContrastTests {
    private static var plateOverTheWorstSky: UIColor {
        // Deliberately through Appearance.composite with an explicit style rather than through a
        // hex literal: a hex constant here would be a second copy of two tokens, and the helper's
        // `style:` is what keeps this from compositing the DARK floating plate over a light sky.
        Appearance.composite(.tuckFloatingPlate,
                             alpha: 0.9,
                             over: Appearance.resolve(.tuckDawnShadow, .light),
                             style: .light)
    }

    @Test func theStatusPlateLiftsCharcoalToAtLeastTheDocumentedRatio() {
        let ink = Appearance.resolve(.tuckCharcoalGreen, .light)
        #expect(Appearance.rounded(Appearance.contrastRatio(ink, on: Self.plateOverTheWorstSky)) == 4.29)
    }

    // The whole point of the plate, stated as the comparison rather than as a second number: the
    // bare sky at this progress is 2,44:1 (LightSkyContrastTests pins that), the plate is over 3:1,
    // and the large-text bar the contrast rule buys the block back with is 3:1.
    @Test func thePlateIsWhatCarriesTheBlockOverTheLargeTextBar() {
        let ink = Appearance.resolve(.tuckCharcoalGreen, .light)
        let bareSky = Appearance.contrastRatio(ink, on: Appearance.resolve(.tuckDawnShadow, .light))

        #expect(Appearance.rounded(bareSky) == 2.44)
        #expect(bareSky < 3.0)
        #expect(Appearance.contrastRatio(ink, on: Self.plateOverTheWorstSky) > 3.0)
    }

    // The gate and the plate's own geometry, at the call site. Without this the numbers above would
    // describe a surface the screen might no longer draw — this project's own failure class.
    @Test func theMorningScreenActuallyDrawsThatPlateAndOnlyAtAccessibilitySizes() throws {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Tuck/GutenMorgenView.swift")
        let code = try String(contentsOf: source, encoding: .utf8)
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }

        #expect(code.contains { $0.contains("@Environment(\\.dynamicTypeSize) private var dynamicTypeSize") })
        #expect(code.contains { $0.contains("if dynamicTypeSize >= .accessibility1 {") })
        #expect(code.contains { $0.contains("RoundedRectangle(cornerRadius: Layout.radiusPlate)") })
        #expect(code.contains { $0.contains(".fill(Color.tuckFloatingPlate.opacity(0.9))") })
        #expect(code.contains { $0.contains(".shadow(color: .black.opacity(0.08), radius: 6, y: 2)") })
        #expect(code.contains { $0.contains(".padding(.horizontal, -Layout.plateInsetX)") })
        #expect(code.contains { $0.contains(".padding(.vertical, -Layout.plateInsetY)") })

        // A `.background`, not a branch around the column: an if/else would rebuild the VStack and
        // restart the subline's `.transition(.opacity)` on every Dynamic-Type change.
        #expect(code.contains { $0.contains(".background(alignment: .center) {") })

        // Found in a screenshot pass, pinned so it cannot come back: without the inset the
        // plate ran off both screen edges and its corners were cut away — the identical defect
        // recorded for the speech bubble. The inset is conditional so that nothing below the
        // accessibility sizes moves, which is what the second screenshot proves.
        #expect(code.contains {
            $0.contains(".padding(.horizontal, dynamicTypeSize >= .accessibility1 ? Layout.textInset : 0)")
        })

        // The design system forbids capping the type scale. Reading the size is allowed; clamping it is not, and
        // the first use of dynamicTypeSize in the project is the moment to say so mechanically.
        for line in code where line.contains("dynamicTypeSize") {
            #expect(!line.contains("dynamicTypeSize("),
                    "the screen caps the type scale instead of reading it: \(line)")
        }

        // The block's ink is deliberately unchanged. The design system keeps the sky out of the ink table, and
        // the span it accepts is measured against charcoal green — a sweep to tuckInk here would
        // trade the large-text path for a 4,5:1 this ground cannot pay anyway.
        #expect(code.contains { $0.contains(".foregroundStyle(Color.tuckCharcoalGreen)") })
    }
}
