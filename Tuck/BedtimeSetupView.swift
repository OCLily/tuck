import SwiftUI

// Same wheel-picker-plus-button shape and the same status-line conventions as WakeAlarmSetupView.
// Opt-in and additive: bedtime is never a precondition for anything, and an unset bedtime shows
// the same calm "—" as an unset alarm rather than nagging.
//
// Plus-only: the gate sits here rather than at the two call sites,
// so the onboarding step and the settings sheet cannot drift into two answers for one question.
struct BedtimeSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var scheduler = BedtimeScheduler()
    @State private var bedtime: Date
    @State private var hasStoredBedtime: Bool
    // The app's own gate, not StoreKit's answer: a running trial grants the window without any
    // entitlement ever having existed.
    //
    // Reaching this screen is one of the two things that start the trial. Read in the
    // State initialiser rather than from a .task, because a .task runs after the first render and
    // would flash the locked branch at somebody who is about to be granted the window. The write
    // behind it is idempotent, which is what makes it safe to sit on a path SwiftUI may re-enter.
    //
    // It is arrival, not the tap on "Bettzeit setzen": the picker is behind the gate, so a trigger
    // on the act itself could never fire — nobody without access can reach the button that would
    // grant it. Arrival is the honest reading anyway. Getting here means the Screen Time prompt was
    // answered, apps were picked and a wake time was set, or else the settings row was tapped by
    // name; none of that is the shrug that launching the app is.
    @State private var access = TrialTrigger.plusBoundaryReached()
    @State private var showPaywall = false
    @State private var trialNotice: TrialNotice?

    init() {
        let stored = BedtimeStore.bedtime()
        let fallback = Calendar.current.date(from: DateComponents(hour: 22, minute: 30))
        _bedtime = State(initialValue: stored.flatMap(Self.date(from:)) ?? fallback ?? .now)
        _hasStoredBedtime = State(initialValue: stored != nil)
    }

    var body: some View {
        // The other Plus boundary carries the same three sentences as the first. Above both
        // branches, because a trial that ends is exactly as true for somebody looking at the gate as
        // for somebody looking at the picker behind it. The 24 pt are this screen's own inset — its
        // hosts (the onboarding step, the settings sheet) set none, which is why every wrapping line
        // below carries the same number by hand.
        VStack(spacing: Layout.section) {
            if let trialNotice {
                TrialNoticeBanner(notice: trialNotice)
                    .padding(.horizontal, Layout.textInset)
            }
            if access.hasPlusAccess {
                setup
            } else {
                locked
            }
        }
        // After the State initialiser above has already asked the boundary question, which is what
        // may have started the fourteen days this line then reports. Consumed rather than read, so
        // it is shown exactly once.
        .task { trialNotice = TrialNotice.consume() }
        // Buying from inside the gate has to open the screen behind it without a relaunch — the
        // same re-read SettingsView runs when its own paywall closes.
        .sheet(isPresented: $showPaywall, onDismiss: { access = SubscriptionAccess.current() }) {
            PaywallView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    // The gate: what the window does, and where it is available. Deliberately no claim about
    // tonight — whether a window stored earlier is still armed is what the status line says, and it
    // says it from the registration flag rather than from the access state.
    private var locked: some View {
        VStack(spacing: Layout.section) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.tuckSage)
                .accessibilityHidden(true)

            Text("Das Bettzeit-Fenster gehört zu Plus")
                .font(.title3.weight(.semibold))
                .fontDesign(.rounded)
                .multilineTextAlignment(.center)

            Text("30 Minuten vor und 30 nach deiner Bettzeit bleiben dieselben Apps ruhig wie morgens. Mit Plus stellst du die Zeit hier ein.")
                .font(.subheadline.weight(.regular))
                .fontDesign(.rounded)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.tuckInk)
                .padding(.horizontal, Layout.textInset)

            // The sage plate, not the charcoal one: this screen is embedded in the onboarding step, whose
            // "Weiter" is the one primary action there, and two filled plates in one screen state
            // is exactly what the design system rules out. Modifiers on the label rather than on the
            // Button, for the reason it spells out — outside it they grow the plate, not the hit area.
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

            if hasStoredBedtime {
                Text(Self.windowSentence(BedtimeStore.bedtime()))
                    .font(.subheadline.weight(.regular))
                    .fontDesign(.rounded)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.tuckInk)
                    .padding(.horizontal, Layout.textInset)

                // The gate keeps the stored bedtime on purpose — it is the intent, not the
                // entitlement (BlockWindowReconciler.bedtimeWindowAction) — but the only way to
                // remove one sat in the branch this user cannot reach: an expired trial left a
                // bedtime that could not be deleted and armed itself again on the next
                // subscription. Same one path as the setup branch, nothing gate-specific about it.
                Button {
                    scheduler.clearBedtime()
                    hasStoredBedtime = false
                } label: {
                    // The frame sits on the label, not on the Button — hung outside it
                    // grows the layout box and leaves the hit area on the line box.
                    Text("Bettzeit entfernen")
                        .frame(minHeight: Layout.hitMin)
                        .contentShape(Rectangle())
                }
                .font(.subheadline.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(Color.tuckCharcoalGreen)
            } else if scheduler.status == .cleared {
                Text(Self.bedtimeRemovedLine)
                    .font(.subheadline.weight(.regular))
                    .fontDesign(.rounded)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.tuckInk)
                    .padding(.horizontal, Layout.textInset)
            }
        }
        .foregroundStyle(Color.tuckCharcoalGreen)
    }

    private var setup: some View {
        VStack(spacing: Layout.section) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.tuckSage)
                .accessibilityHidden(true)

            Text("Wann gehst du ins Bett?")
                .font(.title3.weight(.semibold))
                .fontDesign(.rounded)

            DatePicker("Bettzeit", selection: $bedtime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()

            Button {
                scheduler.setBedtime(bedtime)
                hasStoredBedtime = true
            } label: {
                // Same working state as WakeAlarmSetupView, built the same way: the design system has one
                // definition for it, and this button carried two thirds of it. How long it is on
                // screen is a scheduler question, not a button one — setBedtime resolves inside
                // one main-actor turn today, so the same caveat already applies to the label text
                // that has been switching here since this screen was built.
                HStack(spacing: Layout.pair) {
                    if scheduler.status == .working {
                        ProgressView()
                    }
                    Text(scheduler.status == .working ? "Bettzeit wird gesetzt …" : "Bettzeit setzen")
                }
                // On the label like the "Plus ansehen" plate above: hung outside the Button
                // they left a 51,33 pt plate exposing a 19,33 pt accessibility element.
                .font(.body.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(Color.tuckCharcoalGreen)
                .padding()
                // Same disabled surface as the wake plate: the plate swaps, the ink stays.
                .background(
                    RoundedRectangle(cornerRadius: Layout.radiusPlate)
                        .fill(scheduler.status == .working
                              ? Color.tuckDisabledPlate
                              : Color.tuckSage.opacity(0.5))
                )
            }
            .disabledWithOwnAppearance(scheduler.status == .working)

            if hasStoredBedtime {
                Button {
                    scheduler.clearBedtime()
                    hasStoredBedtime = false
                } label: {
                    Text("Bettzeit entfernen")
                        .frame(minHeight: Layout.hitMin)
                        .contentShape(Rectangle())
                }
                .font(.subheadline.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(Color.tuckCharcoalGreen)
            }

            // Charcoal green cannot reach AA's 4.5:1 for small text on this palette at any alpha,
            // which is why this line used to sit in the large-text category (>=14 pt at weight 700).
            // `tuckInk` reaches 5,26:1 on cream, so the status line no longer
            // has to buy its legibility with weight — and stops being set heavier than the question
            // above it. The primary button keeps the hierarchy through its 17 pt and its sage plate,
            // never through alpha on the text below it.
            statusLine
                .font(.subheadline.weight(.regular))
                .fontDesign(.rounded)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.tuckInk)
                .padding(.horizontal, Layout.textInset)
        }
        .foregroundStyle(Color.tuckCharcoalGreen)
    }

    @ViewBuilder
    private var statusLine: some View {
        switch scheduler.status {
        case .idle:
            if let stored = BedtimeStore.bedtime() {
                Text(Self.windowSentence(stored))
            } else {
                Text("Optional. 30 Minuten vor und 30 nach deiner Bettzeit bleiben die gleichen Apps ruhig wie morgens.")
            }
        case .working:
            Text(StatusCopy.waitingForSystem)
        case .scheduled:
            // Deliberately about the window, not about the shield: a ManagedSettings write reports
            // nothing back, so the app can never truthfully say "gesperrt" here.
            Text(Self.windowSentence(BedtimeStore.bedtime()))
        case .cleared:
            Text(Self.bedtimeRemovedLine)
        case .unavailable(let reason):
            Text(StatusCopy.failure(subject: String(localized: "Das Bettzeit-Fenster"),
                                    verb: String(localized: "scharf stellen"),
                                    reason: reason))
        }
    }

    // One sentence for one state: both branches can remove a bedtime now. Same honesty line as the
    // arm side, one direction further — what ran is BedtimeStore.clear plus a silent ManagedSettings
    // clear, so it may state this app's own store and nothing about the evening.
    private static var bedtimeRemovedLine: String {
        String(localized: "Bettzeit entfernt. Für den Abend ist nichts mehr eingetragen.")
    }

    private static func date(from bedtime: BedtimeStore.Bedtime) -> Date? {
        Calendar.current.date(from: DateComponents(hour: bedtime.time.hour, minute: bedtime.time.minute))
    }

    private static func window(_ bedtime: BedtimeStore.Bedtime?) -> String {
        guard let bedtime else { return "—" }
        return MorningBlockWindowFormatter.range(start: bedtime.blockWindowStart, end: bedtime.blockWindowEnd)
    }

    // Survives the sheet the way the transient .unavailable status does not: a registration that
    // failed in an earlier session is only readable from the stored flag. The evening window shields
    // the same selection as the morning one, so the empty-picker branch is the same here.
    private static func windowSentence(_ bedtime: BedtimeStore.Bedtime?) -> String {
        guard BedtimeStore.blockRegistrationSucceeded() else { return StatusCopy.windowPending(window(bedtime)) }
        return FamilyActivitySelectionStore.selectedActivityCount() == 0
            ? StatusCopy.windowWithoutApps(window(bedtime))
            : String(localized: "\(StatusCopy.blockWindowNoun) um deine Bettzeit: \(window(bedtime)).")
    }
}

#Preview {
    BedtimeSetupView()
        .environment(SubscriptionController())
}
