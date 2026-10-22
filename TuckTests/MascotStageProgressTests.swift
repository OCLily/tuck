import Testing
@testable import Tuck

struct MascotStageProgressTests {
    @Test func progressRisesWithinAStageAndResetsAtEachThreshold() {
        #expect(MascotStage.progressTowardNext(completedMornings: 0) == 0)
        #expect(MascotStage.progressTowardNext(completedMornings: 3) == 3.0 / 7.0)
        #expect(MascotStage.progressTowardNext(completedMornings: 7) == 0)
        #expect(MascotStage.progressTowardNext(completedMornings: 29) == 22.0 / 23.0)
        #expect(MascotStage.progressTowardNext(completedMornings: 30) == 1)
        #expect(MascotStage.progressTowardNext(completedMornings: 100) == 1)
    }

    @Test func ringSweepsOnlyForwardAndOnlyWhileAnotherStageIsAhead() {
        #expect(MascotStage.ringSweepsOnStageChange(from: .start, to: .warmGeworden))
        #expect(MascotStage.ringSweepsOnStageChange(from: .start, to: .eingespielt) == false)
        #expect(MascotStage.ringSweepsOnStageChange(from: .warmGeworden, to: .eingespielt) == false)
        #expect(MascotStage.ringSweepsOnStageChange(from: .eingespielt, to: .start) == false)
        #expect(MascotStage.ringSweepsOnStageChange(from: .start, to: .start) == false)
    }

    @Test func progressNeverLeavesTheUnitRange() {
        for mornings in -5...60 {
            let progress = MascotStage.progressTowardNext(completedMornings: mornings)
            #expect(progress >= 0)
            #expect(progress <= 1)
        }
    }
}
