import FamilyControls
import Testing
@testable import Tuck

// The branch order of the permission section, as a pure function so it can be checked without the
// authorization the Simulator never grants. The defect it pins: a denial is reported twice — thrown
// out of requestIndividual and again as the status — and the error branch used to come first, so
// the retry button replaced the only sentence that says how to come back.
struct FamilyControlsAccessStateTests {
    @Test func aDeniedStatusOutranksTheErrorItThrewOnTheWayThere() {
        let state = FamilyControlsAccessState.resolve(status: .denied, error: "The operation couldn’t be completed.")

        #expect(state == .denied)
    }

    @Test func aFailureIsOnlyVisibleWhileTheStatusItselfSaysNothing() {
        #expect(FamilyControlsAccessState.resolve(status: .notDetermined, error: "kein Zugriff") == .failed("kein Zugriff"))
        #expect(FamilyControlsAccessState.resolve(status: .notDetermined, error: nil) == .notDetermined)
    }

    // Success clears the error in the same turn, but a stale one must not survive it either.
    @Test func anApprovedStatusIsNeverOverwrittenByAnEarlierFailure() {
        #expect(FamilyControlsAccessState.resolve(status: .approved, error: "kein Zugriff") == .approved)
        #expect(FamilyControlsAccessState.resolve(status: .approved, error: nil) == .approved)
    }
}
