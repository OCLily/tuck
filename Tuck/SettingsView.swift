import FamilyControls
import SwiftUI
#if DEBUG
import ManagedSettings
#endif

// The one place every setting lives, so the morning screen can stay a greeting instead of a
// control panel. Everything here is deliberately not urgent — the one action that is (the
// override) stays on GutenMorgenView itself.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionController.self) private var subscriptions

    // Developer preview only, handed straight through to the Entwickler-Status sheet below: the
    // mascot it previews lives on GutenMorgenView, so the binding has to come from there.
    @Binding var previewStage: MascotStage?

    @State private var showWakeAlarmSetup = false
    @State private var showBedtimeSetup = false
    @State private var showAppSelection = false
    @State private var showPaywall = false
    #if DEBUG
    @State private var showDeveloperStatus = false
    @State private var intentShieldProbeArmed = BlockDiagnostics.intentShieldProbeIsArmed()
    @State private var intentShieldWrites = BlockDiagnostics.intentShieldWrites()
    #endif
    @State private var scheduledAlarm = WakeAlarmStore.scheduledAlarm()
    @State private var bedtime = BedtimeStore.bedtime()
    @State private var selectedActivityCount = FamilyActivitySelectionStore.selectedActivityCount()
    // The ratchet, not the live count: the portrait and the spoken "x von y Morgen" below are two
    // readings of the same number, and both have to survive a counter that comes back lower.
    @State private var reachedMornings = MilestoneStore.reachedMornings()
    @State private var access = SubscriptionAccess.current()
    @State private var blockDuration = MorningBlockDurationStore.selected()
    // Read once, like blockDuration and for the same reason: nothing reachable from this screen
    // completes a morning, so neither list can grow while it is open.
    @State private var colorVariant = MilestoneStore.selectedColorVariant()
    @State private var unlockedColorVariants = MilestoneStore.unlockedColorVariants()
    @State private var badges = MilestoneStore.unlockedBadges()
    // Read once like everything else on this screen, and reading IS the accrual — the counter has no
    // callback to hang on, so it settles up on read. A scenePhase change while the sheet is open
    // therefore does not move this row live; it is the screen's existing convention and it costs
    // nothing here, because the value moves at the earliest after the next window end.
    //
    // This one is deliberately kept here rather than moved into a
    // `.task` — a decision, not an oversight, the same way BedtimeSetupView's gate read is one.
    // SwiftUI does re-evaluate this expression on every reconstruction of the struct, so the write
    // behind it runs at moments nobody chose; what makes that harmless is the shape of the write,
    // not its frequency. `accrue` books the span that has elapsed and nothing else, so a call at an
    // unchosen moment credits what a call at a chosen one would have, in the ordinary case
    // (ProtectedTimeStoreTests.aBurstOfUnchosenReadsLandsOnTheSameSumAsOneSettledRead, over a
    // window with no DST transition). Across a spring-forward transition the day-distance
    // arithmetic is not additive — ProtectedTimeStoreTests.aSpringForwardPassKeepsTheCounterMoving-
    // AndCostsTwoOccurrences already pins that a settled read and a burst of reads can differ there
    // by up to 2 occurrences/year, bounded to windows whose *end* falls in the DST gap (reachable
    // only via a ~02:30 bedtime, never the ~07:30 morning window), always in the under-count
    // direction this file's own discipline of never over-claiming already accepts, and realized identically by each of
    // the eight other `accrue()` call sites regardless of where this one sits — so it changes
    // nothing about the decision, only the strength of the claim above it. The call that was moved
    // out of an initialiser was a different kind: `allowanceReachingTheCeiling` starts a
    // fourteen-day clock whose FIRST caller fixes a date nobody can take back.
    //
    // What moving it would cost: `StatusCopy.fullHours(0)` is `emptyCount`, so a placeholder would
    // show "noch keine" for a frame on the one row whose whole job is to say what the app has done
    // — the screen understating itself, on a value it already has. Pinned in place by
    // ProtectedTimeStoreTests.theSettingsRowStillAccruesFromItsStateInitialiser.
    @State private var protectedSeconds = ProtectedTimeStore.accrue()
    // Read once like every other row here. Nothing reachable from this screen moves these numbers,
    // and a live number would invite watching them.
    @State private var morningDiagnostics = SettingsView.morningDiagnostics()
    @State private var bedtimeDiagnostics = SettingsView.bedtimeDiagnostics()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    row(title: "Weckzeit", value: wakeValue) { showWakeAlarmSetup = true }
                    row(title: "Bettzeit", value: bedtimeValue) { showBedtimeSetup = true }
                } header: {
                    header("Deine Zeiten")
                } footer: {
                    footer("Optional — ohne sie bleibt der Abend offen.")
                }
                .listRowBackground(Color.tuckSage.opacity(0.25))

                Section {
                    durationRow
                } header: {
                    header("Morgenfenster")
                } footer: {
                    footer("Zählt ab der Weckzeit, gilt ab morgen früh.")
                }
                .listRowBackground(Color.tuckSage.opacity(0.25))

                Section {
                    row(title: "Apps, die warten", value: appSelectionValue) { showAppSelection = true }
                } header: {
                    header("Apps")
                } footer: {
                    footer("Gilt morgens und abends.")
                }
                .listRowBackground(Color.tuckSage.opacity(0.25))

                Section {
                    row(title: "Abo", value: subscriptionValue) { showPaywall = true }
                } header: {
                    header("Wenn es doch mal nötig ist")
                } footer: {
                    footer("Plus: kein Tageslimit, dazu das Bettzeit-Fenster.")
                }
                .listRowBackground(Color.tuckSage.opacity(0.25))

                Section {
                    progressPortrait
                    row(title: "Fortschritt",
                        value: MascotStage.progressDescription(completedMornings: reachedMornings))
                    if !badges.isEmpty {
                        badgeRow
                    }
                } header: {
                    header("Dein Weg")
                } footer: {
                    footer("Auch Morgen mit Freischaltung zählen.")
                }
                .listRowBackground(Color.tuckSage.opacity(0.25))

                // Absent until the first variant is earned: a list of locked rewards would turn a
                // setting into a ladder, and the schedule is meant to arrive rather than to be
                // worked toward. With only the original there is also nothing to choose.
                if unlockedColorVariants.count > 1 {
                    Section {
                        colorRow
                    } header: {
                        header("Dein Tuck")
                    } footer: {
                        footer("Kommen mit den Morgen dazu und bleiben.")
                    }
                    .listRowBackground(Color.tuckSage.opacity(0.25))
                }

                // A section of its own, deliberately not inside "Dein Weg": that one belongs to the
                // user and feeds the mascot system, this number belongs to the app and feeds
                // nothing. Merging them is exactly what UnlockQuotaStore ruled out for the bedtime.
                // Not tappable, no chevron, no ProgressView, no ring and no "N von M" — a goal is
                // what this value may never have.
                Section {
                    row(title: "Sperrfenster insgesamt", value: StatusCopy.fullHours(protectedSeconds))
                } header: {
                    header("Was Tuck eingetragen hat")
                } footer: {
                    footer("Nur ganz durchgelaufene Fenster.")
                }
                .listRowBackground(Color.tuckSage.opacity(0.25))

                // Deliberately not behind #if DEBUG: the platform failure this measures
                // happens on other people's phones, not on this desk. One line per window, in the
                // order that window walks through — registered, iOS opened it, shield written, and
                // for the morning how often the second one never came and how many days were
                // skipped on purpose. Not tappable, nothing to do about it here; it exists so a
                // support mail can carry one line instead of a guess.
                //
                // The legend moved off the footer and into an accessibilityLabel per row: with two
                // lines of different lengths a single footer can be right for at most one of them,
                // and "3 · 2 · 2 · 0 · 1" under a footer that names other numbers is an instrument
                // nobody can read. The label is read-out text, not layout, so the ten-word rule
                // applies to the footer and the titles here, not to it.
                Section {
                    row(title: "Diagnose Morgen", value: morningDiagnostics.value)
                        .accessibilityLabel(morningDiagnostics.label)
                    row(title: "Diagnose Abend", value: bedtimeDiagnostics.value)
                        .accessibilityLabel(bedtimeDiagnostics.label)
                } header: {
                    header("Technik")
                } footer: {
                    footer("Nur auf diesem Gerät. Für die Fehlersuche.")
                }
                .listRowBackground(Color.tuckSage.opacity(0.25))

                // Removed on purpose: a Section with no rows at all, whose entire content
                // was a 44-word statement of purpose in the footer. It was the longest text on the
                // screen and the only one that answered no question a settings dialog asks. If that
                // sentence is worth saying it belongs in the App Store description, where someone
                // is deciding whether to install — not in the dialog of someone who already did.

                #if DEBUG
                Section {
                    row(title: "Entwickler-Status", value: "") { showDeveloperStatus = true }
                } header: {
                    header("Entwickler")
                }
                .listRowBackground(Color.tuckSage.opacity(0.25))

                // The device gate, and the reason it is four affordances rather than
                // one: that a ManagedSettings write from the app process shields at all is unproven
                // in this repo, and whether the same holds in a process the system started in the
                // background is a second, independent question. Neither is answerable in the
                // Simulator, and everything the fallback would later rest on rests on both.
                //
                // "Nur Morgen-Store räumen" looks redundant next to "Shield jetzt räumen" and is
                // not: the background-write run observes a blocked app, and a morning shield stranded by a
                // missing intervalDidEnd blocks the same app. Clearing the morning store first is
                // what makes "still blocked" mean the bedtime store and nothing else.
                Section {
                    row(title: "Shield jetzt schreiben", value: "") { writeShieldNow() }
                    row(title: "Shield jetzt räumen", value: "") { ShieldRelease.clearAll() }
                    row(title: "Nur Morgen-Store räumen", value: "") { ShieldRelease.clear(.morningBlock) }
                    Toggle("Weckerstopp schreibt den Shield", isOn: $intentShieldProbeArmed)
                        .font(.body.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(Color.tuckCharcoalGreen)
                        .onChange(of: intentShieldProbeArmed) {
                            BlockDiagnostics.armIntentShieldProbe(intentShieldProbeArmed)
                        }
                    row(title: "Intent-Schreibvorgänge", value: String(intentShieldWrites))
                } header: {
                    header("Geräte-Gate")
                }
                .listRowBackground(Color.tuckSage.opacity(0.25))
                #endif
            }
            .scrollContentBackground(.hidden)
            .background(Color.tuckCream)
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Schließen") { dismiss() }
                        .font(.body.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(Color.tuckCharcoalGreen)
                }
            }
            // The cache is read once at init, so the answer that ends the checking state above has
            // to write it a second time — otherwise the row leaves "Noch keine Antwort" for whatever
            // the cache held before StoreKit spoke.
            .onChange(of: subscriptions.entitlement) { access = SubscriptionAccess.current() }
        }
        // The three reconcile calls these sheets carried on GutenMorgenView belong here now, for
        // the same reason they existed at all: setting a window or granting the access is the
        // moment a stored-but-unregistered window can finally be armed, and a sheet dismissal
        // brings no scenePhase change with it.
        // Every sheet in the app declares the same two presentation modifiers, so the form
        // is readable at the call site instead of differing per screen. The grabber is the point:
        // no sheet here sets interactiveDismissDisabled, so all of them can be swiped away — and
        // these two setup screens are also embedded inline in onboarding, where an in-content
        // "Schließen" button would dismiss nothing. A presentation-scoped affordance is the only
        // one that can give them a visible way out without leaking into the flow.
        // Inside onboarding these two views already scroll with the flow; presented as a sheet they
        // need their own, or the wheel picker's fixed height squeezes their title and their note
        // into an ellipsis at accessibility text sizes.
        .sheet(isPresented: $showWakeAlarmSetup, onDismiss: { reconcileAndRefresh() }) {
            WakeAlarmSetupView()
                .padding()
                .scrollableWhenTallerThanScreen()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showBedtimeSetup, onDismiss: { reconcileAndRefresh() }) {
            BedtimeSetupView()
                .padding()
                .scrollableWhenTallerThanScreen()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAppSelection, onDismiss: { reconcileAndRefresh() }) {
            AccessAndAppSelectionView()
                .padding()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        // Reads the cache the paywall wrote rather than StoreKit itself: this row states what the
        // quota will actually use, and that is the cached value, not a second live lookup that
        // could disagree with it.
        .sheet(isPresented: $showPaywall, onDismiss: { access = SubscriptionAccess.current() }) {
            PaywallView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        #if DEBUG
        .sheet(isPresented: $showDeveloperStatus) {
            ContentView(previewStage: $previewStage)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        #endif
    }

    // blockDuration is deliberately not re-read here, unlike every other row: this screen's Menu is
    // the only writer of that key, so a re-read could only ever assign the same value — while the
    // assignment itself would be indistinguishable from a user choice to .onChange and re-register
    // a window on a sheet dismissal.
    @MainActor
    private func reconcileAndRefresh() {
        BlockWindowReconciler.reconcile()
        scheduledAlarm = WakeAlarmStore.scheduledAlarm()
        bedtime = BedtimeStore.bedtime()
        selectedActivityCount = FamilyActivitySelectionStore.selectedActivityCount()
        reachedMornings = MilestoneStore.reachedMornings()
        protectedSeconds = ProtectedTimeStore.accrue()
    }

    // docs/design/palette.md: charcoal-green cannot reach AA's 4.5:1 for small text on this palette at any
    // alpha, so every line on this screen sits in the large-text category instead (>=14 pt at
    // weight 700, bar 3:1). Hierarchy runs down the 17 > 15 size ladder, never down alpha.
    // No action means the row states something instead of leading somewhere (Fortschritt): same
    // fonts, same palette colour, no chevron, and no Button — .disabled() would dim the label,
    // which is the alpha-on-text the contrast budget above has no room for.
    @ViewBuilder
    private func row(title: LocalizedStringKey, value: String, action: (() -> Void)? = nil) -> some View {
        if let action {
            Button(action: action) {
                rowLabel(title: title, value: value, glyph: "chevron.right")
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isButton)
        } else {
            rowLabel(title: title, value: value, glyph: nil)
        }
    }

    // Third variant of the settings row: three fixed values and no screen of its own, so the choice
    // resolves in place instead of behind a sheet. Same rowLabel as every other row — only the
    // trailing glyph differs, because chevron.right would promise a screen this row does not have.
    private var durationRow: some View {
        Menu {
            Picker("Länge", selection: $blockDuration) {
                ForEach(MorningBlockDuration.allCases, id: \.self) { duration in
                    Text(duration.label).tag(duration)
                }
            }
        } label: {
            rowLabel(title: "Länge", value: blockDuration.label, glyph: "chevron.up.chevron.down")
        }
        .accessibilityAddTraits(.isButton)
        // Writing the setting is only half of it: startMonitoring is the only place a new length
        // can reach the system, and the already-registered window still carries the old one. The
        // choice is always stored right here; whether it also reaches the system now depends on
        // the running window (see BlockWindowReconciler.applyPendingMorningDuration).
        .onChange(of: blockDuration) {
            MorningBlockDurationStore.store(blockDuration)
            BlockWindowReconciler.applyPendingMorningDuration()
        }
    }

    // The same Menu-in-the-row form as durationRow, for the same reason: a handful of fixed values
    // and no screen of its own. Only the earned variants are listed — a locked one is not a row
    // that says "later", it is simply not there yet, and the celebration line is what announces it.
    private var colorRow: some View {
        Menu {
            Picker("Farbe", selection: $colorVariant) {
                ForEach(unlockedColorVariants, id: \.self) { variant in
                    Text(variant.displayName).tag(variant)
                }
            }
        } label: {
            rowLabel(title: "Farbe", value: colorVariant.displayName, glyph: "chevron.up.chevron.down")
        }
        .accessibilityAddTraits(.isButton)
        // The store refuses a locked variant on write, so this can only ever store what the menu
        // above offered. GutenMorgenView re-reads the selection when this sheet closes.
        .onChange(of: colorVariant) { MilestoneStore.selectColorVariant(colorVariant) }
    }

    // Which face the portrait shows, and the reason it is a decision rather than a constant: at
    // stage "Start" the rig draws closed eyes over the sleeping mouth — `MascotView`'s own
    // `eyeState`/`mouthShape` reduce to exactly that pair — so an unconditional `.waiting` put an
    // awake, smiling animal on the row about a user's first six mornings while the morning screen
    // showed that same user a sleeping one. The app icon is allowed its fixed stage because "noch
    // kein Nutzer daranhängt"; here one does.
    //
    // No new stage-to-face mapping is introduced and none may be: `stage.eyesOpen` is the mapping
    // the mechanic already has, and stage 0 gets back exactly the face it has everywhere else
    // (see the boundary in MascotExpression.swift).
    //
    // A function, and internal rather than private, because a SwiftUI body is not reachable from a
    // test and this project has no view-inspection layer — the decision lives where
    // `MascotProgressSurfaceExpressionTests` can pin it per stage.
    static func progressPortraitExpression(at stage: MascotStage) -> MascotExpression {
        stage.eyesOpen ? .waiting : MascotExpression(eyes: .closed, mouth: .sleeping)
    }

    // In this section rather than "Dein Tuck": that one appears only after 45 mornings
    // (Shared/MascotMilestone.swift) and shows a colour picker, not a way. "Dein Weg" is always
    // there and already carries the sentence about the user's progress - it just had no trace of
    // who that progress belongs to.
    //
    // `.waiting`: open eyes, a sideways glance, a neutral mouth. Present without asking for
    // anything, which is what a settings screen is owed — but only where the stage has open eyes
    // to give. Which face, see `progressPortraitExpression(at:)`.
    //
    // The real stage, never a fixed one. The same contour override as the breathing circle, for
    // the same reason and with the same honest limit: every section here sits on
    // `Color.tuckSage.opacity(0.25)`, and a sage body on that is 1,1259:1.
    //
    // Hidden from VoiceOver: the row below states the progress in words, and this is the same fact
    // as a picture. A second element saying it again would only be a second stop on the rotor.
    private var progressPortrait: some View {
        let stage = MascotStage.stage(forCompletedMornings: reachedMornings)
        return MascotPose(
            expression: Self.progressPortraitExpression(at: stage),
            sproutStage: stage.sproutStage,
            ink: colorVariant.color,
            saturation: stage.saturation,
            cheekOpacity: stage.cheekOpacity,
            bodyOutlineInk: MascotGeometry.onSageBodyOutlineInk,
            bodyOutlineWidth: MascotGeometry.onSageBodyOutlineWidth,
            earOutlineInk: MascotGeometry.onSageEarOutlineInk,
            earOutlineWidth: MascotGeometry.onSageEarOutlineWidth,
            stemOutlineInk: MascotGeometry.onSageStemOutlineInk
        )
        .frame(width: MascotGeometry.rigWidth, height: MascotGeometry.rigHeight)
        .scaleEffect(MascotGeometry.settingsRowRigScale)
        // The scaled box, so the row is as tall as the drawing and not as tall as the rig's canvas.
        .frame(width: MascotGeometry.rigWidth * MascotGeometry.settingsRowRigScale,
               height: MascotGeometry.rigHeight * MascotGeometry.settingsRowRigScale)
        .frame(maxWidth: .infinity)
        // The sprout stands above the rig's own frame, the way it does everywhere else; the padding
        // is what keeps it from meeting the row's edge.
        // Grund: der Abstand gehört zum Rig, nicht zur Layout-Skala — er misst, wie weit der
        // Spross über den eigenen Rahmen des Tiers hinaussteht, und folgt einer künftigen
        // Rig-Höhe, nicht einem Sektionsabstand.
        .padding(.vertical, 10)
        .accessibilityHidden(true)
    }

    // The one place the badges are seen: a row beside the count they belong to, not a gallery. They
    // unlock nothing and mean nothing beyond having been there, so a screen of their own would give
    // them a weight they do not have. The leaf is the mascot's own growth mark, and it is the
    // one glyph in this list that is neither of the two chevrons — this row leads nowhere and
    // opens nothing, so it carries no affordance to be confused with. The title is the word the
    // celebration line already used ("Ein Blatt für unseren Weg"), not "Abzeichen": a badge is the
    // trophy vocabulary the app rules out, and these mark a stretch of mornings rather than an
    // achievement.
    private var badgeRow: some View {
        rowLabel(title: "Blätter",
                 value: badges.map(\.displayName).joined(separator: " · "),
                 glyph: "leaf.fill")
    }

    private func rowLabel(title: LocalizedStringKey, value: String, glyph: String?) -> some View {
        HStack {
            Text(title)
                .font(.body.weight(.bold))
            Spacer()
            Text(value)
                .font(.subheadline.weight(.bold))
                .multilineTextAlignment(.trailing)
            if let glyph {
                Image(systemName: glyph)
                    .font(.caption.weight(.bold))
                    .accessibilityHidden(true)
            }
        }
        .fontDesign(.rounded)
        .foregroundStyle(Color.tuckCharcoalGreen)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func header(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.subheadline.weight(.bold))
            .fontDesign(.rounded)
            .foregroundStyle(Color.tuckCharcoalGreen)
            .textCase(nil)
    }

    // The one place on this screen that is not a value and not a title. It used to carry
    // the exact token of the values it explains — `.subheadline.weight(.bold)` on charcoal green —
    // so eight explanations sat at the same rank as the eight settings they belong to, and the
    // screen read as one continuous block of equally loud prose. It was not a rule violation: the
    // contrast rule required weight 700 because charcoal green reaches only 3,96:1. `tuckInk` is
    // what removes the requirement, and weight 400 is what finally makes a footer look like a footer.
    private func footer(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.subheadline.weight(.regular))
            .fontDesign(.rounded)
            .foregroundStyle(Color.tuckInk)
    }

    private var wakeValue: String {
        guard let scheduledAlarm else { return StatusCopy.unsetValue }
        return Self.timeFormatter.string(from: scheduledAlarm.fireDate)
    }

    // A bare "22:30" beside "Bettzeit" reads as an evening that is covered, and behind the gate it
    // is not — but hiding the time behind "Teil von Plus" hid the user's own input from them,
    // and it is the only place that value is visible at all. So the lock rides along with it, in the
    // interpunct form the trial line uses: the value stays, the row still never claims the evening.
    private var bedtimeValue: String {
        guard let bedtime,
              let date = Calendar.current.date(
                  from: DateComponents(hour: bedtime.time.hour, minute: bedtime.time.minute)
              )
        else { return access.hasPlusAccess ? StatusCopy.unsetValue : String(localized: "Teil von Plus") }

        let time = Self.timeFormatter.string(from: date)
        return access.hasPlusAccess ? time : String(localized: "\(time) · Teil von Plus")
    }

    // On the row that costs money: before StoreKit has answered, a cached tier is a guess
    // wearing the face of a confirmed state. The paywall already has a line for exactly this
    // moment, so this row shows the same one rather than a second wording.
    //
    // Every branch is written out here instead of delegating to a shared displayName: an earlier
    // version did exactly that, off a property compiled into the shield extension too, so its
    // literals were raw German that no catalog was ever asked about — rendering it in this row
    // left an English user with a German status line for the entire trial. Same per-case
    // String(localized:) shape as PaywallView's statusTitle, which is where the trial line's
    // translated plural already comes from. The property itself is gone now, not just unused.
    private var subscriptionValue: String {
        guard subscriptions.entitlement != .unresolved else { return String(localized: "Noch keine Antwort") }
        switch access {
        // The product name, identical in both languages — a catalog key for it would only invite
        // someone to translate it.
        case .subscribed(let tier): return tier.displayName
        case .trial(let daysRemaining): return String(localized: "Testphase · noch \(daysRemaining) Tage")
        case .free: return String(localized: "Frei · \(UnlockQuotaStore.morning.freeUnlockMaximum) pro Tag")
        }
    }

    private var appSelectionValue: String {
        selectedActivityCount == 0
            ? StatusCopy.emptyCount
            : String(localized: "\(selectedActivityCount) ausgewählt")
    }

    #if DEBUG
    // The foreground half of the device gate. The stored selection, so what is written is what the
    // window would write — an empty one writes four nils and blocks nothing, which is exactly the
    // reading the protocol warns about.
    private func writeShieldNow() {
        guard let selection = FamilyActivitySelectionStore.load() else { return }
        ShieldApplication.apply(selection, to: .morningBlock)
    }
    #endif

    // The visible number sequence and the legend that names each of its numbers, built in one place
    // from one read: two reads could disagree, and a legend that names other numbers than the row
    // shows is worse than no legend.
    struct DiagnosticLine {
        let value: String
        let label: String
    }

    static func morningDiagnostics(
        in defaults: UserDefaults = UserDefaults(suiteName: TuckIdentifiers.appGroupSuiteName) ?? .standard
    ) -> DiagnosticLine {
        DiagnosticLine(
            value: BlockDiagnostics.morningSummary(in: defaults),
            label: String(localized: "Diagnose Morgen: \(BlockDiagnostics.count(of: .morningWindowsRegistered, in: defaults)) Fenster eingetragen, \(BlockDiagnostics.count(of: .morningIntervalsStarted, in: defaults)) Intervalle gestartet, \(BlockDiagnostics.count(of: .morningShieldsApplied, in: defaults)) Shields geschrieben, \(BlockDiagnostics.count(of: .morningCallbacksMissing, in: defaults)) ohne Rückmeldung, \(BlockDiagnostics.count(of: .weekdaysSkipped, in: defaults)) Tage übersprungen")
        )
    }

    static func bedtimeDiagnostics(
        in defaults: UserDefaults = UserDefaults(suiteName: TuckIdentifiers.appGroupSuiteName) ?? .standard
    ) -> DiagnosticLine {
        DiagnosticLine(
            value: BlockDiagnostics.bedtimeSummary(in: defaults),
            label: String(localized: "Diagnose Abend: \(BlockDiagnostics.count(of: .bedtimeWindowsRegistered, in: defaults)) Fenster eingetragen, \(BlockDiagnostics.count(of: .bedtimeIntervalsStarted, in: defaults)) Intervalle gestartet, \(BlockDiagnostics.count(of: .bedtimeShieldsApplied, in: defaults)) Shields geschrieben, \(BlockDiagnostics.count(of: .bedtimeCallbacksMissing, in: defaults)) ohne Rückmeldung")
        )
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("HH:mm")
        return formatter
    }()
}

#Preview {
    SettingsView(previewStage: .constant(nil))
        .environment(SubscriptionController())
}
