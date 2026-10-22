import Testing
@testable import Tuck

// The hard constraint — Verzögerung UND Begründung, nie eine der beiden allein — sits in exactly
// one decision in the app: which phase the override screen opens on when the shield's submenu has
// already supplied the reason. Every test below exists to keep it there.
struct FlowPhaseTests {
    @Test func withoutAPreselectedReasonThePickerComesFirst() {
        #expect(FlowPhase.initial(preselectedReason: nil, allowance: .limited(3)) == .chooseReason)
    }

    @Test func aPreselectedReasonSkipsThePickerAndLandsOnTheTimer() {
        #expect(FlowPhase.initial(preselectedReason: .arbeit, allowance: .limited(1)) == .breathing(.arbeit))
    }

    // The reason chosen in the shield is the one the timer runs for, not a fresh default.
    @Test func thePreselectedReasonIsTheOneCarriedIntoTheTimer() {
        for reason in OverrideReason.allCases {
            #expect(FlowPhase.initial(preselectedReason: reason, allowance: .limited(2)) == .breathing(reason))
        }
    }

    // A spent quota outranks the preselection: .chooseReason is where the screen shows "Für heute
    // aufgebraucht", so this is the exhausted state, not a second picker.
    @Test func anExhaustedQuotaSendsEvenAPreselectedReasonToTheExhaustedState() {
        #expect(FlowPhase.initial(preselectedReason: .notfall, allowance: .limited(0)) == .chooseReason)
    }

    // The regression guard: whatever the shield hands over, the screen may never open already
    // unlocked. .confirmed is only ever reached by the breathing timer running out.
    @Test func thePreselectedPathCanNeverOpenAlreadyConfirmed() {
        let inputs: [OverrideReason?] = OverrideReason.allCases.map { .some($0) } + [nil]
        let allowances: [UnlockAllowance] = (-1...5).map { .limited($0) } + [.unlimited]
        for reason in inputs {
            for allowance in allowances {
                let phase = FlowPhase.initial(preselectedReason: reason, allowance: allowance)
                switch phase {
                case .chooseReason, .breathing:
                    break
                // .reconsider belongs on this side, not next to .breathing above: it is reached only
                // by the timer running out, exactly like .confirmed, and it is the screen that
                // carries the unlock button. Opening on it would hand out the choice without the
                // wait — the same breach, one screen earlier.
                case .reconsider, .confirmed:
                    Issue.record("Verzögerung UND Begründung verletzt: \(String(describing: reason))/\(allowance) startet freigeschaltet")
                }
            }
        }
    }
}
