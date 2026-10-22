import Testing
import Foundation
@testable import Tuck

struct MilestoneStoreTests {
    // Throwaway suite per test, so nothing here can touch the App-Group container the app actually
    // uses. Same shape as MorningProgressStoreTests, including the deferred cleanup.
    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suite = "MilestoneStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        body(defaults)
    }

    // The two calls StopWakeAlarmIntent makes per counted morning: the counter goes up, and the
    // ratchet is latched on the same morning rather than on the next read.
    private func record(mornings: Int, in defaults: UserDefaults) {
        for _ in 0..<mornings {
            MorningProgressStore.recordCompletedMorning(in: defaults)
            MilestoneStore.reachedMornings(in: defaults)
        }
    }

    @Test func aFreshInstallHasNothingButTheOriginalColour() {
        withDefaults { defaults in
            #expect(MilestoneStore.reachedMornings(in: defaults) == 0)
            #expect(MilestoneStore.reachedMilestones(in: defaults).isEmpty)
            #expect(MilestoneStore.unlockedColorVariants(in: defaults) == [.charcoalGreen])
            #expect(MilestoneStore.unlockedIdleAnimations(in: defaults).isEmpty)
            #expect(MilestoneStore.unlockedBadges(in: defaults).isEmpty)
            #expect(MilestoneStore.selectedColorVariant(in: defaults) == .charcoalGreen)
        }
    }

    @Test func theStoreFollowsTheMorningsCounterUpThroughEveryThreshold() {
        withDefaults { defaults in
            for milestone in MascotMilestone.allCases {
                record(mornings: milestone.completedMornings - MorningProgressStore.completedMornings(in: defaults),
                       in: defaults)

                #expect(MilestoneStore.reachedMornings(in: defaults) == milestone.completedMornings)
                #expect(MilestoneStore.reachedMilestones(in: defaults).contains(milestone))
            }
            #expect(MilestoneStore.reachedMilestones(in: defaults).count == MascotMilestone.allCases.count)
        }
    }

    // The whole reason the store keeps a number of its own: a counter that ever comes back
    // partially lower — a lost App-Group write, a bug in the counting path — may not take a reward
    // away that was already handed out. A full App-Group restore stays uncovered: the store's own
    // key travels back with the counter.
    @Test func aCounterThatFallsBackDoesNotTakeAMilestoneAway() {
        withDefaults { defaults in
            record(mornings: 120, in: defaults)
            #expect(MilestoneStore.unlockedColorVariants(in: defaults) == [.charcoalGreen, .dustyBlue, .warmSand])

            defaults.set(3, forKey: "completedMornings")

            #expect(MorningProgressStore.completedMornings(in: defaults) == 3)
            #expect(MilestoneStore.reachedMornings(in: defaults) == 120)
            #expect(MilestoneStore.unlockedColorVariants(in: defaults) == [.charcoalGreen, .dustyBlue, .warmSand])
            #expect(MilestoneStore.unlockedIdleAnimations(in: defaults) == [.stretch])
            #expect(MilestoneStore.unlockedBadges(in: defaults) == [.quarterYear])
        }
    }

    // The ratchet may only hold the line, never freeze it: a counter that recovers keeps counting.
    @Test func aRecoveredCounterKeepsUnlockingBeyondTheHighWaterMark() {
        withDefaults { defaults in
            record(mornings: 90, in: defaults)
            defaults.set(0, forKey: "completedMornings")
            #expect(MilestoneStore.reachedMornings(in: defaults) == 90)

            defaults.set(365, forKey: "completedMornings")

            #expect(MilestoneStore.reachedMornings(in: defaults) == 365)
            #expect(MilestoneStore.unlockedColorVariants(in: defaults).contains(.softLavender))
        }
    }

    // The boundary of the guarantee, written down rather than implied: the mark is set by a read,
    // and the intent performs that read on the morning it counts. A count that nothing ever read
    // holds nothing — which is the harmless half, because a reward nobody looked up was also never
    // shown to anyone.
    @Test func aCountThatWasNeverReadHasNothingToHold() {
        withDefaults { defaults in
            for _ in 0..<45 {
                MorningProgressStore.recordCompletedMorning(in: defaults)
            }
            defaults.set(0, forKey: "completedMornings")

            #expect(MilestoneStore.reachedMornings(in: defaults) == 0)
        }
    }

    @Test func theHighWaterMarkSurvivesANewLookupOnTheSameSuite() {
        let suite = "MilestoneStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        record(mornings: 60, in: defaults)
        defaults.set(0, forKey: "completedMornings")

        let reopened = UserDefaults(suiteName: suite)!
        #expect(MilestoneStore.reachedMornings(in: reopened) == 60)
        #expect(MilestoneStore.unlockedIdleAnimations(in: reopened) == [.stretch])

        defaults.removePersistentDomain(forName: suite)
    }

    @Test func anUnreachedIdleAnimationIsNeverUnlocked() {
        withDefaults { defaults in
            record(mornings: 179, in: defaults)

            #expect(MilestoneStore.unlockedIdleAnimations(in: defaults) == [.stretch])
            #expect(!MilestoneStore.unlockedIdleAnimations(in: defaults).contains(.yawn))
        }
    }

    @Test func aChosenVariantSurvivesAndStaysChosen() {
        withDefaults { defaults in
            record(mornings: 45, in: defaults)
            MilestoneStore.selectColorVariant(.dustyBlue, in: defaults)

            #expect(MilestoneStore.selectedColorVariant(in: defaults) == .dustyBlue)
        }
    }

    // The original is a choice, not a fallback: picking it back is allowed at any count.
    @Test func theOriginalCanAlwaysBeChosenBack() {
        withDefaults { defaults in
            record(mornings: 365, in: defaults)
            MilestoneStore.selectColorVariant(.softLavender, in: defaults)
            MilestoneStore.selectColorVariant(.charcoalGreen, in: defaults)

            #expect(MilestoneStore.selectedColorVariant(in: defaults) == .charcoalGreen)
        }
    }

    @Test func aLockedVariantCannotBeChosen() {
        withDefaults { defaults in
            record(mornings: 44, in: defaults)
            MilestoneStore.selectColorVariant(.dustyBlue, in: defaults)

            #expect(MilestoneStore.selectedColorVariant(in: defaults) == .charcoalGreen)
        }
    }

    // A name written by a later build, or by another process on the shared container, is not a
    // choice this build can honour — it falls back to the original the same way an empty key does.
    @Test func anUnknownStoredNameFallsBackToTheOriginal() {
        withDefaults { defaults in
            defaults.set("neonPink", forKey: "mascotColorVariant")

            #expect(MilestoneStore.selectedColorVariant(in: defaults) == .charcoalGreen)
        }
    }

    // Same for a variant this build knows but the schedule has not handed out — the read side
    // re-checks rather than trusting whatever is in the container.
    @Test func aStoredButLockedNameFallsBackToTheOriginal() {
        withDefaults { defaults in
            defaults.set(MascotColorVariant.softLavender.rawValue, forKey: "mascotColorVariant")

            #expect(MilestoneStore.selectedColorVariant(in: defaults) == .charcoalGreen)
        }
    }

    @Test func everyReachedMilestoneIsUncelebratedUntilItIsRecorded() {
        withDefaults { defaults in
            record(mornings: 90, in: defaults)
            #expect(MilestoneStore.uncelebratedMilestones(in: defaults)
                == [.dustyBlue, .stretch, .quarterYearBadge])

            for milestone in MilestoneStore.uncelebratedMilestones(in: defaults) {
                MilestoneStore.recordCelebration(of: milestone, in: defaults)
            }

            #expect(MilestoneStore.uncelebratedMilestones(in: defaults).isEmpty)
        }
    }

    @Test func recordingTheSameCelebrationTwiceChangesNothing() {
        withDefaults { defaults in
            record(mornings: 45, in: defaults)
            MilestoneStore.recordCelebration(of: .dustyBlue, in: defaults)
            MilestoneStore.recordCelebration(of: .dustyBlue, in: defaults)

            #expect(MilestoneStore.uncelebratedMilestones(in: defaults).isEmpty)
        }
    }

    // The celebration flag is its own piece of state and touches nothing: a celebrated milestone is
    // still reached, and its reward is still unlocked.
    @Test func celebratingAMilestoneLeavesEveryUnlockWhereItIs() {
        withDefaults { defaults in
            record(mornings: 60, in: defaults)
            MilestoneStore.recordCelebration(of: .stretch, in: defaults)

            #expect(MilestoneStore.reachedMilestones(in: defaults) == [.dustyBlue, .stretch])
            #expect(MilestoneStore.unlockedIdleAnimations(in: defaults) == [.stretch])
            #expect(MilestoneStore.unlockedColorVariants(in: defaults) == [.charcoalGreen, .dustyBlue])
        }
    }

    @Test func aLaterMilestoneIsStillUncelebratedAfterTheEarlierOnesWere() {
        withDefaults { defaults in
            record(mornings: 60, in: defaults)
            MilestoneStore.recordCelebration(of: .dustyBlue, in: defaults)
            MilestoneStore.recordCelebration(of: .stretch, in: defaults)

            record(mornings: 30, in: defaults)

            #expect(MilestoneStore.uncelebratedMilestones(in: defaults) == [.quarterYearBadge])
        }
    }
}
