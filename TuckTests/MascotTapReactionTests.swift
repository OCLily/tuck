import Foundation
import Testing
@testable import Tuck

// The still-face invariant, and the control group this project asks for. `MascotTapReaction` was
// written to describe the CURRENT behaviour, so the matrix below is red on the code that shipped —
// four of sixteen cells — and green once the cells are filled. Green on the post-fix code alone
// would prove nothing.
struct MascotTapReactionTests {
    @Test func everyTouchIsAnsweredOnEveryStageAndInBothMotionSettings() {
        for index in 0...3 {
            for reduceMotion in [false, true] {
                for eyesOpen in [true, false] {
                    let axes = MascotTapReaction.axes(for: index,
                                                      reduceMotion: reduceMotion,
                                                      eyesOpen: eyesOpen)
                    #expect(!axes.isEmpty,
                            """
                            Tap \(index) · Reduce Motion \(reduceMotion) · eyes open \(eyesOpen) \
                            draws nothing. Visibly there and not answering is the worse state.
                            """)
                }
            }
        }
    }

    // THE CELL THE MATRIX ABOVE CANNOT SEE. `everyTouchIsAnswered…` asks "not empty", and tap 1 ·
    // Reduce Motion · eyes open was never empty: it carried the cheeks. A rendered screenshot
    // then measured that channel at stage `.eingespielt` in light appearance — a peak delta of 5 of
    // 255 against resting cheeks, which nobody sees. "Not empty" and "visible" turned out to be two
    // different claims, and only the first one had a test.
    //
    // So this pins the second one the only way a pure function can: the cell has to carry an axis
    // that is not the cheeks, and the axis is the one indices 2 and 3 already use.
    @Test func theSecondTouchAnswersWithSomethingOtherThanCheeksWhereCheeksAreNotSeen() {
        let answer = MascotTapReaction.axes(for: 1, reduceMotion: true, eyesOpen: true)
        #expect(answer.contains(.blink),
                "tap 1 under Reduce Motion answers with the cheek channel alone again")
        #expect(answer.subtracting([.cheeks]).isEmpty == false)

        // And not by taking the eyes away from the stage that has none: at `.start` the lid is
        // already down, so the fix stays out of the cell it cannot draw in.
        #expect(!MascotTapReaction.axes(for: 1, reduceMotion: true, eyesOpen: false).contains(.blink),
                "a blink was promised behind a closed lid")
    }

    // THE SAME CELL ON THE OTHER SIDE, and the one the blink could not reach. Stage `.start` is the
    // first seven mornings and all three MascotView instances in OnboardingFlowView — the first
    // impression the app makes — and there indices 1 to 3 under Reduce Motion carried the cheeks
    // alone: 6 / 5 / 4 of 255 against resting cheeks, 0 pixels over 10, rendered through
    // `MascotPose` at scale 4 in light appearance.
    //
    // The closed lid is not an absence, which is what made an answer possible at all: it is a
    // 12 x 3 capsule of ink, and `.squint` is the same two eyes as an arc. Existing vocabulary,
    // existing geometry, no transform — 127 of 255 over 974 pixels, measured the same way.
    @Test func everyTouchFoldsTheEyesWhereTheLidIsAlreadyDown() {
        for index in 0...3 {
            for reduceMotion in [false, true] {
                let axes = MascotTapReaction.axes(for: index,
                                                  reduceMotion: reduceMotion,
                                                  eyesOpen: false)
                #expect(axes.contains(.squint),
                        """
                        Tap \(index) · Reduce Motion \(reduceMotion) · stage .start answers without \
                        the fold. The cheeks alone measure 6/5/4 of 255 there.
                        """)
                #expect(axes.subtracting([.cheeks]).isEmpty == false)
            }
        }
    }

    // Per channel, not globally: a global monotonicity over "the scale values" is FALSE on today's
    // code, because index 2 writes no `tapScale` at all and reading it as a resting 1.0 shows a rise
    // from 2 to 3 that the code does not make.
    @Test func theSequenceNeverEscalates() {
        let written = [0, 1, 3].compactMap { MascotTapReaction.scale(for: $0) }
        #expect(written == [1.06, 1.04, 1.02])
        #expect(MascotTapReaction.scale(for: 2) == nil)
        for pair in zip(written, written.dropFirst()) {
            #expect(pair.0 >= pair.1, "the tap scale rises from \(pair.0) to \(pair.1)")
        }

        // Index 0 is not a link in this chain — it writes cheekOpacity absolutely — so it is not in
        // the sequence, and no boost value is invented for it.
        #expect(MascotTapReaction.cheekBoost(for: 0) == nil)
        let boosts = (1...3).compactMap { MascotTapReaction.cheekBoost(for: $0) }
        #expect(boosts.count == 3)
        for pair in zip(boosts, boosts.dropFirst()) {
            #expect(pair.0 >= pair.1, "the cheek boost rises from \(pair.0) to \(pair.1)")
        }

        // The one place the stage really occurs: index 0's absolute 0.75 has to stay above the first
        // additive step in EVERY stage, and `.eingespielt` (0.62) is the tight one.
        let firstBoost = MascotTapReaction.cheekBoost(for: 1) ?? 0
        for stage in MascotStage.allCases {
            #expect(0.75 > stage.cheekOpacity + firstBoost, "\(stage) loses its descent at tap 1")
        }

        // THE EYE CHANNEL, added when tap 1 gained the blink. A new axis on a later index is a
        // different channel and not a rise of an existing one — but the channel it joins has to
        // stay unable to rise, and it has two ways it could: by carrying both folds at once, or by
        // owning a size that a later tap could raise. The first is checked, the second cannot
        // happen — `.blink` is one axis with no magnitude, which is exactly why it was chosen.
        // Both eye states, not only the open one: since the closed lid answers with `.squint` the
        // double fold has a second way to happen, and an `eyesOpen: true`-only loop would not see it.
        for index in 0...3 {
            for reduceMotion in [false, true] {
                for eyesOpen in [true, false] {
                    let axes = MascotTapReaction.axes(for: index,
                                                      reduceMotion: reduceMotion,
                                                      eyesOpen: eyesOpen)
                    #expect(!(axes.contains(.squint) && axes.contains(.blink)),
                            "tap \(index) folds the eyes twice at once")
                }
            }
        }
        let folding = (0...3).filter {
            MascotTapReaction.axes(for: $0, reduceMotion: true, eyesOpen: true).contains(.blink)
        }
        #expect(folding == [1, 2, 3], "the blink moved to other taps than 1, 2 and 3: \(folding)")
    }

    // The other half of "a completed morning gets a mouth no tap has": if a tap ever grew one, the
    // disjoint axis would be gone as soon as it was created.
    @Test func theMouthBelongsToTheMorningAndToNothingElse() {
        for index in 0...3 {
            for reduceMotion in [false, true] {
                for eyesOpen in [true, false] {
                    #expect(!MascotTapReaction.axes(for: index,
                                                    reduceMotion: reduceMotion,
                                                    eyesOpen: eyesOpen).contains(.mouth),
                            "tap \(index) took the morning's mouth")
                }
            }
        }
    }

    // MARK: - The wiring

    // Without this the decision can be right while the body quietly does something else — the state
    // MascotProgressSurfaceExpressionTests records for its own two surfaces. And the second half is
    // the lesson of the sky stops: a pure function that MIRRORS numbers living somewhere else is a
    // hand copy, and a hand copy drifts in silence. `scale(for:)` has no call site in the rig by
    // design (the descending ladder stays where it is), so the copy is pinned instead of trusted.
    @Test func theRigAsksTheFunctionInsteadOfMirroringIt() throws {
        let lines = try Self.strippedLines("Tuck/MascotView.swift")

        let stack = try Self.body(of: "private func bodyStack(sway: Double) -> some View {", in: lines)
        let call = try Self.parenthesised("MascotExpression(", in: stack)
        #expect(call.contains("MascotTapReaction.cheekBoost(for:"),
                "the drawn cheek warmth no longer comes from MascotTapReaction")

        let tap = try Self.body(of: "private func handleTap(at location: CGPoint) {", in: lines)
        #expect(tap.contains { $0.contains("activeTapIndex = index") },
                "handleTap no longer stamps the index it is answering")

        // The second copy that made the perceptual gap possible. The rig used to decide its own
        // blink with `index >= 2` while the matrix was read off the pure function, so the two could
        // disagree without a single test noticing — and they did. Both halves are pinned: the call
        // is there, and it is fed the stage's own eye state rather than a constant.
        let tapSource = tap.joined(separator: "\n")
        #expect(tapSource.contains("MascotTapReaction.axes(for:"),
                "handleTap decides its own blink again instead of asking MascotTapReaction")
        #expect(tapSource.contains("eyesOpen: stage.eyesOpen"),
                "the blink decision no longer gets the stage's real eye state")
        #expect(!tapSource.contains("index >= 2"),
                "the mirrored blink condition is back next to the function that owns it")

        // The fold comes from the same answer. Exactly one writer, and it is the one that asks —
        // a second `squint = true` in a `case` is the copy that let the open-eye and closed-eye
        // sides of this decision drift apart in the first place.
        #expect(tap.filter { $0.contains("squint = true") }.count == 1,
                "handleTap writes the fold in more than one place again")
        #expect(tap.contains { $0.contains("answer.contains(.squint)") && $0.contains("squint = true") },
                "handleTap decides its own fold instead of asking MascotTapReaction")

        // Every `tapScale` the rig actually writes, in order, ignoring the reset to 1.
        var written: [Double] = []
        for line in tap {
            var rest = Substring(line)
            while let marker = rest.range(of: "tapScale = ") {
                let tail = rest[marker.upperBound...]
                let literal = tail.prefix { $0.isNumber || $0 == "." }
                if let value = Double(literal), value > 1 { written.append(value) }
                rest = tail
            }
        }
        #expect(written == [1.06, 1.04, 1.02], "the rig's own tap ladder changed: \(written)")
        #expect(written == [0, 1, 3].compactMap { MascotTapReaction.scale(for: $0) },
                "MascotTapReaction.scale has drifted away from the ladder it describes")
    }

    // The mechanical proof the morning's mouth would otherwise not have: it only had a screenshot line,
    // and a screenshot line is not a mechanism. Without (b) the flag is dead; without (a) it sits
    // where the existing pin already forbids it — `everyTrapSiteReadsItsDurationFromMotion` checks
    // `withAnimation(.easeInOut(duration: Motion.beamCheeksIn)) { cheekBoost = true }` VERBATIM, so
    // a `; beaming = true` inside that closure goes red immediately. Both requirements pull the same
    // way, which is worth knowing before somebody reads that red line as a test bug.
    @Test func theMorningsMouthIsActuallyWiredAndNotJustDecided() throws {
        let lines = try Self.strippedLines("Tuck/MascotView.swift")

        let beam = try Self.body(of: "private func beam() async {", in: lines)
        #expect(beam.contains { $0.trimmingCharacters(in: .whitespaces) == "beaming = true" },
                "beam() does not set `beaming` as a statement of its own")

        let mouth = try Self.body(of: "private var mouthShape: MascotMouthShape {", in: lines)
        #expect(mouth.contains { $0.contains("beaming") && $0.contains(".soft") },
                "mouthShape has no beaming branch on .soft — the flag is dead inventory")
    }

    // THE COLLISION NO EXISTING TEST SEES, and the reason this scan carries the whole load.
    // The entrance's held look and beam() run at the same time on the main path — the
    // entrance hands over at 1.4 s, the look would end around 2.0-2.2 s, and beam() holds the cheeks
    // until roughly 3.35 s — and both want the cheeks. `MotionTokenTests.trapSites` stays green
    // through all of it, because beam()'s body is untouched; `theMouthBelongsToTheMorningAndToNothingElse`
    // checks the mouth, not the cheeks.
    @Test func theEntranceNeverWarmsTheCheeksWhileTheMorningDoes() throws {
        let lines = try Self.strippedLines("Tuck/MascotView.swift")
        let entrance = try Self.body(of: "private func runEntranceThenIdle() async {", in: lines)
        let handler = try Self.body(of: ".onChange(of: morningBeat) {", in: lines)

        // The other direction first, so none of the assertions below can pass because its region
        // vanished — the lesson of LayoutContainmentTests.theScanHasSomethingToScan.
        #expect(entrance.count > 5)
        #expect(handler.count > 3)

        // (a) the shared flag stays with handleTap, beam() and the yawn.
        #expect(!entrance.contains { $0.contains("cheekBoost") },
                "the entrance writes beam()'s own cheek flag")

        // (b) exactly two writers for the entrance's own warmth, and no third place.
        let writers = lines.indices.filter { lines[$0].contains("entranceWarmth = ") }
        let entranceRange = try #require(lines.firstIndex { $0.contains("private func runEntranceThenIdle() async {") })
        let handlerStart = try #require(lines.firstIndex { $0.contains(".onChange(of: morningBeat) {") })
        for writer in writers {
            let insideEntrance = writer > entranceRange && writer < entranceRange + entrance.count + 1
            let insideHandler = writer > handlerStart && writer < handlerStart + handler.count + 1
            #expect(insideEntrance || insideHandler,
                    "entranceWarmth is written at line \(writer + 1), outside its two allowed places")
        }
        #expect(writers.count >= 3)

        // (c) the precedence rule is readable in the source, not merely decided: the check sits
        // AFTER both entrance sleeps. Not simply "after the last Task.sleep line", for a reason:
        // the held look now owns a sleep of its own that by construction sits
        // after the check, so the two entrance sleeps are named instead of "the last one".
        let check = try #require(entrance.firstIndex { $0.contains("morningBeatArrived") })
        let handover = try #require(entrance.firstIndex { $0.contains(".milliseconds(800)") })
        let afterGap = try #require(entrance.firstIndex { $0.contains(".milliseconds(1600)") })
        #expect(check > handover, "the beat is checked before the entrance has even handed over")
        #expect(check > afterGap, "the beat is checked before the after-gap pause")

        // (d) the cancel sits in the handler and before the beam task — and the old one is still
        // there. Expressly not inside beam(): that body is a trap site.
        let cancel = try #require(handler.firstIndex { $0.contains("entranceWarmthTask?.cancel()") })
        let beamTask = try #require(handler.firstIndex { $0.contains("Task { await beam() }") })
        #expect(cancel < beamTask)
        #expect(handler.contains { $0.contains("morningBeatTask?.cancel()") })
        let beam = try Self.body(of: "private func beam() async {", in: lines)
        #expect(!beam.contains { $0.contains("entranceWarmthTask") },
                "the cancel migrated into beam(), which is a MotionTokenTests trap site")

        // (e) a SUM, not a replacement. `cheekBoost: entranceWarmth` would silently drop the
        // measured tap warmth and no other test would notice.
        let stack = try Self.body(of: "private func bodyStack(sway: Double) -> some View {", in: lines)
        let call = try Self.parenthesised("MascotExpression(", in: stack)
        #expect(call.contains("MascotTapReaction.cheekBoost(for:"))
        #expect(call.contains("entranceWarmth"))
        #expect(call.contains("+"))
    }

    // MARK: - Reading

    private static var repository: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    static func strippedLines(_ relativePath: String) throws -> [String] {
        try String(contentsOf: repository.appendingPathComponent(relativePath), encoding: .utf8)
            .components(separatedBy: "\n")
            .map { line in
                guard let marker = line.range(of: "//") else { return line }
                return String(line[..<marker.lowerBound])
            }
    }

    enum ScanError: Error { case notFound(String), neverCloses(String) }

    // A call spanning several lines, read to its closing paren rather than to a guessed line count:
    // comments are stripped before scanning, so the arguments of this particular call are separated
    // by a run of empty lines and any fixed window is a coin flip.
    static func parenthesised(_ opening: String, in lines: [String]) throws -> String {
        guard let start = lines.firstIndex(where: { $0.contains(opening) }) else {
            throw ScanError.notFound(opening)
        }
        var depth = 0
        var collected: [String] = []
        for index in start ..< lines.count {
            let line = index == start
                ? String(lines[index][(lines[index].range(of: opening)!.lowerBound)...])
                : lines[index]
            collected.append(line)
            depth += line.filter { $0 == "(" }.count
            depth -= line.filter { $0 == ")" }.count
            if depth <= 0 { return collected.joined(separator: "\n") }
        }
        throw ScanError.neverCloses(opening)
    }

    static func body(of signature: String, in lines: [String]) throws -> [String] {
        guard let start = lines.firstIndex(where: { $0.contains(signature) }) else {
            throw ScanError.notFound(signature)
        }
        var depth = 0
        var opened = false
        var body: [String] = []
        for index in start ..< lines.count {
            let line = lines[index]
            depth += line.filter { $0 == "{" }.count
            depth -= line.filter { $0 == "}" }.count
            if depth > 0 { opened = true }
            if index > start { body.append(line) }
            if opened && depth == 0 { return body }
        }
        throw ScanError.neverCloses(signature)
    }
}

// The four conditions of the eye, as a table rather than as a scan — the decision that makes the
// fold above visible at all. It used to read `guard stage.eyesOpen && awake && !blink`, which gave a
// stage's closed lid the power to swallow a fold that was already requested; `squint = true` at
// stage `.start` was a variable nobody could see, for a tap and for beam() alike.
//
// The rows that changed are the two marked below. Every other row is the behaviour that shipped and
// is here so that moving the condition cannot quietly move anything else — a rig that is not awake
// yet and a blinking rig both still close the eyes, and the resting shape is still the stage's own.
@MainActor
struct MascotEyeStateTests {
    @Test func theFoldOutranksAClosedLidAndNothingElseMoved() {
        let rows: [(eyesOpen: Bool, awake: Bool, blink: Bool, squint: Bool, expected: MascotEyeState)] = [
            // Stage .start, at rest: the sleeping line, unchanged.
            (false, true, false, false, .closed),
            // CHANGED — the tap and beam() answer of the first seven mornings.
            (false, true, false, true, .squint),
            // CHANGED only in that it stays closed for the reason it always did: the entrance owns
            // the lid until `awake`, and a fold may not open it early.
            (false, false, false, true, .closed),
            (false, true, true, true, .closed),
            (false, false, false, false, .closed),
            (true, true, false, false, .open),
            (true, true, false, true, .squint),
            (true, true, true, false, .closed),
            (true, true, true, true, .closed),
            (true, false, false, false, .closed),
            (true, false, false, true, .closed)
        ]
        for row in rows {
            let state = MascotView.eyeState(eyesOpen: row.eyesOpen, awake: row.awake,
                                            blink: row.blink, squint: row.squint)
            #expect(state == row.expected,
                    """
                    eyesOpen \(row.eyesOpen) · awake \(row.awake) · blink \(row.blink) · \
                    squint \(row.squint) draws \(state), not \(row.expected)
                    """)
        }
    }

    // The named gap stays named: `.half` exists in the vocabulary and this rig reaches it from no
    // combination at all. MascotStageExpressionBoundaryTests holds the other half of that sentence.
    @Test func noCombinationOfTheFourConditionsReachesTheHalfOpenLid() {
        for eyesOpen in [true, false] {
            for awake in [true, false] {
                for blink in [true, false] {
                    for squint in [true, false] {
                        #expect(MascotView.eyeState(eyesOpen: eyesOpen, awake: awake,
                                                    blink: blink, squint: squint) != .half)
                    }
                }
            }
        }
    }
}
