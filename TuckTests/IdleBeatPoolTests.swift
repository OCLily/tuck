import Testing
@testable import Tuck

struct IdleBeatPoolTests {
    private static let all: Set<MascotIdleAnimation> = Set(MascotIdleAnimation.allCases)

    @Test func anUnreachedBeatIsNeverInThePool() {
        let pool = IdleBeat.pool(reduceMotion: false, unlocked: [], excluding: nil)
        #expect(!pool.contains(.stretch))
        #expect(!pool.contains(.yawn))
        #expect(pool.count == 5)
    }

    @Test func eachUnlockAddsItsOwnBeatAndNothingElse() {
        let stretchOnly = IdleBeat.pool(reduceMotion: false, unlocked: [.stretch], excluding: nil)
        #expect(stretchOnly.contains(.stretch))
        #expect(!stretchOnly.contains(.yawn))

        let both = IdleBeat.pool(reduceMotion: false, unlocked: Self.all, excluding: nil)
        #expect(both.count == IdleBeat.allCases.count)
    }

    // This is the selection step alone, not the loop or the @State mirror that feeds it — a real
    // MascotView cannot be driven from a unit test, so what this proves is narrower than the name
    // once implied: the pure pool function itself reaches a newly unlocked beat on the very next
    // call once its set includes it. Whether the live mirror actually delivers that set to the
    // running loop without a cold launch is verified separately (design-system.md), not here.
    @Test func thePoolFunctionReachesANewlyUnlockedBeatOnTheVeryNextCall() {
        var unlocked: Set<MascotIdleAnimation> = []
        var previous: IdleBeat?

        for _ in 0..<20 {
            let pool = IdleBeat.pool(reduceMotion: false, unlocked: unlocked, excluding: previous)
            #expect(!pool.contains(.stretch))
            previous = pool.first
        }

        unlocked = MascotMilestone.idleAnimations(completedMornings: 60)
        let afterUnlock = IdleBeat.pool(reduceMotion: false, unlocked: unlocked, excluding: previous)
        #expect(afterUnlock.contains(.stretch))
    }

    // The two filters are independent: the unlock decides whether a beat exists at all, Reduce
    // Motion decides whether it may move. Stretch is a scale and loses; the yawn is a shape change
    // and stays.
    @Test func reduceMotionStillFiltersABeatThatWasJustUnlocked() {
        let pool = IdleBeat.pool(reduceMotion: true, unlocked: Self.all, excluding: nil)
        #expect(!pool.contains(.stretch))
        #expect(pool.contains(.yawn))
    }

    @Test func theBeatThatJustRanIsExcludedNoMatterHowItGotIntoThePool() {
        let pool = IdleBeat.pool(reduceMotion: false, unlocked: Self.all, excluding: .stretch)
        #expect(!pool.contains(.stretch))
        #expect(pool.contains(.yawn))
    }
}
