import Foundation
import Testing
@testable import Tuck

// The breathing circle. Pure arithmetic on the constants the drawing actually uses —
// no rendering, because there is no snapshot layer here and because the question is a geometric
// one: does the rig fit inside the circle at its smallest, and is the scale that makes it fit a
// derived number rather than one somebody liked the look of.
//
// A first draft asserted "about 0.69, sprout tip at -83" with no working shown, and
// the tip was wrong by 3 pt. So the derivation is the test: every step below is computed from
// MascotGeometry and from OverrideBreathPhase's own diameter, and the two built constants are
// checked against the result instead of standing on their own.
struct MascotRigFitTests {
    // Leaf and stem overlap by one point — the column's VStack spacing is -1 — so the height is
    // the sum of the two minus that overlap, which is what adding a negative spacing does.
    static var sproutColumnHeight: Double {
        MascotGeometry.leafHeight + MascotGeometry.stemLength + MascotGeometry.sproutColumnSpacing
    }

    // The column is centred on its own offset, so half of it stands above that, plus the outward
    // half of the leaf's contour.
    static var sproutTip: Double {
        MascotGeometry.sproutOffsetY
            - sproutColumnHeight / 2
            - MascotGeometry.sproutOutlineWidth / 2
    }

    // The small state of the breathing circle — the tight one, and therefore the only one worth
    // fitting against. Read off the enum the screen animates rather than copied from the design system.
    static var circleRadius: Double { OverrideBreathPhase.exhale.diameter / 2 }

    static var scale: Double { MascotGeometry.breathingCircleRigScale }
    static var offset: Double { MascotGeometry.breathingCircleRigOffsetY }

    private static func rounded(_ value: Double) -> Double { (value * 10_000).rounded() / 10_000 }

    // The farthest any point of the body ellipse lands from the circle's centre, once the pose has
    // been scaled and pushed down. Closed form rather than sampling: with semi-axes a (wide) and b
    // (tall) and the ellipse's centre at c on the y axis, the squared distance over the ellipse is
    // a² + c² + 2bc·u + (b² - a²)u² for u = sin t, which is concave while b < a and therefore has
    // its maximum at u = bc / (a² - b²), clamped into [-1, 1].
    static var bodyReach: Double {
        let a = MascotGeometry.bodyWidth / 2 * scale
        let b = MascotGeometry.bodyHeight / 2 * scale
        let c = offset
        let u = min(max(b * c / (a * a - b * b), -1), 1)
        let squared = a * a + c * c + 2 * b * c * u + (b * b - a * a) * u * u
        return squared.squareRoot()
    }

    @Test func theSproutColumnIsAsTallAsItsTwoPartsMinusTheirOverlap() {
        #expect(MascotGeometry.leafHeight == 10)
        #expect(MascotGeometry.stemLength == 10)
        #expect(MascotGeometry.sproutColumnSpacing == -1)
        #expect(Self.sproutColumnHeight == 19)
    }

    // -79.5 from the geometry, -80 once the contour is counted. Named here because a first draft
    // assumed -83 and the difference is the whole scale below.
    @Test func theSproutReachesEightyPointsAboveTheRigsCentre() {
        let withoutContour = MascotGeometry.sproutOffsetY - Self.sproutColumnHeight / 2
        #expect(withoutContour == -79.5)
        #expect(Self.sproutTip == -80)
    }

    @Test func theCircleAtItsSmallestHasARadiusOfFiftyFive() {
        #expect(OverrideBreathPhase.exhale.diameter == 110)
        #expect(OverrideBreathPhase.inhale.diameter == 180)
        #expect(Self.circleRadius == 55)
    }

    // What a plain scale with no offset at all would have to be. The built pair is not this, and
    // the point of pinning it is that the built pair has to be justified against it.
    @Test func aScaleWithNoOffsetWouldHaveToBeSixtyNineHundredths() {
        #expect(Self.rounded(Self.circleRadius / abs(Self.sproutTip)) == 0.6875)
    }

    // The two constants the surface actually uses, checked against the derivation rather than
    // asserted. The offset is what buys the extra 0.0125 of scale.
    @Test func theBuiltScaleIsLargerThanTheOffsetlessOneAndTheOffsetIsWhatPaysForIt() {
        #expect(Self.scale == 0.7)
        #expect(Self.offset == 12)
        #expect(Self.scale > Self.circleRadius / abs(Self.sproutTip))
    }

    // Both ends, because they are different constraints and the offset moves them in opposite
    // directions: pushing the pose down buys room above the sprout and spends it under the body.
    @Test func theWholePoseFitsInsideTheCircleAtItsSmallest() {
        let scaledSproutTip = Self.sproutTip * Self.scale + Self.offset
        #expect(Self.rounded(scaledSproutTip) == -44)
        #expect(abs(scaledSproutTip) < Self.circleRadius)

        // The lower flank of the body, not its lowest point: an ellipse pushed down inside a circle
        // touches first at the side, and checking only the bottom (50.5) would have understated it.
        #expect(Self.rounded(Self.bodyReach) == 52.7003)
        #expect(Self.bodyReach < Self.circleRadius)

        let scaledEarTop = (MascotGeometry.earOffsetY - MascotGeometry.earDiameter / 2) * Self.scale + Self.offset
        #expect(abs(scaledEarTop) < Self.circleRadius)
    }

    // The margin, stated rather than left implicit: about 11 pt above the sprout and about 2.30 pt
    // at the body's widest lower flank. The second one is the number to watch — it is what a taller
    // scale or a smaller circle would spend first.
    @Test func theTighterOfTheTwoMarginsIsTheBodysLowerFlank() {
        let aboveTheSprout = Self.circleRadius - abs(Self.sproutTip * Self.scale + Self.offset)
        let atTheBody = Self.circleRadius - Self.bodyReach

        #expect(Self.rounded(aboveTheSprout) == 11)
        #expect(Self.rounded(atTheBody) == 2.2997)
        #expect(atTheBody < aboveTheSprout)
    }
}
