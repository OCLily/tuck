import Foundation

// WHICH AXES A TOUCH MOVES, as a pure function over the three things that decide it — and the third
// one is the finding. The obvious cut is `axes(for:reduceMotion:)`, and it describes a reality that
// only exists from morning seven onwards: `MascotView.eyeState` goes hard to `.closed` whenever
// `stage.eyesOpen` is false, and `MascotStage.start.eyesOpen` IS false. Stage `.start` is the first
// seven mornings AND all three MascotView instances in OnboardingFlowView. Without `eyesOpen` this
// function would say a blink answers a touch in exactly the place where it draws nothing.
//
// THE STILL-FACE INVARIANT, which is what this exists to hold: visibly present and not answering is
// a worse state than absent. Every one of the sixteen cells — four tap indices × Reduce Motion ×
// eyes open — has to move something.
//
// AND IT MAY NOT ESCALATE. `handleTap` is built descending (1.06 / 1.04 / no scale at all / 1.02),
// which is the opposite of an escalation pattern and the only mechanism that keeps a more responsive
// mascot from raising screen time — the exact opposite of what this app is for. It stood nowhere as
// a rule. It does now, per channel.
//
// Same cut as MorningCelebration.presentation(for:reduceMotion:): a pure function, answerable
// without a rendered view. Foundation only, app-target-local.
enum MascotTapReaction {
    enum Axis: CaseIterable {
        case scale, lean, gaze, earTwitch, earFlare, headTilt, squint, blink, cheeks, mouth
    }

    /// Every transform of this rig is pinned under Reduce Motion (`tapScale`, `tapLean`, `headTilt`,
    /// `earFlare`, `earTwist`, `appliedGaze`). What is left over is what actually answers.
    ///
    /// "Every eye axis is invisible while the lid is closed" stood here until the fold arrived, and
    /// it was true of `.blink` and false of the rig: the closed lid is not an absence, it is a
    /// 12 x 3 capsule of ink, and a capsule can become an arc. `.squint` is that arc — existing
    /// vocabulary, existing geometry, no transform — so the closed-eye side answers with a fold
    /// where the open-eye side answers with a blink.
    static func axes(for index: Int, reduceMotion: Bool, eyesOpen: Bool) -> Set<Axis> {
        var axes: Set<Axis> = []
        if !reduceMotion { axes.insert(.lean) }

        switch index {
        case 0:
            if !reduceMotion {
                axes.insert(.scale)
                axes.insert(.earFlare)
            }
            // No longer conditional on `eyesOpen`: the fold draws at every stage since `eyeState`
            // stopped letting a stage's closed lid outrank it. It was requested here all along and
            // drew nothing at stage `.start` — the same shape of defect the third parameter was
            // introduced for, on the axis that could actually be fixed rather than gated away.
            axes.insert(.squint)
            // The one index that writes `cheekOpacity` absolutely (0.75) rather than adding to it.
            axes.insert(.cheeks)
        case 1:
            if !reduceMotion {
                axes.insert(.scale)
                axes.insert(.gaze)
                axes.insert(.earTwitch)
            }
            // MECHANICALLY ANSWERED, PERCEPTUALLY NOT — and this line is the difference. Under
            // Reduce Motion this index kept exactly one channel, the cheeks, and a rendered screenshot
            // measured what that channel is worth at stage `.eingespielt` in light appearance: a
            // peak delta of 5 of 255 against resting cheeks, which is below the threshold at which
            // anything is seen. The still-face invariant held on paper and broke on screen.
            //
            // No new vocabulary and no new number: `.blink` is the axis indices 2 and 3 already
            // answer with, unchanged, on one more cell. `eyesOpen` for the reason the whole third
            // parameter exists — at stage `.start` the lid is already down and a blink draws
            // nothing there.
            //
            // AND THE OTHER SIDE OF THAT `else`, which the blink could not reach. At stage `.start`
            // — the first seven mornings and all three MascotView instances in OnboardingFlowView —
            // indices 1 to 3 kept the cheeks alone under Reduce Motion, measured at 6 / 5 / 4 of
            // 255 against resting cheeks with not a single pixel over 10. The fold is the same
            // answer one shape further: the closed line curves. Measured the same way, peak 127 of
            // 255 over 974 pixels at scale 4.
            axes.insert(eyesOpen ? .blink : .squint)
        case 2:
            if !reduceMotion { axes.insert(.headTilt) }
            axes.insert(eyesOpen ? .blink : .squint)
        default:
            if !reduceMotion { axes.insert(.scale) }
            axes.insert(eyesOpen ? .blink : .squint)
        }

        if index > 0, let boost = cheekBoost(for: index), boost > 0 { axes.insert(.cheeks) }
        return axes
    }

    /// `nil` where no `tapScale` is written at all — index 2 only tilts the head. Deliberately not
    /// 1.0: an invented resting value would enter the monotonicity sequence and quietly falsify it
    /// (1.06 / 1.04 / 1.00 / 1.02 reads as a RISE from 2 to 3, which the code does not do).
    static func scale(for index: Int) -> Double? {
        switch index {
        case 0: 1.06
        case 1: 1.04
        case 2: nil
        default: 1.02
        }
    }

    /// The ADDITIVE boost on `MascotExpression.cheekBoost`, not the effective opacity. The effective
    /// value is stage-dependent (`MascotStage.cheekOpacity` is 0.35 / 0.50 / 0.62), so a function
    /// without a stage parameter cannot express it. The boost it can: `MascotPose.cheek` draws
    /// `min(cheekOpacity + expression.cheekBoost, 1)`, so the same boost shifts every stage by the
    /// same amount — a non-increasing boost sequence is a non-increasing opacity in every stage.
    ///
    /// `nil` for index 0 for the same reason `scale` is nil for index 2: index 0 is the absolute
    /// starting value (0.75) and not a link in the additive chain, and what does not exist is not
    /// invented as a zero.
    ///
    /// The window is narrow and the numbers respect it rather than ignore it: index 0 writes 0.75
    /// absolutely, `MascotStage.eingespielt.cheekOpacity` is already 0.62, so the whole headroom
    /// below index 0 is 0.13 in the tightest stage. 0.12 / 0.08 / 0.05 uses it and keeps the descent
    /// in every stage. Whether three steps inside 0.13 are three DISTINGUISHABLE steps is the one
    /// open design number here and has to be judged on screenshots; the channel and the
    /// rule are decided, the size is measured.
    static func cheekBoost(for index: Int) -> Double? {
        switch index {
        case 0: nil
        case 1: 0.12
        case 2: 0.08
        default: 0.05
        }
    }
}
