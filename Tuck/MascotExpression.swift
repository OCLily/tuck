import Foundation

// The rig has always had four eye shapes and three mouth shapes; what it did not have
// was a name for any of them. They existed as conditions inside one drawing function — `open &&
// squint`, `yawning ? 15 : 22` — so nothing outside `MascotView` could ask for a face, and the
// three animal-less surfaces had no vocabulary to ask in.
//
// The measurements below are TODAY'S, not those of the original design. That design gives eye and
// mouth sizes as fractions of a body width B, and that B comes from the same CSS reference and the same
// derivation as the deferred tail — they are part of the redraw, not independent of it. Three
// shapes are genuinely new (`.half`, `.soft`, `.smallO`); everything else is the shipped value
// under a name.
//
// THE HARD BOUNDARY, and the reason this file cannot grow a `MascotStage` extension:
// `MascotStage.eyesOpen` stays exactly `stage != .start`. No stage gets a new eye or mouth mapping
// out of this vocabulary. mascot.md's "Stufe 2: Augen halb geöffnet" is therefore an open, named
// gap — `.half` exists here and no stage reaches it — because rebuilding the mascot mechanic is
// ruled out by a fixed product decision, and changing which stage shows which face
// is exactly that. New surfaces and future idle beats may use this freely. The three
// existing stages may not.
// `MascotExpressionTests` holds both halves of that boundary.

enum MascotEyeState: CaseIterable {
    // The sleeping line the rig has drawn at stage 0 since the beginning.
    case closed
    // Half-open: the one state with no precedent in the drawing. Between `.closed` and `.open` —
    // a lowered lid with a rounded top rather than the folded arc of `.squint`, and no catchlight,
    // because a catchlight on a half-lidded eye reads as awake rather than as waking.
    case half
    // The tap reaction, already built, now named: the smile arc turned upside down.
    case squint
    case open

    var width: Double {
        switch self {
        case .closed: MascotGeometry.eyeClosedWidth
        case .half: MascotGeometry.eyeHalfWidth
        case .squint: MascotGeometry.eyeSquintWidth
        case .open: MascotGeometry.eyeOpenDiameter
        }
    }

    var height: Double {
        switch self {
        case .closed: MascotGeometry.eyeClosedHeight
        case .half: MascotGeometry.eyeHalfHeight
        case .squint: MascotGeometry.eyeSquintHeight
        case .open: MascotGeometry.eyeOpenDiameter
        }
    }

    var hasCatchlight: Bool { self == .open }
}

enum MascotMouthShape: CaseIterable {
    case sleeping
    case neutral
    // Wider and flatter than `.neutral` — the quiet-contentment mouth of sheet states 4 and 8.
    case soft
    case yawn
    // The only shape that is not the rig's one smile path: a small open ring. Its diameter is the
    // open eye's diameter, and that is a size REFERENCE, not a distinguishing feature — the two
    // never share a face, because the one surface that uses `.smallO` draws the eyes
    // `.closed`.
    case smallO

    var width: Double {
        switch self {
        case .sleeping, .neutral: MascotGeometry.mouthWidth
        case .soft: MascotGeometry.mouthSoftWidth
        case .yawn: MascotGeometry.mouthYawnWidth
        case .smallO: MascotGeometry.mouthSmallODiameter
        }
    }

    var height: Double {
        switch self {
        case .sleeping: MascotGeometry.mouthSleepingHeight
        case .neutral: MascotGeometry.mouthNeutralHeight
        case .soft: MascotGeometry.mouthSoftHeight
        case .yawn: MascotGeometry.mouthYawnHeight
        case .smallO: MascotGeometry.mouthSmallODiameter
        }
    }

    // Four of the five are one `Smile` path at four frame sizes, which is what makes a change
    // between them the soft morph the yawn already has. Giving each case its own view would be a
    // change of identity to SwiftUI, and it would pop instead. `.smallO` is a circle and therefore
    // unavoidably its own identity — no surface animates between it and a smile.
    var isDrawnAsTheSmilePath: Bool { self != .smallO }
}

// A flat rig cannot tell looking-ahead from looking-at-you: there is no head to turn and no iris
// inside the pupil to shift. So the design's "Blick zum Nutzer" state is `.ahead` here, and what
// actually carries "aufmerksam" is the ear pose. `.aside` is the one gaze the drawing can really
// make — the pupils move, inside the same ±2.5 band the drag gesture already uses.
enum MascotGaze {
    case ahead
    case aside

    var offsetX: Double {
        switch self {
        case .ahead: 0
        case .aside: MascotGeometry.gazeAsideOffset
        }
    }
}

// Added on top of whatever rotation the host is already applying, so `MascotView`'s tap flare,
// entrance fold and ear twitch keep working untouched and simply pass `.neutral`.
enum MascotEarPose {
    case neutral
    case forward
    // State 2, "ein Ohr noch angelegt". A pose, not anatomy — the asymmetric ear SHAPE is part of
    // the deferred redraw and is not this.
    case oneFolded

    // Degrees, written here rather than in MascotGeometry: that file holds sizes and offsets, and
    // the rig's other angles (the leaf's ±28) are literals at their own drawing too. The two
    // magnitudes are the ones the rig already moves ears by — the tap's flare and the entrance's
    // fold — so a pose borrows a motion the animal already has instead of inventing a third.
    static let forwardDegrees: Double = 10
    static let foldDegrees: Double = -6

    var leadingDegrees: Double {
        switch self {
        case .neutral: 0
        case .forward: -Self.forwardDegrees
        case .oneFolded: 0
        }
    }

    var trailingDegrees: Double {
        switch self {
        case .neutral: 0
        case .forward: Self.forwardDegrees
        case .oneFolded: Self.foldDegrees
        }
    }
}

struct MascotExpression: Equatable {
    var eyes: MascotEyeState
    var mouth: MascotMouthShape
    var gaze: MascotGaze = .ahead
    var ears: MascotEarPose = .neutral
    // Added to the host's own cheek opacity. `MascotView` keeps its own tap and morning-beat warmth
    // (0.75) and passes 0 here; this is for the surfaces that have no tap state to warm them.
    var cheekBoost: Double = 0
}

// The seven of the original design's ten expression states that this vocabulary can actually draw.
extension MascotExpression {
    // 2 — Aufwachend
    static let waking = MascotExpression(eyes: .half, mouth: .neutral, ears: .oneFolded)
    // 3 — Ruhig wach. The default, and what MascotView has always drawn awake.
    static let awake = MascotExpression(eyes: .open, mouth: .neutral)
    // 4 — Leise zufrieden. Not jubilant: a cheer would be a verdict on the user.
    static let content = MascotExpression(eyes: .squint, mouth: .soft, ears: .forward,
                                          cheekBoost: 0.30)
    // 5 — Aufmerksam
    static let attentive = MascotExpression(eyes: .open, mouth: .neutral, ears: .forward)
    // 6 — Atmend
    static let breathing = MascotExpression(eyes: .closed, mouth: .smallO)
    // 7 — Gähnend
    static let yawning = MascotExpression(eyes: .squint, mouth: .yawn, cheekBoost: 0.20)
    // 9 — Neutral wartend
    static let waiting = MascotExpression(eyes: .open, mouth: .neutral, gaze: .aside)

    // The other three, named rather than left out and rather than approximated with something this
    // rig can draw. An approximation would be the worse outcome: it would look finished and be
    // wrong, and nobody would have a reason to look at it again.
    enum Unbuilt: String, CaseIterable {
        case sleeping = "1 Schlafend"
        case stretching = "8 Streckend"
        case somethingIsOff = "10 Etwas ist schief"

        var waitsFor: String {
            switch self {
            case .sleeping, .stretching:
                // Both are defined by the tail in the original expression sheet ("Schwanz eng",
                // "Schwanz aufgerollt"), and the tail is the species question the redraw was
                // deferred over.
                "3.2 — the tail, which carries the whole state in the sheet"
            case .somethingIsOff:
                // An asymmetric lid and a sixth mouth shape ("kleine Seitenkurve"), neither built.
                "3.2 — an asymmetric eyelid and a sixth mouth shape, neither in this vocabulary"
            }
        }
    }
}
