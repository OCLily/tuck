import Foundation
// The mascot rig's measurements, in one place, and value-neutral by construction:
// every number this file arrived with is the number that was already being drawn,
// copied across unchanged. Nothing here is divided out of a body width or derived from anything
// else — a derivation would round differently and move real pixels, and the consolidation
// is the step that proved it moved none (both PNGs re-rendered and compared by SHA-256, see
// docs/design/design-system.md). Values added since then are new shapes, never a
// recomputation of an existing one.
//
// Until now these ~20 values existed four times over: in MascotView.swift, in MascotSurfaces
// .swift's own default parameters, in tools/AppIconComposition.swift and in
// TuckShield/ShieldMascotIcon.swift. The duplication had been documented rather than merged on
// one's own initiative; merging the constants is now a design decision, so they merge here. The
// *drawings* do not: the shield keeps its hand-drawn flat shading and the icon keeps its own
// contour, both now as named divergences at the bottom of this file rather than as unexplained
// numbers in two other files.

//
// `import Foundation`, not SwiftUI — the same rule Tuck/Motion.swift follows. This file holds
// values and renders nothing, which is also what lets it compile into the shield extension and
// into the two macOS render binaries (tools/render-app-icon.sh, tools/render-shield-mascot.sh).
//
// What is NOT here: shading intensity (opacity, blur radius, saturation), the grain's seed and dot
// count (texture), and animation values. The one intensity pair that is here is the
// contour — `outlineInk`/`outlineWidth` are per-surface rig parameters the icon already overrides,
// which makes them part of the rig rather than part of a gradient.
enum MascotGeometry {
    // MARK: - The canvas

    static let rigWidth: Double = 160
    static let rigHeight: Double = 140

    // MARK: - Body

    static let bodyWidth: Double = 140
    static let bodyHeight: Double = 110
    static let bodyOutlineInk: Double = 0.16
    static let bodyOutlineWidth: Double = 1

    // MARK: - Ears

    static let earDiameter: Double = 26
    static let earOutlineInk: Double = 0
    static let earOutlineWidth: Double = 1
    // Negative: the two ears overlap behind the crown rather than standing apart.
    static let earSpacing: Double = -18
    static let earOffsetY: Double = -46
    static let earRootShadowWidth: Double = 46
    static let earRootShadowHeight: Double = 13
    static let earRootShadowOffsetY: Double = -40

    // MARK: - Cheeks

    static let cheekHaloWidth: Double = 22
    static let cheekHaloHeight: Double = 14
    static let cheekCoreWidth: Double = 16
    static let cheekCoreHeight: Double = 10
    static let cheekSpacing: Double = 22
    static let cheekOffsetY: Double = 14

    // MARK: - Eyes

    static let eyeSpacing: Double = 28
    static let eyeOffsetY: Double = -8
    static let eyeOpenDiameter: Double = 8
    static let eyeCatchlightDiameter: Double = 2.5
    static let eyeCatchlightOffsetX: Double = -1.5
    static let eyeCatchlightOffsetY: Double = -1.5
    static let eyeClosedWidth: Double = 12
    static let eyeClosedHeight: Double = 3
    static let eyeSquintWidth: Double = 11
    static let eyeSquintHeight: Double = 5
    // The half-open lid. The one eye state with no precedent in the shipped drawing: between
    // the closed line and the open circle, and wider than tall so it reads as a lid rather than as
    // a smaller eye.
    static let eyeHalfWidth: Double = 11
    static let eyeHalfHeight: Double = 5.5
    static let eyeLineWidth: Double = 2
    // How far `.aside` moves the pupils. Inside the same band the drag gesture clamps its own gaze
    // to, so a posed sideways look and a followed one cannot disagree about how far sideways is.
    static let gazeAsideOffset: Double = 2

    // MARK: - Mouth

    static let mouthWidth: Double = 22
    static let mouthNeutralHeight: Double = 8
    static let mouthSleepingHeight: Double = 4
    static let mouthYawnWidth: Double = 15
    static let mouthYawnHeight: Double = 14
    // The two new mouths. `.soft` is a wider, flatter arc than `.neutral`; `.smallO` is the
    // one mouth that is not the smile path, and its diameter is the open eye's — a size reference,
    // not a shared meaning.
    static let mouthSoftWidth: Double = 26
    static let mouthSoftHeight: Double = 6
    static let mouthSmallODiameter: Double = 8
    // What `.smallO` narrows to at the bottom of a breath. The mouth is the one part of the
    // breathing pose that moves, and a frame size is a change of shape rather than a transform —
    // so it keeps moving under Reduce Motion, where the circle around it stands still.
    static let mouthSmallOMinDiameter: Double = 4
    static let mouthOffsetY: Double = 16
    static let mouthLineWidth: Double = 2

    // MARK: - Sprout

    // The stem at full growth; the three stages take 0.6 / 0.8 / 1.0 of it.
    static let stemLength: Double = 10
    static let stemWidth: Double = 2
    // 0.06 of the body width — round, and narrower than the leaf it becomes.
    static let budDiameter: Double = 8.4
    static let leafWidth: Double = 18
    static let leafHeight: Double = 10
    static let leafPairSpacing: Double = 1
    static let sproutColumnSpacing: Double = -1
    static let sproutOffsetY: Double = -70
    static let sproutTransitionOffsetY: Double = 8
    static let sproutOutlineWidth: Double = 1

    // MARK: - Contact shadow

    static let contactShadowOffsetY: Double = 66
    static let contactShadowHeight: Double = 18
    static let contactShadowCoreHeight: Double = 9

    // MARK: - The pose on a sage ground

    // Two surfaces put the sage body on a sage ground: the breathing circle (sage at 0.6 over
    // cream) and the settings list rows (sage at 0.25). Body against ground is 1.07:1 and 1.12:1
    // there — under the 3:1 non-text floor, and worse than the 1.17:1 the disabled plate is already
    // an accepted exception for. The answer is the app icon's: the contour carries the
    // silhouette when the ground cannot. All THREE sage elements need it — the body, the ears
    // (whose default contour is 0, so they would dissolve) and the stem (which originally had no
    // contour option at all).
    static let onSageBodyOutlineInk: Double = 0.55
    static let onSageBodyOutlineWidth: Double = 1.5
    static let onSageEarOutlineInk: Double = 0.55
    static let onSageEarOutlineWidth: Double = 1
    static let onSageStemOutlineInk: Double = 0.55

    // MARK: - The rig inside the breathing circle

    // Derived, not chosen — the arithmetic is in MascotRigFitTests and the design system. The sprout
    // column reaches about 80 pt above the rig centre at its tallest stage; the circle's small
    // state has a radius of 55. A plain 55/80 = 0.6875 would fit with no offset at all; 0.7 with
    // the whole pose nudged 12 pt down puts the sprout's tip and the body's lower flank inside the
    // same circle with room on both.
    static let breathingCircleRigScale: Double = 0.7
    static let breathingCircleRigOffsetY: Double = 12

    // MARK: - The rig in a settings row

    // Not derived the way the circle's scale is: nothing constrains it but the row itself. 0.45
    // puts the rig at 72 x 63, a portrait in a list of 44-pt rows rather than an icon beside one.
    static let settingsRowRigScale: Double = 0.45

    // MARK: - The rig above the reconsider line

    // The same number as the settings row today, and deliberately not the same constant: one is a
    // portrait in a list of rows, the other is a presence over a decision, and tuning one of them
    // must not quietly move the other.
    static let reconsiderRigScale: Double = 0.45

    // MARK: - The app icon's own divergences

    // Named rather than left as literals in tools/AppIconComposition.swift, so every place the icon
    // is deliberately not the screen is visible from one file. The icon lays the rig out at 256 pt
    // and renders at scale 4; the rig itself is unchanged, only its placement and its contour are.
    static let iconRigScale: Double = 1.15
    static let iconRigOffsetY: Double = 4
    static let iconContactShadowWidth: Double = 96
    static let iconContactShadowOffsetY: Double = 62
    // At 40 px on a home screen the silhouette has to hold on its own, so the icon overdraws both
    // contours. The screen keeps the hairline it had — these are the icon's values, not new
    // defaults.
    static let iconBodyOutlineInk: Double = 0.55
    static let iconBodyOutlineWidth: Double = 2.5
    static let iconEarOutlineInk: Double = 0.55
    static let iconEarOutlineWidth: Double = 1.5

    // MARK: - The shield drawing's own divergences

    // -62 where the app uses -70: ImageRenderer crops the shield asset to exactly the rig canvas,
    // and a column centred on -70 has half its height above that edge. In the app a SwiftUI frame
    // does not clip, so nothing there notices. -62 is the smallest move that puts the whole column
    // inside the bounds.
    static let shieldSproutOffsetY: Double = -62
    static let shieldStemLength: Double = 6
    // The single flat highlight that stands in for MascotSurfaces' radial shading, which this
    // drawing deliberately does not share.
    static let shieldHighlightWidth: Double = 70
    static let shieldHighlightHeight: Double = 46
    static let shieldHighlightOffsetX: Double = -18
    static let shieldHighlightOffsetY: Double = -8
}
