import SwiftUI

private struct SpeechBubble: View {
    let text: String

    var body: some View {
        // The white plate lifts this line to 4.47:1 — still short of AA's 4.5:1 for small text, so
        // the bubble has to clear the contrast rule the same way every other line does: >=14 pt at
        // weight 700. 13 pt could not, at any weight. In dark the plate is Moon Plate and the pair reaches
        // 5.65:1; the size rule holds either way, it is the palette that has room there.
        Text(text)
            .font(.subheadline.weight(.bold))
            .fontDesign(.rounded)
            .foregroundStyle(Color.tuckCharcoalGreen)
            // Das Innenmaß einer Schwebend-Platte um *eine* Aussage — enger als der
            // projektweite Texteinzug, der einen Textblock einrückt. Inzwischen hat es eine zweite
            // Aufrufstelle (die Statustext-Platte) und damit einen Namen.
            .padding(.horizontal, Layout.plateInsetX)
            .padding(.vertical, Layout.plateInsetY)
            .background(
                RoundedRectangle(cornerRadius: Layout.radiusPlate)
                    .fill(Color.tuckFloatingPlate.opacity(0.9))
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
            )
            .transition(.opacity)
    }
}

private struct SunriseBloom: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bloom = false

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [.clear, Color.tuckDawnGlow.opacity(0.5), .clear],
                    center: .center,
                    startRadius: 20,
                    endRadius: 130
                )
            )
            .frame(width: 260, height: 260)
            // Reduce Motion keeps the celebration and drops only its scale jump: the glow still
            // rises and fades over the same 2.6 s, held at the exact mean of 0.6 and 1.35 — the
            // same remedy the override's breathing circle uses for its two diameters.
            .scaleEffect(reduceMotion ? 0.975 : (bloom ? 1.35 : 0.6))
            .opacity(bloom ? 0 : 0.55)
            .animation(.easeOut(duration: Motion.celebrationBloom), value: bloom)
            .onAppear { bloom = true }
            .allowsHitTesting(false)
    }
}

// Reading the request destroys it (ShieldOverrideRequest.take), so it may only be read at a moment
// the override sheet can actually come up. SwiftUI does not stack a second sheet on a presented
// one: with the settings sheet open, the request would be consumed, the sheet would never appear,
// and the tap on the shield would have silently done nothing. The request survives instead — it
// stays valid for five minutes and is picked up when the settings sheet closes.
enum ShieldOverridePresentation {
    static func mayConsumeRequest(overrideFlowPresented: Bool, settingsPresented: Bool) -> Bool {
        !overrideFlowPresented && !settingsPresented
    }
}

struct GutenMorgenView: View {
    // A stored parameter with a default, the same shape MascotView's parameters have: the call site
    // in ContentView is unchanged, and the previews below can show all four seasons on a day that is
    // only one of them. A pure calendar read is not an init-time side effect —
    // no store is touched, nothing is written, and the value is read once for this view session.
    var season: Season = .current(on: .now)
    // Read ONCE, at view init, and deliberately never re-read on the foregrounding path beside
    // refreshSubline(): an object that swaps itself out under the user's gaze is an arrival.
    var foundObject: FoundObject = .current(on: .now)

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // The project's first dynamicTypeSize. A read, not a cap: the design system forbids capping the
    // scale, and asking what it currently is is a different thing.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showOverrideFlow = false
    @State private var bubbleText: String?
    @State private var showCelebration = false
    @State private var showSettings = false
    @State private var overrideContext: OverrideContext = .morning
    @State private var overrideReason: OverrideReason?
    @State private var scheduledAlarm = WakeAlarmStore.scheduledAlarm()
    @State private var blockRegistrationConfirmed = WakeAlarmStore.blockRegistrationSucceeded()
    @State private var selectedActivityCount = FamilyActivitySelectionStore.selectedActivityCount()
    // The reason this is the ratchet rather than MorningProgressStore's live count: every
    // stage channel on this screen is derived from this one number — the saturation that is animated
    // over 6 s in BOTH directions, the scale, the sprout, the ring, the spoken progress. A counter
    // that comes back partially lower (a lost App-Group write, a bug in the counting path) would
    // otherwise fade the colour out while the animal shrinks and drops a leaf, which is a punishment
    // this app does not do. A full App-Group restore is NOT covered — the ratchet travels back with
    // the counter. Guarding each channel separately was the alternative; removing the regressing
    // input covers the ones nobody thought of.
    @State private var reachedMornings = MilestoneStore.reachedMornings()
    @State private var colorVariant = MilestoneStore.selectedColorVariant()
    @State private var unlockedIdleAnimations = MilestoneStore.unlockedIdleAnimations()
    @State private var skyProgress: Double = 0
    @State private var mascotCenterY: CGFloat = 0
    @State private var recognition: MorningRecognition.Kind = .sameMorning
    @State private var animatedSaturation = MascotStage.stage(forCompletedMornings: MilestoneStore.reachedMornings()).saturation
    @State private var subline: String?
    @State private var pendingSubline: String = ""
    @State private var noticeConsumed = false
    @State private var mascotActivations = 0
    // Developer preview only (Entwickler-Status, reached through SettingsView): view-local, never
    // written back to MorningProgressStore, gone with this view session.
    @State private var previewStage: MascotStage?
    @State private var bubbleDismissTask: Task<Void, Never>?
    @State private var celebrationTask: Task<Void, Never>?
    @State private var ringTrimStart: Double = 0
    // Not the current progress: the progress the user last saw. On the morning the alarm was just
    // dismissed those two differ, and the difference is the whole thing this screen has to show.
    @State private var ringTrimEnd = MorningCelebration.ringOrigin(
        acknowledged: MorningCelebration.acknowledgedMornings(),
        completed: MilestoneStore.reachedMornings()
    )
    @State private var ringFlourish: Double = 0
    @State private var ringTask: Task<Void, Never>?
    // Which count the ring currently stands on, as presented — not what the store says. The two
    // differ for exactly one render after the second counting path moves the count from
    // inside .task, and that render is the one that must not present the same morning again.
    @State private var presentedMornings: Int?
    @State private var morningBeat = 0
    // The ring moves the instant the screen is there; the animal answers as soon as it is awake,
    // which on a cold launch is the end of its entrance. This holds the beat in between.
    @State private var pendingMorningBeat = false
    @State private var sceneIsActive = true
    // A cold launch runs .task and then the inactive -> active scene-phase change moments later, so
    // this is what tells the two apart. The first activation belongs to .task, which waits for the
    // mascot's entrance before anything is said; every later one is a real return from the
    // background — and that is the path a milestone actually arrives on, because the alarm is
    // dismissed while this app is not in front.
    @State private var hasBeenForegrounded = false

    private var stage: MascotStage {
        previewStage ?? MascotStage.stage(forCompletedMornings: reachedMornings)
    }

    // The developer preview is the one deliberate exception to the ratchet above: it is a view-local
    // jump for a developer, it may go backwards, and it is gone with the view session.
    private var displayedMornings: Int {
        previewStage?.completedMornings ?? reachedMornings
    }

    // A VoiceOver value is not a number on the screen: the "keine Zahl auf dem Screen" rule keeps
    // the count out of the visual design, it does not take progress away from screen reader users.
    private var progressDescription: String {
        MascotStage.progressDescription(completedMornings: displayedMornings)
    }

    // A stored window is only the plan. Saying "Sperrfenster bis 07:30" without a registration that
    // actually went through would keep claiming a block that no DeviceActivity schedule backs — and
    // a registration that went through over an empty picker backs a schedule that shields nothing,
    // which is the second half of the same claim.
    private func blockWindowLine(_ alarm: WakeAlarmStore.ScheduledAlarm) -> String {
        // First, before anything else this line could say: an unprovisioned App Group makes the
        // registration flag below meaningless — it was written into a container the monitor
        // extension cannot read, so a `true` there vouches for nothing at all.
        guard TuckIdentifiers.appGroupIsProvisioned else { return StatusCopy.sharedStorageMissing }

        // Before the registration flag and before the app count, because it outranks both: the
        // schedule really is registered today and the picker really is filled, and the monitor
        // extension will still let this day go by. This is the screen the user reads on the
        // morning itself — the setup screen's status line was adjusted for the weekday selection
        // and this one was not, so it kept saying "Sperrfenster bis 07:30" on a Saturday nobody
        // chose. The same decision function as the monitor's guard, on the same day.
        guard WakeAlarmWeekdayStore.morningBlockApplies(on: .now) else { return Self.dayOffLine() }

        let end = MorningBlockWindowFormatter.endTime(alarm.blockWindowEnd)
        guard blockRegistrationConfirmed else {
            return StatusCopy.windowPending(String(localized: "bis \(end)"))
        }
        return selectedActivityCount == 0
            ? StatusCopy.windowWithoutApps(String(localized: "bis \(end)"))
            : String(localized: "\(StatusCopy.blockWindowNoun) bis \(end)")
    }

    // The stored selection, like the setup screen's line and for the same reason: the days the
    // alarm was actually scheduled on, never a picker state nobody applied.
    static func dayOffLine(_ days: Set<WakeAlarmWeekday> = WakeAlarmWeekdayStore.selected()) -> String {
        StatusCopy.windowOffToday(WakeAlarmSetupView.daysPhrase(days))
    }

    var body: some View {
        ZStack {
            MorningSky.gradient(progress: skyProgress)
                .ignoresSafeArea()

            MorningAmbience(progress: skyProgress, mascotCenterY: mascotCenterY, season: season)

            // Between the ambience and the drifting particles, and that order is the whole claim: a
            // leaf that falls IN FRONT of the lying object reads as being in the air, a leaf behind
            // it reads as a drawing error. Both stay behind the column, so neither is ever over text.
            FoundObjectAccent(object: foundObject, mascotCenterY: mascotCenterY)

            // Behind the column, so no particle is ever drawn over text; in front of the ambience,
            // so it reads as being in the same air as the dust. `quiet` is fed from showCelebration:
            // an ordinary morning has one channel for its peak, and the accent is not it.
            SeasonalAccent(season: season, mascotCenterY: mascotCenterY, quiet: showCelebration)

            VStack(spacing: Layout.root) {
                // The bubble floats 110 pt above the mascot's centre and is not part of the
                // layout, so the band above the mascot has to be reserved rather than earned: at
                // accessibility text sizes the column below fills the screen, this Spacer would
                // collapse to nothing and the bubble would be drawn over the status bar. The
                // minimum is the tallest bubble the speech bubble's five-word rule can produce there.
                Spacer(minLength: 160)

                ZStack {
                    Circle()
                        .trim(from: ringTrimStart, to: ringTrimEnd)
                        .stroke(
                            Color.tuckSage.opacity(0.55 + 0.30 * ringFlourish),
                            style: StrokeStyle(lineWidth: 2 + 1.2 * ringFlourish, lineCap: .round)
                        )
                        .frame(width: 178, height: 178)
                        // The flourish is three things at once — brightness, stroke weight, scale —
                        // and only the third is motion. Pinning it leaves the other two to carry the
                        // reaction under Reduce Motion.
                        .scaleEffect(reduceMotion ? 1 : 1 + 0.04 * ringFlourish)
                        .rotationEffect(.degrees(-90))
                        .accessibilityElement()
                        .accessibilityLabel("Dein Fortschritt")
                        .accessibilityValue(progressDescription)

                    if showCelebration {
                        SunriseBloom()
                    }

                    MascotView(
                        stage: stage,
                        saturation: animatedSaturation,
                        lightElevation: skyProgress,
                        recognition: recognition,
                        colorVariant: colorVariant,
                        unlockedIdleAnimations: unlockedIdleAnimations,
                        accessibilityActivations: mascotActivations,
                        morningBeat: morningBeat
                    ) { tapMascot(index: $0) }
                        .id(recognition)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Dein Tuck, Stufe \(stage.displayName)")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityHint("Tippen für ein paar Worte")
                        // The trait and the hint promise an action; without this one VoiceOver had
                        // to synthesise a touch at the activation point and hope it reached the
                        // .onTapGesture underneath. Same handler, same tap counter, no fallback.
                        .accessibilityAction { mascotActivations += 1 }
                        .shadow(
                            color: Color.tuckDawnGlow.opacity(0.30 + 0.25 * skyProgress),
                            radius: 16 + 8 * skyProgress,
                            y: 8 - 16 * skyProgress
                        )

                    if let bubbleText {
                        SpeechBubble(text: bubbleText)
                            // The component spec names no width limit, so at accessibility text sizes the bubble
                            // grew to the full screen width and its rounded corners were cut off by
                            // both edges. The inset is the limit the component never had.
                            .padding(.horizontal, Layout.textInset)
                            .offset(y: -110)
                    }
                }
                .frame(height: 160)
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).midY } action: { mascotCenterY = $0 }

                // The one screen the `tuckInk` sweep deliberately did not touch. The design system
                // keeps the sky out of the ink table on purpose: it is not a body-text ground but a
                // four-stop gradient running 2,44:1 to 4,16:1, and the span accepted for it is
                // measured against charcoal green and stays measured against it. Weight 400 here
                // would give up the large-text path (>=14 pt at 700, bar 3:1) on the one ground of
                // the app that cannot pay the small-text 4,5:1 in return — a contrast regression
                // bought with a typographic improvement. Both lines therefore stay at weight 700.
                VStack(spacing: Layout.pair) {
                    Text(MorningCopy.greeting(at: .now))
                        .font(.title2.weight(.semibold))
                        .fontDesign(.rounded)
                    if let subline {
                        Text(subline)
                            .font(.subheadline.weight(.bold))
                            .fontDesign(.rounded)
                            .transition(.opacity)
                    }
                    if let scheduledAlarm {
                        Text(blockWindowLine(scheduledAlarm))
                            .font(.body.weight(.bold))
                            .fontDesign(.rounded)
                            .multilineTextAlignment(.center)
                    }
                }
                .foregroundStyle(Color.tuckCharcoalGreen)
                // The design system accepts that the light sky falls under 3:1 across the
                // upper band, and names the reason it is worth accepting: "als akzeptierter
                // Tradeoff für Statustext bei Accessibility-Textgrößen". This is that text, and
                // this is the ground it gets from .accessibility1 upwards — the same floating step
                // the speech bubble carries: tuckFloatingPlate at 0.9, radius 16, padding
                // 14/8, shadow black 0.08 / radius 6 / y 2. On it, charcoal green reads at least
                // 4,29:1 — "at least", because that is the worst case, the Dawn-Shadow top edge at
                // progress = 0, not the value at the block's own y.
                //
                // A `.background` modifier rather than an if/else around the VStack: a branch
                // rebuilds the column, and the subline's `.transition(.opacity)` would restart on
                // every Dynamic-Type change.
                //
                // The first `dynamicTypeSize` in the project, and a READ, not a cap — capping the scale
                // is forbidden, which is a different thing from asking what it currently is.
                //
                // Below the accessibility sizes nothing changes: the column does not scroll over
                // the standing sky there, so the ground stays uncritical and a third floating plate
                // on this screen would be three plates for two reasons.
                .background(alignment: .center) {
                    if dynamicTypeSize >= .accessibility1 {
                        RoundedRectangle(cornerRadius: Layout.radiusPlate)
                            .fill(Color.tuckFloatingPlate.opacity(0.9))
                            .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                            .padding(.horizontal, -Layout.plateInsetX)
                            .padding(.vertical, -Layout.plateInsetY)
                    }
                }
                // Found in a screenshot pass, not by a test: without this the plate ran
                // off both screen edges and its rounded corners were cut away — it read as a band
                // across the screen rather than as the floating step it is. Exactly the defect recorded
                // for the speech bubble ("at accessibility text sizes the bubble grew to
                // the full screen width"), on the second surface to carry that step, and the same
                // remedy. Only at the sizes that draw the plate: below the threshold this column's
                // width is unchanged, which is the whole promise.
                .padding(.horizontal, dynamicTypeSize >= .accessibility1 ? Layout.textInset : 0)

                Spacer()

                // Charcoal-green on this gradient runs 2.44:1 to 4.16:1 depending on progress and
                // height, so WCAG AA 4.5:1 for small text is out of reach without changing the
                // palette. The button below therefore sits in the large-text category instead
                // (>=14 pt at weight 700), where 3:1 is the bar — which it clears where it sits:
                // below y = 0.8 the ground never falls under 3.40:1 at any progress. Higher up it
                // does fall under 3:1; that is the status text above, not this one, and it is an
                // accepted tradeoff (docs/design/design-system.md, pinned in
                // LightSkyContrastTests). Settings left this column and is the
                // gear overlay below.
                Button {
                    // Resolved at tap time, not at view init: which window is active depends on
                    // the clock, and this screen can sit open across the boundary.
                    overrideContext = .current()
                    overrideReason = nil
                    showOverrideFlow = true
                } label: {
                    // The way out of a block window was tappable across its line box
                    // only. Same place as the gear above — on the label, inside the Button.
                    Text("Ich brauche kurz Zugriff")
                        .frame(minHeight: Layout.hitMin)
                        .contentShape(Rectangle())
                }
                    .font(.subheadline.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(Color.tuckCharcoalGreen)
            }
            .padding(.bottom, 24)
            // The sky and the ambience stay put behind this; only the column moves, and only once
            // it no longer fits — without it the greeting truncated to "Schön, dass d…".
            .scrollableWhenTallerThanScreen()
        }
        // As a bare `Button("Einstellungen")` this carried exactly the three modifiers
        // of the status line above it — no plate, no glyph, no navigation bar — and a hit area under
        // half the HIG minimum. "There are no settings" was a correct reading of the screen. As an
        // overlay it stays off the sky: nothing about the gradient, the ambience or the column
        // changes, the gear simply sits above them at a size a thumb can find.
        //
        // The plate under it is not decoration: the old text button sat at the
        // bottom of the sky, where charcoal green never falls under 3.40:1, and the top is the one
        // band where it does — 2.44:1 on Dawn Shadow at progress 0, under the 3:1 WCAG asks of a
        // control. Moving the control up without it would have traded one hit-area failure for a
        // contrast one. It is the floating elevation the speech bubble already uses,
        // charcoal on it 4.47:1, and it touches nothing but the button.
        .overlay(alignment: .topTrailing) {
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.body.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(Color.tuckCharcoalGreen)
                    .frame(width: Layout.hitMin, height: Layout.hitMin)
                    .background(
                        Circle()
                            .fill(Color.tuckFloatingPlate.opacity(0.9))
                            .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                    )
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Einstellungen")
            .padding(.trailing, 8)
        }
        .task {
            // Onboarding hands over without a scenePhase change, so the first pass after the
            // permission was granted there has to happen here.
            BlockWindowReconciler.reconcile()
            // Before the count is read below: this is the second path a morning can be
            // counted on, for every dismissal AlarmKit's stop intent is never delivered for. It is
            // idempotent against the intent through CompletedMorningLedger's single claim, so a
            // morning both paths reach still moves the ring exactly once.
            countThisMorningIfTheIntentDidNot()
            auditThisMorningsCallback()
            auditThisEveningsCallback()
            blockRegistrationConfirmed = WakeAlarmStore.blockRegistrationSucceeded()
            openOverrideIfRequestedFromShield()
            recognition = MorningRecognition.check(now: .now, alarm: scheduledAlarm)
            // First thing, before anything sleeps: on a cold launch this is the only path the
            // morning's reaction can arrive on, and "instant" means the ring is already moving while
            // the rest of the screen is still fading in.
            presentCompletedMorning(for: reachedMornings)
            refreshSubline()
            try? await Task.sleep(for: .seconds(Motion.sublineDelay))
            withAnimation(.easeIn(duration: Motion.sublineIn)) { subline = pendingSubline }
            await greetAfterEntrance()
        }
        .task {
            while !Task.isCancelled {
                // Nothing to cross-fade into a screen nobody is looking at: the scenePhase change
                // below runs the same 8 s fade at the moment the app comes forward again.
                if sceneIsActive {
                    withAnimation(.easeInOut(duration: Motion.skyCrossfade)) {
                        skyProgress = MorningSky.progress(now: .now, alarm: scheduledAlarm)
                    }
                }
                try? await Task.sleep(for: .seconds(Motion.skyPoll))
            }
        }
        .onChange(of: displayedMornings) { _, new in
            moveRing(to: new)
        }
        .onChange(of: stage) {
            withAnimation(.easeInOut(duration: Motion.stageSaturation)) { animatedSaturation = stage.saturation }
            celebrateStageChange()
        }
        // The alarm is dismissed while the app is in the background, so the count that was read
        // at view init is stale by the time the user actually looks at the screen.
        .onChange(of: scenePhase) {
            // The poll above outlives every render it was started from, so it can only read the
            // scene phase through @State — its own @Environment copy never updates.
            sceneIsActive = scenePhase == .active
            guard scenePhase == .active else { return }
            BlockWindowReconciler.reconcile()
            // Before refreshFromStores, which reads the count this may have just moved. The
            // ordinary path for the morning the app was not open on: the alarm is dismissed while
            // this app is in the background, so this is the first moment either path can run.
            countThisMorningIfTheIntentDidNot()
            auditThisMorningsCallback()
            auditThisEveningsCallback()
            openOverrideIfRequestedFromShield()
            refreshFromStores()
            refreshSubline()
            subline = pendingSubline
            if hasBeenForegrounded { celebrateNewMilestone() }
            hasBeenForegrounded = true
            withAnimation(.easeInOut(duration: Motion.skyCrossfade)) {
                skyProgress = MorningSky.progress(now: .now, alarm: scheduledAlarm)
            }
        }
        // No reconcile here, unlike the setup sheets it replaced: SettingsView runs one after each
        // of its own sub-sheets, at the moment a newly stored window can actually be armed. All
        // that is left for this screen is re-reading what may have changed behind the sheet.
        // The second half of the guard above: a shield request that arrived while this sheet was up
        // was left untouched, and this is the first moment it can be answered.
        .sheet(isPresented: $showSettings, onDismiss: {
            refreshFromStores()
            openOverrideIfRequestedFromShield()
        }) {
            SettingsView(previewStage: $previewStage)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        // The only sheet without an onDismiss reconcile, deliberately: a completed override clears
        // the shield inside its own confirm path, and reconcile() re-registers any window whose
        // registration is still unconfirmed — which would re-arm the block the user just spent an
        // unlock on. Nothing on this screen shows the quota, so there is nothing to refresh either.
        // The grabber is honest here too, not a risk: swiping the breathing phase away cancels its
        // task, and the Task.isCancelled guards inside make that a way out that spends no unlock.
        .sheet(isPresented: $showOverrideFlow) {
            OverrideFlowView(context: overrideContext, preselectedReason: overrideReason)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    // The other half of the unlock path: .openParentalControlsApp brings the app forward with
    // nothing attached, so the tap that caused it is read back out of the App Group here. Without
    // this the shield would open the app onto the morning screen and leave the user to find the
    // override button themselves — which is option 4, the one the decision record rejected.
    private func openOverrideIfRequestedFromShield() {
        guard ShieldOverridePresentation.mayConsumeRequest(
            overrideFlowPresented: showOverrideFlow,
            settingsPresented: showSettings
        ), let request = ShieldOverrideRequest.take() else { return }
        overrideContext = .current()
        overrideReason = request.reason
        showOverrideFlow = true
    }

    // The whole of path two at this screen. The read afterwards is unconditional rather than tied
    // to the return value: on the cold-launch path `reachedMornings` was read at view init and is
    // stale by whatever the intent counted while the app was in the background, which is the case
    // this screen has always had to survive.
    private func countThisMorningIfTheIntentDidNot() {
        CompletedMorningLedger.recordForegroundEntry()
        reachedMornings = MilestoneStore.reachedMornings()
    }

    // A callback that never arrives arrives nowhere, so the app comes looking for it — once
    // per occurrence, at the two moments it is in front anyway. Changes nothing the user sees; it
    // moves the one number that decides whether the five-day observation passed.
    private func auditThisMorningsCallback() {
        BlockDiagnostics.auditMorningCallback(occurrence: CompletedMorningLedger.countableMorning(now: .now))
    }

    // The evening's half of the same instrument, on the same two entry points. It does not have to
    // run in the evening: it has to run after the occurrence, and the ordinary moment for that is
    // the next morning, on the screen the user opens anyway.
    private func auditThisEveningsCallback() {
        BlockDiagnostics.auditBedtimeCallback(occurrence: BedtimeStore.countableOccurrence(now: .now))
    }

    private func refreshFromStores() {
        scheduledAlarm = WakeAlarmStore.scheduledAlarm()
        blockRegistrationConfirmed = WakeAlarmStore.blockRegistrationSucceeded()
        selectedActivityCount = FamilyActivitySelectionStore.selectedActivityCount()
        reachedMornings = MilestoneStore.reachedMornings()
        colorVariant = MilestoneStore.selectedColorVariant()
        unlockedIdleAnimations = MilestoneStore.unlockedIdleAnimations()
    }

    // The mascot wakes up first (MascotView entrance, 1.4 s, plus the held look after a gap) —
    // the bubble only follows once it is looking at the user.
    private func greetAfterEntrance() async {
        // No entrance and no greeting on this path, but a milestone reached since the last launch
        // still gets its line: the reward exists either way, only the greeting is tied to arriving.
        guard recognition != .sameMorning else {
            flushMorningBeat()
            celebrateNewMilestone()
            return
        }
        let entrance: Duration = .seconds(recognition == .afterGap
                                          ? Motion.entranceHandoverAfterGap
                                          : Motion.entranceHandover)
        try? await Task.sleep(for: entrance)
        flushMorningBeat()
        guard !celebrateNewMilestone() else { return }
        let morningIndex = MorningCopy.morningIndex(for: .now, alarm: scheduledAlarm)
        say(recognition == .afterGap
            ? MorningCopy.line(from: MorningCopy.wiedersehen, index: morningIndex)
            : MorningCopy.line(from: stage.encouragements, index: morningIndex))
    }

    // Exactly once per milestone: the flag is written at the moment the line goes up, so the same
    // unlock can never be announced a second time — not on the next foregrounding, not on the next
    // launch. Forgetting to write it would repeat a line; writing it can never take a reward away
    // (MilestoneStore keeps the two apart).
    //
    // If several are outstanding at once, the newest speaks and the rest are marked silently.
    // Mornings arrive one at a time and the thresholds sit at least fifteen apart, so that case
    // needs a restored backup or an import to happen at all — and then a queue of bubbles for
    // unlocks from months ago would be neither news nor this screen.
    @discardableResult
    private func celebrateNewMilestone() -> Bool {
        let outstanding = MilestoneStore.uncelebratedMilestones()
        guard let newest = outstanding.last else { return false }
        for milestone in outstanding { MilestoneStore.recordCelebration(of: milestone) }
        say(newest.celebration)
        return true
    }

    // The bubble is inserted text, and SwiftUI announces no text it merely inserts: without this
    // the mascot's hint promised a few words that VoiceOver never got, and the milestone line — the
    // only announcement an unlocked idle beat ever gets — was silent too. The announcement
    // lives independently of the element, so the 2.8 s dismissal below cannot cut it short.
    private func say(_ line: String?) {
        guard let line else { return }
        withAnimation(.easeOut(duration: Motion.bubbleIn)) { bubbleText = line }
        AccessibilityNotification.Announcement(line).post()
        scheduleBubbleDismiss()
    }

    // A second trigger must own the bubble for its full duration: without cancelling, the first
    // trigger's stale timer fires early and clears text that belongs to the second one.
    private func scheduleBubbleDismiss() {
        bubbleDismissTask?.cancel()
        bubbleDismissTask = Task {
            try? await Task.sleep(for: .seconds(Motion.bubbleHold))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: Motion.bubbleOut)) { bubbleText = nil }
        }
    }

    // The notice takes the subline slot for one pass and nothing else — no second line, no badge,
    // no history. Reading it consumes it in the App Group, so the outcome is held here for the rest
    // of this view session: a cold launch runs .task and then the inactive -> active scene phase
    // change moments later, and the second take() would come back empty and overwrite the line
    // before it was ever on screen. Gone with the view: said once, never repeated, never counted.
    private func refreshSubline() {
        if noticeConsumed || ScreenTimeNotice.take() {
            noticeConsumed = true
            pendingSubline = MorningCopy.screenTime
            return
        }
        pendingSubline = MorningCopy.subline(
            morningIndex: MorningCopy.morningIndex(for: .now, alarm: scheduledAlarm),
            completedMornings: displayedMornings,
            isPastBlockWindowToday: isPastBlockWindowToday()
        )
    }

    // Three parts, all of them read fresh here — and expressly WITHOUT `recognition`, which is
    // computed exactly once, in the first `.task`, and is deliberately never recomputed (MascotView
    // carries `.id(recognition)`, so a change would replay the entrance, and
    // `MorningRecognition.check` writes `lastSeenMorningAnchor` as a side effect). Whoever opens the
    // app at 06:35 has `recognition == .nextMorning` for the whole view session, including at 11.
    // This function runs on every foregrounding, which is the path the end node is about.
    //
    // 1. There has to be an alarm — without a window there is no end for a line to comment on.
    // 2. The window has to apply TODAY. `MorningBlockWindow.mostRecentStart` is weekday-blind: it
    //    returns an anchor on a day the user never chose, and `MorningSky.progress` then stands at 1
    //    all day. Without this check the line would appear on a free Saturday while the status line
    //    two rows above correctly says the window is off. Same question the status line asks.
    // 3. The progress is RECOMPUTED, not read: `skyProgress` is stale on both paths — on cold launch
    //    `refreshSubline()` runs while it still holds its init value of 0, and on foregrounding it
    //    runs before the sky is updated. Reading it here would build a line that never appears on
    //    the first look and only on the second.
    private func isPastBlockWindowToday() -> Bool {
        guard let scheduledAlarm, WakeAlarmWeekdayStore.morningBlockApplies(on: .now) else { return false }
        return MorningSky.progress(now: .now, alarm: scheduledAlarm) == 1
    }

    // The tap index is part of the key, or every tap of one morning would get the same line. The
    // `+ 1` keeps tap zero off the greeting's own line, which is drawn from the same pool.
    //
    // Honest counter-point: the same line can now come up twice in one morning once `tapResetTask`
    // has put the counter back after 8 s. That is the price of testability and it is small — the
    // rotation existed either way, only who decides it has changed. The three-line memory
    // (`recentPhraseIndices`) is gone without replacement: a deterministic offset does its job
    // without state.
    private func tapMascot(index: Int) {
        guard index < 3 else { return }
        let morningIndex = MorningCopy.morningIndex(for: .now, alarm: scheduledAlarm)
        say(MorningCopy.line(from: stage.encouragements, index: morningIndex + 1 + index))
    }

    // The developer preview is a view-local jump between stages, not a morning: it moves the ring
    // and nothing else. Every real change goes through presentCompletedMorning, which asks the store
    // rather than this delta — otherwise clearing the preview would read as a morning earned.
    private func moveRing(to new: Int) {
        guard previewStage == nil else {
            // The preview owns the ring from here, so whatever was presented last no longer stands
            // on it: clearing the preview has to be free to put the real value back.
            presentedMornings = nil
            ringTask?.cancel()
            ringTrimStart = 0
            ringFlourish = 0
            // Without the nil the fallback still travelled the ring for 1.4 s — a shorter sweep,
            // not a still one.
            withAnimation(reduceMotion ? nil : .easeInOut(duration: Motion.ringSettle)) {
                ringTrimEnd = MascotStage.progressTowardNext(completedMornings: new)
            }
            return
        }
        // The count can move during .task, on the cold launch where the second path
        // counts the morning the stop intent never reported. That assignment reaches this
        // observer one render later, so without the guard the reaction is presented twice: the
        // second pass finds the morning already acknowledged, cancels the running fill or sweep
        // and flushes the mascot's beat while the animal is still asleep — the two glitches the
        // celebration is built to avoid. Nothing else changes: every real change of the count
        // still arrives here with a value that was never presented.
        guard presentedMornings != new else { return }
        presentCompletedMorning(for: new)
        // The rig is awake on this path — the view was already on screen when the count changed,
        // so there is no entrance to wait out.
        flushMorningBeat()
    }

    // The single entry for "a morning has been counted since this screen last showed it". Both paths
    // it can arrive on lead here: the cold launch through .task, and the return from the background
    // through the count change above — which is the same pair the milestone copy already runs on.
    // Same shape as scheduleBubbleDismiss: without cancelling, a stale timer would end a reaction
    // that is not its own.
    private func presentCompletedMorning(for mornings: Int) {
        presentedMornings = mornings
        ringTask?.cancel()
        let target = MascotStage.progressTowardNext(completedMornings: mornings)
        let kind = MorningCelebration.kind(acknowledged: MorningCelebration.acknowledgedMornings(),
                                           completed: mornings)
        MorningCelebration.acknowledge(completed: mornings)
        if MorningCelebration.mascotReacts(to: kind) { pendingMorningBeat = true }

        switch MorningCelebration.presentation(for: kind, reduceMotion: reduceMotion) {
        case .none:
            ringTrimStart = 0
            ringFlourish = 0
            withAnimation(reduceMotion ? nil : .easeInOut(duration: Motion.ringSettle)) { ringTrimEnd = target }
        case .flourishOnly:
            ringTrimStart = 0
            ringTrimEnd = target
            ringTask = Task { await flourishRing() }
        case .fill:
            ringTrimStart = 0
            ringTask = Task { await fillRing(to: target) }
        case .sweep:
            ringTask = Task { await sweepRing(to: target) }
        }

        // Deliberately outside the switch: on a cold launch `stage` never changes as state, so the
        // .onChange that normally opens the bloom does not run, and the crossing would be the one
        // morning with no light behind it. Under Reduce Motion the presentation is .flourishOnly and
        // the trim lands on an empty new arc without travelling — a flourish on a ring of length zero
        // draws nothing at all, so there the bloom is the entire reaction. On the foregrounding
        // path both fire in the same update and the second cancels the first: one bloom either way.
        if kind == .stageSweep { celebrateStageChange() }
    }

    // The everyday counterpart to sweepRing. The ring starts where the user last saw it (ringOrigin
    // seeds it, so nothing has to be moved back first) and travels the single step this morning
    // earned, while the stroke brightens and thickens with it. Past the last stage the ring is
    // already full and only the flourish is left — that morning counted just as much.
    private func fillRing(to target: Double) async {
        withAnimation(.easeOut(duration: Motion.ringFill)) { ringTrimEnd = target }
        await flourishRing()
    }

    private func flourishRing() async {
        withAnimation(.easeInOut(duration: Motion.ringFlourishIn)) { ringFlourish = 1 }
        try? await Task.sleep(for: .seconds(Motion.ringFlourishHold))
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: Motion.ringFlourishOut)) { ringFlourish = 0 }
    }

    // A beaming face behind closed eyes is not warmth, it is a glitch: on a cold launch the animal
    // is still asleep when the ring starts moving, so its half of the reaction waits for the
    // entrance to hand over. Exactly once — the flag is cleared before the counter goes up.
    private func flushMorningBeat() {
        guard pendingMorningBeat else { return }
        pendingMorningBeat = false
        morningBeat += 1
    }

    // The ring closes its circle, then the tail follows the head past twelve o'clock until the
    // circle is spent — so the empty ring is the end of one motion, not a backward jump at the
    // exact moment the threshold is reached. Runs inside the SunriseBloom window on purpose.
    private func sweepRing(to target: Double) async {
        ringTrimStart = 0
        withAnimation(.easeOut(duration: Motion.sweepClose)) { ringTrimEnd = 1 }
        withAnimation(.easeInOut(duration: Motion.sweepFlourishIn)) { ringFlourish = 1 }
        try? await Task.sleep(for: .seconds(Motion.sweepGap))
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: Motion.sweepTail)) { ringTrimStart = 1 }
        try? await Task.sleep(for: .seconds(Motion.sweepTailHold))
        guard !Task.isCancelled else { return }
        ringTrimStart = 0
        ringTrimEnd = target
        withAnimation(.easeOut(duration: Motion.sweepFlourishOut)) { ringFlourish = 0 }
    }

    private func celebrateStageChange() {
        celebrationTask?.cancel()
        showCelebration = false
        celebrationTask = Task {
            try? await Task.sleep(for: .milliseconds(30))
            guard !Task.isCancelled else { return }
            showCelebration = true
            try? await Task.sleep(for: .seconds(Motion.celebrationWindow))
            guard !Task.isCancelled else { return }
            showCelebration = false
        }
    }
}

#Preview("Frühling") {
    GutenMorgenView(season: .spring)
}

#Preview("Sommer") {
    GutenMorgenView(season: .summer)
}

#Preview("Herbst") {
    GutenMorgenView(season: .autumn)
}

#Preview("Winter") {
    GutenMorgenView(season: .winter)
}

// The five placeholder forms, on the one season that draws no particles of its own: the object is
// the only thing to look at there, which is what a screenshot comparison needs.
#Preview("Fundstück · Scheibe") {
    GutenMorgenView(season: .summer, foundObject: .disc)
}

#Preview("Fundstück · Kuppe") {
    GutenMorgenView(season: .summer, foundObject: .dome)
}

#Preview("Fundstück · Keil") {
    GutenMorgenView(season: .summer, foundObject: .wedge)
}

#Preview("Fundstück · Raute") {
    GutenMorgenView(season: .summer, foundObject: .lozenge)
}

#Preview("Fundstück · Riegel") {
    GutenMorgenView(season: .summer, foundObject: .bar)
}
