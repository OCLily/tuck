import Testing
import Foundation
@testable import Tuck

// The never-punish rule for the stage rig. MilestoneStore has held a high-water mark since the milestones shipped, and
// MascotStage.ringSweepsOnStageChange guards the ring against going backwards — but the stage itself
// was read straight off MorningProgressStore's live count on three screens. A counter that comes
// back partially lower (a lost App-Group write, a bug in the counting path, a foreign writer on the
// shared container: the case MilestoneStore was built against) therefore faded the saturation down
// over 6 s while the animal shrank and dropped a leaf. A full App-Group restore is NOT covered —
// there `milestoneReachedMornings` travels back with `completedMornings` and the ratchet has nothing
// higher to hold on to.
//
// Two halves, because neither is the whole statement:
//   - the table itself only ever climbs, so "a later stage" and "more of everything" are one fact;
//   - no screen feeds that table from the live counter.
struct MascotStageMonotonicityTests {
    // The channels that carry growth. Injectivity of a single one was already checked in places
    // (MascotMilestoneTests pins sproutStage's); what was missing is all of them pinned against the
    // SAME ordering, so a new stage cannot be added with, say, a lower cheekOpacity than its
    // predecessor and still look correct one channel at a time.
    @Test func everyNumericChannelClimbsStrictlyWithTheStage() {
        let climbing: [(String, (MascotStage) -> Double)] = [
            ("saturation", \.saturation),
            ("scale", \.scale),
            ("cheekOpacity", \.cheekOpacity),
            ("completedMornings", { Double($0.completedMornings) })
        ]

        for (name, channel) in climbing {
            let values = MascotStage.allCases.map(channel)
            for (earlier, later) in zip(values, values.dropFirst()) {
                #expect(earlier < later,
                        "MascotStage.\(name) does not grow from stage to stage: \(values)")
            }
        }
    }

    // Not a number, so not in the table above, and not symmetrical either: the eyes open once and
    // stay open. `true -> false` is the shape this forbids.
    @Test func theEyesNeverCloseAgainOnceAStageHasOpenedThem() {
        let states = MascotStage.allCases.map(\.eyesOpen)
        for (earlier, later) in zip(states, states.dropFirst()) {
            #expect(!(earlier && !later),
                    "MascotStage.eyesOpen closes again on a later stage: \(states)")
        }
    }

    // Distinct AND ordered. Distinctness alone would pass a stage table that grows two leaves before
    // one; ordering alone would pass three stages sharing one form.
    @Test func theSproutGrowsForwardThroughItsOwnFormsWithoutRepeating() {
        let forms = MascotStage.allCases.map(\.sproutStage)
        let positions = forms.compactMap { SproutStage.allCases.firstIndex(of: $0) }

        #expect(positions.count == forms.count)
        #expect(Set(positions).count == positions.count,
                "two stages draw the same sprout: \(forms)")
        #expect(positions == positions.sorted(),
                "the sprout does not grow forward through the stages: \(forms)")
    }
}

// The control group. A behavioural test cannot be red here: the ratchet this needs has existed in
// MilestoneStore all along, the bug was that three screens did not use it — and there is no view
// inspection layer in this project to assert what a screen read. So the call sites are pinned in
// source, the same answer SproutSourceTests and MascotStageExpressionBoundaryTests give to the same
// problem, and this file compiles unchanged against the pre-fix code.
struct MascotStageRatchetSourceTests {
    // The three screens that derive a stage, its ring, its saturation or its spoken progress from a
    // stored count — the fixed list is only for the "replaced, not deleted" direction below. The
    // forbidding scan runs over all of Tuck/ instead, because a fourth screen that starts reading the
    // live counter is exactly the regression this file exists to catch.
    private static let stageScreens = [
        "Tuck/GutenMorgenView.swift",
        "Tuck/OverrideFlowView.swift",
        "Tuck/SettingsView.swift"
    ]

    // Excluded by name rather than by glob-with-holes, the same reason LayoutContainmentTests gives:
    // a scan that has to be extended to see new code is a scan that will not see it.
    private static let notScanned: Set<String> = [
        "ContentView.swift"  // developer debug readout of the raw counter, deliberately unratcheted
    ]

    private static var repository: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static func source(_ relativePath: String) throws -> [String] {
        let text = try String(contentsOf: repository.appendingPathComponent(relativePath), encoding: .utf8)
        return text.components(separatedBy: "\n")
    }

    static func scannedFiles() throws -> [String] {
        let directory = repository.appendingPathComponent("Tuck")
        return try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasSuffix(".swift") && !notScanned.contains($0) }
            .sorted()
            .map { "Tuck/\($0)" }
    }

    // Comment bodies are cut before anything is scanned, the same way LayoutContainmentTests does it:
    // several of these files explain in prose which read they replaced, and a comment naming the
    // forbidden call must not read as a violation of it. A whole-line prefix check would have missed
    // a block comment and a comment trailing live code.
    static func withoutComments(_ line: String) -> String {
        guard let marker = line.range(of: "//") else { return line }
        return String(line[..<marker.lowerBound])
    }

    // The red one. Before the fix each of the three screens opened with
    // `@State private var completedMornings = MorningProgressStore.completedMornings()`.
    @Test func noScreenDerivesTheStageFromTheLiveCounter() throws {
        for screen in try Self.scannedFiles() {
            let offenders = try Self.source(screen).enumerated().filter {
                Self.withoutComments($0.element).contains("MorningProgressStore.completedMornings(")
            }
            #expect(offenders.isEmpty,
                    "\(screen) reads the live morning counter instead of MilestoneStore's high-water mark; every stage channel on that screen would fade, shrink and drop a leaf if the counter ever came back lower. Lines: \(offenders.map { $0.offset + 1 })")
        }
    }

    // Gone is not the same as replaced: deleting the read outright would satisfy the test above and
    // leave the screen showing stage zero forever.
    @Test func everyScreenReadsTheRatchetInstead() throws {
        for screen in Self.stageScreens {
            let lines = try Self.source(screen)
            #expect(lines.contains { Self.withoutComments($0).contains("MilestoneStore.reachedMornings(") },
                    "\(screen) does not read MilestoneStore's ratchet anywhere")
        }
    }
}

// What the source scan above buys, stated as behaviour on the store side: 30 mornings, a counter
// that falls back to 6, and the stage plus BOTH derivations that are spoken next to it stay where
// they were. Without the fix the screens computed these three from 6 and showed "6 von 7 Morgen,
// Stufe Start" over a sprout that had just lost a leaf.
struct MascotStageRatchetBehaviourTests {
    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suite = "MascotStageRatchetTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        body(defaults)
    }

    @Test func aCounterThatFallsBackKeepsTheStageAndTheWordsNextToIt() {
        withDefaults { defaults in
            for _ in 0..<30 {
                MorningProgressStore.recordCompletedMorning(in: defaults)
                MilestoneStore.reachedMornings(in: defaults)
            }
            #expect(MascotStage.stage(forCompletedMornings: MilestoneStore.reachedMornings(in: defaults)) == .eingespielt)

            // The fall-back itself: the App Group comes back holding six mornings.
            defaults.set(6, forKey: "completedMornings")
            #expect(MorningProgressStore.completedMornings(in: defaults) == 6)
            #expect(MascotStage.stage(forCompletedMornings: 6) == .start)

            let reached = MilestoneStore.reachedMornings(in: defaults)
            #expect(reached == 30)
            #expect(MascotStage.stage(forCompletedMornings: reached) == .eingespielt)
            // The half that a stage-only guard would have missed: the ring and the VoiceOver line
            // have to stand on the same number as the animal, or the screen contradicts itself.
            #expect(MascotStage.progressTowardNext(completedMornings: reached) == 1)
            #expect(MascotStage.progressDescription(completedMornings: reached).contains("30"))
        }
    }
}
