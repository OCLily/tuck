import ManagedSettings
import SwiftUI

extension OverrideContext {
    // Whether this app's own bookkeeping says a block was up: a window whose registration went
    // through and that contains `now`. Both halves are the reconciler's, not a second opinion —
    // `blockRegistrationSucceeded` is what it arms and disarms on, `contains` is what
    // applyPendingMorningDuration asks before it touches a running window.
    //
    // It is the window, never the shield. A shield that outlives its interval is exactly what this
    // button is the only way out of (the manual open from the block screen lands here), so a
    // "no shield is up" reading would be false in the one case that matters. What the answer is
    // allowed to decide is therefore only whether anything gets charged.
    func shieldIsStanding(
        now: Date = .now,
        calendar: Calendar = .current,
        in defaults: UserDefaults = UserDefaults(suiteName: TuckIdentifiers.appGroupSuiteName) ?? .standard
    ) -> Bool {
        switch self {
        case .morning:
            guard let alarm = WakeAlarmStore.scheduledAlarm(in: defaults),
                  WakeAlarmStore.blockRegistrationSucceeded(in: defaults)
            else { return false }
            return MorningBlockWindow(start: alarm.blockWindowStart, end: alarm.blockWindowEnd)
                .contains(now, calendar: calendar)
        case .bedtime:
            guard let bedtime = BedtimeStore.bedtime(in: defaults),
                  BedtimeStore.blockRegistrationSucceeded(in: defaults)
            else { return false }
            return MorningBlockWindow(start: bedtime.blockWindowStart, end: bedtime.blockWindowEnd)
                .contains(now, calendar: calendar)
        }
    }

    // Spending the unlock is not what lifts the shield: the two other places that ever clear one are
    // BlockWindowMonitor.cancel and the Monitor extension's intervalDidEnd, and neither is
    // on this path — without this call the quota is spent on a screen reporting an override while
    // the block stays up. Whether it actually comes down is not readable back: the ManagedSettings
    // write is non-throwing and silent (Shared/ShieldRelease.swift), so this is the attempt,
    // never evidence. There is no re-lock timer — the quota is the rate limit, and the shield returns
    // with the window's own next interval.
    //
    // The charge is conditional, the clear never is. Outside every
    // registered window the 30 seconds and the reason still run — that friction is the product, not
    // the counter — but there is no block to buy off, so nothing is spent; and the clear still goes
    // out, because a stale shield is the reason somebody would tap here at that hour.
    // Returns whether the quota moved, which is the only thing the screen after this may report.
    func unlock(
        now: Date = .now,
        calendar: Calendar = .current,
        in defaults: UserDefaults = UserDefaults(suiteName: TuckIdentifiers.appGroupSuiteName) ?? .standard,
        clearingShieldWith clearShield: (ManagedSettingsStore.Name) -> Void = ShieldRelease.clear
    ) -> Bool {
        let shieldStood = shieldIsStanding(now: now, calendar: calendar, in: defaults)
        if shieldStood {
            quota.consumeUnlock(now: now, calendar: calendar, in: defaults)
        }
        clearShield(shieldStoreName)
        return shieldStood
    }
}

// What the booking of an unlock leaves behind, as one value. Both halves used to be written side by
// side inside the breathing task; since the reconsider step there is a second call site, and two
// hand-written pairs are how one of them silently loses the allowance refresh that `confirmed(for:)`
// reads back.
struct UnlockBooking: Equatable {
    let spentUnlock: Bool
    let allowance: UnlockAllowance
}

extension OverrideContext {
    func bookUnlock(
        now: Date = .now,
        calendar: Calendar = .current,
        in defaults: UserDefaults = UserDefaults(suiteName: TuckIdentifiers.appGroupSuiteName) ?? .standard,
        clearingShieldWith clearShield: (ManagedSettingsStore.Name) -> Void = ShieldRelease.clear
    ) -> UnlockBooking {
        let spent = unlock(now: now, calendar: calendar, in: defaults, clearingShieldWith: clearShield)
        return UnlockBooking(
            spentUnlock: spent,
            allowance: quota.allowance(now: now, calendar: calendar, in: defaults)
        )
    }
}

extension OverrideContext {
    // The other Plus boundary, and the only one a user who never opens the bedtime screen can reach:
    // the daily unlock ceiling. Asked once, when the override flow opens, and it starts the trial
    // only where the answer is "no" — an override with a slot left is not a refusal and has no
    // argument to make.
    //
    // The allowance is read again afterwards on purpose rather than assumed to be .unlimited: what a
    // started trial means for the ceiling is UnlockQuotaStore's answer, not this function's guess,
    // and an existing entitlement or an already-expired trial makes it the same exhausted value it
    // was. Deliberately not on the plain `allowance` read: the shield's configuration extension calls
    // that on every block screen it draws, and a system process may not start anybody's fourteen days.
    func allowanceReachingTheCeiling(
        now: Date = .now,
        calendar: Calendar = .current,
        in defaults: UserDefaults = UserDefaults(suiteName: TuckIdentifiers.appGroupSuiteName) ?? .standard
    ) -> UnlockAllowance {
        let allowance = quota.allowance(now: now, calendar: calendar, in: defaults)
        guard allowance.isExhausted else { return allowance }
        TrialTrigger.plusBoundaryReached(now: now, in: defaults)
        return quota.allowance(now: now, calendar: calendar, in: defaults)
    }
}

enum FlowPhase: Equatable {
    case chooseReason
    case breathing(OverrideReason)
    case reconsider(OverrideReason)
    case confirmed(OverrideReason)

    // The one line that carries the shield handover: a reason picked in the submenu skips the picker and
    // nothing else. `.confirmed` is unreachable from here by construction — reaching it means the
    // shield handed out an unlock without the timer, which is the half of "Verzögerung UND
    // Begründung" that no submenu can give. Extracted out of the view so that stays testable.
    static func initial(preselectedReason: OverrideReason?, allowance: UnlockAllowance) -> FlowPhase {
        guard let preselectedReason, !allowance.isExhausted else { return .chooseReason }
        return .breathing(preselectedReason)
    }

    // The second decision worth keeping out of the view: what the timer running out leads to. It is
    // the same phase for all three reasons, and that uniformity is the point rather than an
    // implementation detail — an exception for "Notfall" would be the first mechanical advantage any
    // reason ever had, i.e. a standing invitation to always pick that one. The unlock is not booked
    // here; it is booked by the button on the screen this returns.
    static func afterBreathing(reason: OverrideReason) -> FlowPhase {
        .reconsider(reason)
    }
}

private let breathingDurationSeconds = 30

// The same 11.0 s cycle as MascotView's BreathPhase, phase for phase — one house rhythm
// (docs/design/design-system.md). It does not divide into the 30 s above and is not meant to: the
// wait is product mechanics, the breath is presentation and simply gets cut off mid-cycle.
// Internal rather than private, for the reason IdleBeat is: MascotRigFitTests computes
// whether the pose fits inside this circle, and it has to read the diameter the drawing actually
// uses rather than a second copy of it.
enum OverrideBreathPhase: CaseIterable {
    case inhale, hold, exhale, rest

    // Kept at this screen's own amplitude instead of the mascot's ±3.5 % body scale: here the
    // expansion is the instruction, not an ambient sign of life. The Reduce-Motion midpoint
    // (145) and the design system's size table both hang on this pair staying 180/110.
    var diameter: Double {
        switch self {
        case .inhale, .hold: 180
        case .exhale, .rest: 110
        }
    }

    // The animal's own half of the breath. It is a frame size, so it is a change of shape and not a
    // transform — which is why it keeps moving under Reduce Motion while the circle around it is
    // pinned (the design system's second Reduce-Motion pattern, the same verdict as for blink and cheeks).
    var mouthOpenness: Double {
        switch self {
        case .inhale, .hold: 1
        case .exhale, .rest: 0
        }
    }

    var label: String {
        switch self {
        case .inhale, .hold: String(localized: "Einatmen …")
        case .exhale, .rest: String(localized: "Ausatmen …")
        }
    }

    var animation: Animation {
        switch self {
        case .inhale: .easeOut(duration: Motion.breathIn)
        case .hold: .linear(duration: Motion.breathHold)
        case .exhale: .easeInOut(duration: Motion.breathOut)
        case .rest: .linear(duration: Motion.breathStill)
        }
    }
}

struct OverrideFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let context: OverrideContext
    private let preselectedReason: OverrideReason?

    @State private var allowance: UnlockAllowance
    @State private var phase: FlowPhase
    @State private var secondsLeft = breathingDurationSeconds
    @State private var spentUnlock = false
    @State private var showPaywall = false
    @State private var trialNotice: TrialNotice?
    // This screen drew no animal at all at first and therefore read no progress. A fixed
    // stage would have been the documented anti-pattern — "eine falsche Stufe wäre schlimmer als
    // keine" — so the two surfaces below read the same two stores GutenMorgenView and
    // SettingsView read. Once, like every other read on this flow: nothing reachable from here
    // completes a morning or unlocks a variant.
    // The ratchet, not the live count, for the same reason GutenMorgenView reads it: a stage that
    // fell back would be a wrong stage, and a wrong stage is worse than none.
    @State private var reachedMornings = MilestoneStore.reachedMornings()
    @State private var colorVariant = MilestoneStore.selectedColorVariant()

    // Reads, never writes: `allowanceReachingTheCeiling` starts the fourteen days, and SwiftUI
    // re-evaluates an initialiser's expressions on every re-evaluation of the parent — a side effect
    // sitting here runs at times nobody chose. The plain read is the honest state before the
    // boundary is answered; the answer arrives one frame later, from the .task below.
    init(context: OverrideContext = .morning, preselectedReason: OverrideReason? = nil) {
        self.context = context
        self.preselectedReason = preselectedReason
        let allowance = context.quota.allowance()
        _allowance = State(initialValue: allowance)
        _phase = State(
            initialValue: .initial(preselectedReason: preselectedReason, allowance: allowance)
        )
    }

    var body: some View {
        ZStack {
            Color.tuckCream.ignoresSafeArea()

            VStack {
                content
            }
            .padding()
            // At accessibility text sizes the reason picker lost its question, its quota line
            // and its closing sentence to an ellipsis. Scrolling is also the only thing that keeps
            // the three reason buttons reachable once they wrap to two lines each.
            .scrollableWhenTallerThanScreen()
        }
        // The second of the two Plus boundaries, asked once per appearance instead of once per
        // initialiser evaluation. The write behind it is idempotent, so what moves here is not
        // correctness of the trial's start date but who decides when the question is asked.
        //
        // The phase is recomputed from the same function the initialiser used rather than nudged by
        // hand: a trial that opens here turns an exhausted screen into the reason picker, and that
        // transition is `FlowPhase.initial`'s job in both places. Only `.chooseReason` is
        // rewritten — anything further along is a phase the user moved into.
        .task {
            adopt(context.allowanceReachingTheCeiling())
            // After the boundary question, never before it: this is the screen that can start the
            // fourteen days, and the confirmation of a start has to come from a store that has
            // already been written. Consumed rather than read, so it appears exactly once.
            trialNotice = TrialNotice.consume()
        }
        // Buying from inside the refusal has to lift it without a relaunch, the same re-read
        // BedtimeSetupView and SettingsView run when their paywall closes. The plain read, never the
        // ceiling question: closing a paywall is not a boundary being reached a second time.
        .sheet(isPresented: $showPaywall, onDismiss: { adopt(context.quota.allowance()) }) {
            PaywallView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var stage: MascotStage {
        MascotStage.stage(forCompletedMornings: reachedMornings)
    }

    // One place for "the allowance turned out to be something else than this screen opened with",
    // because there are two ways for that to happen and they were one hand-written pair apart from
    // drifting: the trial opening under the .task, and a purchase closing the paywall. Only
    // `.chooseReason` is rewritten — anything further along is a phase the user moved into
    // themselves, and no allowance may throw them out of it.
    private func adopt(_ answered: UnlockAllowance) {
        guard answered != allowance else { return }
        allowance = answered
        guard phase == .chooseReason else { return }
        phase = .initial(preselectedReason: preselectedReason, allowance: answered)
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .chooseReason:
            // The trial line rides on the entry phase alone. Neither the 30 seconds nor the
            // reconsider screen may carry it: those two are the ritual, and a sentence about a
            // subscription arriving in the middle of them is the interruption they exist without.
            VStack(spacing: Layout.container) {
                if let trialNotice {
                    TrialNoticeBanner(notice: trialNotice)
                }
                if !allowance.isExhausted {
                    reasonPicker
                } else {
                    exhausted
                }
            }
        case .breathing(let reason):
            breathing(for: reason)
        case .reconsider(let reason):
            reconsider(for: reason)
        case .confirmed(let reason):
            confirmed(for: reason)
        }
    }

    private var reasonPicker: some View {
        VStack(spacing: Layout.section) {
            Spacer()
            Text("Warum möchtest du entsperren?")
                .font(.title3.weight(.semibold))
                .fontDesign(.rounded)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.tuckCharcoalGreen)

            // Charcoal-green cannot reach AA's 4.5:1 for small text on cream at any alpha, so this
            // line sits in the large-text category — >=14 pt at weight 700, where the bar is 3:1.
            // It keeps that where the prose of this file moved to `tuckInk` at weight 400:
            // a remaining count is a value, not an explanation, and it belongs at the rank of the
            // numbers elsewhere in the app rather than at the rank of the sentence below the buttons.
            // Hierarchy runs down the 20 > 17 > 15 size ladder, never down alpha, which would come
            // straight out of the contrast that is already at its ceiling. No line at all where
            // there is no ceiling: printing "unbegrenzt" would put a count on a screen whose whole
            // point is that the friction is the wait, not the number.
            if let remaining = allowance.remainingCount {
                Text("\(remaining) von \(context.quota.freeUnlockMaximum) heute übrig")
                    .font(.subheadline.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(Color.tuckCharcoalGreen)
            }

            VStack(spacing: Layout.choiceStack) {
                ForEach(OverrideReason.allCases) { reason in
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: Motion.stepOverride)) {
                            phase = .breathing(reason)
                        }
                    } label: {
                        HStack {
                            Image(systemName: reason.icon)
                                .accessibilityHidden(true)
                            // The label is the whole button; at accessibility text sizes the icon
                            // takes enough of the row that "Something else" was cut to "Somethi…".
                            Text(reason.displayName)
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .font(.body.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(Color.tuckCharcoalGreen)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: Layout.radiusPlate).fill(Color.tuckSage.opacity(0.5)))
                    }
                }
            }
            Spacer()
            Text("Freischalten braucht trotzdem einen Moment — das ist Absicht, nicht Bremse.")
                .font(.subheadline.weight(.regular))
                .fontDesign(.rounded)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.tuckInk)
        }
    }

    private var exhausted: some View {
        VStack(spacing: Layout.container) {
            Spacer()
            // Charcoal, because this glyph exists only in the exhausted branch — it reports
            // a state, and charcoal is the palette's meaning colour. Sage is for the glyphs that
            // stay the same whatever the screen is showing.
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.tuckCharcoalGreen)
                .accessibilityHidden(true)
            Text(ShieldCopy.exhaustedHeading)
                .font(.title3.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(Color.tuckCharcoalGreen)
            Text(ShieldCopy.exhaustedBody(for: context))
                .font(.subheadline.weight(.regular))
                .fontDesign(.rounded)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.tuckInk)
            Spacer()
            // This screen used to be "Schließen" and nothing else — the one moment in the
            // app where somebody has a use for Plus in front of them, with no way to it. The way out
            // is the same secondary sage plate and the same three words as the bedtime gate,
            // and it stays an offer: no line above it selling the ceiling, no number, nothing that
            // reads as a consequence of what the user just did.
            Button {
                showPaywall = true
            } label: {
                Text("Plus ansehen")
                    .font(.body.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(Color.tuckCharcoalGreen)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: Layout.radiusPlate).fill(Color.tuckSage.opacity(0.5)))
            }
            // The only way off this screen, and it was tappable across its line box
            // only. On the label, inside the Button — outside it the frame moves the box, not the
            // hit area.
            Button { dismiss() } label: {
                Text("Schließen")
                    .frame(minHeight: Layout.hitMin)
                    .contentShape(Rectangle())
            }
                .font(.body.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(Color.tuckCharcoalGreen)
        }
    }

    private func breathing(for reason: OverrideReason) -> some View {
        VStack(spacing: Layout.overrideSection) {
            Spacer()
            // Reduce Motion darf nur die Darstellung ändern, nie die Wartezeit: der Kreis steht
            // still, der Phasenwechsel läuft weiter, und der Timer unten bleibt unberührt.
            PhaseAnimator(OverrideBreathPhase.allCases) { breath in
                VStack(spacing: Layout.overrideSection) {
                    Circle()
                        .fill(Color.tuckSage.opacity(0.6))
                        .frame(width: reduceMotion ? 145 : breath.diameter,
                               height: reduceMotion ? 145 : breath.diameter)
                        // Inside the circle rather than beside it: the thirty seconds are the
                        // animal's breath too, and a second element next to the circle would be a
                        // second thing to look at. Scale and offset are derived, not chosen —
                        // MascotRigFitTests carries the arithmetic.
                        .overlay {
                            breathingPose(openness: breath.mouthOpenness)
                        }

                    Text(breath.label)
                        .font(.body.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(Color.tuckCharcoalGreen)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: Motion.breathLabelCrossfade), value: breath)
                }
            } animation: { $0.animation }

            Text("\(secondsLeft)s")
                .font(.subheadline.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(Color.tuckCharcoalGreen)
            Spacer()
        }
        .task {
            // Swiping the sheet away cancels this task, and `try?` swallows the resulting
            // CancellationError — without the checks the loop free-runs to completion in
            // milliseconds and spends an unlock the user never got.
            for _ in 0..<breathingDurationSeconds {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                secondsLeft -= 1
            }
            guard !Task.isCancelled else { return }
            // Nothing is booked here any more: the timer running out ends the wait, and the choice
            // on the next screen is what spends the unlock. Reduce Motion only drops the crossfade
            // into that screen — never a second of the 30 the loop above waited.
            withAnimation(reduceMotion ? nil : .easeInOut(duration: Motion.stepOverride)) {
                phase = .afterBreathing(reason: reason)
            }
        }
    }

    // The rig laid into its own canvas first, so the pose has the same 160 x 140 box here that it
    // has on the morning screen and the scale below means the same thing in both places.
    //
    // The stage's own `scale` (0.82/0.92/1.0) is deliberately NOT applied: on the morning screen
    // that is a growth signal, here the size is set by the circle the animal has to sit in.
    // `.offset` after `.scaleEffect`, so the 12 pt are 12 pt on the screen and not 8.4.
    private func breathingPose(openness: Double) -> some View {
        MascotPose(
            expression: .breathing,
            sproutStage: stage.sproutStage,
            ink: colorVariant.color,
            saturation: stage.saturation,
            cheekOpacity: stage.cheekOpacity,
            mouthOpenness: openness,
            bodyOutlineInk: MascotGeometry.onSageBodyOutlineInk,
            bodyOutlineWidth: MascotGeometry.onSageBodyOutlineWidth,
            earOutlineInk: MascotGeometry.onSageEarOutlineInk,
            earOutlineWidth: MascotGeometry.onSageEarOutlineWidth,
            stemOutlineInk: MascotGeometry.onSageStemOutlineInk
        )
        .frame(width: MascotGeometry.rigWidth, height: MascotGeometry.rigHeight)
        .scaleEffect(MascotGeometry.breathingCircleRigScale)
        .offset(y: MascotGeometry.breathingCircleRigOffsetY)
        .accessibilityHidden(true)
    }

    // The two buttons carry the same weight on purpose: same font, same plate, same width, stacked
    // rather than paired left/right, and "Ich lass es doch" comes first. A quieter dismiss would
    // make this screen a nudge towards unlocking, which is the opposite of why it exists — the
    // honest offer is the whole mechanic (one sec, PNAS 2023).
    //
    // The line above them is the reason itself, mirrored back — not a fact the app brought along.
    // Why that changed: ReconsiderCopy.
    private func reconsider(for reason: OverrideReason) -> some View {
        VStack(spacing: Layout.overrideSection) {
            Spacer()
            reconsiderPose
            Text(ReconsiderCopy.reasonReflection(for: reason))
                .font(.body.weight(.bold))
                .fontDesign(.rounded)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(Color.tuckCharcoalGreen)
            Spacer()
            VStack(spacing: Layout.choiceStack) {
                Button { dismiss() } label: { choicePlate(ReconsiderCopy.dismissChoice) }
                Button {
                    let booking = context.bookUnlock()
                    spentUnlock = booking.spentUnlock
                    allowance = booking.allowance
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: Motion.stepOverride)) {
                        phase = .confirmed(reason)
                    }
                } label: { choicePlate(ReconsiderCopy.unlockChoice) }
            }
        }
    }

    // The same decision the settings portrait makes, for the same reason and with the same two
    // outcomes: `.waiting` where the stage has open eyes, the sleeping pair of stage "Start" where
    // it does not. Written out here rather than shared with `SettingsView`, because the two
    // surfaces choose independently and only happen to agree — the full reasoning and the app-icon
    // precedent are at `SettingsView.progressPortraitExpression(at:)` and in the design system.
    //
    // The breathing circle above deliberately does NOT take this: `.breathing` closes the eyes at
    // every stage, so it is coherent at stage 0 without asking.
    static func reconsiderPoseExpression(at stage: MascotStage) -> MascotExpression {
        stage.eyesOpen ? .waiting : MascotExpression(eyes: .closed, mouth: .sleeping)
    }

    // A NAMED EXCEPTION to the reconsider-screen rule rather than a quiet reversal of it — the rule
    // that this screen carries no head and no glyph stays in force everywhere else, and the design
    // system now says where it does not and why.
    //
    // `.waiting`, not `.attentive`, and that is the one deliberate lever here: `.attentive` leans
    // its ears forward and looks straight ahead, which over somebody's decision reads more easily
    // as being watched than as being accompanied. `.waiting` keeps the ears neutral and the glance
    // to the side. At this size the ear pose is what actually carries the difference; the sideways
    // pupils are about a point, present but small.
    //
    // `.waiting` only where the stage has open eyes, though — see `reconsiderPoseExpression(at:)`.
    //
    // `.accessibilityHidden(true)`: the design system says the screen shows only what the user themselves put
    // in, and that VoiceOver hears flowing text with no element of its own. Both stay true — this
    // is mood, not information, and the line below it is unchanged and still the only thing read.
    //
    // No contour override here, unlike the breathing circle and the settings row: this ground is
    // Cream, which is the ground the rig's own hairline was drawn for (1,1673:1 — the accepted
    // value, not something below it).
    private var reconsiderPose: some View {
        MascotPose(
            expression: Self.reconsiderPoseExpression(at: stage),
            sproutStage: stage.sproutStage,
            ink: colorVariant.color,
            saturation: stage.saturation,
            cheekOpacity: stage.cheekOpacity
        )
        .frame(width: MascotGeometry.rigWidth, height: MascotGeometry.rigHeight)
        .scaleEffect(MascotGeometry.reconsiderRigScale)
        .frame(width: MascotGeometry.rigWidth * MascotGeometry.reconsiderRigScale,
               height: MascotGeometry.rigHeight * MascotGeometry.reconsiderRigScale)
        .accessibilityHidden(true)
    }

    // The centred variant: modifiers inside the label closure, so the plate is the hit area.
    private func choicePlate(_ title: String) -> some View {
        Text(title)
            .font(.body.weight(.bold))
            .fontDesign(.rounded)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(Color.tuckCharcoalGreen)
            .frame(maxWidth: .infinity)
            .padding()
            .background(RoundedRectangle(cornerRadius: Layout.radiusPlate).fill(Color.tuckSage.opacity(0.5)))
    }

    private func confirmed(for reason: OverrideReason) -> some View {
        VStack(spacing: Layout.container) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.tuckCharcoalGreen)
                .accessibilityHidden(true)
            // The attempt, in the same form the arm side uses ("eingetragen, noch nicht scharf
            // gestellt"): "Freigeschaltet" reported a completed transaction for a ManagedSettings
            // write that reports nothing back at all. The direction of the error is the mild
            // one — a block that stays up is noticed in seconds — except on the documented
            // 30-second edge, where the quota was spent, the shield stayed and this screen said the
            // opposite of both.
            Text("Freischaltung eingetragen")
                .font(.title3.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(Color.tuckCharcoalGreen)
            if let remaining = allowance.remainingCount {
                Text(quotaLine(remaining: remaining))
                    .font(.subheadline.weight(.regular))
                    .fontDesign(.rounded)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.tuckInk)
            }
            Spacer()
            Button { dismiss() } label: {
                Text("Schließen")
                    .frame(minHeight: Layout.hitMin)
                    .contentShape(Rectangle())
            }
                .font(.body.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(Color.tuckCharcoalGreen)
        }
    }

    // The same count either way, but only one of the two is a report of a spend: an override run
    // outside every registered window leaves the number where it was, and "Noch 1 für heute übrig"
    // alone would read as the result of a transaction that did not happen. The reason names the
    // window, never the shield — see shieldIsStanding.
    private func quotaLine(remaining: Int) -> String {
        spentUnlock
            ? String(localized: "Noch \(remaining) für heute übrig.")
            : String(localized: "Ohne laufendes Fenster kostet das keine Freischaltung. Noch \(remaining) für heute übrig.")
    }
}

#Preview {
    OverrideFlowView()
}
