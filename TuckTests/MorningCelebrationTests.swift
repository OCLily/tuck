import Testing
import Foundation
@testable import Tuck

struct MorningCelebrationTests {
    // Throwaway suite per test, same shape as MilestoneStoreTests: nothing here may touch the
    // App-Group container the app actually uses.
    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suite = "MorningCelebrationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        body(defaults)
    }

    @Test func anOrdinaryMorningFillsTheRing() {
        #expect(MorningCelebration.kind(acknowledged: 3, completed: 4) == .fill)
        #expect(MorningCelebration.kind(acknowledged: 12, completed: 13) == .fill)
    }

    @Test func aMorningThatCrossesAThresholdSweepsInstead() {
        #expect(MorningCelebration.kind(acknowledged: 6, completed: 7) == .stageSweep)
    }

    // The last stage has nothing ahead to fill toward, so the ring completes rather than draining —
    // the same limit ringSweepsOnStageChange draws, reached through the other path.
    @Test func theLastThresholdCompletesTheRingRatherThanSweepingIt() {
        #expect(MorningCelebration.kind(acknowledged: 29, completed: 30) == .fill)
        #expect(MascotStage.progressTowardNext(completedMornings: 30) == 1)
    }

    // The whole point of hanging the reaction on the morning instead of on the ring: past the last
    // stage the ring is full forever, and those mornings still count.
    @Test func aMorningPastTheLastStageStillCounts() {
        #expect(MorningCelebration.kind(acknowledged: 40, completed: 41) == .fill)
        #expect(MorningCelebration.mascotReacts(to: .fill))
    }

    @Test func nothingHappensWithoutANewMorning() {
        #expect(MorningCelebration.kind(acknowledged: 4, completed: 4) == .none)
        #expect(MorningCelebration.kind(acknowledged: 0, completed: 0) == .none)
        #expect(MorningCelebration.mascotReacts(to: .none) == false)
    }

    // A skipped morning is not an event. A counter that came back lower is not one either — it
    // is neither a reason to celebrate nor a reason to show anything missing.
    @Test func aCounterThatMovesBackwardsShowsNothing() {
        #expect(MorningCelebration.kind(acknowledged: 12, completed: 11) == .none)
        #expect(MorningCelebration.kind(acknowledged: 12, completed: 0) == .none)
    }

    // An install that updates into this build has mornings behind it and no record of what its
    // screen has already shown. Celebrating all of them at once would be a reaction to a morning
    // that did not happen.
    @Test func aStoreThatWasNeverWrittenCelebratesNothing() {
        #expect(MorningCelebration.kind(acknowledged: nil, completed: 0) == .none)
        #expect(MorningCelebration.kind(acknowledged: nil, completed: 40) == .none)
    }

    // The one invariant the ring cannot break: a fill only ever moves forward. Anything that would
    // travel backwards has to be a sweep, which closes the circle before it starts over.
    @Test func aFillNeverTravelsBackwards() {
        for acknowledged in 0...60 {
            for completed in 0...60 {
                guard MorningCelebration.kind(acknowledged: acknowledged, completed: completed) == .fill
                else { continue }
                let origin = MorningCelebration.ringOrigin(acknowledged: acknowledged, completed: completed)
                #expect(origin <= MascotStage.progressTowardNext(completedMornings: completed))
            }
        }
    }

    @Test func theRingStartsWhereTheUserLastSawIt() {
        #expect(MorningCelebration.ringOrigin(acknowledged: 3, completed: 4)
                == MascotStage.progressTowardNext(completedMornings: 3))
        #expect(MorningCelebration.ringOrigin(acknowledged: 6, completed: 7)
                == MascotStage.progressTowardNext(completedMornings: 6))
    }

    @Test func withoutANewMorningTheRingStartsWhereItBelongs() {
        #expect(MorningCelebration.ringOrigin(acknowledged: 4, completed: 4)
                == MascotStage.progressTowardNext(completedMornings: 4))
        #expect(MorningCelebration.ringOrigin(acknowledged: nil, completed: 40)
                == MascotStage.progressTowardNext(completedMornings: 40))
    }

    // Reduce Motion takes the travel, never the statement. Nothing that would have been seen
    // becomes nothing at all.
    @Test func reduceMotionKeepsEveryReactionAndDropsOnlyItsTravel() {
        #expect(MorningCelebration.presentation(for: .fill, reduceMotion: false) == .fill)
        #expect(MorningCelebration.presentation(for: .fill, reduceMotion: true) == .flourishOnly)
        #expect(MorningCelebration.presentation(for: .stageSweep, reduceMotion: false) == .sweep)
        #expect(MorningCelebration.presentation(for: .stageSweep, reduceMotion: true) == .flourishOnly)
    }

    @Test func reduceMotionNeverTurnsAReactionIntoSilence() {
        for kind in [MorningCelebration.Kind.none, .fill, .stageSweep] {
            let quiet = MorningCelebration.presentation(for: kind, reduceMotion: true) == .none
            #expect(quiet == (kind == .none))
            // The mascot's own reaction has no Reduce-Motion gate at all: what it degrades to
            // (warmer cheeks, folded eyes) is a change of shape, pinned inside MascotView.
            #expect(MorningCelebration.mascotReacts(to: kind) == (kind != .none))
        }
    }

    @Test func aFreshStoreHasNothingAcknowledged() {
        withDefaults { defaults in
            #expect(MorningCelebration.acknowledgedMornings(in: defaults) == nil)
        }
    }

    @Test func acknowledgingTheSameMorningTwiceCelebratesItOnce() {
        withDefaults { defaults in
            MorningCelebration.acknowledge(completed: 12, in: defaults)
            #expect(MorningCelebration.kind(acknowledged: MorningCelebration.acknowledgedMornings(in: defaults),
                                            completed: 12) == .none)
            MorningCelebration.acknowledge(completed: 13, in: defaults)
            #expect(MorningCelebration.acknowledgedMornings(in: defaults) == 13)
            #expect(MorningCelebration.kind(acknowledged: MorningCelebration.acknowledgedMornings(in: defaults),
                                            completed: 13) == .none)
        }
    }

    @Test func theAcknowledgementOnlyEverRatchetsUpwards() {
        withDefaults { defaults in
            MorningCelebration.acknowledge(completed: 40, in: defaults)
            MorningCelebration.acknowledge(completed: 3, in: defaults)
            #expect(MorningCelebration.acknowledgedMornings(in: defaults) == 40)
        }
    }

    // Zero is a real acknowledgement, not an absent one: a fresh install acknowledges its zeroth
    // morning on first launch, and the very first completed morning has to be a fill after that.
    @Test func aFreshInstallAcknowledgesZeroAndThenEarnsItsFirstMorning() {
        withDefaults { defaults in
            MorningCelebration.acknowledge(completed: 0, in: defaults)
            #expect(MorningCelebration.acknowledgedMornings(in: defaults) == 0)
            #expect(MorningCelebration.kind(acknowledged: MorningCelebration.acknowledgedMornings(in: defaults),
                                            completed: 1) == .fill)
        }
    }
}
