import Foundation
import Testing
@testable import Tuck
// The idle loop draws every 3.5–7 s regardless of what the user just did, so roughly one tap in five
// is followed by an unprompted beat inside a second — and because `earTwitch` and `headTilt` are in
// both repertoires, that second move is formally indistinguishable from the answer. This file holds
// the arithmetic half of the fix.
//
// WHY THE SOURCE SCAN BELOW CARRIES MORE WEIGHT THAN THE PURE FUNCTION. There is no control group
// here — `IdleSchedule` cannot be called before it exists, and a compile error is not a red test

// (SproutSourceTests' header). What can go silently wrong is not the arithmetic, it is the wiring:
// a `from: .now` passes every assertion in this file and changes nothing at all.
struct IdleScheduleTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func withoutAReactionTheDeadlineIsExactlyTheDrawnInterval() {
        let deadline = IdleSchedule.nextDeadline(from: t0, draw: 5.25, lastReaction: nil)

        #expect(deadline == t0.addingTimeInterval(5.25))
    }

    // The one case that really tests the identity, and it needs `lastReaction > periodStart`: with a
    // reaction at or before the start of the period the claim is arithmetically empty (any draw is
    // already at least `idleQuietAfterReaction` long), and a test written that way stays green for
    // the no-op build.
    @Test func aReactionPushesTheNextUnpromptedBeatBeyondTheQuietFloor() {
        let deadline = IdleSchedule.nextDeadline(from: t0,
                                                 draw: Motion.idleIntervalMin,
                                                 lastReaction: t0.addingTimeInterval(3.0))

        #expect(deadline == t0.addingTimeInterval(3.0 + Motion.idleQuietAfterReaction))
        #expect(deadline > t0.addingTimeInterval(Motion.idleIntervalMin))
    }

    // Idempotence of a pure function, and honest about its reach: it only holds the runaway build
    // down together with the wiring scan at the bottom of this file. The scan carries the load.
    @Test func aDeadlineDoesNotRunAwayWhileTheAnimalIsLeftAlone() {
        for _ in 0..<5 {
            #expect(IdleSchedule.nextDeadline(from: t0, draw: 6.0, lastReaction: nil)
                    == t0.addingTimeInterval(6.0))
        }
    }

    @Test func anOldReactionChangesNothing() {
        let deadline = IdleSchedule.nextDeadline(from: t0,
                                                 draw: 4.0,
                                                 lastReaction: t0.addingTimeInterval(-600))

        #expect(deadline == t0.addingTimeInterval(4.0))
    }

    // The change may only MOVE idle beats, never add one: across the whole band the deadline is
    // never earlier than it would be without a reaction.
    @Test func theFunctionNeverPullsADeadlineForward() {
        for step in 0...35 {
            let draw = Motion.idleIntervalMin
                + (Motion.idleIntervalMax - Motion.idleIntervalMin) * Double(step) / 35
            for offset in [-10.0, -1.0, 0.0, 1.0, 3.0, 6.9] {
                let withReaction = IdleSchedule.nextDeadline(from: t0,
                                                             draw: draw,
                                                             lastReaction: t0.addingTimeInterval(offset))
                #expect(withReaction >= t0.addingTimeInterval(draw))
            }
        }
    }

    // The time comes in, it is not fetched — the same separation SeasonTests will ask of the
    // calendar readers, and the reason this function is testable at all.
    @Test func theScheduleHoldsNoClockAndNoDice() throws {
        // Comments stripped: this file explains in prose why a `.now` in here would be wrong, and
        // prose about the rule must not read as the rule being broken.
        let source = try Self.lines(of: "Tuck/IdleSchedule.swift").joined(separator: "\n")

        #expect(!source.contains("random"))
        #expect(!source.contains("Date()"))
        #expect(!source.contains(".now"))
    }

    // MARK: - The wiring, which is where the silent failure lives

    private static var repository: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    // Own machinery rather than an import of MotionTokenTests', for the reason
    // LayoutContainmentTests writes down itself: a change to one scan's definition of a violation
    // must not silently redefine the other's. Comments are stripped first — this file's own prose
    // names `from: .now` as the failure, and prose about the rule is not the rule being broken.
    static func source(_ relativePath: String) throws -> String {
        try String(contentsOf: repository.appendingPathComponent(relativePath), encoding: .utf8)
    }

    static func lines(of relativePath: String) throws -> [String] {
        try source(relativePath).components(separatedBy: "\n").map { line in
            guard let marker = line.range(of: "//") else { return line }
            return String(line[..<marker.lowerBound])
        }
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

    enum ScanError: Error { case notFound(String), neverCloses(String) }

    @Test func theLoopAsksForTheDeadlineInsideItsWaitAndNotOnceBeforeIt() throws {
        let body = try Self.body(of: "private func runIdleBeats() async {",
                                 in: try Self.lines(of: "Tuck/MascotView.swift"))

        let call = try #require(body.firstIndex { $0.contains("IdleSchedule.nextDeadline(") })
        let binding = try #require(body.firstIndex { $0.contains("let periodStart") })
        // The slicing loop has to open BETWEEN the binding and the call: that is what makes the
        // recomputation happen mid-sleep instead of once, before anything can have reacted.
        let slicingLoop = try #require(body[(binding + 1)..<call].firstIndex { $0.contains("while") })

        #expect(binding < slicingLoop)
        #expect(slicingLoop < call)
        // The whole change in one assertion. `from: .now` is the complete no-op: the floor can never
        // bind, every test above stays green, and the loop behaves exactly as it did before.
        #expect(body[call].contains("from: periodStart"))
        #expect(!body[call].contains("from: .now"))
        #expect(!body[call].contains("from: Date()"))
        // And the draw is bound once per period, not per slice — otherwise the deadline walks with
        // the clock and no unprompted beat ever falls again.
        let drawBinding = try #require(body.firstIndex { $0.contains("let draw") })
        #expect(drawBinding < slicingLoop)
    }

    @Test func bothReactionsStampTheirMoment() throws {
        let lines = try Self.lines(of: "Tuck/MascotView.swift")
        for member in ["private func handleTap(at location: CGPoint) {", "private func beam() async {"] {
            let assignments = try Self.body(of: member, in: lines)
                .filter { $0.contains("lastReaction = ") }
            #expect(assignments.count == 1, "\(member) stamps lastReaction \(assignments.count) times, 1 expected")
        }
    }
}
