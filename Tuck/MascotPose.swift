import SwiftUI

// The rig, drawn once. This IS `MascotView.bodyStack(sway:)`, moved out and parametrised over a
// `MascotExpression` instead of over `stage`/`blink`/`squint`/`awake` — deliberately an extraction
// and not a fourth composition of ears, eyes, mouth and sprout. A new composition would have put a
// fourth copy of the rig back just after the rig's constants lost their fourth copy.
//
// It is STATELESS on purpose: no `@State`, no `PhaseAnimator`, no idle loop. Everything that moves
// stays in the host. `MascotView` keeps its breath, its entrance, its tap repertoire and its idle
// beats and passes the result in as plain values; the three other surfaces pass constants, or feed
// a phase in from their own animator.
//
// The body colour is `tuckMascotBody`, at all six places the animal is filled - the two ears, the
// body, the stem, the bud and the leaves. In light that token IS `tuckSage`, unchanged to the byte;
// in dark it is the animal's own tone rather than the app's furniture colour.
//
// `MascotContactShadow` is not here, and that is structural rather than a decision taken per
// surface: it lives in `MascotView.body`, outside the function this file extracts. A surface that
// draws a pose therefore has no contact shadow unless it draws one itself.
struct MascotPose: View {
    var expression: MascotExpression
    // No default. "Eine falsche Stufe wäre schlimmer als keine" — a caller that has not
    // decided which stage it is showing has to say so by fetching the real one, not by inheriting
    // a plausible-looking guess from here.
    var sproutStage: SproutStage
    var ink: Color
    var saturation: Double
    var cheekOpacity: Double
    var sway: Double = 0
    // What the host's own gaze is doing — drag, idle beat, entrance. The expression's own gaze is
    // added to it, so a posed sideways look and a followed one compose instead of fighting.
    var gaze: CGSize = .zero
    var leadingEarRotation: Double = 0
    var trailingEarRotation: Double = 0
    var reduceMotion: Bool = false
    // How far `.smallO` is open, 0 to 1. Read by that one mouth and by nothing else — the four
    // smile-based shapes have their size from the shape itself.
    var mouthOpenness: Double = 1
    // The contour, per surface. Defaults are the screen's own hairline, so MascotView draws exactly
    // what it drew before; a surface that puts this animal on a sage ground overrides all three
    // together, because leaving one out is how the ears vanish while the body keeps its edge.
    var bodyOutlineInk: Double = MascotGeometry.bodyOutlineInk
    var bodyOutlineWidth: Double = MascotGeometry.bodyOutlineWidth
    var earOutlineInk: Double = MascotGeometry.earOutlineInk
    var earOutlineWidth: Double = MascotGeometry.earOutlineWidth
    // Zero by default, which draws a fully transparent border and therefore nothing — the same
    // shape MascotEarSurface's own `outlineInk: 0` default already has.
    var stemOutlineInk: Double = 0

    var body: some View {
        ZStack {
            HStack(spacing: MascotGeometry.earSpacing) {
                ear.rotationEffect(.degrees(leadingEarRotation + expression.ears.leadingDegrees),
                                   anchor: .bottom)
                ear.rotationEffect(.degrees(trailingEarRotation + expression.ears.trailingDegrees),
                                   anchor: .bottom)
            }
            .foregroundStyle(Color.tuckMascotBody)
            .saturation(saturation)
            .offset(y: MascotGeometry.earOffsetY)

            MascotBodySurface(fill: Color.tuckMascotBody, ink: ink, bounce: Color.tuckDustyRose,
                              outlineInk: bodyOutlineInk, outlineWidth: bodyOutlineWidth)
                .saturation(saturation)

            MascotEarRootShadow(ink: ink)

            HStack(spacing: MascotGeometry.cheekSpacing) {
                cheek
                cheek
            }
            .offset(y: MascotGeometry.cheekOffsetY)

            HStack(spacing: MascotGeometry.eyeSpacing) {
                eye
                eye
            }
            .offset(y: MascotGeometry.eyeOffsetY)

            mouth

            sprout
        }
    }

    private var ear: some View {
        MascotEarSurface(fill: Color.tuckMascotBody, ink: ink,
                         outlineInk: earOutlineInk, outlineWidth: earOutlineWidth)
    }

    private var cheek: some View {
        MascotCheek(color: Color.tuckDustyRose,
                    opacity: min(cheekOpacity + expression.cheekBoost, 1))
    }

    @ViewBuilder
    private var eye: some View {
        switch expression.eyes {
        case .closed:
            Capsule().fill(ink)
                .frame(width: MascotEyeState.closed.width, height: MascotEyeState.closed.height)
        case .half:
            // A dome on a flat base rather than the folded arc of `.squint`: the top radii are the
            // whole height, so what is left of the eye is the upper curve of the open one with a
            // lid across it. No catchlight — see MascotEyeState.
            UnevenRoundedRectangle(topLeadingRadius: MascotEyeState.half.height,
                                   bottomLeadingRadius: 0,
                                   bottomTrailingRadius: 0,
                                   topTrailingRadius: MascotEyeState.half.height)
                .fill(ink)
                .frame(width: MascotEyeState.half.width, height: MascotEyeState.half.height)
        case .squint:
            Smile()
                .stroke(ink, style: StrokeStyle(lineWidth: MascotGeometry.eyeLineWidth, lineCap: .round))
                .frame(width: MascotEyeState.squint.width, height: MascotEyeState.squint.height)
                .scaleEffect(y: -1)
        case .open:
            ZStack {
                Circle().fill(ink)
                    .frame(width: MascotEyeState.open.width, height: MascotEyeState.open.height)
                Circle().fill(Color.tuckMascotCatchlight)
                    .frame(width: MascotGeometry.eyeCatchlightDiameter,
                           height: MascotGeometry.eyeCatchlightDiameter)
                    .offset(x: MascotGeometry.eyeCatchlightOffsetX,
                            y: MascotGeometry.eyeCatchlightOffsetY)
            }
            .offset(x: gaze.width + expression.gaze.offsetX, y: gaze.height)
        }
    }

    // One path, four frame sizes — not a switch that builds a different view per shape. SwiftUI
    // reads a per-case view as a change of identity and crossfades it; the yawn has always been a
    // frame morph on the one smile path and stays one. `.smallO` is the exception the vocabulary
    // names: a circle cannot be a frame of a smile, so it is its own branch and no surface animates
    // across that line.
    @ViewBuilder
    private var mouth: some View {
        if expression.mouth.isDrawnAsTheSmilePath {
            Smile()
                .stroke(ink, style: StrokeStyle(lineWidth: MascotGeometry.mouthLineWidth, lineCap: .round))
                .frame(width: expression.mouth.width, height: expression.mouth.height)
                .offset(y: MascotGeometry.mouthOffsetY)
        } else {
            // Stroked, not filled: every mouth this animal has is a line, and a solid disc would be
            // the first one that is not.
            Circle()
                .strokeBorder(ink, lineWidth: MascotGeometry.mouthLineWidth)
                .frame(width: smallODiameter, height: smallODiameter)
                .offset(y: MascotGeometry.mouthOffsetY)
        }
    }

    // An interpolated value on one circle, never a swap between two shapes: the breath has to be a
    // size that moves, and a second `.smallO` case at a second diameter would crossfade.
    private var smallODiameter: Double {
        let closed = MascotGeometry.mouthSmallOMinDiameter
        return closed + (MascotMouthShape.smallO.width - closed) * min(max(mouthOpenness, 0), 1)
    }

    // A switch over the stage's own attribute rather than an animated parameter on one continuous
    // view: each branch is its own identity, which is what makes the transition below the thing that
    // runs between two stages — the same transition the sprout had when it only ever appeared once.
    @ViewBuilder
    private var sprout: some View {
        switch sproutStage {
        case .seed:
            sproutColumn(stemLength: MascotGeometry.stemLength * 0.6) { bud }
        case .oneLeaf:
            sproutColumn(stemLength: MascotGeometry.stemLength * 0.8) {
                leaf.rotationEffect(.degrees(-28 + sway), anchor: .bottomTrailing)
            }
        case .twoLeaves:
            sproutColumn(stemLength: MascotGeometry.stemLength) {
                HStack(spacing: MascotGeometry.leafPairSpacing) {
                    leaf.rotationEffect(.degrees(-28 + sway), anchor: .bottomTrailing)
                    leaf.rotationEffect(.degrees(28 - sway), anchor: .bottomLeading)
                }
            }
        }
    }

    private func sproutColumn<Crown: View>(stemLength: Double,
                                           @ViewBuilder crown: () -> Crown) -> some View {
        VStack(spacing: MascotGeometry.sproutColumnSpacing) {
            crown()
            Capsule().fill(Color.tuckMascotBody)
                .frame(width: MascotGeometry.stemWidth, height: stemLength)
                .overlay(Capsule().strokeBorder(ink.opacity(stemOutlineInk),
                                                lineWidth: MascotGeometry.sproutOutlineWidth))
        }
        .offset(y: MascotGeometry.sproutOffsetY)
        .transition(reduceMotion
            ? AnyTransition.opacity
            : .opacity.combined(with: .offset(y: MascotGeometry.sproutTransitionOffsetY)))
    }

    private var bud: some View {
        Circle()
            .fill(Color.tuckMascotBody)
            .overlay(Circle().stroke(ink.opacity(0.5), lineWidth: MascotGeometry.sproutOutlineWidth))
            .frame(width: MascotGeometry.budDiameter, height: MascotGeometry.budDiameter)
    }

    private var leaf: some View {
        Ellipse()
            .fill(Color.tuckMascotBody)
            .overlay(
                Ellipse().fill(
                    LinearGradient(colors: [.white.opacity(0.30), .clear],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                )
            )
            .overlay(Ellipse().stroke(ink.opacity(0.5), lineWidth: MascotGeometry.sproutOutlineWidth))
            .frame(width: MascotGeometry.leafWidth, height: MascotGeometry.leafHeight)
    }
}

// Internal rather than private: the mouth and the squinting eye are drawn here now, and
// `MascotView` is no longer the only file that needs the curve.
struct Smile: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}
