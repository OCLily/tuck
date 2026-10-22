import FamilyControls
import SwiftUI

// Not private any more: the resume rule below is the whole of the step persistence that can be
// reasoned about without a rendered view, so it has to be reachable from the tests.
enum OnboardingStep: Int, CaseIterable {
    case welcome, explain, permission, appSelection, wakeTime, bedtime, done

    // Anything this build does not know about starts over rather than lands nowhere: a raw value
    // from a newer build after a downgrade, or a key some other writer left behind. Falling back to
    // .welcome costs the taps of one flow; a nil would cost the screen.
    static func resuming(from rawValue: Int) -> OnboardingStep {
        OnboardingStep(rawValue: rawValue) ?? .welcome
    }

    // The flow used to have no way back at all: a mistyped wake time, a category tapped by
    // accident, and the only exit was finishing the flow and finding the same screen again in
    // settings. nil on the first step, where there is nothing behind.
    var previous: OnboardingStep? {
        OnboardingStep(rawValue: rawValue - 1)
    }
}

// Titles, glyphs and buttons keep charcoal green and its large-text path (>=14 pt at weight 700
// where the bar is 3:1) — on this gradient that colour cannot reach AA's 4.5:1 for small text at
// any alpha. The four body lines no longer have to: they sit on `tuckInk`,
// which reaches 4,80:1 on the gradient's own bottom stop — sage 0.6 over
// cream, the worst ground of this flow, pinned in BodyInkContrastTests — so the small-text
// threshold applies directly and they may fall to weight 400. Hierarchy runs down size *and*
// weight, never down alpha.
struct OnboardingFlowView: View {
    @AppStorage("hasCompletedOnboarding", store: TuckIdentifiers.appGroupDefaults)
    private var hasCompletedOnboarding = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // @State, not persistence, was the bug. Two
    // of the seven steps put a system dialog in front of the app — FamilyControls at .permission,
    // AlarmKit at .wakeTime — and the app is in the background while either one is up, where iOS
    // may terminate it. The user answered the dialog and came back to step one, with the permission
    // already granted and nothing on screen saying so.
    @AppStorage("onboardingStep") private var storedStep = OnboardingStep.welcome.rawValue

    // Which way the next step slides in from. Set in one place — the setter below — rather
    // than at each of the seven call sites, because a call site that forgets it would not break
    // anything visibly, it would just slide the wrong way: this project's own failure class.
    @State private var movingForward = true

    private var step: OnboardingStep {
        get { OnboardingStep.resuming(from: storedStep) }
        // The comparison has to read the current step before the assignment overwrites it — that
        // is the whole of the direction. `>=` and not `>`: a step set to where it already is is
        // not a way back.
        //
        // It compares against `step`, not against `storedStep`: the raw int is the one value in
        // this view that may be out of range (a newer build's step after a downgrade, a foreign
        // writer's key — the reason `resuming(from:)` exists at all), and everything else on
        // screen already goes through that sanitising. A stored 99 draws the welcome screen, so
        // the first "Los geht's" is a step forward from 0; read raw, it was 1 >= 99, false, and
        // the flow's very first tap slid in from the back-button side.
        nonmutating set {
            movingForward = newValue.rawValue >= step.rawValue
            storedStep = newValue.rawValue
        }
    }
    // Owned here rather than inside the section: the permission step's button title and the app
    // selection step's picker both read it, across two steps.
    @State private var authorizationStatus: AuthorizationStatus = .notDetermined
    // The wake step's gate. Written by WakeAlarmSetupView, because the alarm is only stored on a
    // path that lives inside it — and a user who tapped "Wecker stellen" and refused the iOS dialog
    // stores nothing, so the same gate holds for them without a case of its own.
    @State private var wakeAlarmIsStored = WakeAlarmStore.scheduledAlarm() != nil
    @State private var selectedActivityCount = FamilyActivitySelectionStore.selectedActivityCount()

    // The first content of every step starts this far below the safe area — fixed, not
    // earned by a Spacer. The header takes the first 44 of it, so the column below it
    // carries the remainder.
    private static let contentStartOffset: CGFloat = 96
    // Grund: keine Trefferfläche, sondern die Höhe der Kopfleiste — dass der Zurück-Pfeil sie
    // ausfüllt und damit die 44 pt der Mindestfläche erbt, ist die Folge, nicht die Definition. Bewusst
    // NICHT auf `Layout.hitMin` migriert: zwei unabhängige Entscheidungen, die zufällig dieselbe
    // Zahl tragen, dürfen sich nicht gemeinsam bewegen.
    private static let headerHeight: CGFloat = 44

    var body: some View {
        ZStack {
            // The same cream-to-sage movement the morning sky ends on (MorningSky.swift), now
            // deep enough to be seen — at 0.35 the flow announced nothing about where it leads.
            // Charcoal green on the bottom stop drops 3,75:1 -> 3,55:1 (recomputed), which
            // keeps every line of this flow inside its large-text band (>=14 pt at 700, bar 3:1).
            LinearGradient(
                colors: [Color.tuckCream, Color.tuckSage.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Grund: kein Abstand, nicht der kleinste — der Kopf und die Schrittspalte sind eine
            // Fläche, und jeder Wert über 0 macht aus ihr zwei. Die 0 ist die Aussage.
            VStack(spacing: 0) {
                header
                steps
            }
            .padding()
            // 0,6 s was a screen swap read as a slow fade; 0,25 s is the same movement at the
            // speed of a tap. This modifier is the only timing the step change has — it
            // drives the directional transition on `content` rather than an implicit crossfade.
            // The ScrollView identity is unchanged: the anchor below is still
            // constant, and still the only `.id` this file hands out.
            .animation(reduceMotion ? nil : .easeInOut(duration: Motion.stepOnboarding), value: step)
        }
    }

    // Outside the ScrollView on purpose: at accessibility text sizes a header inside it scrolls
    // away, and the way back would be gone exactly where the screens are hardest to read.
    private var header: some View {
        ZStack {
            stepDots
            HStack {
                if let previous = step.previous {
                    Button { step = previous } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.bold))
                            .fontDesign(.rounded)
                            .frame(width: Self.headerHeight, height: Self.headerHeight)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Zurück")
                }
                Spacer()
            }
        }
        .frame(height: Self.headerHeight)
        .foregroundStyle(Color.tuckCharcoalGreen)
    }

    // Seven dots rather than "Schritt 3 von 7": the position is the only thing the line said, and a
    // dot says it without a sentence to read. VoiceOver keeps the sentence.
    private var stepDots: some View {
        HStack(spacing: Layout.pair) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { dot in
                Circle()
                    .fill(dot == step ? Color.tuckCharcoalGreen : Color.tuckSage)
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Schritt \(step.rawValue + 1) von \(OnboardingStep.allCases.count)")
    }

    @ViewBuilder
    private var steps: some View {
        // The app selection step brings its own ScrollView and keeps "Weiter" outside it; a second
        // one on the same axis would leave the inner one without a height to scroll in.
        if step == .appSelection {
            VStack(spacing: Layout.root) { content }
                .padding(.top, Self.contentStartOffset - Self.headerHeight)
        } else {
            // Six of the seven steps render into this one ScrollView, whose identity survives the
            // step change — and so did its content offset: at accessibility text sizes every step
            // is taller than the screen, so the next one arrived mid-scroll with its glyph and its
            // title, the question the screen asks, already above the viewport (measured: -72 pt at
            // step 2, -227 pt at step 6). The anchor id is constant on purpose. `.id(step)` would
            // reset the offset too, but by discarding the ScrollView per step — and with it the
            // identity the 0.6 s step animation above cross-fades across.
            ScrollViewReader { proxy in
                VStack(spacing: Layout.root) { content }
                    .padding(.top, Self.contentStartOffset - Self.headerHeight)
                    .id(Self.topAnchor)
                    .scrollableWhenTallerThanScreen()
                    .onChange(of: step) { proxy.scrollTo(Self.topAnchor, anchor: .top) }
            }
        }
    }

    private static let topAnchor = "onboarding-step-top"

    private var content: some View {
        Group {
            switch step {
            case .welcome: welcome
            case .explain: explain
            case .permission: permission
            case .appSelection: appSelection
            case .wakeTime: wakeTimePicker
            case .bedtime: bedtimePicker
            case .done: done
            }
        }
        // No `.id(step)` here, and none anywhere in this file — the prohibition is flat, and it
        // survives untouched. An earlier build added one on the premise that the
        // transition would not fire without it; the premise was wrong twice over. A `switch` in a
        // `@ViewBuilder` is a `_ConditionalContent`, whose identity already changes with the
        // branch, which is the removal-and-insertion a `.transition` needs; and `Group` forwards
        // this modifier down to that child rather than putting a stable wrapper in front of it.
        // Filmed both ways with the id gone, 60 fps, and both directions still travel
        // (`docs/audit-log.md`).
        //
        // "Richtungsgebend". Timing stays with the `.animation(…, value: step)` in `body`
        // (0,25 s — the speed of a tap); this only gives it a direction to animate.
        // Move combined with opacity, not a bare slide: a hard slide reads mechanical, and the
        // flow's register is quiet. Under Reduce Motion the `.opacity` branch is what is left over
        // once the travel is gone, not a fade anyone gets to see: the `.animation(nil, …)` above
        // leaves the step change with no animation to interpolate, so the step change is a hard
        // cut — measured, zero in-between frames in a 60-fps capture (the design system's second Reduce
        // Motion pattern).
        //
        // The departing screen only fades, and that is not a matter of taste. A removal transition
        // is read off the view that is *going away*, which means it is read off that view's last
        // render — the one from before this change, where `movingForward` still held the direction
        // of the *previous* step change. Built with a directional removal here, the first tap on
        // "Zurück" after any number of forward taps sent the old screen out to the left while the
        // new one came in from the left as well: the two crossed, and the exit pointed forward on
        // a way back. Measured, not reasoned: 60-fps capture of that build, frames b153–b160 of
        // `back.mp4`, permission sliding leading-ward while explain arrived leading-ward behind it.
        // The insertion is the half that can be trusted, because it belongs to the view being
        // built right now — so the direction lives there alone.
        .transition(reduceMotion ? AnyTransition.opacity : .asymmetric(
            insertion: .move(edge: movingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .opacity
        ))
    }

    private var welcome: some View {
        // The leading Spacer of every step was half of a symmetric pair that centred four
        // lines in an 874 pt screen — two dead bands of ~33 % each, measured. Top alignment plus the
        // fixed offset above replaces it; the single Spacer before the button stays.
        VStack(spacing: Layout.section) {
            MascotView(stage: .start, saturation: MascotStage.start.saturation)
                // The tap here is cosmetic only — a no-op onTap, no bubble, no state change a
                // VoiceOver user could act on (contrast GutenMorgenView.swift, where the same tap
                // drives a real reply). Announcing it as a button would promise an action that
                // isn't there, so children: .ignore + a plain label, no .isButton, no
                // .accessibilityAction.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Tuck")
            Text("Tuck")
                .font(.largeTitle.weight(.semibold))
                .fontDesign(.rounded)
            // The purpose comes before the mechanism, and the sentence that carries it names the
            // feed rather than the reader: a line about how much time someone spent would
            // be the shame mechanism the app refuses. "Trägt ein" is the house word — what iOS makes of
            // a registered window is not something this screen may claim.
            Text("Der Morgen und der Abend sollen dir gehören, nicht dem Feed. Tuck trägt dafür zwei Sperrfenster ein — nach dem Wecker mindestens 30 Minuten, statt direkt Social Media.")
                .font(.subheadline.weight(.regular))
                .fontDesign(.rounded)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.tuckInk)
                .padding(.horizontal, Layout.textInset)
            Spacer()
            nextButton("Los geht's") { step = .explain }
        }
        .foregroundStyle(Color.tuckCharcoalGreen)
    }

    private var explain: some View {
        VStack(spacing: Layout.section) {
            // A 40 pt system glyph left this step at 395 pt of contiguous emptiness
            // (50,5 % of the safe area) and 24,1 % ink — the emptiest step of the flow, measured
            // on the simulator. The same rig the step before it opens with — identical call,
            // identical stage — is the content the design called for ("den gewonnenen Raum mit
            // dem Maskottchen … füllen statt mit Luft"), and it exists already: no new asset has to
            // be waited for. It also keeps one character across the two earliest screens instead of
            // handing the user a stranger on the second. After: 302 pt / 38,7 % and 32,9 % ink —
            // the welcome step's own numbers, still short of the targets (≤20 % empty, ≥50 % ink).
            MascotView(stage: .start, saturation: MascotStage.start.saturation)
                // The tap here is cosmetic only — a no-op onTap, no bubble, no state change a
                // VoiceOver user could act on (contrast GutenMorgenView.swift, where the same tap
                // drives a real reply). Announcing it as a button would promise an action that
                // isn't there, so children: .ignore + a plain label, no .isButton, no
                // .accessibilityAction.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Tuck")
            Text("Gleich fragen wir nach Bildschirmzeit-Zugriff")
                .font(.title3.weight(.semibold))
                .fontDesign(.rounded)
                .multilineTextAlignment(.center)
            Text("Damit wählst du selbst, welche Apps morgens kurz warten müssen — Tuck bekommt nie eine feste Liste vorgegeben, das entscheidest nur du im nächsten Schritt.")
                .font(.subheadline.weight(.regular))
                .fontDesign(.rounded)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.tuckInk)
                .padding(.horizontal, Layout.textInset)
            Spacer()
            nextButton("Verstanden") { step = .permission }
        }
        .foregroundStyle(Color.tuckCharcoalGreen)
    }

    private var permission: some View {
        VStack(spacing: Layout.section) {
            FamilyControlsAccessSection(authorizationStatus: $authorizationStatus)

            nextButton(authorizationStatus == .approved ? "Weiter" : "Später erlauben, weiter") {
                step = .appSelection
            }
        }
        .foregroundStyle(Color.tuckCharcoalGreen)
    }

    private var appSelection: some View {
        // "Weiter" stays outside the ScrollView: this step carries more copy than fits at
        // accessibility text sizes, and the button has to stay reachable there.
        VStack(spacing: Layout.container) {
            ShieldedAppSelectionSection(authorizationStatus: authorizationStatus) {
                selectedActivityCount = $0
            }

            // The flow could be finished with nothing selected at all: a registered window over an
            // empty picker shields nothing, and the screen said so nowhere. The step stays passable
            // — this app does not punish — but the button now says what the tap means. A one-tap
            // preselection is not buildable: ActivityCategoryToken has no public initializer, so
            // Apple's categories cannot be put into a FamilyActivitySelection from code (verified
            // in the iOS 26.5 ManagedSettings interface).
            nextButton(selectedActivityCount == 0 ? "Ohne Auswahl weiter" : "Weiter") {
                step = .wakeTime
            }
        }
        .foregroundStyle(Color.tuckCharcoalGreen)
    }

    private var wakeTimePicker: some View {
        VStack(spacing: Layout.section) {
            WakeAlarmSetupView(isAlarmStored: $wakeAlarmIsStored)
            Spacer()
            // The one gate in the flow, and the only step whose "Weiter" is not unconditional: the
            // alarm is what every later screen hangs off — without it BlockWindowReconciler never
            // registers a window, no shield is ever applied, and the morning screen has nothing to
            // show. It is also the app's one *persistent* disabled state, so the appearance matters
            // here more than anywhere: the disabled pair carries the look, the line below carries
            // the reason.
            VStack(spacing: Layout.pair) {
                nextButton("Weiter") { step = .bedtime }
                    .disabledWithOwnAppearance(!wakeAlarmIsStored)
                if !wakeAlarmIsStored {
                    Text("Weiter geht es, sobald der Wecker steht.")
                        .font(.subheadline.weight(.regular))
                        .fontDesign(.rounded)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.tuckInk)
                }
            }
        }
        .foregroundStyle(Color.tuckCharcoalGreen)
    }

    private var bedtimePicker: some View {
        VStack(spacing: Layout.section) {
            BedtimeSetupView()
            Spacer()
            nextButton("Weiter") { step = .done }
        }
        .foregroundStyle(Color.tuckCharcoalGreen)
    }

    private var done: some View {
        VStack(spacing: Layout.section) {
            MascotView(stage: .start, saturation: MascotStage.start.saturation)
                // The tap here is cosmetic only — a no-op onTap, no bubble, no state change a
                // VoiceOver user could act on (contrast GutenMorgenView.swift, where the same tap
                // drives a real reply). Announcing it as a button would promise an action that
                // isn't there, so children: .ignore + a plain label, no .isButton, no
                // .accessibilityAction.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Tuck")
            Text("Bereit")
                .font(.title2.weight(.semibold))
                .fontDesign(.rounded)
            Text("Guten Morgen sagen wir dir ab jetzt jeden Morgen hier.")
                .font(.subheadline.weight(.regular))
                .fontDesign(.rounded)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.tuckInk)
            Spacer()
            nextButton("Fertig") {
                // Wound back as the flow is left, not on the way in: a leftover .done would put
                // anyone who ever runs this flow again straight onto its last screen.
                storedStep = OnboardingStep.welcome.rawValue
                hasCompletedOnboarding = true
            }
        }
        .foregroundStyle(Color.tuckCharcoalGreen)
    }

    private func nextButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).primaryButtonPlate()
        }
    }
}

#Preview {
    OnboardingFlowView()
}
