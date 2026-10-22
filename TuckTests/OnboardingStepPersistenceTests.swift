import Foundation
import Testing
@testable import Tuck

// The step used to live in @State, and two of
// the seven steps hand the screen to a system dialog — FamilyControls at .permission, AlarmKit at
// .wakeTime. The app is in the background while either is up and iOS may terminate it there, so
// the answer came back to a flow that had started over.
struct OnboardingStepPersistenceTests {
    @Test func everyStepSurvivesTheRoundTripThroughItsStoredValue() {
        for step in OnboardingStep.allCases {
            #expect(OnboardingStep.resuming(from: step.rawValue) == step)
        }
    }

    // The stored value comes from outside this build's control — a downgrade, a restored backup, a
    // key some other writer left behind. None of those may cost the screen.
    @Test func anUnknownStoredValueStartsTheFlowOverInsteadOfNowhere() {
        #expect(OnboardingStep.resuming(from: -1) == .welcome)
        #expect(OnboardingStep.resuming(from: OnboardingStep.allCases.count) == .welcome)
        #expect(OnboardingStep.resuming(from: 99) == .welcome)
    }

    // The raw values are the persisted format now, not just an ordering: renumbering them would
    // resume a half-finished flow at the wrong screen for everyone mid-onboarding at update time.
    @Test func theStoredNumbersAreTheOrderTheFlowIsWalkedIn() {
        #expect(OnboardingStep.welcome.rawValue == 0)
        #expect(OnboardingStep.allCases.map(\.rawValue) == Array(0..<OnboardingStep.allCases.count))
        #expect(OnboardingStep.allCases.last == .done)
    }

    // Both dialog steps sit past the first screen, which is the entire reason this is persisted:
    // if they were the first thing shown there would be nothing to lose.
    @Test func bothSystemDialogStepsAreReachedOnlyAfterProgressWorthKeeping() {
        #expect(OnboardingStep.permission.rawValue > OnboardingStep.welcome.rawValue)
        #expect(OnboardingStep.wakeTime.rawValue > OnboardingStep.permission.rawValue)
    }

    // The wiring, the way MorningCelebrationWiringTests reads its own: a @State step would pass
    // every assertion above and still lose the flow, because none of them can see where it is held.
    @Test func theFlowHoldsItsStepInStorageRatherThanInViewState() throws {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Tuck/OnboardingFlowView.swift")
        let lines = try String(contentsOf: source, encoding: .utf8).components(separatedBy: "\n")

        #expect(lines.contains { $0.contains("@AppStorage(\"onboardingStep\")") })
        #expect(!lines.contains { $0.contains("@State private var step") })
        #expect(lines.contains { $0.contains("OnboardingStep.resuming(from: storedStep)") })
    }
}
