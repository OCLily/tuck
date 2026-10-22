import Foundation
import Testing
@testable import Tuck

// MorningCelebrationTests pins the decision; this pins the wiring, because the two came apart once.
// The bloom used to be a statement inside `case .sweep` of the presentation switch, so the one path
// that needs it most never reached it: Reduce Motion on, cold launch, the morning that crosses a
// stage threshold. There the presentation is .flourishOnly and the trim is set straight onto the new
// stage's arc, which at the threshold is empty — a flourish brightening a ring of length zero draws
// nothing. Empty ring, no light, on the morning that earned the most: the exact reading of loss the
// Reduce-Motion rule exists to prevent.
//
// The structural half reads the source through #filePath, the way AppIconAssetTests reads the
// committed icon: the reaction lives in @State that only a rendered view moves, and there is no
// view-inspection dependency in this project. The claim it makes is narrow and is precisely the
// shape the bug had — the bloom may not live inside a branch of the presentation switch.
struct MorningCelebrationWiringTests {
    private func presentCompletedMorningBody() throws -> [String] {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Tuck/GutenMorgenView.swift")
        let lines = try String(contentsOf: source, encoding: .utf8).components(separatedBy: "\n")
        let start = try #require(lines.firstIndex { $0.contains("private func presentCompletedMorning(") })
        let end = try #require(lines[start...].dropFirst().firstIndex { $0 == "    }" })
        return Array(lines[start...end])
    }

    @Test func theStageChangeBloomIsNotOwnedByOneBranchOfThePresentationSwitch() throws {
        let body = try presentCompletedMorningBody()
        let switchStart = try #require(body.firstIndex { $0.contains("switch MorningCelebration.presentation(") })
        let switchEnd = try #require(body[switchStart...].dropFirst().firstIndex { $0 == "        }" })
        let bloom = try #require(body.lastIndex { $0.contains("celebrateStageChange()") })

        #expect(bloom > switchEnd)
        // ...and fired for the crossing itself, not for every counted morning: an ordinary fill has
        // no threshold behind it and a bloom there would be light without a reason.
        #expect(body[switchEnd...].contains { $0.contains(".stageSweep") })
    }

    // The scenario the branch missed, spelled out over the pure decision it is wired to: the ring
    // has nothing left to show on this morning, so the bloom is the whole reaction.
    @Test func aReduceMotionColdLaunchAcrossAThresholdStillGetsItsBloom() {
        let kind = MorningCelebration.kind(acknowledged: 6, completed: 7)
        #expect(kind == .stageSweep)
        #expect(MorningCelebration.presentation(for: kind, reduceMotion: true) == .flourishOnly)
        // Nearly full a moment ago, empty now, and under Reduce Motion it gets there without
        // travelling: whatever the stroke does to a zero-length arc, no one can see it.
        #expect(MorningCelebration.ringOrigin(acknowledged: 6, completed: 7) > 0.8)
        #expect(MascotStage.progressTowardNext(completedMornings: 7) == 0)
    }
}
