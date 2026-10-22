import Foundation
import Testing
@testable import Tuck

// This is hygiene rather than a fix: all three sites were verified identical before the
// change (4.0 / 1.0 / 5.0 / 1.0 = 11.0 in MascotView's BreathPhase and OverrideFlowView's
// OverrideBreathPhase, plus the raw 11.0 in MorningSky's `sin(t * 2 * .pi / 11.0)`). Nothing was out
// of sync. What existed was the failure mode the design system names: "Die 11,0 s
// existieren als drei unverbundene Literale … Eine Änderung an einer einzelnen Phasendauer
// desynchronisiert die anderen beiden Stellen lautlos." One house breath, three places to edit it.
//
// The scan is deliberately bounded to the two ENUM BODIES and not to the two files. MascotView holds
// a whole idle repertoire of unrelated durations — 0.12 s blinks, a 1.6 s stretch, a 1.1 s head tilt
// — none of which is breath and none of which may be pulled onto these constants.
//
// And the pattern is `duration: <value>`, never the bare number: BreathPhase carries an independent
// 1.055 body scale, so a substring scan for "1.0" would be permanently, wrongly red on a line that
// has nothing to do with the breath. `theBodyScaleWasNotSweptUpWithTheDurations` pins exactly that.
struct BreathRhythmTests {
    struct Site: Sendable, CustomTestStringConvertible {
        let file: String
        let declaration: String

        var testDescription: String { declaration }
    }

    static let sites: [Site] = [
        Site(file: "Tuck/MascotView.swift", declaration: "private enum BreathPhase: CaseIterable {"),
        // Lost its `private` so MascotRigFitTests can read the circle's own diameter off this
        // enum instead of keeping a second copy of 110. The scan below is unaffected — it matches
        // on the declaration line, which is why that line has to move with it.
        Site(file: "Tuck/OverrideFlowView.swift", declaration: "enum OverrideBreathPhase: CaseIterable {")
    ]

    // Four phases, four durations — pinned as a count so that satisfying the scan by deleting a
    // phase is not an option.
    private static let phaseCount = 4

    private static func source(_ relativePath: String) throws -> [String] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n")
    }

    enum ScanError: Error { case declarationNotFound, neverCloses }

    private static func body(of site: Site) throws -> [String] {
        let lines = try source(site.file)
        guard let start = lines.firstIndex(where: { $0.contains(site.declaration) }) else {
            throw ScanError.declarationNotFound
        }

        var depth = 0
        var body: [String] = []
        for index in start..<lines.count {
            let line = lines[index]
            depth += line.filter { $0 == "{" }.count
            depth -= line.filter { $0 == "}" }.count
            if index > start { body.append(line) }
            if depth == 0 { return body.dropLast().map { $0 } }
        }
        throw ScanError.neverCloses
    }

    private static func durationArguments(in body: [String]) -> [String] {
        body.compactMap { line in
            guard let range = line.range(of: "duration: ") else { return nil }
            return String(line[range.upperBound...].prefix { $0 != ")" })
                .trimmingCharacters(in: .whitespaces)
        }
    }

    // The red one. Before the shared constants, every duration in both enum bodies was a bare literal.
    @Test(arguments: sites) func noBreathPhaseSpellsItsOwnDuration(site: Site) throws {
        let arguments = Self.durationArguments(in: try Self.body(of: site))

        #expect(arguments.count == Self.phaseCount,
                "\(site.file): \(site.declaration) has \(arguments.count) durations, expected \(Self.phaseCount)")
        for argument in arguments {
            #expect(argument.hasPrefix("Motion.breath"),
                    "\(site.file): \(site.declaration) still carries the raw duration `\(argument)`")
        }
    }

    // The same thing said as the three literals themselves, so the diff that matters is named in the
    // failure message rather than inferred from a prefix check.
    @Test(arguments: sites) func theFourPhaseLiteralsAreGone(site: Site) throws {
        let body = try Self.body(of: site)
        for literal in ["duration: 4.0", "duration: 1.0", "duration: 5.0"] {
            #expect(!body.contains { $0.contains(literal) },
                    "\(site.file): \(site.declaration) still contains `\(literal)`")
        }
    }

    // The guard on the scan itself. 1.055 is BreathPhase's body scale — not a duration, not part of
    // the rhythm, and the reason this file never greps for a bare "1.0".
    @Test func theBodyScaleWasNotSweptUpWithTheDurations() throws {
        let body = try Self.body(of: Self.sites[0])
        #expect(body.contains { $0.contains("1.055") },
                "Tuck/MascotView.swift: BreathPhase lost its own body scale to the duration sweep")
    }

    // The value itself, written out by hand rather than read back off the sum it checks: the design system's
    // decision is 11,0 s and 5,45 breaths per minute, and a constant that agrees with whatever it
    // currently is would not be a decision any more. The exhale being the longest phase is the half
    // of coherent breathing that does the work, so it is pinned as a relation and not only as 5.0.
    @Test func theHouseBreathIsStillElevenSecondsWithTheLongerExhale() {
        #expect(Motion.breathCycle == 11.0)
        #expect(Motion.breathIn == 4.0)
        #expect(Motion.breathHold == 1.0)
        #expect(Motion.breathOut == 5.0)
        #expect(Motion.breathStill == 1.0)
        #expect(Motion.breathOut > Motion.breathIn)
        #expect(60 / Motion.breathCycle > 5.4 && 60 / Motion.breathCycle < 5.5)
    }

    // The third site, and the only one that was already a whole cycle rather than four phases.
    @Test func theAmbientLightAndDustReadTheSameCycle() throws {
        let lines = try Self.source("Tuck/MorningSky.swift")
        #expect(lines.contains { $0.contains("Motion.breathCycle") },
                "Tuck/MorningSky.swift: the ambience does not read the shared cycle")
        #expect(!lines.contains { $0.contains("/ 11.0") },
                "Tuck/MorningSky.swift: the raw 11.0 cycle literal is still there")
    }
}
