import Foundation
import Testing
@testable import Tuck

// Tuck/Motion.swift held four numbers; the design system's "Etablierte Dauern" held about forty more
// as prose, and every one of them lived as a literal at its call site. This file pins both halves
// of the consolidation: that each named duration still carries its decided value, and — the half
// that actually protects something — that naming them did not turn into gating them.
//
// WHY THE SECOND HALF NEEDS ITS OWN MECHANISM. The design system lists four places that carry a
// reaction which has to keep running under Reduce Motion and are deliberately ungated at the
// animation itself:
// SunriseBloom.body, OverrideFlowView.breathing(for:), MascotView.beam() and
// GutenMorgenView.flourishRing(). Anyone "repairing" one of them by adding `reduceMotion ? nil : …`
// silences a reaction rather than fixing a bug — a real Reduce-Motion violation. Renaming 2.6 to
// Motion.celebrationBloom is a change that touches all four of those lines, which makes this the
// exact moment such a "fix" is most likely to be slipped in.
//
// WHY A LINE SCAN IS NOT ENOUGH — the three holes the obvious version has, all real:
//
//   1. "the animation line" is not one line. beam() has three animated lines plus two springs,
//      flourishRing() has two. A scan written for one line per function checks a third of one.
//   2. `guard !reduceMotion else { return }` at the top of a function silences the whole reaction
//      without touching any animation line at all. A line scan cannot see it.
//   3. "no reduceMotion anywhere in this function" is wrong in the other direction: SunriseBloom
//      .body and breathing(for:) carry legitimate, long-standing reduceMotion pins (the bloom's
//      scale, the breathing circle's diameter). Forbidding the token outright would fail today.
//
// So what is pinned is a COUNT over the whole function body, as an exact equality. A new condition
// raises it and goes red wherever in the body it was inserted; the existing pins keep their place.
// That is the difference between checking a line and checking a function.
struct MotionTokenTests {
    struct Region: Sendable, CustomTestStringConvertible {
        let file: String
        /// The type whose body has to be entered first, where the member's signature is not unique
        /// in the file — `var body: some View {` occurs in every view of GutenMorgenView.swift.
        let enclosing: String?
        let member: String
        let reduceMotionOccurrences: Int
        let animatedLines: [String]

        var testDescription: String { "\(file) · \(member)" }
    }

    // The four trap sites, cited by symbol rather than by line number: the design system's own line-number
    // citations had drifted on three of the four, which is why the convention is to
    // quote symbols, not line numbers.
    static let trapSites: [Region] = [
        Region(file: "Tuck/GutenMorgenView.swift",
               enclosing: "private struct SunriseBloom: View {",
               member: "var body: some View {",
               // The scale pin (0.975, the exact mean of 0.6 and 1.35). Long-standing and correct.
               reduceMotionOccurrences: 1,
               animatedLines: [".animation(.easeOut(duration: Motion.celebrationBloom), value: bloom)"]),

        // Three, not two. An earlier count said two and was counting lines rather
        // than occurrences: the breathing circle's diameter pin appears TWICE, once at `width:` and
        // once at `height:`, on two lines of one `.frame(` call. The third is the step change into
        // the next screen, which is gated on purpose (the flow-step convention). Measured rather than
        // taken over.
        Region(file: "Tuck/OverrideFlowView.swift",
               enclosing: nil,
               member: "private func breathing(for reason: OverrideReason) -> some View {",
               reduceMotionOccurrences: 3,
               animatedLines: [
                ".animation(.easeInOut(duration: Motion.breathLabelCrossfade), value: breath)",
                "withAnimation(reduceMotion ? nil : .easeInOut(duration: Motion.stepOverride)) {"
               ]),

        Region(file: "Tuck/MascotView.swift",
               enclosing: nil,
               member: "private func beam() async {",
               reduceMotionOccurrences: 0,
               animatedLines: [
                "withAnimation(.easeInOut(duration: Motion.beamCheeksIn)) { cheekBoost = true }",
                "withAnimation(.easeInOut(duration: Motion.beamSquintOut)) { squint = false }",
                "withAnimation(.easeInOut(duration: Motion.beamCheeksOut)) { cheekBoost = false }"
               ]),

        Region(file: "Tuck/GutenMorgenView.swift",
               enclosing: nil,
               member: "private func flourishRing() async {",
               reduceMotionOccurrences: 0,
               animatedLines: [
                "withAnimation(.easeInOut(duration: Motion.ringFlourishIn)) { ringFlourish = 1 }",
                "withAnimation(.easeInOut(duration: Motion.ringFlourishOut)) { ringFlourish = 0 }"
               ])
    ]

    // THE FIFTH SITE, AND IT IS THE MIRROR IMAGE OF THE FOUR ABOVE. `trapSites` pins a count against
    // RISING: a new `reduceMotion ?` in one of those bodies silences a reaction that has to keep
    // running, so more is the failure. A drifting ambient surface is the opposite case — the gate IS
    // the requirement, and the failure is FEWER. One list cannot carry both directions, so
    // this is a second list with the same machinery and its own message.
    //
    // WHY `enclosing:` IS NOT DECORATION HERE. `body(of:in:)` takes the FIRST line containing the
    // signature, not a unique one — that is what `Region.enclosing` exists for, and its own comment
    // says so. `var body: some View {` occurs TWICE in SeasonalAccent.swift since the found object
    // moved in beside the particles. With `enclosing: nil` the measured region would hang on
    // declaration order: put the still view first and this pin measures a body with zero
    // `reduceMotion`, pins zero as an exact equality, and the one test whose entire purpose is to
    // notice a disappearing gate can never go red again.
    static let motionGatedSites: [Region] = [
        Region(file: "Tuck/SeasonalAccent.swift",
               enclosing: "struct SeasonalAccent: View {",
               member: "var body: some View {",
               // Counted on the finished code, not estimated: the `paused:` condition and the
               // `t = reduceMotion ? 0 : …` binding, the same two the reference implementation in
               // MorningAmbience carries. `quiet` sits beside both and is deliberately NOT spelled
               // `reduceMotion`, or this number would mean two things at once.
               reduceMotionOccurrences: 2,
               animatedLines: [])
    ]

    @Test(arguments: motionGatedSites)
    func noMotionGateQuietlyDisappears(region: Region) throws {
        let occurrences = try Self.body(of: region)
            .joined(separator: "\n")
            .components(separatedBy: "reduceMotion")
            .count - 1
        #expect(occurrences == region.reduceMotionOccurrences,
                """
                \(region.file) · \(region.member): \(occurrences) `reduceMotion` in the body, \
                \(region.reduceMotionOccurrences) expected. If this number has FALLEN, somebody \
                removed a Reduce-Motion gate that is the requirement here. This is \
                an ambient surface that drifts; under Reduce Motion it has to stand still.
                """)
    }

    // MARK: - Reading

    private static var repository: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static func source(_ relativePath: String) throws -> String {
        try String(contentsOf: repository.appendingPathComponent(relativePath), encoding: .utf8)
    }

    // Comments are stripped first: three of the four trap sites explain their own Reduce-Motion
    // treatment in prose directly above the code, and that prose names `reduceMotion` — counted in,
    // the pin would measure how much was written about the rule rather than how often it is applied.
    private static func withoutComments(_ lines: [String]) -> [String] {
        lines.map { line in
            guard let marker = line.range(of: "//") else { return line }
            return String(line[..<marker.lowerBound])
        }
    }

    enum ScanError: Error { case notFound(String), neverCloses(String) }

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

    static func body(of region: Region) throws -> [String] {
        var lines = withoutComments(try source(region.file).components(separatedBy: "\n"))
        if let enclosing = region.enclosing { lines = try body(of: enclosing, in: lines) }
        return try body(of: region.member, in: lines)
    }

    // MARK: - The four trap sites

    @Test(arguments: trapSites)
    func noTrapSiteGrowsANewReduceMotionCondition(region: Region) throws {
        let occurrences = try Self.body(of: region)
            .joined(separator: "\n")
            .components(separatedBy: "reduceMotion")
            .count - 1
        #expect(occurrences == region.reduceMotionOccurrences,
                """
                \(region.file) · \(region.member): \(occurrences) `reduceMotion` in the body, \
                \(region.reduceMotionOccurrences) expected. If this went UP, read the Reduce-Motion rules before \
                changing the number: these four reactions have to keep running under Reduce Motion, \
                and gating one is a violation, not a fix. Naming a duration is not gating it.
                """)
    }

    @Test(arguments: trapSites)
    func everyTrapSiteReadsItsDurationFromMotion(region: Region) throws {
        let body = try Self.body(of: region).map { $0.trimmingCharacters(in: .whitespaces) }
        for expected in region.animatedLines {
            #expect(body.contains(expected),
                    "\(region.file) · \(region.member) no longer carries `\(expected)`")
        }
        // And nothing in these four bodies writes a duration as a number any more, which is what
        // makes the lines above a complete list rather than a sample.
        for line in body where line.contains("duration:") {
            #expect(line.contains("Motion."),
                    "\(region.file) · \(region.member): `\(line)` writes a duration instead of naming one")
        }
    }

    // MARK: - The values

    // Exact equalities, not ranges: the design system decided numbers, and a token that may drift inside a band
    // documents nothing. Same shape as BreathRhythmTests for the four that were already here.
    @Test func everyNamedDurationCarriesTheValueSixOneDecided() {
        #expect(Motion.skyCrossfade == 8)
        #expect(Motion.skyPoll == 60)
        #expect(Motion.stageSaturation == 6.0)
        #expect(Motion.ambientTick == 1.0 / 20.0)

        #expect(Motion.bubbleIn == 0.5)
        #expect(Motion.bubbleHold == 2.8)
        #expect(Motion.bubbleOut == 0.9)

        #expect(Motion.sublineDelay == 0.4)
        #expect(Motion.sublineIn == 1.2)

        #expect(Motion.celebrationBloom == 2.6)
        #expect(Motion.celebrationWindow == 2.8)

        #expect(Motion.ringSettle == 1.4)
        #expect(Motion.ringFill == 1.1)
        #expect(Motion.ringFlourishIn == 0.9)
        #expect(Motion.ringFlourishHold == 1.4)
        #expect(Motion.ringFlourishOut == 1.2)

        #expect(Motion.sweepClose == 0.5)
        #expect(Motion.sweepFlourishIn == 0.8)
        #expect(Motion.sweepGap == 0.6)
        #expect(Motion.sweepTail == 1.1)
        #expect(Motion.sweepTailHold == 1.1)
        #expect(Motion.sweepFlourishOut == 0.9)

        #expect(Motion.stepOnboarding == 0.25)
        #expect(Motion.stepOverride == 0.6)
        #expect(Motion.breathLabelCrossfade == 0.6)

        #expect(Motion.entranceHandover == 1.4)
        #expect(Motion.entranceHandoverAfterGap == 3.0)

        #expect(Motion.beamCheeksIn == 0.45)
        #expect(Motion.beamHold == 1.0)
        #expect(Motion.beamSquintOut == 0.4)
        #expect(Motion.beamCheekGap == 0.5)
        #expect(Motion.beamCheeksOut == 0.9)

        #expect(Motion.blink == 0.12)
        #expect(Motion.blinkHold == 0.12)
        #expect(Motion.doubleBlinkGap == 0.14)
        #expect(Motion.slowBlink == 0.3)
        #expect(Motion.slowBlinkHold == 0.3)

        #expect(Motion.idleIntervalMin == 3.5)
        #expect(Motion.idleIntervalMax == 7)
        #expect(Motion.idleQuietAfterReaction == 3.5)

        #expect(Motion.tiltIn == 1.1)
        #expect(Motion.tiltHold == 1.4)
        #expect(Motion.tiltOut == 1.4)

        #expect(Motion.gazeShift == 0.6)
        #expect(Motion.gazeHold == 1.2)

        #expect(Motion.stretchUp == 1.6)
        #expect(Motion.stretchHold == 0.5)
        #expect(Motion.stretchDown == 1.4)

        #expect(Motion.yawnOpen == 0.5)
        #expect(Motion.yawnHold == 1.1)
        #expect(Motion.yawnClose == 0.6)
        #expect(Motion.yawnCheekGap == 0.6)
        #expect(Motion.yawnCheeksOut == 0.6)

        #expect(Motion.earTwitchHold == 0.3)
    }

    // The two derived values, and the one claim the design system makes about them. `sweepRing()`
    // reaches the end of its last sub-animation after gap + tail hold + flourish-out; the design system
    // carried "≈2,9 s" for that earlier, which would NOT have fitted the 2,8 s window it says it sits
    // inside. The real wall clock is 2,6 s, and this is the assertion that keeps the sentence true.
    @Test func theStageSweepStillFitsInsideTheCelebrationWindow() {
        #expect(Motion.sweepWallClock == 2.6)
        #expect(Motion.sweepWallClock <= Motion.celebrationWindow)
        #expect(Motion.stretchTurn == 2.1)
    }

    // The same guard the layout scan carries: a token nothing reads drifts away from the drawing in
    // silence. Every name above has to appear at a call site in Tuck/ outside Motion.swift itself.
    @Test func everyNamedDurationIsReadSomewhere() throws {
        let names = ["skyCrossfade", "skyPoll", "stageSaturation", "ambientTick",
                     "bubbleIn", "bubbleHold",
                     "bubbleOut", "sublineDelay", "sublineIn", "celebrationBloom",
                     "celebrationWindow", "ringSettle", "ringFill", "ringFlourishIn",
                     "ringFlourishHold", "ringFlourishOut", "sweepClose", "sweepFlourishIn",
                     "sweepGap", "sweepTail", "sweepTailHold", "sweepFlourishOut",
                     "stepOnboarding", "stepOverride", "breathLabelCrossfade",
                     "entranceHandover", "entranceHandoverAfterGap", "beamCheeksIn",
                     "beamHold", "beamSquintOut", "beamCheekGap", "beamCheeksOut", "blink",
                     "blinkHold", "doubleBlinkGap", "slowBlink", "slowBlinkHold",
                     "idleIntervalMin", "idleIntervalMax", "idleQuietAfterReaction",
                     "tiltIn", "tiltHold", "tiltOut",
                     "gazeShift", "gazeHold", "stretchUp", "stretchTurn", "stretchDown",
                     "yawnOpen", "yawnHold", "yawnClose", "yawnCheekGap", "yawnCheeksOut",
                     "earTwitchHold"]
        let directory = Self.repository.appendingPathComponent("Tuck")
        var corpus = ""
        for name in try FileManager.default.contentsOfDirectory(atPath: directory.path)
        where name.hasSuffix(".swift") && name != "Motion.swift" {
            corpus += Self.withoutComments(try Self.source("Tuck/\(name)").components(separatedBy: "\n"))
                .joined(separator: "\n")
        }
        for name in names {
            #expect(corpus.contains("Motion.\(name)"), "Motion.\(name) is read nowhere — dead token inventory")
        }
    }
}
