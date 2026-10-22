import SwiftUI
// The shading half of the mascot rig, split out of MascotView so a second drawing can reach it
// without copying it: tools/render-app-icon.sh compiles this file for macOS. It therefore names no
// palette token and imports nothing but SwiftUI — every colour arrives as a parameter, the way
// ShieldMascotIcon reads Color.LightPalette rather than the appearance-resolving tokens.
//
// It is a richer *rendering of the same pose*, not a new pose: silhouette, proportions and the
// body stay what they were, and no behaviour lives here.
//
// The defaults below read Tuck/MascotGeometry.swift instead of writing numbers.
// They were the rig's measurements under another name — a fourth copy of the body width that no
// scan could see, because a default parameter sits at no argument position. What stays local are
// the proportions (`width * 0.66`): they say two thirds of whatever the body is, and stay true
// when the body moves. The earlier rule "erwähnen, nicht eigenmächtig zusammenlegen" was lifted for the

// constants only — TuckShield/ShieldMascotIcon.swift still keeps its own flat two-stop body on
// purpose, and now names that divergence in MascotGeometry rather than leaving it unexplained.

// Deterministic per seed, so the same view renders the same grain on every pass — a random grain
// would flicker once per frame under the breath animation and would make the icon PNG unreproducible.
struct MascotGrain: View {
    var seed: UInt64 = 11
    var dots: Int = 900
    var opacity: Double = 0.03

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: false) { context, size in
            var state = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            func next() -> Double {
                state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                return Double((state >> 33) & 0xFF_FFFF) / Double(0xFF_FFFF)
            }
            for _ in 0..<dots {
                let x = next() * size.width
                let y = next() * size.height
                let radius = 0.20 + next() * 0.32
                let lifts = next() > 0.5
                context.fill(
                    Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                    with: .color((lifts ? Color.white : Color.black).opacity(opacity))
                )
            }
        }
        .allowsHitTesting(false)
    }
}

struct MascotBodySurface: View {
    var fill: Color
    var ink: Color
    var bounce: Color
    var width: Double = MascotGeometry.bodyWidth
    var height: Double = MascotGeometry.bodyHeight
    var grainSeed: UInt64 = 11
    // The screen keeps the hairline it had; the app icon overdraws both, because at 40 px the
    // silhouette has to hold on its own. Parameters rather than a second copy of this rig.
    var outlineInk: Double = MascotGeometry.bodyOutlineInk
    var outlineWidth: Double = MascotGeometry.bodyOutlineWidth

    var body: some View {
        ZStack {
            Ellipse().fill(fill)

            // Volume, from one light source up and to the left: a lit crown, a neutral middle and a
            // rim that turns towards the ink instead of stopping at the outline.
            Ellipse().fill(
                RadialGradient(
                    stops: [
                        .init(color: .white.opacity(0.30), location: 0),
                        .init(color: .white.opacity(0.10), location: 0.42),
                        .init(color: .clear, location: 0.66),
                        .init(color: ink.opacity(0.13), location: 1)
                    ],
                    center: UnitPoint(x: 0.36, y: 0.26),
                    startRadius: 0,
                    endRadius: width * 0.80
                )
            )

            Ellipse().fill(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.52),
                        .init(color: ink.opacity(0.05), location: 0.78),
                        .init(color: ink.opacity(0.14), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            ZStack {
                // Warm light thrown back up from the ground, the counterpart of the contact shadow.
                Ellipse()
                    .fill(bounce.opacity(0.40))
                    .frame(width: width * 0.66, height: height * 0.26)
                    .blur(radius: 12)
                    .offset(y: height * 0.36)

                Ellipse()
                    .fill(.white.opacity(0.20))
                    .frame(width: width * 0.50, height: height * 0.42)
                    .blur(radius: 10)
                    .rotationEffect(.degrees(12))
                    .offset(x: -width * 0.13, y: -height * 0.07)

                Ellipse()
                    .fill(.white.opacity(0.32))
                    .frame(width: width * 0.17, height: height * 0.12)
                    .blur(radius: 4)
                    .rotationEffect(.degrees(18))
                    .offset(x: -width * 0.22, y: -height * 0.20)

                MascotGrain(seed: grainSeed)
            }
            .frame(width: width, height: height)
            .mask(Ellipse().frame(width: width, height: height))

            Ellipse().strokeBorder(ink.opacity(outlineInk), lineWidth: outlineWidth)
        }
        .frame(width: width, height: height)
        .compositingGroup()
    }
}

struct MascotEarSurface: View {
    var fill: Color
    var ink: Color
    var diameter: Double = MascotGeometry.earDiameter
    var outlineInk: Double = MascotGeometry.earOutlineInk
    var outlineWidth: Double = MascotGeometry.earOutlineWidth

    var body: some View {
        ZStack {
            Circle().fill(fill)
            Circle().fill(
                RadialGradient(
                    stops: [
                        .init(color: .white.opacity(0.26), location: 0),
                        .init(color: .clear, location: 0.58),
                        .init(color: ink.opacity(0.18), location: 1)
                    ],
                    center: UnitPoint(x: 0.38, y: 0.28),
                    startRadius: 0,
                    endRadius: diameter * 0.66
                )
            )
            Circle().strokeBorder(ink.opacity(outlineInk), lineWidth: outlineWidth)
        }
        .frame(width: diameter, height: diameter)
        .compositingGroup()
    }
}

// Where the ears disappear behind the crown. Drawn on the body, after it, because that is the side
// the occlusion belongs to — the ears themselves sit below the body in the stack.
struct MascotEarRootShadow: View {
    var ink: Color

    var body: some View {
        Ellipse()
            .fill(ink.opacity(0.11))
            .frame(width: MascotGeometry.earRootShadowWidth, height: MascotGeometry.earRootShadowHeight)
            .blur(radius: 6)
            .offset(y: MascotGeometry.earRootShadowOffsetY)
    }
}

struct MascotCheek: View {
    var color: Color
    var opacity: Double

    var body: some View {
        ZStack {
            Ellipse()
                .fill(color.opacity(opacity * 0.55))
                .frame(width: MascotGeometry.cheekHaloWidth, height: MascotGeometry.cheekHaloHeight)
                .blur(radius: 6)
            Ellipse()
                .fill(color.opacity(opacity))
                .frame(width: MascotGeometry.cheekCoreWidth, height: MascotGeometry.cheekCoreHeight)
                .blur(radius: 3)
        }
    }
}

// Two layers instead of one: a wide soft pool for the light the body blocks, and a tighter, darker
// core where it actually touches down. Both stay driven by the breath's own numbers.
struct MascotContactShadow: View {
    var ink: Color
    var width: Double
    var blur: Double
    var strength: Double

    var body: some View {
        ZStack {
            Ellipse()
                .fill(ink.opacity(0.12 * strength))
                .frame(width: width, height: MascotGeometry.contactShadowHeight)
                .blur(radius: blur)
            Ellipse()
                .fill(ink.opacity(0.10 * strength))
                .frame(width: width * 0.52, height: MascotGeometry.contactShadowCoreHeight)
                .blur(radius: blur * 0.6)
        }
    }
}
