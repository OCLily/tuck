import AlarmKit
import SwiftUI

// Both routes into "the alarm permission is denied": the refusal that just came back from the iOS
// dialog, and a fresh open after an earlier refusal, where the status is idle and nothing was ever
// stored. Same state, so one sentence and one way out — modelled as a pure function for the same
// reason FamilyControlsAccessState is, since AlarmKit never authorizes in the Simulator.
@MainActor
enum WakeAlarmPermission {
    static func isDenied(
        status: WakeAlarmScheduler.Status,
        authorizationState: AlarmManager.AuthorizationState,
        hasStoredAlarm: Bool
    ) -> Bool {
        if status == .denied { return true }
        return status == .idle && !hasStoredAlarm && authorizationState == .denied
    }
}

struct WakeAlarmSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var scheduler = WakeAlarmScheduler()
    @State private var wakeTime: Date
    @State private var weekdays: Set<WakeAlarmWeekday>
    @State private var showAppSelection = false
    @State private var showCancelConfirmation = false
    // Written for the host, the same shape FamilyControlsAccessSection hands its status up: the
    // onboarding step gates its "Weiter" on a stored alarm, and only this view learns when one
    // appears. Both other call sites present this view without a gate and pass nothing.
    @Binding private var isAlarmStored: Bool

    init(isAlarmStored: Binding<Bool> = .constant(false)) {
        _isAlarmStored = isAlarmStored
        let stored = WakeAlarmStore.scheduledAlarm()?.fireDate
        let fallback = Calendar.current.date(from: DateComponents(hour: 7, minute: 0))
        _wakeTime = State(initialValue: stored ?? fallback ?? .now)
        _weekdays = State(initialValue: WakeAlarmWeekdayStore.selected())
    }

    var body: some View {
        VStack(spacing: Layout.section) {
            Image(systemName: "alarm.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.tuckSage)
                .accessibilityHidden(true)

            Text("Wann weckt dich Tuck?")
                .font(.title3.weight(.semibold))
                .fontDesign(.rounded)

            DatePicker("Weckzeit", selection: $wakeTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()

            weekdayRow

            Button {
                Task { await scheduler.scheduleWakeAlarm(wakeTime: wakeTime, weekdays: weekdays) }
            } label: {
                // Modifiers on the label, not on the Button: outside it they drew a 51,33 pt
                // plate around a 19,33 pt element — VoiceOver, Voice Control and Switch Control all
                // landed on the text, and the 16 pt of visible plate around it was not tappable.
                HStack(spacing: Layout.pair) {
                    if scheduler.status == .working {
                        ProgressView()
                    }
                    Text(scheduler.status == .working ? "Wecker wird gestellt …" : "Wecker stellen")
                }
                // Weight 700, not .medium: the sage plate puts this label at 3.67:1, the weakest
                // actionable ground in the app, so it only clears the contrast rule through the large-text path.
                .font(.body.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(Color.tuckCharcoalGreen)
                .padding()
                // The disabled surface is the one the whole app uses: the plate swaps, the
                // ink does not, because this plate's own label token already resolves to the
                // disabled ink in both appearances.
                .background(
                    RoundedRectangle(cornerRadius: Layout.radiusPlate)
                        .fill(scheduler.status == .working
                              ? Color.tuckDisabledPlate
                              : Color.tuckSage.opacity(0.5))
                )
            }
            .disabledWithOwnAppearance(scheduler.status == .working)

            VStack(spacing: Layout.pair) {
                // The two prose children of this block carry the token per child rather than the
                // block carrying it for them: the same VStack holds two secondary buttons, and a
                // font/colour swap on the container would have pulled those down to body weight
                // too. The ink token is a role split, not a screen-wide repaint.
                statusLine
                    .font(.subheadline.weight(.regular))
                    .foregroundStyle(Color.tuckInk)
                // The way back the denied line names, on both of its paths — the permission lives
                // in the Settings app, and the sage plate above cannot ask for it a second time
                // once iOS has the answer.
                if permissionIsDenied {
                    OpenSystemSettingsButton()
                }
                if let blockRegistrationError = scheduler.blockRegistrationError {
                    // Never phrased as "the block is active": the schedule is what failed here,
                    // and a ManagedSettings write gives no success signal to claim either.
                    Text(StatusCopy.failure(subject: String(localized: "Das \(StatusCopy.blockWindowNoun)"),
                                            verb: String(localized: "scharf stellen"),
                                            reason: blockRegistrationError))
                        .font(.subheadline.weight(.regular))
                        .foregroundStyle(Color.tuckInk)
                }
                // Second level, below this screen's one plate, and only where there is
                // something to switch off. Behind a confirmation because the mistake it prevents is
                // the one this app cannot make good: an alarm silently gone in the evening is a
                // morning that does not happen.
                // The frame sits on the label, inside the Button, so the hit area is the whole line. The
                // dialog's own "Wecker ausschalten" below keeps the shorthand form on purpose: iOS draws
                // and sizes confirmationDialog buttons itself. The comment sits above the gate, not
                // between it and the button: WakeAlarmCancellationTests measures that distance to pin
                // the button to its condition.
                if scheduler.status != .working, WakeAlarmStore.scheduledAlarm() != nil {
                    Button { showCancelConfirmation = true } label: {
                        Text("Wecker ausschalten")
                            .frame(minHeight: Layout.hitMin)
                            .contentShape(Rectangle())
                    }
                }
                if Self.windowIsPending {
                    // The remedy for a window that is stored but not armed is the Family-Controls
                    // access, and nothing led there from any of the three screens that show the
                    // pending line. It hangs off the line rather than off the error above because
                    // the error lives for one turn and the line outlives the session. Second
                    // level: the sage plate above is this screen's one action.
                    Button { showAppSelection = true } label: {
                        Text("Bildschirmzeit-Zugriff prüfen")
                            .frame(minHeight: Layout.hitMin)
                            .contentShape(Rectangle())
                    }
                }
            }
            // What is left on this block after the two prose children took `tuckInk` above: the two
            // secondary buttons. AA's 4.5:1 for small text is unreachable with charcoal-green here
            // at any alpha, so they sit in the large-text category (>=14 pt at weight 700, bar 3:1).
            // The block carried 0.7 alpha before — which put the failure message, the one line that
            // must not be missed, at the worst contrast on the screen.
            .font(.subheadline.weight(.bold))
            .fontDesign(.rounded)
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.tuckCharcoalGreen)
            .padding(.horizontal, Layout.textInset)
        }
        .foregroundStyle(Color.tuckCharcoalGreen)
        .task {
            await scheduler.refreshAuthorizationState()
            isAlarmStored = WakeAlarmStore.scheduledAlarm() != nil
        }
        .onChange(of: scheduler.status) {
            isAlarmStored = WakeAlarmStore.scheduledAlarm() != nil
            // Only meaningful when this view is sheet-presented (from SettingsView) - when
            // it's embedded inline in OnboardingFlowView there is no enclosing presentation, so
            // dismiss() is a harmless no-op and the onboarding flow's own "Weiter" button still
            // drives progress there. Brief delay so the confirmation text is actually readable
            // before the sheet closes, instead of the two happening at the same instant. Kept
            // alongside the drag indicator: that one is the way out at any moment, this
            // one is the courtesy after the one moment there is nothing left to do here.
            // Only when both halves went through: an alarm whose block window threw is the one
            // moment the reason has to stay readable, and closing over it after 1,2 s left the
            // user unarmed without ever learning why.
            guard scheduler.status.isScheduledWithArmedWindow else { return }
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                dismiss()
            }
        }
        // The same nested presentation BedtimeSetupView uses for its paywall, for the same reason:
        // this view also runs inline in onboarding, where it has no presentation of its own to
        // hand the job back to. Reconciling on dismissal is what makes it a remedy rather than a
        // detour — granting the access is the moment a stored window can finally be armed, and a
        // sheet dismissal brings no scenePhase change with it.
        .confirmationDialog("Wecker ausschalten?", isPresented: $showCancelConfirmation, titleVisibility: .visible) {
            Button("Wecker ausschalten") {
                Task { await scheduler.cancelWakeAlarm() }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            // What actually goes away, both halves of it — the alarm and the window are set in one
            // step and are taken back in one step, and only naming both keeps the second from being
            // a surprise the next morning.
            Text("Der Wecker klingelt dann nicht mehr, und das Sperrfenster danach fällt mit weg.")
        }
        .sheet(isPresented: $showAppSelection, onDismiss: { BlockWindowReconciler.reconcile() }) {
            AccessAndAppSelectionView()
                .padding()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    // Seven toggles rather than a "Werktags/Wochenende" pair: AlarmKit takes a real subset, so a
    // preset would only hide which days it actually holds. Ordered by the locale's own first
    // weekday and labelled out of the calendar's own symbols — no second copy of the weekday names
    // for anyone to translate, and no assumption that the week starts on Monday.
    private var weekdayRow: some View {
        VStack(spacing: Layout.pair) {
            // Grund: sieben Trefferflächen auf einer Bildschirmbreite — jeder Wert der Skala macht
            // die einzelne Wochentagsfläche schmaler als die 44 pt, die sie tragen muss.
            HStack(spacing: 4) {
                ForEach(Self.orderedWeekdays, id: \.self) { day in
                    weekdayToggle(day)
                }
            }
            // The half of this control that is not obvious: the block window follows the alarm, so
            // a day switched off here is a day the phone stays open. Without the sentence the
            // setting reads as an alarm setting alone.
            // 15 pt, not the `.footnote` this line was written with: the type scale keeps `.footnote` out of
            // running text at any weight, and the Fließtext token is one size — 15 pt at weight 400
            // on `tuckInk`. Left at 13 pt this was the one converted site off the app's size ladder.
            Text("An den anderen Tagen bleibt auch das Sperrfenster aus.")
                .font(.subheadline.weight(.regular))
                .fontDesign(.rounded)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.tuckInk)
        }
        .padding(.horizontal, Layout.textInset)
    }

    private func weekdayToggle(_ day: WakeAlarmWeekday) -> some View {
        let isOn = weekdays.contains(day)
        return Button {
            toggle(day)
        } label: {
            // Modifiers on the label rather than on the Button, same as the plate below.
            Text(Self.shortLabel(day))
                .font(.subheadline.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(Color.tuckCharcoalGreen)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, minHeight: Layout.hitMin)
                // Diese beiden Radien standen zuvor auf 12 — ein Wert, den das Design-System längst
                // abgeschafft hatte. Die Zeile entstand erst danach, ohne den Entscheid zu kennen.
                // Kein Rückschritt, sondern der Beleg, dass eine Entscheidung ohne Mechanismus
                // nur so lange hält, wie sie jemand
                // erinnert. Ein Wochentag trägt eine Handlung, also Plate.
                .background(
                    RoundedRectangle(cornerRadius: Layout.radiusPlate)
                        .fill(isOn ? Color.tuckSage : Color.tuckSage.opacity(0.15))
                )
                // The unselected day is not a disabled control — it stays tappable and has to keep
                // reading as one, which the pale plate alone does not carry.
                .overlay(
                    RoundedRectangle(cornerRadius: Layout.radiusPlate)
                        .strokeBorder(Color.tuckSage, lineWidth: isOn ? 0 : 1.5)
                )
        }
        .accessibilityLabel(Self.fullLabel(day))
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    // The last remaining day cannot be switched off here: an empty selection is an alarm that never
    // rings under a screen that still says one is set. Switching everything off is a different
    // control — "Wecker ausschalten" below, which takes the block window with it.
    private func toggle(_ day: WakeAlarmWeekday) {
        if weekdays.contains(day) {
            guard weekdays.count > 1 else { return }
            weekdays.remove(day)
        } else {
            weekdays.insert(day)
        }
    }

    private static var orderedWeekdays: [WakeAlarmWeekday] {
        let first = Calendar.current.firstWeekday
        return (0..<7).compactMap { WakeAlarmWeekday(rawValue: (first - 1 + $0) % 7 + 1) }
    }

    private static func shortLabel(_ day: WakeAlarmWeekday) -> String {
        Calendar.current.shortWeekdaySymbols[day.rawValue - 1]
    }

    private static func fullLabel(_ day: WakeAlarmWeekday) -> String {
        Calendar.current.weekdaySymbols[day.rawValue - 1]
    }

    // "jeden Morgen" only when it is true. A subset named as "jeden Morgen" would be the silent
    // discrepancy in its purest form: the sentence claims six mornings the alarm will not ring on.
    static func daysPhrase(_ days: Set<WakeAlarmWeekday>) -> String {
        guard days != WakeAlarmWeekdayStore.everyDay else { return String(localized: "jeden Morgen") }
        return orderedWeekdays.filter(days.contains).map(shortLabel).formatted(.list(type: .and))
    }

    private var permissionIsDenied: Bool {
        WakeAlarmPermission.isDenied(
            status: scheduler.status,
            authorizationState: scheduler.authorizationState,
            hasStoredAlarm: WakeAlarmStore.scheduledAlarm() != nil
        )
    }

    // One sentence for one state, in the form settled on for the Family-Controls denial:
    // what is, the way back, the honest consequence. The two wordings this replaces both promised
    // something they cannot keep inside onboarding, where the "Weiter" is gated on a stored alarm —
    // one said "weiter geht es trotzdem", the other "bis dahin bleibt alles andere nutzbar".
    // Same opening as the Family-Controls denial ("fehlt noch"), for the same reason: one form for
    // one situation, and neither line reports a verdict on what the user did.
    private static var permissionDeniedLine: String {
        String(localized: "Die Erlaubnis für den Wecker fehlt noch. Du kannst sie in den Systemeinstellungen geben — ohne sie weckt Tuck dich nicht.")
    }

    // Outlives the transient blockRegistrationError the same way windowSentence does: after a
    // failed registration in an earlier session the flag is all that is left of it.
    private static var windowIsPending: Bool {
        WakeAlarmStore.scheduledAlarm() != nil && !WakeAlarmStore.blockRegistrationSucceeded()
    }

    @ViewBuilder
    private var statusLine: some View {
        switch scheduler.status {
        case .idle:
            if let stored = WakeAlarmStore.scheduledAlarm() {
                Text("Wecker klingelt \(Self.storedDaysPhrase) um \(Self.timeFormatter.string(from: stored.fireDate)). \(Self.windowSentence(stored))")
            } else if permissionIsDenied {
                Text(Self.permissionDeniedLine)
            } else {
                Text("Beim ersten Mal fragt iOS einmal nach Erlaubnis für Wecker.")
            }
        case .working:
            Text(StatusCopy.waitingForSystem)
        case .scheduled(let fireDate, _):
            Text("Wecker klingelt \(Self.storedDaysPhrase) um \(Self.timeFormatter.string(from: fireDate)). \(Self.windowSentence(WakeAlarmStore.scheduledAlarm()))")
        case .denied:
            Text(Self.permissionDeniedLine)
        case .unavailable(let reason):
            Text(StatusCopy.failure(subject: String(localized: "Der Wecker"),
                                    verb: String(localized: "stellen"),
                                    reason: reason))
        }
    }

    // The stored selection, not the row above it: the toggles are unapplied until the plate is
    // tapped, exactly like the time picker, and a status line built on them would describe an alarm
    // nobody scheduled.
    private static var storedDaysPhrase: String { daysPhrase(WakeAlarmWeekdayStore.selected()) }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("HH:mm")
        return formatter
    }()

    private static func window(_ alarm: WakeAlarmStore.ScheduledAlarm?) -> String {
        guard let alarm else { return "—" }
        return MorningBlockWindowFormatter.range(start: alarm.blockWindowStart, end: alarm.blockWindowEnd)
    }

    // Outlives the transient blockRegistrationError above: a registration that failed in an earlier
    // session leaves nothing behind but this flag, and the window must not read as armed then. The
    // second branch is the same claim on the other axis — a registration that succeeded over an
    // empty picker arms a schedule that shields nothing.
    private static func windowSentence(_ alarm: WakeAlarmStore.ScheduledAlarm?) -> String {
        guard WakeAlarmStore.blockRegistrationSucceeded() else { return StatusCopy.windowPending(window(alarm)) }
        return FamilyActivitySelectionStore.selectedActivityCount() == 0
            ? StatusCopy.windowWithoutApps(window(alarm))
            : String(localized: "\(StatusCopy.blockWindowNoun): \(window(alarm)).")
    }
}

enum MorningBlockWindowFormatter {
    static func range(start: DateComponents, end: DateComponents) -> String {
        "\(time(start))–\(time(end))"
    }

    static func endTime(_ components: DateComponents) -> String { time(components) }

    private static func time(_ components: DateComponents) -> String {
        String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
    }
}

#Preview {
    WakeAlarmSetupView()
}
