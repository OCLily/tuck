import SwiftUI

// The shield takes one flat UIImage (docs/build-plan-phase1.md): no SwiftUI view, no animation
// and no live state. MascotView itself is not reusable here — its `recognition` parameter reaches
// through MorningRecognition into WakeAlarmStore, three files of app state that an extension which
// only draws has no reason to compile, and every one of its stage/idle/tap behaviours would be
// discarded by the single snapshot anyway. Same shapes, same palette, no motion, no growth stage:
// making the shield mirror the mascot's real stage needs live App-Group state this drawing does not
// have, and a wrong stage is worse than none.
//
// The seed does not break that. What reveals a stage is the leaves — one at
// "Warm geworden", two at "Eingespielt" — and neither is drawn here. The bud is the form the sprout
// has before it has grown into anything, which is exactly what this surface is allowed to say: it
// claims no progress, so it cannot claim the wrong one. Before the seed the shield showed no sprout at
// all, which was already the stage-0 look; this keeps it at the stage-0 look and makes that look
// visible. Drawn by hand a second time and not shared.
//
// This view is never rendered at runtime: it is the source of Assets.xcassets/ShieldMascot, which
// tools/render-shield-mascot.sh regenerates from it. Change the drawing, run the script, commit the
// PNG with it. Both drawings are placeholders until the real illustration lands
// and are replaced together at that point.
//
// It reads `Color.LightPalette` and not the appearance-resolving tokens, which is the one place in
// the app where that is the *drawing's* decision rather than a transport limitation. Two
// reasons, and the second is the binding one:
//
// 1. The output is a checked-in PNG. Against the tokens, `swiftc` + `ImageRenderer` would resolve
//    them against the rendering Mac's own appearance, so the committed asset would silently depend
//    on whether whoever ran the script had dark mode on.
// 2. The shield's *colours* cross to the host process still dynamic, but the icon does not:
//    ManagedSettingsUI flattens it to PNG bytes (`UIImagePNGRepresentation` / CGImageDestination)
//    inside this extension, at configuration time. A dark variant would therefore be frozen to
//    whatever appearance was current when the configuration was built, while the colours around it
//    kept following the system live — a shield that half-flips is worse than one that does not.
//    One appearance-neutral drawing avoids that: a pale sage body reads on Cream and on Night Ink
//    alike, and it is the same PNG in both.
//
// A dark icon variant is not blocked by anything except that mismatch, so it becomes available the
// day ManagedSettingsUI re-asks the data source on a trait change. It does not today.
struct ShieldMascotIcon: View {
    var body: some View {
        ZStack {
            HStack(spacing: MascotGeometry.earSpacing) {
                ear
                ear
            }
            .foregroundStyle(Color.LightPalette.sage)
            .offset(y: MascotGeometry.earOffsetY)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color.LightPalette.sage.opacity(0.85), Color.LightPalette.sage],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: MascotGeometry.bodyWidth, height: MascotGeometry.bodyHeight)

            Ellipse()
                .fill(.white.opacity(0.18))
                .frame(width: MascotGeometry.shieldHighlightWidth,
                       height: MascotGeometry.shieldHighlightHeight)
                .blur(radius: 10)
                .rotationEffect(.degrees(12))
                .offset(x: MascotGeometry.shieldHighlightOffsetX,
                        y: MascotGeometry.shieldHighlightOffsetY)

            HStack(spacing: MascotGeometry.cheekSpacing) {
                cheek
                cheek
            }
            .offset(y: MascotGeometry.cheekOffsetY)

            HStack(spacing: MascotGeometry.eyeSpacing) {
                closedEye
                closedEye
            }
            .offset(y: MascotGeometry.eyeOffsetY)

            Smile()
                .stroke(Color.LightPalette.charcoalGreen,
                        style: StrokeStyle(lineWidth: MascotGeometry.mouthLineWidth, lineCap: .round))
                .frame(width: MascotGeometry.mouthWidth, height: MascotGeometry.mouthSleepingHeight)
                .offset(y: MascotGeometry.mouthOffsetY)

            sprout
        }
        .frame(width: MascotGeometry.rigWidth, height: MascotGeometry.rigHeight)
    }

    // The hand-copied twin of MascotView's `.seed` branch: bud plus the stem at 0.6 of its length.
    //
    // The one number that is deliberately NOT the app's (`MascotGeometry.shieldSproutOffsetY`): the
    // offset is -62 where MascotView uses -70. A column centred on -70 always has half its height
    // above the frame's own top edge, and the app does not care — a SwiftUI `.frame` does not clip,
    // so the crown simply draws outside it.
    // This drawing has a hard boundary the app does not: `ImageRenderer` crops to exactly these
    // 160 x 140, and at -70 the committed PNG showed a severed nub instead of a bud (measured, first
    // render of the seed). -62 is the smallest move that puts the whole 13.4 pt column inside the bounds,
    // with ~1.3 pt to spare. It reads as rooted between the ears rather than floating above them —
    // the second visible divergence of this drawing from the app's, after the flat shading.
    private var sprout: some View {
        VStack(spacing: MascotGeometry.sproutColumnSpacing) {
            Circle()
                .fill(Color.LightPalette.sage)
                .overlay(Circle().stroke(Color.LightPalette.charcoalGreen.opacity(0.5),
                                         lineWidth: MascotGeometry.sproutOutlineWidth))
                .frame(width: MascotGeometry.budDiameter, height: MascotGeometry.budDiameter)
            Capsule()
                .fill(Color.LightPalette.sage)
                .frame(width: MascotGeometry.stemWidth, height: MascotGeometry.shieldStemLength)
        }
        .offset(y: MascotGeometry.shieldSproutOffsetY)
    }

    private var ear: some View {
        Circle().frame(width: MascotGeometry.earDiameter, height: MascotGeometry.earDiameter)
    }

    private var closedEye: some View {
        Capsule().fill(Color.LightPalette.charcoalGreen)
            .frame(width: MascotGeometry.eyeClosedWidth, height: MascotGeometry.eyeClosedHeight)
    }

    private var cheek: some View {
        Ellipse()
            .fill(Color.LightPalette.dustyRose.opacity(0.35))
            .frame(width: MascotGeometry.cheekCoreWidth, height: MascotGeometry.cheekCoreHeight)
            .blur(radius: 3)
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
