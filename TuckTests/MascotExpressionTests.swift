import Foundation
import Testing
@testable import Tuck

// The vocabulary itself, as exact equalities rather than tolerance bands — the standing rule
// for anything a later change could erode a point at a time.
struct MascotExpressionVocabularyTests {
    // Four states, and the three that already existed keep the measurements they shipped with. The
    // original design's eye sizes are fractions of a body width that belongs to the deferred redraw, so
    // taking them now would have moved the face for a reason nobody decided.
    @Test func theFourEyeStatesCarryTheirNamedSizes() {
        let expected: [(MascotEyeState, Double, Double, Bool)] = [
            (.closed, 12, 3, false),
            (.half, 11, 5.5, false),
            (.squint, 11, 5, false),
            (.open, 8, 8, true)
        ]
        #expect(MascotEyeState.allCases.count == expected.count)
        for (state, width, height, catchlight) in expected {
            #expect(state.width == width, "\(state) width")
            #expect(state.height == height, "\(state) height")
            #expect(state.hasCatchlight == catchlight, "\(state) catchlight")
        }
    }

    // The catchlight is the open eye's alone. `.half` is between closed and open, and a highlight on
    // a lowered lid reads as awake — the one thing that state is not.
    @Test func onlyTheOpenEyeCarriesACatchlight() {
        for state in MascotEyeState.allCases where state != .open {
            #expect(!state.hasCatchlight, "\(state)")
        }
    }

    @Test func theFiveMouthShapesCarryTheirNamedSizes() {
        let expected: [(MascotMouthShape, Double, Double)] = [
            (.sleeping, 22, 4),
            (.neutral, 22, 8),
            (.soft, 26, 6),
            (.yawn, 15, 14),
            (.smallO, 8, 8)
        ]
        #expect(MascotMouthShape.allCases.count == expected.count)
        for (shape, width, height) in expected {
            #expect(shape.width == width, "\(shape) width")
            #expect(shape.height == height, "\(shape) height")
        }
    }

    // The architectural half of the mouth, and the reason it is a property rather than a comment:
    // four shapes have to stay ONE path at four frame sizes or the yawn stops morphing and starts
    // crossfading. `.smallO` is the single deliberate exception.
    @Test func exactlyOneMouthShapeIsNotDrawnOnTheSmilePath() {
        let circles = MascotMouthShape.allCases.filter { !$0.isDrawnAsTheSmilePath }
        #expect(circles == [.smallO])
    }

    // `.soft` has to be wider and flatter than `.neutral`, or it is not the shape the sheet
    // describes — it is just a second neutral.
    @Test func theSoftMouthIsWiderAndFlatterThanTheNeutralOne() {
        #expect(MascotMouthShape.soft.width > MascotMouthShape.neutral.width)
        #expect(MascotMouthShape.soft.height < MascotMouthShape.neutral.height)
    }

    // `.smallO` borrows the open eye's diameter as a size reference. Pinned so the comment that says
    // so cannot quietly stop being true — and so the reason stays the right way round: they are the
    // same size, which is fine precisely because no surface shows both on one face.
    @Test func theSmallOSharesTheOpenEyesDiameter() {
        #expect(MascotMouthShape.smallO.width == MascotEyeState.open.width)
        #expect(MascotExpression.breathing.eyes == .closed)
    }

    @Test func onlyTheSidewaysGazeMovesThePupils() {
        #expect(MascotGaze.ahead.offsetX == 0)
        #expect(MascotGaze.aside.offsetX == 2)
    }

    @Test func theNeutralEarPoseAddsNothingAndTheOthersAreNotSymmetric() {
        #expect(MascotEarPose.neutral.leadingDegrees == 0)
        #expect(MascotEarPose.neutral.trailingDegrees == 0)
        #expect(MascotEarPose.forward.leadingDegrees == -MascotEarPose.forward.trailingDegrees)
        // One ear, not both — that is what "ein Ohr noch angelegt" says.
        #expect(MascotEarPose.oneFolded.leadingDegrees == 0)
        #expect(MascotEarPose.oneFolded.trailingDegrees != 0)
    }
}

// The original design's expression sheet, checked against what was actually built. Seven of its ten states
// are here; the other three are named as unbuilt rather than approximated, because an approximation
// looks finished and would never be revisited.
struct MascotExpressionSheetTests {
    @Test func theSevenBuildableSheetStatesMapToTheirDocumentedPairs() {
        let sheet: [(String, MascotExpression, MascotEyeState, MascotMouthShape)] = [
            ("2 Aufwachend", .waking, .half, .neutral),
            ("3 Ruhig wach", .awake, .open, .neutral),
            ("4 Leise zufrieden", .content, .squint, .soft),
            ("5 Aufmerksam", .attentive, .open, .neutral),
            ("6 Atmend", .breathing, .closed, .smallO),
            ("7 Gähnend", .yawning, .squint, .yawn),
            ("9 Neutral wartend", .waiting, .open, .neutral)
        ]
        #expect(sheet.count == 7)
        for (name, expression, eyes, mouth) in sheet {
            #expect(expression.eyes == eyes, "\(name)")
            #expect(expression.mouth == mouth, "\(name)")
        }
    }

    // The three pairs above that share an eye/mouth pair have to differ somewhere, or naming them
    // apart was decoration. Awake, attentive and waiting are all open-eyed and neutral-mouthed:
    // what separates them is the ears and the gaze, and that is the whole lever they use.
    @Test func theThreeOpenNeutralStatesAreToldApartByEarsAndGaze() {
        #expect(MascotExpression.awake != MascotExpression.attentive)
        #expect(MascotExpression.awake != MascotExpression.waiting)
        #expect(MascotExpression.attentive != MascotExpression.waiting)
        #expect(MascotExpression.attentive.ears == .forward)
        #expect(MascotExpression.waiting.gaze == .aside)
        #expect(MascotExpression.awake.gaze == .ahead)
        #expect(MascotExpression.awake.ears == .neutral)
    }

    @Test func theCheeksWarmOnTheTwoStatesTheSheetWarmsThemOn() {
        #expect(MascotExpression.content.cheekBoost == 0.30)
        #expect(MascotExpression.yawning.cheekBoost == 0.20)
        for expression in [MascotExpression.waking, .awake, .attentive, .breathing, .waiting] {
            #expect(expression.cheekBoost == 0)
        }
    }

    @Test func theThreeUnbuildableSheetStatesAreNamedAndNotApproximated() {
        let unbuilt = MascotExpression.Unbuilt.allCases
        #expect(unbuilt.count == 3)
        #expect(unbuilt.map(\.rawValue) == ["1 Schlafend", "8 Streckend", "10 Etwas ist schief"])
        for state in unbuilt {
            #expect(state.waitsFor.contains("3.2"), "\(state.rawValue) does not say what it waits for")
        }
    }
}

// THE MECHANIC BOUNDARY. A fixed product decision rules out rebuilding the
// mascot's mechanic, and changing which stage shows which face is exactly that — so the new
// vocabulary may be used by new surfaces and by future idle beats, and by none of the three
// existing stages.
//
// The first version of this guard was one line, `MascotStage.start.eyesOpen == false`, and it was
// too weak in a way worth writing down: it checks the bool that exists and says nothing about a
// bool that does not. Somebody adding `var eyeState: MascotEyeState { ... .warmGeworden: .half }`
// would have wired a per-stage expression mapping straight past a green test. So the guard has two
// halves — the three values pinned exactly, and a scan that goes red the moment MascotStage grows
// any member at all.
struct MascotStageExpressionBoundaryTests {
    @Test func theThreeStagesKeepExactlyTheEyeMappingTheyShippedWith() {
        #expect(MascotStage.start.eyesOpen == false)
        #expect(MascotStage.warmGeworden.eyesOpen == true)
        #expect(MascotStage.eingespielt.eyesOpen == true)
        #expect(MascotStage.allCases.count == 3)
    }

    private static let file = "Tuck/MascotView.swift"
    private static let signature = "enum MascotStage: String, CaseIterable, Identifiable {"

    // Everything MascotStage declares today. `eyesOpen` is the only member of this list that says
    // anything about a face, and it may stay the only one.
    private static let expectedMembers: Set<String> = [
        "id", "displayName", "saturation", "scale", "eyesOpen", "sproutStage", "cheekOpacity",
        "completedMornings", "encouragements", "next",
        "stage", "progressTowardNext", "progressDescription", "ringSweepsOnStageChange"
    ]

    private static let forbiddenVocabulary = ["eye", "mouth", "expression", "lid", "gaze", "pose", "face"]

    private static func stageBody() throws -> [String] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(file)
        let lines = try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n")
        guard let start = lines.firstIndex(where: { $0.contains(signature) }) else {
            throw BoundaryScanError.enumNotFound
        }
        var depth = 0
        var opened = false
        var body: [String] = []
        for index in start..<lines.count {
            let line = lines[index]
            depth += line.filter { $0 == "{" }.count
            depth -= line.filter { $0 == "}" }.count
            if depth > 0 { opened = true }
            if index > start { body.append(line) }
            if opened && depth == 0 { return body }
        }
        throw BoundaryScanError.enumNeverCloses
    }

    enum BoundaryScanError: Error { case enumNotFound, enumNeverCloses }

    // Only what the enum itself declares. Depth matters: without it the scan also collects the
    // `let current`/`let span` bindings inside progressTowardNext, and the guard would then report
    // a change every time somebody renames a local variable.
    private static func declaredMembers() throws -> Set<String> {
        var names: Set<String> = []
        var depth = 0
        for line in try stageBody() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if depth == 0 {
                if let range = trimmed.range(of: "func "),
                   trimmed.hasPrefix("func") || trimmed.hasPrefix("static func") {
                    names.insert(String(trimmed[range.upperBound...].prefix { $0 != "(" && $0 != "<" }))
                } else {
                    for keyword in ["static var ", "static let ", "var ", "let "] where trimmed.hasPrefix(keyword) {
                        let rest = trimmed.dropFirst(keyword.count)
                        names.insert(String(rest.prefix { $0.isLetter || $0.isNumber || $0 == "_" }))
                        break
                    }
                }
            }
            depth += line.filter { $0 == "{" }.count
            depth -= line.filter { $0 == "}" }.count
        }
        return names
    }

    // Goes red on ANY new member, which is the point: a per-appearance or per-stage face mapping is
    // not something to be caught by guessing its name in advance.
    @Test func mascotStageGrowsNoMemberBeyondTheOnesItShippedWith() throws {
        let declared = try Self.declaredMembers()
        #expect(declared == Self.expectedMembers,
                "MascotStage's members changed. Added: \(declared.subtracting(Self.expectedMembers)) · removed: \(Self.expectedMembers.subtracting(declared)). A new per-stage mapping into the 3.3 expression vocabulary is exactly what this guard exists to stop; if the addition is something else, decide it deliberately and update this list.")
    }

    // The same rule stated in the failure message rather than in a comment, so whoever trips it
    // reads the reason instead of a set difference.
    @Test func noMascotStageMemberSpeaksAboutAFaceExceptTheOneThatAlwaysHas() throws {
        for member in try Self.declaredMembers() where member != "eyesOpen" {
            let lowered = member.lowercased()
            for word in Self.forbiddenVocabulary {
                #expect(!lowered.contains(word),
                        "MascotStage.\(member) maps a stage onto part of the face. eyesOpen is the only such mapping the mechanic has, and 3.3 was explicitly not allowed to add a second (mascot.md's \"Stufe 2: Augen halb geöffnet\" stays an open, named gap).")
            }
        }
    }

    // The other direction: `.half` exists and nothing in the app reaches it yet. That is the gap
    // being named, not a bug — and it stops being true the day a stage maps to it, which the scan
    // above would catch first.
    @Test func theHalfOpenEyeExistsAndNoStageReachesIt() {
        #expect(MascotEyeState.allCases.contains(.half))
        for stage in MascotStage.allCases {
            #expect(stage.eyesOpen == (stage != .start))
        }
    }
}

// The two surfaces that are about one particular user's progress — the "Dein Weg" row and the
// reconsider screen. Both shipped with `.waiting` unconditionally, so between day 1 and day 6 the
// app showed the same person a sleeping Tuck on the morning screen and an awake, smiling one on the
// two screens about exactly those mornings. The app icon carries a fixed stage on purpose ("die
// eine Stelle, an der eine feste Stufe ehrlich ist, weil noch kein Nutzer daranhängt");
// these two are the opposite case and now read `stage.eyesOpen` like everything else.
//
// Nothing new is mapped: at stage 0 both hand back the pair `MascotView` has always drawn there —
// `eyeState` returns `.closed` whenever `stage.eyesOpen` is false, `mouthShape` returns `.sleeping`
// in the same breath. The boundary above stays intact.
struct MascotProgressSurfaceExpressionTests {
    // Both surfaces spelled out rather than reduced to one call: they choose independently and only
    // happen to agree, so each is pinned instead of one standing in for the other. `@MainActor`
    // because a View's own static members are main-actor isolated under Swift 6.
    @MainActor
    @Test func stageStartShowsTheSleepingFaceOnBothProgressSurfaces() {
        #expect(MascotStage.start.eyesOpen == false)
        let faces = [
            ("SettingsView.progressPortrait", SettingsView.progressPortraitExpression(at: .start)),
            ("OverrideFlowView.reconsiderPose", OverrideFlowView.reconsiderPoseExpression(at: .start))
        ]
        for (name, face) in faces {
            #expect(face.eyes == .closed, "\(name) at stage .start")
            #expect(face.mouth == .sleeping, "\(name) at stage .start")
            #expect(face != .waiting, "\(name) at stage .start")
        }
    }

    @MainActor
    @Test func theTwoAwakeStagesShowTheWaitingFaceOnBothProgressSurfaces() {
        for stage in [MascotStage.warmGeworden, .eingespielt] {
            #expect(stage.eyesOpen)
            #expect(SettingsView.progressPortraitExpression(at: stage) == .waiting,
                    "SettingsView.progressPortrait at stage \(stage)")
            #expect(OverrideFlowView.reconsiderPoseExpression(at: stage) == .waiting,
                    "OverrideFlowView.reconsiderPose at stage \(stage)")
        }
    }

    // The wiring half, structural because a SwiftUI body is not reachable from a test and this
    // project has no view-inspection layer — the same shape MorningCelebrationWiringTests uses for
    // the same reason. The decision above can be right while a placement quietly keeps passing a
    // constant past it, and that is precisely the state this branch shipped in.
    private static func expressionArgument(in file: String, ofPlacement placement: String) throws -> String {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(file)
        let lines = try String(contentsOf: source, encoding: .utf8).components(separatedBy: "\n")
        let start = try #require(lines.firstIndex { $0.contains(placement) })
        return try #require(lines[start...].prefix(12).first { $0.contains("expression:") })
            .trimmingCharacters(in: .whitespaces)
    }

    @Test func bothProgressSurfacesAskTheStageWhichFaceToDraw() throws {
        let sites = [
            ("Tuck/SettingsView.swift",
             "private var progressPortrait: some View {",
             "Self.progressPortraitExpression(at: stage)"),
            ("Tuck/OverrideFlowView.swift",
             "private var reconsiderPose: some View {",
             "Self.reconsiderPoseExpression(at: stage)")
        ]
        for (file, placement, call) in sites {
            let argument = try Self.expressionArgument(in: file, ofPlacement: placement)
            #expect(argument.contains(call),
                    "\(file): the placement no longer asks the stage which face to draw. A fixed expression here shows a user in their first six mornings an awake animal on a screen about those mornings, while the morning screen shows them a sleeping one.")
            #expect(!argument.contains(".waiting"),
                    "\(file): a literal `.waiting` at the call site is the pre-fix behaviour — the choice belongs in the expression function, where stage .start can reach the sleeping face.")
        }
    }

    // The third surface, and the reason it is NOT in the list above: `.breathing` closes the
    // eyes at every stage, so it is already coherent at stage 0 and has nothing to ask.
    @Test func theBreathingCircleStillTakesItsOneFixedExpression() throws {
        let argument = try Self.expressionArgument(in: "Tuck/OverrideFlowView.swift",
                                                   ofPlacement: "private func breathingPose(openness:")
        #expect(argument.contains(".breathing"))
        #expect(MascotExpression.breathing.eyes == .closed)
    }
}
