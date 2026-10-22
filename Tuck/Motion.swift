import Foundation

// The house breath, in one place. The design system decided one rhythm for the whole app — 11,0 s,
// 5,45 breaths per minute — and then left it standing as three unconnected literals: twice as a
// sum of four phase durations (MascotView's BreathPhase, OverrideFlowView's OverrideBreathPhase)
// and once as a bare 11.0 in MorningSky's ambience. All three agreed. The risk was never that they
// disagreed today, it was that a single phase could be retuned in one of them and desync the other
// two without a sound.
//
// `breathCycle` is derived rather than written down: the one number this file exists to protect is
// the sum, and a sum spelled out beside its own addends is the same drift one file smaller.
enum Motion {
    static let breathIn: Double = 4.0
    static let breathHold: Double = 1.0
    // Longer than the inhale on purpose — the design system's breathing table, and the half of
    // coherent breathing that does the calming.
    static let breathOut: Double = 5.0
    static let breathStill: Double = 1.0

    static let breathCycle: Double = breathIn + breathHold + breathOut + breathStill
    // MARK: - The durations the design system had already decided
    //
    // THE RULE THIS FILE FOLLOWS, and the reason it is not a list of every number in the app: a
    // duration is named here when the design system already decided it ("Etablierte Dauern", the
    // morning completion) — when the number is an answer somebody gave. A duration that is
    // choreography internal to one gesture (the tap repertoire, the mascot's entrance, the 30 ms
    // lead-in that keeps the bloom from starting in the same frame it is cancelled in) stays a
    // literal at its call site, because naming it would suggest a decision that was never made.
    // Counted when this block was written: 78 real time literals in Tuck/ (49 `duration:` with a
    // number, 29 `Task.sleep(for:)`), of which 56 are named below and 22 stay literals.

    //
    // THE SAFETY RULE, and it is the important half:
    //
    //   NAMING A VALUE IS NOT THE SAME AS GATING IT.
    //
    // `.easeOut(duration: 2.6)` -> `.easeOut(duration: Motion.celebrationBloom)` changes no runtime
    // behaviour and is allowed at all four Reduce-Motion trap sites. Introducing a NEW
    // `reduceMotion ?` condition anywhere in the body of `SunriseBloom.body`,
    // `OverrideFlowView.breathing(for:)`, `MascotView.beam()` or `GutenMorgenView.flourishRing()`
    // is forbidden: it would silence a reaction that has to keep running under Reduce Motion.
    // `MotionTokenTests` pins the number of `reduceMotion` occurrences in each of those four bodies
    // as an exact equality, so a new condition goes red wherever in the body it is inserted.

    // MARK: Sonnenaufgang und Ambiente

    /// Jede Stufe des Himmels wird über diese Zeit überblendet — auch beim Foregrounding, nie ein Sprung.
    static let skyCrossfade: Double = 8
    /// Der Takt, in dem der Himmelsstand neu gelesen wird.
    static let skyPoll: Double = 60
    /// Sättigungswechsel beim Stufenaufstieg des Tiers.
    static let stageSaturation: Double = 6.0
    /// Der Takt, in dem eine Ambient-Fläche neu zeichnet — die Tabelle im Design-System führte ihn als
    /// „20 fps (`minimumInterval: 1.0/20.0`)", im Code stand er als Literal. Mit der zweiten
    /// Ambient-Fläche wäre er die zweite Aufrufstelle einer entschiedenen Zahl geworden, und genau
    /// dafür existiert diese Datei. Ein Name, kein Gate: die `paused:`-Bedingung bleibt, wo sie ist.
    static let ambientTick: Double = 1.0 / 20.0

    // MARK: Sprechblase

    static let bubbleIn: Double = 0.5
    static let bubbleHold: Double = 2.8
    static let bubbleOut: Double = 0.9

    // MARK: Subline

    static let sublineDelay: Double = 0.4
    static let sublineIn: Double = 1.2

    // MARK: Feier

    /// Der Sonnenaufgangs-Bloom. Reduce-Motion-Fallenstelle: benennen ja, gaten nie.
    static let celebrationBloom: Double = 2.6
    /// Das Fenster, in dem die Feier steht — der Bloom und der Ring-Sweep müssen hineinpassen.
    static let celebrationWindow: Double = 2.8

    // MARK: Fortschrittsring — der alltägliche Weg

    /// Der Ring setzt sich ohne Feier auf seinen neuen Stand.
    static let ringSettle: Double = 1.4
    /// Die Morgen-Füllung: ein gezählter Morgen bewegt den Ring sichtbar.
    static let ringFill: Double = 1.1
    static let ringFlourishIn: Double = 0.9
    static let ringFlourishHold: Double = 1.4
    static let ringFlourishOut: Double = 1.2

    // MARK: Fortschrittsring — der Stufen-Sweep

    static let sweepClose: Double = 0.5
    static let sweepFlourishIn: Double = 0.8
    static let sweepGap: Double = 0.6
    static let sweepTail: Double = 1.1
    static let sweepTailHold: Double = 1.1
    static let sweepFlourishOut: Double = 0.9

    /// Die Wanduhrzeit von `sweepRing()` bis zum Ende seiner letzten Teilanimation — abgeleitet,
    /// nicht danebengeschrieben, wie `breathCycle`. Das Design-System führte dafür früher „≈2,9 s"; die
    /// drei Schritte, die die Wanduhr wirklich weiterdrehen, sind der Abstand vor dem Schweif, das
    /// Halten danach und das Ausblenden des Aufblühens. `MotionTokenTests` pinnt, dass die Summe
    /// in `celebrationWindow` passt — das ist die eigentliche Aussage der Tabellenzeile.
    static let sweepWallClock: Double = sweepGap + sweepTailHold + sweepFlourishOut

    // MARK: Flow-Schrittwechsel

    /// Sieben Schritte hintereinander sind eine Bedienfolge, keine Meldung.
    static let stepOnboarding: Double = 0.25
    /// Der Override meldet das Ergebnis einer Entscheidung und darf Zeit haben.
    static let stepOverride: Double = 0.6
    /// Zufällig derselbe Wert wie `stepOverride` und trotzdem eine eigene Rolle: der Crossfade des
    /// Atem-Labels. Zwei Namen für eine Zahl, damit die eine sich bewegen kann, ohne die andere
    /// mitzunehmen.
    static let breathLabelCrossfade: Double = 0.6

    // MARK: Mascot — die Übergabe der Entrance

    /// Wie lange der Host wartet, bevor er den gepufferten Morgen-Beat auslöst — die Entrance des
    /// Tiers muss übergeben haben, sonst strahlt es hinter geschlossenen Augen. Die beiden Zahlen
    /// standen als Literale in `greetAfterEntrance()` und waren von keinem Test gepinnt, obwohl jede
    /// Verlängerung der Entrance den Morgen-Beat mitverschiebt.
    static let entranceHandover: Double = 1.4
    /// Nach einer längeren Abwesenheit. Die Differenz zu `entranceHandover` IST die bestehende
    /// Entrance-Differenz — nicht die Haltezeit des Entrance-Blicks, die eine eigene Zahl ist.
    static let entranceHandoverAfterGap: Double = 3.0

    // MARK: Mascot — die Freude über einen abgeschlossenen Morgen

    static let beamCheeksIn: Double = 0.45
    static let beamHold: Double = 1.0
    static let beamSquintOut: Double = 0.4
    static let beamCheekGap: Double = 0.5
    static let beamCheeksOut: Double = 0.9

    // MARK: Mascot — Blinzeln

    static let blink: Double = 0.12
    static let blinkHold: Double = 0.12
    static let doubleBlinkGap: Double = 0.14
    /// Die zweite Blinzeldauer, die die Dauern-Tabelle nie hatte: das langsame Blinzeln der Tap-Antwort.
    static let slowBlink: Double = 0.3
    static let slowBlinkHold: Double = 0.3

    // MARK: Mascot — das Idle-Repertoire

    static let idleIntervalMin: Double = 3.5
    static let idleIntervalMax: Double = 7
    /// Die Ruhe, die eine Reaktion sich nimmt, bevor der Loop wieder unaufgefordert zieht — die
    /// untere Grenze des Idle-Intervalls, damit keine neue Zahl entsteht, wo eine schon steht. Sie
    /// fügt nichts hinzu: sie verschiebt nur den nächsten unaufgeforderten Beat aus der Antwort
    /// heraus, gegen die er sonst verrechnet wird.
    static let idleQuietAfterReaction: Double = 3.5

    static let tiltIn: Double = 1.1
    static let tiltHold: Double = 1.4
    static let tiltOut: Double = 1.4

    static let gazeShift: Double = 0.6
    static let gazeHold: Double = 1.2

    static let stretchUp: Double = 1.6
    static let stretchHold: Double = 0.5
    static let stretchDown: Double = 1.4
    /// Der Wendepunkt des längsten Beats, abgeleitet statt danebengeschrieben: die Schlafzeit im
    /// Code lief bisher als 2,1 s und war die Summe aus „1,6 s hoch" und „0,5 s gehalten" —
    /// zwei Zahlen, aus denen eine dritte geworden war.
    static let stretchTurn: Double = stretchUp + stretchHold

    static let yawnOpen: Double = 0.5
    static let yawnHold: Double = 1.1
    static let yawnClose: Double = 0.6
    static let yawnCheekGap: Double = 0.6
    static let yawnCheeksOut: Double = 0.6

    static let earTwitchHold: Double = 0.3
}
