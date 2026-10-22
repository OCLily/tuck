import SwiftUI

// THE UNEARNED CHANNEL. Everything else this screen gives back was earned: the ring the user filled,
// the animal they raised, the line they worked up to. This layer is the one thing that is simply
// there, because it is March. It must therefore never look like something one can deserve or lose.
//
// TWO RULES IT MAY NEVER BREAK, and both are mechanically held rather than merely written down:
//
//   1. THE ACCENT DECORATES THE WORLD, NEVER THE ANIMAL. No season changes wakefulness, posture,
//      readiness to react, idle frequency or tap answer. The animal wakes up for the user in every
//      season — that is the carrying story, not a seasonal state. A hibernation motif on the animal
//      would additionally break the still-face invariant. `SeasonalAccent` therefore takes no
//      parameter through which a seasonal value could ever reach the creature, and `GutenMorgenView`
//      does not pass `season` to `MascotView` (`theSeasonNeverReachesTheAnimal`).
//
//   2. IT WAS ALREADY LYING THERE. No arrival, reveal or sparkle animation, no badge, no "new". The
//      accent stands in the first rendered frame — which is why the band below is derived primarily
//      from `size.height` and only SHIFTED by `mascotCenterY`: that value is 0 until the screen has
//      measured itself, and a layer that is empty for one frame and full the next is an arrival.
//
// WHAT IS DECIDED AND WHAT IS ATMOSPHERE. Decided per season: which motif, and how many. Where a
// leaf currently is, is atmosphere — exactly like the 24 dust motes of the same surface, which also
// move. The habit this guards against needs something discoverable; a drift phase is not
// discoverable. Without this distinction a later reader reads "no daily change" as a ban on drift
// and builds a still image.
//
// ASYMMETRY, so nobody goes looking for summer in this file: two of the four seasons are
// particles (autumn, winter), one is a colour parameter in `MorningSky` (summer), one is a third
// particle shape (spring). Four seasons, two mechanisms.
struct SeasonalAccent: View {
    let season: Season
    let mascotCenterY: CGFloat
    /// Frozen while the morning's own celebration runs: one channel for the peak, and the accent is
    /// not it. Deliberately NOT a second Reduce-Motion gate — the condition in the body is spelled
    /// `quiet`, never `reduceMotion`, or `motionGatedSites` would count it and the number would mean
    /// two things at once.
    let quiet: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    struct Particle: Equatable {
        var position: CGPoint
        var diameter: Double
        var rotation: Double
        var opacity: Double
    }

    // Exact equalities in a test rather than prose: a sixth flake is a decision, not a diff.
    nonisolated static func count(for season: Season) -> Int {
        switch season {
        case .spring: 1
        case .summer: 0
        case .autumn: 2
        case .winter: 3
        }
    }

    // Primarily from `size.height`, only shifted by `mascotCenterY` — see rule 2 above. The centre is
    // clamped before the band is built so the band can never leave the screen even if the column has
    // scrolled the animal far out of view.
    nonisolated static func band(mascotCenterY: CGFloat, in size: CGSize) -> (low: Double, high: Double) {
        let raw = mascotCenterY > 0 ? Double(mascotCenterY) : size.height * 0.42
        let centre = min(max(raw, size.height * 0.25), size.height * 0.75)
        let half = size.height * 0.17
        return (centre - half, centre + half)
    }

    // Deterministic from the index, never `Double.random`: the same house rule that makes
    // `MorningAmbience`'s 24 motes golden-ratio remainders and that `MorningCopy.morningIndex`
    // explains in its own comment. A pure function is also the one part of this layer a test without
    // a rendered view can hold on to — which is why it is a function and not a loop inside the
    // Canvas closure.
    nonisolated static func particles(season: Season,
                                      t: Double,
                                      mascotCenterY: CGFloat,
                                      in size: CGSize) -> [Particle] {
        let count = count(for: season)
        guard count > 0, size.width > 0, size.height > 0 else { return [] }
        let band = band(mascotCenterY: mascotCenterY, in: size)

        return (0..<count).map { index in
            let fi = Double(index)
            let seed = (fi * 0.6180339887 + 0.31).truncatingRemainder(dividingBy: 1)
            let speed = 0.010 + 0.008 * (fi * 0.7548).truncatingRemainder(dividingBy: 1)
            // Grund: die Fallperiode ist Choreografie innerhalb einer Geste und bleibt nach
            // Motion.swifts eigener Aufnahmeregel ein Literal. Das Design-System hat nie entschieden, wie lange
            // ein Blatt fällt — ausdrücklich nicht an Motion.breathCycle gekoppelt.
            let fall = (seed + t * speed).truncatingRemainder(dividingBy: 1)
            let sway = 0.05 * sin(t * (0.09 + 0.05 * seed) + fi)

            return Particle(
                position: CGPoint(x: size.width * (0.18 + 0.64 * seed + sway),
                                  y: band.low + (band.high - band.low) * fall),
                diameter: season == .winter ? 7 : 9,
                rotation: 360 * seed + t * 11,
                // The palette documents "Warmer Akzent, nie bei voller Deckkraft". 0.6 is the ceiling of the
                // documented alpha band, not a number picked here.
                opacity: min(0.35 + 0.25 * seed, 0.6)
            )
        }
    }

    var body: some View {
        // The reference implementation, copied rather than reinvented: MorningAmbience's own
        // TimelineView. `t = 0` under Reduce Motion is what turns the drift into a still image, and
        // the placement function guarantees that still image is three separate points rather than
        // one dot on top of another.
        TimelineView(.animation(minimumInterval: Motion.ambientTick,
                                paused: reduceMotion || scenePhase != .active || quiet)) { timeline in
            let t = reduceMotion || quiet ? 0 : timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                for particle in Self.particles(season: season, t: t,
                                               mascotCenterY: mascotCenterY, in: size) {
                    draw(particle, in: &context)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func draw(_ particle: Particle, in context: inout GraphicsContext) {
        let box = CGRect(x: -particle.diameter / 2, y: -particle.diameter / 2,
                         width: particle.diameter, height: particle.diameter)
        let placement = CGAffineTransform(rotationAngle: particle.rotation * .pi / 180)
            .concatenating(CGAffineTransform(translationX: particle.position.x,
                                             y: particle.position.y))

        switch season {
        case .autumn:
            // tuckDustyRose is the palette's one warm accent token and needs no new colour. Light
            // #E8C4B8, dark Moon Glow #E4C9A0 — it carries both ends of the sky.
            let leaf = Path(ellipseIn: CGRect(x: box.minX, y: box.minY / 2,
                                              width: box.width, height: box.height / 2))
            context.fill(leaf.applying(placement),
                         with: .color(Color.tuckDustyRose.opacity(particle.opacity)))
        case .winter:
            // An outlined ring, not a filled dot, and the fifth role of the brand token — the design system's
            // own argument: the outline carries the silhouette where the ground cannot. There is no
            // token for "cool white", and no single FILL token can carry a flake across a light sky
            // that runs #B6C2B3 to #F9F5EF. tuckCharcoalGreen is the one token that INVERTS per
            // appearance (#6B7A6E light, Moon Sage #CDD3C9 dark).
            context.stroke(Path(ellipseIn: box).applying(placement),
                           with: .color(Color.tuckCharcoalGreen.opacity(particle.opacity)),
                           lineWidth: 1)
        case .spring:
            // A third form, not a change to the rig. The sketch asked for "a small blossom on the
            // existing sprout stem" and that is not buildable as an independent layer: the stem
            // never stands still (breath, stage scale, entrance, stretch, tap, head tilt, lean and
            // two gaze offsets all sit between `sproutOffsetY` and the screen), and it is the
            // PROGRESS carrier, not decoration — something that appears on 1 March and vanishes on
            // 1 June would move the growth symbol backwards on 1 June with nothing having happened.
            // The design system's mascot-ink section decided the same shape of question,
            // against. So: near the creature, not on it — the honest price is that the blossom
            // does not sit on the stem.
            //
            // Same token as the leaf: tuckDustyRose is the palette's one warm accent, and that is a
            // consequence of the palette rather than carelessness. What separates the two is form
            // (four petals against one flat ellipse) and direction, not colour.
            let petal = particle.diameter * 0.55
            let reach = particle.diameter * 0.26
            for corner in [CGPoint(x: -reach, y: 0), CGPoint(x: reach, y: 0),
                           CGPoint(x: 0, y: -reach), CGPoint(x: 0, y: reach)] {
                let bud = Path(ellipseIn: CGRect(x: corner.x - petal / 2, y: corner.y - petal / 2,
                                                 width: petal, height: petal))
                context.fill(bud.applying(placement),
                             with: .color(Color.tuckDustyRose.opacity(particle.opacity)))
            }
        case .summer:
            break
        }
    }
}

// The second cadence of the same channel, and the one that never moves. It sits in this file rather
// than in a third one so a reviewer sees both cadences side by side instead of having to look for
// the other — but it is a SECOND VIEW, not a second case of the first: laying a standing object into
// the particle layer's TimelineView would pay a 20-fps redraw for something that does not move, and
// would put its code inside the region whose `reduceMotion` occurrences are pinned as an exact
// equality. That number would then mean two things at once, and the false-positive guard the pin
// exists to be would be blunt.
//
// It is also the one surface here that needs no explanation for its parameters: no `quiet`
// (there is nothing to freeze), no `stage`, no counter of any kind. That is what makes "one channel,
// two cadences" mechanical rather than asserted.
struct FoundObjectAccent: View {
    let object: FoundObject
    let mascotCenterY: CGFloat

    /// Every placeholder is this wide. Not cosmetics: a period in which the object were bigger or
    /// heavier would be a BETTER period, and the unearned channel would have become a verdict. The
    /// heights may differ — that is the variation there is meant to be.
    nonisolated static let width: Double = 12

    nonisolated static func height(of object: FoundObject) -> Double {
        switch object {
        case .disc: 12
        case .dome: 6
        case .wedge: 10
        case .lozenge: 12
        case .bar: 5
        }
    }

    // x: measured against the FULL rig width, i.e. against the largest shape the animal ever has —
    // so the gap can only grow, never shrink, and `stage.scale` is never needed. One fixed side: a
    // side that changed with the period would be a second axis of variation and a second thing to
    // notice. The app ships two LTR languages, so a mirrored version is not a case.
    //
    // y: the animal's own ground-line offset, as a NUMBER rather than an import — the object lies in
    // the same band the animal stands in, not on its contact line. "Near it, not on it."
    //
    // The clamp is the one thing `LightSource` deliberately does not have: a 300-pt radial with a
    // 24-pt blur does not care where it drifts, a hard-edged 12-pt object does. From .accessibility1
    // the column scrolls over the standing sky and `mascotCenterY` is a global measurement, so
    // without this the object scrolls under the gear plate or off the screen.
    nonisolated static func position(mascotCenterY: CGFloat, in size: CGSize) -> CGPoint {
        let anchor = mascotCenterY > 0 ? Double(mascotCenterY) : size.height * 0.42
        // Grund: MascotGeometry.contactShadowOffsetY as a number, on purpose — see above.
        let y = anchor + 66
        return CGPoint(
            x: size.width / 2 - (MascotGeometry.rigWidth / 2 + 16),
            // Grund: zwei Brüche der Höhe, wie MorningAmbiences eigene Verhältniszahlen. Keine
            // Dauer (die Dauern-Regel greift nicht), kein Abstand, Radius oder Padding (Layout greift nicht).
            y: min(max(y, size.height * 0.18), size.height * 0.88)
        )
    }

    nonisolated static func box(for object: FoundObject, standingOn point: CGPoint) -> CGRect {
        let height = height(of: object)
        return CGRect(x: point.x - width / 2, y: point.y - height, width: width, height: height)
    }

    // Only `addLine`, `Path(ellipseIn:)`, `addArc` and `Path(CGRect)` — no `addQuadCurve`. Not a
    // style rule: `Path.boundingRect` can include control points on Bézier curves, and the
    // equal-width/same-standing-line invariant is asserted on exactly that rectangle.
    nonisolated static func path(for object: FoundObject, in box: CGRect) -> Path {
        var path = Path()
        switch object {
        case .disc:
            path = Path(ellipseIn: box)
        case .dome:
            path.move(to: CGPoint(x: box.minX, y: box.maxY))
            path.addArc(center: CGPoint(x: box.midX, y: box.maxY), radius: box.width / 2,
                        startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            path.closeSubpath()
        case .wedge:
            path.move(to: CGPoint(x: box.minX, y: box.maxY))
            path.addLine(to: CGPoint(x: box.maxX, y: box.maxY))
            path.addLine(to: CGPoint(x: box.midX, y: box.minY))
            path.closeSubpath()
        case .lozenge:
            path.move(to: CGPoint(x: box.minX, y: box.midY))
            path.addLine(to: CGPoint(x: box.midX, y: box.minY))
            path.addLine(to: CGPoint(x: box.maxX, y: box.midY))
            path.addLine(to: CGPoint(x: box.midX, y: box.maxY))
            path.closeSubpath()
        case .bar:
            path = Path(box)
        }
        return path
    }

    // No TimelineView, no @State, no onAppear, no reduceMotion, no scenePhase, no quiet, no .now.
    // What stands here stood in the first rendered frame. `.ignoresSafeArea()` on the OUTSIDE, in the
    // same modifier order as MorningAmbience — that is the one coordinate pairing this screen has
    // ever been measured against (`mascotCenterY` is global, the GeometryReader sits inside). Pulling
    // it inwards shifts the object by the height of the status bar and no test sees it.
    var body: some View {
        GeometryReader { _ in
            Canvas { context, size in
                let point = Self.position(mascotCenterY: mascotCenterY, in: size)
                let box = Self.box(for: object, standingOn: point)
                let path = Self.path(for: object, in: box)
                // The second call site of the role Entscheidung 3 created for the winter flake —
                // outline of a small decorative object on the sky — not a sixth role. It is the one
                // token that inverts per appearance, so it carries a small object at BOTH ends of the
                // sky; every fill token drops out at one end.
                context.fill(path, with: .color(Color.tuckCharcoalGreen.opacity(0.18)))
                // Grund: Strichstärke ist eine Stil-Tatsache des Gegenstands, keine räumliche des
                // Rigs — `MascotGeometry.bodyOutlineWidth` wird bewusst NICHT gelesen. `rigWidth`
                // oben wird gelesen, weil es eine räumliche Tatsache ist.
                context.stroke(path, with: .color(Color.tuckCharcoalGreen.opacity(0.55)), lineWidth: 1)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
