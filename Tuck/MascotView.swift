import SwiftUI

// What the sprout is at each stage. A named form rather than a pair of booleans read off the stage
// inside the drawing: the seed is a symbol a test can hold on to, and without one there is nothing
// to check that the first stage draws anything at all.
enum SproutStage: CaseIterable {
    case seed, oneLeaf, twoLeaves
}

enum MascotStage: String, CaseIterable, Identifiable {
    case start = "Start"
    case warmGeworden = "Warm geworden"
    case eingespielt = "Eingespielt"

    var id: String { rawValue }

    // The rawValue stays the stable identity (Picker tag, `id`); only this reaches a screen.
    var displayName: String {
        switch self {
        case .start: String(localized: "Start")
        case .warmGeworden: String(localized: "Warm geworden")
        case .eingespielt: String(localized: "Eingespielt")
        }
    }

    var saturation: Double {
        switch self {
        case .start: 0.35
        case .warmGeworden: 0.7
        case .eingespielt: 1.0
        }
    }

    var scale: Double {
        switch self {
        case .start: 0.82
        case .warmGeworden: 0.92
        case .eingespielt: 1.0
        }
    }

    var eyesOpen: Bool { self != .start }

    // Originally the sprout began at "Warm geworden" and stage 0 carried none at all — the stage a
    // new user looks at for a week showed no growth to be at the start of. Every stage has a sprout
    // now; what changes between them is what it has grown into.
    var sproutStage: SproutStage {
        switch self {
        case .start: .seed
        case .warmGeworden: .oneLeaf
        case .eingespielt: .twoLeaves
        }
    }

    var cheekOpacity: Double {
        switch self {
        case .start: 0.35
        case .warmGeworden: 0.50
        case .eingespielt: 0.62
        }
    }

    // Matches the thresholds in docs/design/mascot.md - the only place they are written down in code.
    var completedMornings: Int {
        switch self {
        case .start: 0
        case .warmGeworden: 7
        case .eingespielt: 30
        }
    }

    // Depends on allCases being ordered by ascending threshold, which is what the case order
    // above encodes - the thresholds themselves stay defined only once, in completedMornings.
    //
    // Pure, and deliberately without a ratchet of its own: the number handed in is expected to be
    // MilestoneStore.reachedMornings() already, never MorningProgressStore's live count. Ratcheting
    // here would have to read a store from inside a pure derivation, and it would still leave the
    // two functions below taking the unratcheted number — the stage would hold while the words next
    // to it said "5 von 30 Morgen". MascotStageRatchetSourceTests holds the call sites to it.
    static func stage(forCompletedMornings mornings: Int) -> MascotStage {
        allCases.last { mornings >= $0.completedMornings } ?? .start
    }

    var next: MascotStage? {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self), index + 1 < all.count else { return nil }
        return all[index + 1]
    }

    static func progressTowardNext(completedMornings mornings: Int) -> Double {
        let current = stage(forCompletedMornings: mornings)
        guard let next = current.next else { return 1 }
        let span = Double(next.completedMornings - current.completedMornings)
        guard span > 0 else { return 1 }
        return min(max(Double(mornings - current.completedMornings) / span, 0), 1)
    }

    // The one place the count is spelled out in words. GutenMorgenView reads it to VoiceOver, the
    // settings screen shows it — the "keine Zahl auf dem Screen" rule keeps it off the morning
    // itself, it does not hide the progress from someone who goes looking for it.
    static func progressDescription(completedMornings mornings: Int) -> String {
        let current = stage(forCompletedMornings: mornings)
        guard let next = current.next else {
            return String(localized: "\(mornings) Morgen, Stufe \(current.displayName)")
        }
        return String(localized: "\(mornings) von \(next.completedMornings) Morgen, Stufe \(current.displayName)")
    }

    // Only forward, and only when a next stage exists to fill toward: the final stage keeps its
    // full ring instead of draining into an empty one it can never fill again.
    static func ringSweepsOnStageChange(from old: MascotStage, to new: MascotStage) -> Bool {
        new.completedMornings > old.completedMornings && new.next != nil
    }

    // Second person or "wir", present tense, max five words, no exclamation mark, no imperative,
    // never a number, never a mention of what the user did not do.
    var encouragements: [String] {
        switch self {
        case .start: [
            String(localized: "Jeder Morgen zählt."),
            String(localized: "Schön, dass du da bist."),
            String(localized: "Noch ganz früh hier."),
            String(localized: "Wir sitzen das aus."),
            String(localized: "Ich bin auch müde."),
            String(localized: "Es ist still, gut so."),
            String(localized: "Du bist schon da."),
            String(localized: "Langsam ist auch ein Tempo.")
        ]
        case .warmGeworden: [
            String(localized: "Du kommst rein."),
            String(localized: "Das wird schon Routine."),
            String(localized: "Fühlt sich vertraut an."),
            String(localized: "Wir kennen uns jetzt."),
            String(localized: "Der Morgen hat Form."),
            String(localized: "Ganz normal geworden."),
            String(localized: "Du bist wieder da."),
            String(localized: "Kein großes Ding mehr.")
        ]
        case .eingespielt: [
            String(localized: "Du hast das im Griff."),
            String(localized: "Ruhig und eingespielt."),
            String(localized: "Wie immer, gut so."),
            String(localized: "Nichts mehr zu beweisen."),
            String(localized: "Der Morgen läuft von selbst."),
            String(localized: "Vertrautes Bild."),
            String(localized: "Wir haben das."),
            String(localized: "Einfach so, jeden Morgen.")
        ]
        }
    }
}

// 11.0 s per cycle = 5.45 breaths/min (coherent breathing), with 2.0 s of complete stillness in
// it - net less motion than a permanently pulsing repeatForever animation.
private enum BreathPhase: CaseIterable {
    case inhale, hold, exhale, rest

    var bodyScale: Double {
        switch self {
        case .inhale, .hold: 1.055
        case .exhale, .rest: 0.985
        }
    }

    var leafSway: Double {
        switch self {
        case .inhale, .hold: 3
        case .exhale, .rest: -3
        }
    }

    var shadowWidth: Double {
        switch self {
        case .inhale, .hold: 86
        case .exhale, .rest: 100
        }
    }

    var shadowBlur: Double {
        switch self {
        case .inhale, .hold: 9
        case .exhale, .rest: 6
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

// The mapping is here rather than in Shared/MascotMilestone.swift so the hex values keep their one
// file and the shared types stay free of SwiftUI — Color+Palette.swift is compiled into the
// shield extension, which knows nothing about milestones.
extension MascotColorVariant {
    var color: Color {
        switch self {
        case .charcoalGreen: .tuckCharcoalGreen
        case .dustyBlue: .tuckDustyBlue
        case .warmSand: .tuckWarmSand
        case .softLavender: .tuckSoftLavender
        }
    }
}

// Internal rather than private so a test can reach `pool` below: the unlock filter is the one part
// of this rig a running loop can get wrong, and a pure function is the only part of that a test
// outside a rendered view can hold on to.
enum IdleBeat: CaseIterable {
    case blink, doubleBlink, earTwitch, headTilt, lookAround, stretch, yawn

    // The five original beats have no unlock. The two earned ones stay out of the pool until their
    // milestone is reached, so an unreached beat can never be picked.
    var unlock: MascotIdleAnimation? {
        switch self {
        case .stretch: .stretch
        case .yawn: .yawn
        default: nil
        }
    }

    // The same verdict as for blink, squint and cheeks: a change of shape is not motion,
    // so it stays. The yawn is built as a mouth and a pair of eyes only, with no transform on the
    // rig, and is therefore in this list; the stretch is a scale and is not.
    var survivesReduceMotion: Bool {
        switch self {
        case .blink, .doubleBlink, .yawn: true
        default: false
        }
    }

    var weight: Double {
        switch self {
        case .blink: 0.45
        case .doubleBlink: 0.15
        case .earTwitch: 0.15
        case .headTilt: 0.125
        case .lookAround: 0.125
        case .stretch: 0.1
        case .yawn: 0.1
        }
    }

    // The unlock set is passed in rather than read from the view: the loop that draws from this
    // pool outlives the render it was started in, so the set has to come from the @State mirror
    // and never from the view's own stored property.
    static func pool(reduceMotion: Bool,
                     unlocked: Set<MascotIdleAnimation>,
                     excluding previous: IdleBeat?) -> [IdleBeat] {
        allCases
            .filter { !reduceMotion || $0.survivesReduceMotion }
            .filter { beat in beat.unlock.map(unlocked.contains) ?? true }
            .filter { $0 != previous }
    }
}

struct MascotView: View {
    let stage: MascotStage
    var saturation: Double
    var lightElevation: Double
    var recognition: MorningRecognition.Kind
    var colorVariant: MascotColorVariant
    var unlockedIdleAnimations: Set<MascotIdleAnimation>
    // The host owns the accessibility element (children: .ignore), so its action cannot live in
    // here — but the tap counter that decides which phrase and which reaction follow does. Counting
    // the activations up there instead would give VoiceOver a second, drifting sequence.
    var accessibilityActivations: Int
    // Not part of the idle repertoire and never drawn from it: this beat has a cause. The host
    // increments it exactly once per completed morning, at the moment the rig is awake enough to
    // answer — same channel shape as accessibilityActivations, without the phrase.
    var morningBeat: Int
    var onTap: (Int) -> Void

    init(stage: MascotStage,
         saturation: Double = 1,
         lightElevation: Double = 0,
         recognition: MorningRecognition.Kind = .sameMorning,
         colorVariant: MascotColorVariant = .charcoalGreen,
         unlockedIdleAnimations: Set<MascotIdleAnimation> = [],
         accessibilityActivations: Int = 0,
         morningBeat: Int = 0,
         onTap: @escaping (Int) -> Void = { _ in }) {
        self.stage = stage
        self.saturation = saturation
        self.lightElevation = lightElevation
        self.recognition = recognition
        self.colorVariant = colorVariant
        self.unlockedIdleAnimations = unlockedIdleAnimations
        self.accessibilityActivations = accessibilityActivations
        self.morningBeat = morningBeat
        self.onTap = onTap
        _unlockedBeats = State(initialValue: unlockedIdleAnimations)
        _awake = State(initialValue: recognition == .sameMorning)
        _entranceScale = State(initialValue: recognition == .sameMorning ? CGSize(width: 1, height: 1) : CGSize(width: 1, height: 0.94))
        _entranceEarFold = State(initialValue: recognition == .sameMorning ? 0 : -6)
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var blink = false
    @State private var earTwist: Double = 0
    @State private var headTilt: Double = 0
    @State private var gaze: CGSize = .zero
    @State private var tapIndex = 0
    @State private var tapScale: Double = 1
    @State private var tapLean: Double = 0
    @State private var tapEarFlare: Double = 0
    @State private var squint = false
    @State private var cheekBoost = false
    @State private var awake: Bool
    @State private var entranceScale: CGSize
    @State private var entranceEarFold: Double
    @State private var stretchScale: CGSize = CGSize(width: 1, height: 1)
    @State private var yawning = false
    @State private var tapResetTask: Task<Void, Never>?
    @State private var tapAnimationTask: Task<Void, Never>?
    @State private var morningBeatTask: Task<Void, Never>?
    // The idle loop cannot read scenePhase itself: an @Environment value is resolved per render and
    // the running task keeps the copy it was started with, while @State reads stay current.
    @State private var sceneIsActive = true
    // Same reason, one step further: a stored property is part of the view struct the running task
    // captured, so the loop would keep the unlock set of its first render for the whole session.
    // A milestone is crossed while the app is in the background, so the set that matters arrives on
    // a later render — seeded here (the parameter is already correct at init, unlike scenePhase)
    // and kept current in the .onChange below.
    @State private var unlockedBeats: Set<MascotIdleAnimation>
    // Third instance of the same rule, on a value that — unlike scenePhase — has no safe guess to
    // start from: a user who already has Reduce Motion on cannot be assumed active-scene-style, and
    // may never toggle it again this session, so a wrong default would never self-correct. Seeded
    // and kept current by the same .onChange, using `initial: true` to fire once immediately.
    @State private var reduceMotionMirror = false
    // Fourth instance of the same rule, and the one the idle loop reads while it is already asleep:
    // the running task keeps the view struct it captured, so a stored property would freeze this at
    // whatever it was when the loop started. Written by handleTap and beam, read by runIdleBeats.
    @State private var lastReaction: Date?
    // Which tap the rig is currently answering, so the drawing can ASK MascotTapReaction how warm
    // the cheeks are instead of carrying a second copy of the numbers. No Reduce-Motion condition
    // anywhere near it, deliberately: cheeks are a change of fill, not motion. They were
    // long held to be the ONLY channel still drawing at stage `.start` with Reduce Motion on, and a
    // rendered screenshot measured what that is worth there — 6 / 5 / 4 of 255. The eye fold is the
    // second one.
    @State private var activeTapIndex: Int?
    // The one form element a completed morning has and nothing else does. Not a new vocabulary:
    // `MascotMouthShape.soft` already existed in the vocabulary, is pinned at 26 x 6 by
    // MascotExpressionVocabularyTests, and `MascotExpression.content` ("4 — Leise zufrieden. Not
    // jubilant: a cheer would be a verdict on the user") was already the vetted expression
    // for it — read by no drawing surface at all until now.
    @State private var beaming = false
    // The entrance's own warmth, on its own flag. Deliberately NOT `cheekBoost`: that one belongs to
    // handleTap, beam() and the yawn, and sharing it would let this cleanup wipe beam()'s cheeks.
    // It draws through the ADDITIVE channel and never touches the `cheekBoost ? 0.75 : …` ternary.
    @State private var entranceWarmth: Double = 0
    @State private var entranceWarmthTask: Task<Void, Never>?
    // Fifth instance of the @State-mirror rule, and the one with a race in it: the entrance task was
    // started on the first render and keeps that view struct, so `morningBeat` itself is unreadable
    // from inside it. This mirror is written in the same .onChange handler, before the beam starts.
    @State private var morningBeatArrived = false

    // Reduce Motion pins every transform this rig owns — breath, entrance, tap, gaze — while the
    // beats that are not motion (blink, squint, cheeks) keep their rhythm: MorningSky's "phase
    // clock keeps running, the delta gets pinned". Backgrounding stills the breath the same way,
    // but only the breath: pinning what a tap left behind would snap it back on return.
    private var breathStill: Bool { reduceMotion || scenePhase != .active }

    private var appliedGaze: CGSize { reduceMotion ? .zero : gaze }

    // Everything this rig draws in the charcoal green: outline, eyes, mouth and contact shadow. The
    // sage body and the dusty-rose cheeks are palette surfaces and stay what they are.
    private var ink: Color { colorVariant.color }

    var body: some View {
        PhaseAnimator(BreathPhase.allCases) { phase in
            ZStack {
                MascotContactShadow(
                    ink: ink,
                    width: (breathStill ? 100 : phase.shadowWidth) * (1 - 0.26 * lightElevation),
                    blur: breathStill ? 6 : phase.shadowBlur,
                    strength: (0.12 - 0.05 * lightElevation) / 0.12
                )
                .offset(y: MascotGeometry.contactShadowOffsetY)

                bodyStack(sway: breathStill ? 0 : phase.leafSway)
                    .scaleEffect(breathStill ? 1 : phase.bodyScale)
                    .rotationEffect(.degrees(reduceMotion ? 0 : headTilt), anchor: .bottom)
                    .rotationEffect(.degrees(reduceMotion ? 0 : tapLean), anchor: .bottom)
                    .offset(x: appliedGaze.width * 0.6, y: appliedGaze.height * 0.6)
            }
            .frame(width: MascotGeometry.rigWidth, height: MascotGeometry.rigHeight)
            // Foregrounding lets the breath grow back instead of popping: the phase itself never
            // changes here, so this only ever animates the un-pinning.
            .animation(.easeInOut(duration: 1.0), value: scenePhase)
        } animation: { $0.animation }
        .scaleEffect(stage.scale)
        .scaleEffect(x: reduceMotion ? 1 : entranceScale.width,
                     y: reduceMotion ? 1 : entranceScale.height,
                     anchor: .bottom)
        .scaleEffect(x: reduceMotion ? 1 : stretchScale.width,
                     y: reduceMotion ? 1 : stretchScale.height,
                     anchor: .bottom)
        .scaleEffect(reduceMotion ? 1 : tapScale)
        .contentShape(Rectangle())
        .onTapGesture(coordinateSpace: .local) { location in handleTap(at: location) }
        // The centre of the 160 x 140 frame: an activation has no touch point, and the only thing
        // the location decides is which way the tier leans.
        .onChange(of: accessibilityActivations) { handleTap(at: CGPoint(x: 80, y: 70)) }
        // Deliberately not `initial: true`: the host holds the beat back until the entrance is over,
        // so the counter is never already raised when this rig is built.
        .onChange(of: morningBeat) {
            // beam() WINS, and the entrance's look drops out without replacement — no catching up,
            // no lengthening of beam(), no weakened version. The two overlap on the main path: the
            // entrance hands over at 1.4 s, the look would end around 2.0-2.2 s, and beam() holds
            // the cheeks until roughly 3.35 s. The cancel belongs HERE and expressly not inside
            // beam(): that body is a MotionTokenTests trap site.
            morningBeatArrived = true
            morningBeatTask?.cancel()
            entranceWarmthTask?.cancel()
            // Without animation on purpose: a `withAnimation` here would overlap beamCheeksIn for
            // 0.3 s and read as the cheeks cooling at the exact moment they are meant to warm.
            entranceWarmth = 0
            morningBeatTask = Task { await beam() }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    withAnimation(.interpolatingSpring(stiffness: 60, damping: 14)) {
                        gaze = CGSize(width: min(max((value.location.x - 80) / 32, -2.5), 2.5),
                                      height: min(max((value.location.y - 70) / 40, -1.5), 1.5))
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 1.0)) { gaze = .zero }
                }
        )
        .onChange(of: scenePhase) { sceneIsActive = scenePhase == .active }
        .onChange(of: unlockedIdleAnimations) { unlockedBeats = unlockedIdleAnimations }
        .onChange(of: reduceMotion, initial: true) { _, newValue in reduceMotionMirror = newValue }
        // No `id:` on this task: restarting it would replay the entrance the mascot already had.
        .task { await runEntranceThenIdle() }
    }

    // This is where the rig stops and the host begins. `MascotPose` is this function,
    // extracted — the same ZStack in the same order — so everything that moves stays up here and
    // nothing that draws is written twice. What used to be four booleans read inside the drawing
    // (`stage.eyesOpen`, `awake`, `blink`, `squint`, `yawning`) is now one expression handed down.
    private func bodyStack(sway: Double) -> some View {
        MascotPose(
            expression: MascotExpression(
                eyes: eyeState,
                mouth: mouthShape,
                // The additive channel, never the absolute one: `MascotPose.cheek` draws
                // `min(cheekOpacity + expression.cheekBoost, 1)`, so this shifts every stage by the
                // same amount and can never cool the cheeks below their stage's own warmth. Taps 1-3
                // had no visible answer at all under Reduce Motion; this is it.
                // A SUM, never a replacement. Writing `cheekBoost: entranceWarmth` here would
                // silently undo the measured tap warmth: the pure function would stay correct, the
                // wiring scan only pins that handleTap ASKS it, and no existing test would see the
                // value failing to reach the drawing.
                cheekBoost: (activeTapIndex.flatMap { MascotTapReaction.cheekBoost(for: $0) } ?? 0)
                    + entranceWarmth
            ),
            sproutStage: stage.sproutStage,
            ink: ink,
            saturation: saturation,
            cheekOpacity: cheekBoost ? 0.75 : stage.cheekOpacity,
            sway: sway,
            gaze: appliedGaze,
            leadingEarRotation: -earFlare + gazeEarRotation,
            trailingEarRotation: earFlare + (reduceMotion ? 0 : earTwist) + gazeEarRotation,
            reduceMotion: reduceMotion
        )
    }

    // The same three conditions the drawing used to ask itself, in the same order, now answered
    // once. `.half` is deliberately unreachable from here: it exists in the vocabulary and no
    // MascotStage maps to it, which is the open gap mascot.md's "Stufe 2: Augen halb geöffnet"
    // names and that a fixed product decision keeps open: closing it would mean rewiring
    // the stage mechanic.
    //
    // ONE CONDITION MOVED, and it is the whole fix. `stage.eyesOpen` used to sit inside the guard,
    // so a stage with a closed lid swallowed the fold before anything could draw it — at stage
    // `.start` `squint = true` was a variable nobody could see, for taps and for beam() alike. It
    // asks last now: a blink and a rig that is not awake yet still close the eyes, the fold is a
    // fold at every stage, and only the resting shape is the stage's own. Not a per-stage
    // expression mapping: `MascotStage` gains nothing, it is still asked the one bool it has always
    // had (MascotStageExpressionBoundaryTests).
    static func eyeState(eyesOpen: Bool, awake: Bool, blink: Bool, squint: Bool) -> MascotEyeState {
        guard awake && !blink else { return .closed }
        if squint { return .squint }
        return eyesOpen ? .open : .closed
    }

    private var eyeState: MascotEyeState {
        Self.eyeState(eyesOpen: stage.eyesOpen, awake: awake, blink: blink, squint: squint)
    }

    // A TAP/BEAT MAPPING, NOT A STAGE MAPPING, and the distinction is the whole reason this is
    // allowed. MascotStageExpressionBoundaryTests reads only the body of `enum MascotStage` and goes
    // red on any new member or eye/mouth vocabulary there; the file's own header says it: "New
    // surfaces and future idle beats may use this freely. The three existing stages may not."
    // `.soft` is reached from @State, never from a stage.
    //
    // First, because it outranks both: a yawn is an idle beat and the morning is not. The quiet floor
    // from Motion.idleQuietAfterReaction keeps them apart in time anyway — this decides the frame in
    // which they would still overlap.
    private var mouthShape: MascotMouthShape {
        if beaming { return .soft }
        if yawning { return .yawn }
        return stage.eyesOpen ? .neutral : .sleeping
    }

    private var earFlare: Double { reduceMotion ? 0 : tapEarFlare + entranceEarFold }

    private var gazeEarRotation: Double { appliedGaze.width * 1.2 }

    private func handleTap(at location: CGPoint) {
        lastReaction = .now
        let index = tapIndex
        tapIndex += 1
        onTap(index)

        let spring: Animation = index < 2
            ? .spring(response: 0.55, dampingFraction: 0.85)
            : .spring(response: 0.5, dampingFraction: 0.9)
        let lean: Double = location.x < 80 ? -1.5 : 1.5
        withAnimation(spring) { tapLean = lean; activeTapIndex = index }

        // ASKED, not mirrored, and one step earlier than before: the fold has to be set in the same
        // frame as the lean, while the blink is awaited in the task below. Both read the one answer.
        let answer = MascotTapReaction.axes(for: index,
                                            reduceMotion: reduceMotion,
                                            eyesOpen: stage.eyesOpen)
        // Raw, like it always was — only the release is animated, three statements down in the task.
        if answer.contains(.squint) { squint = true }

        switch index {
        case 0:
            withAnimation(spring) { tapScale = 1.06; tapEarFlare = 10 }
            cheekBoost = true
        case 1:
            withAnimation(spring) { tapScale = 1.04 }
            withAnimation(.easeInOut(duration: 0.6)) {
                gaze = CGSize(width: min(max((location.x - 80) / 32, -2.5), 2.5),
                              height: min(max((location.y - 70) / 40, -1.5), 1.5))
            }
            Task { await twitchEar() }
        case 2:
            withAnimation(.easeInOut(duration: 1.1)) { headTilt = lean < 0 ? -4 : 4 }
        default:
            withAnimation(spring) { tapScale = 1.02 }
        }

        tapAnimationTask?.cancel()
        tapAnimationTask = Task {
            // The function decides, the rig no longer mirrors it: `index >= 2` was a second copy of
            // a decision `MascotTapReaction.axes` already makes, and the copy is what kept tap 1
            // blinkless while the pure function was the only place the still-face matrix could be
            // read. At stage `.start` no blink is requested at all any more — a fold is.
            if answer.contains(.blink) { await slowBlink() }
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) { squint = false }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            cheekBoost = false
            withAnimation(spring) { tapScale = 1; tapEarFlare = 0; activeTapIndex = nil }
            withAnimation(.easeOut(duration: 2.5)) { tapLean = 0 }
            withAnimation(.easeInOut(duration: 1.4)) { headTilt = 0 }
        }

        tapResetTask?.cancel()
        tapResetTask = Task {
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            tapIndex = 0
        }
    }

    // The answer to a completed morning. Until now it was built out of the tap repertoire and
    // nothing new — and that was the defect, not the virtue: at stage `.start` the squint was
    // invisible behind a closed lid, and under Reduce Motion the scale and the flare are pinned on
    // both sides, so for a user in their first seven mornings with Reduce Motion on, a completed
    // morning and a fingertip were literally the same picture: warm cheeks. The mouth is the one
    // channel that survives the Reduce-Motion pins and belongs to nothing else, which is why it is
    // the one that carries the difference. The squint below draws at stage `.start` too since
    // `eyeState` stopped letting the stage outrank the fold — it strengthens this moment, and the
    // distinction rests where it was put: on the mouth.
    // It cancels the tap reset because that one would otherwise clear the cheeks mid-beat.
    //
    // Under Reduce Motion the two transforms are pinned where every transform of this rig is pinned
    // (`tapScale`, `earFlare`) and what remains — warmer cheeks, folded eyes — is a change of shape,
    // not motion. The reaction stays, only its travel goes.
    private func beam() async {
        lastReaction = .now
        tapAnimationTask?.cancel()
        let spring = Animation.spring(response: 0.5, dampingFraction: 0.8)
        withAnimation(.easeInOut(duration: Motion.beamCheeksIn)) { cheekBoost = true }
        beaming = true
        squint = true
        withAnimation(spring) { tapScale = 1.06; tapEarFlare = 9 }
        try? await Task.sleep(for: .seconds(Motion.beamHold))
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: Motion.beamSquintOut)) { squint = false }
        withAnimation(spring) { tapScale = 1; tapEarFlare = 0 }
        try? await Task.sleep(for: .seconds(Motion.beamCheekGap))
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: Motion.beamCheeksOut)) { cheekBoost = false }
        withAnimation(.easeInOut(duration: Motion.beamCheeksOut)) { beaming = false }
    }

    private func runEntranceThenIdle() async {
        if !awake {
            withAnimation(.easeOut(duration: 0.6)) { entranceScale = CGSize(width: 0.96, height: 1.06) }
            try? await Task.sleep(for: .milliseconds(600))
            withAnimation(.easeOut(duration: 0.4)) { entranceScale = CGSize(width: 1, height: 1) }
            withAnimation(.easeInOut(duration: 0.35)) { awake = true }
            withAnimation(.easeInOut(duration: 0.8)) { entranceEarFold = 0 }
            try? await Task.sleep(for: .milliseconds(800))
            // A longer absence earns more warmth, never less. Until now the only thing this branch
            // did was delay the first idle beat: `withAnimation { gaze = .zero }` animated a
            // variable that was already `.zero` on this path — a no-op with a comment claiming a
            // warmth the code drew nowhere, and unnoticed because `.afterGap` (>= 3 days away) is the
            // rarest path in the app. The sleep stays; it is the entrance-duration difference the
            // host's buffered morning beat waits on.
            if recognition == .afterGap {
                try? await Task.sleep(for: .milliseconds(1600))
            }
            // The look, now that there is one: a short held moment of warmth at the end of EVERY
            // entrance, not only after a long absence — the `.afterGap` path stays the longer one, so
            // "more warmth, never less" gains a normal case to stand out from for the first time.
            //
            // Skipped without replacement if the morning beat is already here. Checked at this point
            // and not at the top of the function: up there the beat could not have arrived yet, and
            // the check would pass while the look still starts.
            if !morningBeatArrived {
                entranceWarmthTask?.cancel()
                entranceWarmthTask = Task {
                    // Grund: Choreografie innerhalb einer Geste — das Design-System hat nie entschieden, wie lange
                    // das Tier aufsieht. 0,7 s Halt, mit einem Anlauf und einem Ausklang, die sich in
                    // die vorhandenen Bänder des Rigs einfügen.
                    withAnimation(.easeInOut(duration: 0.6)) { entranceWarmth = 0.18 }
                    try? await Task.sleep(for: .milliseconds(700))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeInOut(duration: 0.9)) { entranceWarmth = 0 }
                }
            }
        } else if !reduceMotion {
            // The same verdict the idle pool passes on headTilt below: unsuitable under Reduce
            // Motion. The entrance timing stays untouched either way — only the tilt is dropped.
            await perform(.headTilt)
        }
        await runIdleBeats()
    }

    // The wait is slept in slices rather than in one go, because the deadline is not knowable when
    // the sleep starts: a tap or a completed morning arrives mid-sleep, and only a recomputation
    // that happens after it can push the next unprompted beat out of the reaction's way.
    //
    // `periodStart` and `draw` are bound ONCE per waiting period and stay constant for it. Re-drawing
    // either inside the slice loop would be the second of the two failure modes: the deadline would
    // walk along with the clock and the loop would never fire again after the first reaction —
    // indistinguishable, from the outside, from a calm animal.
    private func runIdleBeats() async {
        var previous: IdleBeat?
        while !Task.isCancelled {
            let periodStart = Date.now
            let draw = Double.random(in: Motion.idleIntervalMin...Motion.idleIntervalMax)
            while !Task.isCancelled {
                let deadline = IdleSchedule.nextDeadline(from: periodStart, draw: draw, lastReaction: lastReaction)
                if Date.now >= deadline { break }
                // Grund: Choreografie innerhalb einer Schleife, keine entschiedene Dauer (Motion.swifts
                // eigene Aufnahmeregel). Kurz genug, dass eine Reaktion den Termin noch verschiebt.
                try? await Task.sleep(for: .milliseconds(200))
            }
            guard !Task.isCancelled else { return }
            // Backgrounded: skip this beat and keep waiting, so the loop resumes on its own rhythm
            // when the app comes forward instead of firing a queued animation into a dark screen.
            guard sceneIsActive else { continue }
            let beat = nextBeat(excluding: previous)
            previous = beat
            await perform(beat)
        }
    }

    private func nextBeat(excluding previous: IdleBeat?) -> IdleBeat {
        let pool = IdleBeat.pool(reduceMotion: reduceMotionMirror, unlocked: unlockedBeats, excluding: previous)
        let total = pool.reduce(0) { $0 + $1.weight }
        var roll = Double.random(in: 0..<total)
        for beat in pool {
            roll -= beat.weight
            if roll <= 0 { return beat }
        }
        return .blink
    }

    private func perform(_ beat: IdleBeat) async {
        switch beat {
        case .blink:
            await blinkOnce()
        case .doubleBlink:
            await blinkOnce()
            try? await Task.sleep(for: .seconds(Motion.doubleBlinkGap))
            await blinkOnce()
        case .earTwitch:
            await twitchEar()
        case .headTilt:
            let target: Double = Bool.random() ? 4 : -4
            withAnimation(.easeInOut(duration: Motion.tiltIn)) { headTilt = target }
            try? await Task.sleep(for: .seconds(Motion.tiltHold))
            withAnimation(.easeInOut(duration: Motion.tiltOut)) { headTilt = 0 }
        case .lookAround:
            withAnimation(.easeInOut(duration: Motion.gazeShift)) {
                gaze = CGSize(width: .random(in: -2.5...2.5), height: .random(in: -1.5...1.5))
            }
            try? await Task.sleep(for: .seconds(Motion.gazeHold))
            withAnimation(.easeInOut(duration: Motion.gazeShift)) { gaze = .zero }
        case .stretch:
            // Slow on purpose: 1.6 s up, half a second held, 1.4 s back down is the longest beat of
            // the repertoire and the only one that reaches out of the breath's own amplitude. The
            // scale is pinned under Reduce Motion like every other transform of this rig, but the
            // beat is filtered out before that anyway (survivesReduceMotion).
            withAnimation(.easeInOut(duration: Motion.stretchUp)) {
                stretchScale = CGSize(width: 0.97, height: 1.07)
                earTwist = -10
            }
            try? await Task.sleep(for: .seconds(Motion.stretchTurn))
            withAnimation(.easeInOut(duration: Motion.stretchDown)) {
                stretchScale = CGSize(width: 1, height: 1)
                earTwist = 0
            }
        case .yawn:
            withAnimation(.easeInOut(duration: Motion.yawnOpen)) {
                yawning = true
                blink = true
                cheekBoost = true
            }
            try? await Task.sleep(for: .seconds(Motion.yawnHold))
            withAnimation(.easeInOut(duration: Motion.yawnClose)) {
                yawning = false
                blink = false
            }
            try? await Task.sleep(for: .seconds(Motion.yawnCheekGap))
            withAnimation(.easeInOut(duration: Motion.yawnCheeksOut)) { cheekBoost = false }
        }
    }

    private func blinkOnce() async {
        withAnimation(.easeInOut(duration: Motion.blink)) { blink = true }
        try? await Task.sleep(for: .seconds(Motion.blinkHold))
        withAnimation(.easeInOut(duration: Motion.blink)) { blink = false }
    }

    private func slowBlink() async {
        withAnimation(.easeInOut(duration: Motion.slowBlink)) { blink = true }
        try? await Task.sleep(for: .seconds(Motion.slowBlinkHold))
        withAnimation(.easeInOut(duration: Motion.slowBlink)) { blink = false }
    }

    private func twitchEar() async {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { earTwist = 8 }
        try? await Task.sleep(for: .seconds(Motion.earTwitchHold))
        withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { earTwist = 0 }
    }
}

#Preview {
    MascotView(stage: .eingespielt, saturation: MascotStage.eingespielt.saturation)
        .padding(80)
        .background(Color.tuckCream)
}
