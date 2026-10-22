import SwiftUI

// The source of Tuck/Assets.xcassets/AppIcon.appiconset/AppIcon.png, rendered once on a Mac by
// tools/render-app-icon.sh. Same arrangement as the shield's icon (TuckShield/ShieldMascotIcon
// .swift): a static pose written out here rather than MascotView reused, because MascotView carries
// stage, recognition, idle beats and tap state that a single 1024 px snapshot discards anyway. What
// is *not* copied is the shading — that comes from Tuck/MascotSurfaces.swift, the same file
// the live rig draws with, so the icon and the app cannot drift in the part that was made richer.
//
// Color.LightPalette rather than the appearance-resolving tokens, for the reason ShieldMascotIcon
// gives: the output is a checked-in PNG, and against the tokens swiftc would resolve them against
// the rendering Mac's own appearance. An app icon has no dark variant on iOS anyway.
//
// No transparency anywhere: the outermost layer is an opaque rectangle, and the renderer flattens
// the alpha channel out on top of that. Corners stay square — iOS applies its own mask.
struct AppIconComposition: View {
    // Laid out at 256 pt and rendered at scale 4. Rendering the 160 x 140 rig at 6.4x instead would
    // scale the grain with it into visible blotches; at 1.05x it stays the fine texture it is.
    static let side: Double = 256
    static let scale: CGFloat = 4

    private let sage = Color.LightPalette.sage
    private let rose = Color.LightPalette.dustyRose
    private let ink = Color.LightPalette.charcoalGreen

    // The two gradient anchors that are not product tokens, and are therefore written out here
    // rather than named. Neither is a new colour the palette gained.
    //
    // Identical to nightInk, not a new colour — literal only because DarkPalette sits behind
    // #if canImport(UIKit) and this file compiles for a plain macOS binary with no UIKit.
    private let night = Color(hex: 0x17201B)
    // Matches no existing token: not a palette entry and not a mixture of two, just the one stop
    // that carries the gradient from night to dawn without a visible band. A single-use value gets
    // a literal, not a name (three similar lines beat a premature abstraction).
    private let duskGreen = Color(hex: 0x3E4A41)

    var body: some View {
        ZStack {
            // A light body on a dark ground, because the reverse does not survive the home screen:
            // sage on cream, and sage on the Dawn-Shadow→cream gradient of the first version, are
            // both inside the palette's own low-contrast band — right on a screen, mush at
            // 40 px between other apps' saturated icons. What changes in this third version is not
            // that finding but the ground itself: the flat charcoal field (3,40:1) was the app's
            // darkest *product* colour standing in for a sky, and the brand layer now has an actual
            // dawn to put there. Night at the top, morning red at the bottom — the thing the app is
            // named for, on the one surface where Morgenrot is allowed (BrandPalette).
            //
            // The cost is that the ground is no longer one value: contrast against the sage body
            // runs from 12,50:1 at the top stop to 2,53:1 at the last one, so the number that counts
            // is the minimum along the body's own visible edge — see docs/design/design-system.md for the
            // measurement and for why it lands under the originally specified 4,8 target rather than on it.
            Rectangle().fill(
                LinearGradient(
                    stops: [
                        .init(color: night, location: 0),
                        .init(color: duskGreen, location: 0.42),
                        .init(color: Color.BrandPalette.dawnRedDeep, location: 0.78),
                        .init(color: Color.BrandPalette.dawnRed, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            mascot
                .scaleEffect(MascotGeometry.iconRigScale)
                .offset(y: MascotGeometry.iconRigOffsetY)
        }
        .frame(width: Self.side, height: Self.side)
        .clipped()
    }

    private var mascot: some View {
        ZStack {
            MascotContactShadow(ink: ink, width: MascotGeometry.iconContactShadowWidth, blur: 6, strength: 1.1)
                .offset(y: MascotGeometry.iconContactShadowOffsetY)

            HStack(spacing: MascotGeometry.earSpacing) {
                MascotEarSurface(fill: sage, ink: ink,
                                 outlineInk: MascotGeometry.iconEarOutlineInk,
                                 outlineWidth: MascotGeometry.iconEarOutlineWidth)
                MascotEarSurface(fill: sage, ink: ink,
                                 outlineInk: MascotGeometry.iconEarOutlineInk,
                                 outlineWidth: MascotGeometry.iconEarOutlineWidth)
            }
            .offset(y: MascotGeometry.earOffsetY)

            MascotBodySurface(fill: sage, ink: ink, bounce: rose,
                              outlineInk: MascotGeometry.iconBodyOutlineInk,
                              outlineWidth: MascotGeometry.iconBodyOutlineWidth)

            MascotEarRootShadow(ink: ink)

            HStack(spacing: MascotGeometry.cheekSpacing) {
                MascotCheek(color: rose, opacity: 0.62)
                MascotCheek(color: rose, opacity: 0.62)
            }
            .offset(y: MascotGeometry.cheekOffsetY)

            HStack(spacing: MascotGeometry.eyeSpacing) {
                eye
                eye
            }
            .offset(y: MascotGeometry.eyeOffsetY)

            Smile()
                .stroke(ink, style: StrokeStyle(lineWidth: MascotGeometry.mouthLineWidth, lineCap: .round))
                .frame(width: MascotGeometry.mouthWidth, height: MascotGeometry.mouthNeutralHeight)
                .offset(y: MascotGeometry.mouthOffsetY)

            sprout
        }
        .frame(width: MascotGeometry.rigWidth, height: MascotGeometry.rigHeight)
    }

    private var eye: some View {
        ZStack {
            Circle().fill(ink).frame(width: MascotGeometry.eyeOpenDiameter, height: MascotGeometry.eyeOpenDiameter)
            Circle().fill(.white)
                .frame(width: MascotGeometry.eyeCatchlightDiameter, height: MascotGeometry.eyeCatchlightDiameter)
                .offset(x: MascotGeometry.eyeCatchlightOffsetX, y: MascotGeometry.eyeCatchlightOffsetY)
        }
    }

    // The full-grown pair of MascotStage.eingespielt: the icon shows what the app grows towards, not
    // where a first-day user stands. It is the one place a fixed stage is honest, because there is
    // no user attached to it yet.
    private var sprout: some View {
        VStack(spacing: MascotGeometry.sproutColumnSpacing) {
            HStack(spacing: MascotGeometry.leafPairSpacing) {
                leaf.rotationEffect(.degrees(-28), anchor: .bottomTrailing)
                leaf.rotationEffect(.degrees(28), anchor: .bottomLeading)
            }
            Capsule().fill(sage).frame(width: MascotGeometry.stemWidth, height: MascotGeometry.stemLength)
        }
        .offset(y: MascotGeometry.sproutOffsetY)
    }

    private var leaf: some View {
        Ellipse()
            .fill(sage)
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

    private struct Smile: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.maxY))
            return path
        }
    }
}
