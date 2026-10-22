import Foundation

// The layout scale, in one place. The design system's layout section had the scale right and no
// place to keep it: every value was a literal at its own call site, and that section's closing
// sentence ("wird hiermit als Sollzustand festgeschrieben") was prose asked to hold sixty-nine
// numbers apart.
//
// Prose is what drifted. Two pieces of evidence, both from this repo rather than from principle:
// the design system's own list of exceptions was already incomplete (28, 14, 12, 10 each have
// more than one call site and were filed as Einzelfälle), and two `cornerRadius: 12` grew back in
// WakeAlarmSetupView after the design system had decided 12 away, by a hand that had no
// way to know. Neither is a documentation failure. Both are the absence of a mechanism.
//
// Same move as Tuck/MascotGeometry.swift, and `import Foundation` for the same
// reason: this file holds values and renders nothing.
//
// What is NOT here: `radiusBrandCard` (24) and `radiusPill` (100) from the original design's brand
// layer. Neither has a single call site in the repo, and a token nothing reads is inventory, not a
// scale — it drifts from the drawing without anything going red. The decision is recorded in
// docs/design/design-system.md.
enum Layout {
    // MARK: - Stack-Abstände

    /// Root-Stack eines ganzen Screens.
    static let root: CGFloat = 24
    /// Sektionen innerhalb eines Setup-/Onboarding-Screens.
    static let section: CGFloat = 20
    /// Container, verschachtelte Stacks, Listen.
    static let container: CGFloat = 16
    /// Eng gekoppeltes Textpaar (Zeile + Unterzeile).
    static let pair: CGFloat = 8

    // The four the design system filed under "vorhanden, aber Einzelfälle". Each has more than one
    // call site, so each is a role rather than an exception — named after what it spaces, not after
    // its number, because the number is the part that is allowed to move.

    /// Die Sektionen des Atem-/Override-Screens, weiter als anderswo.
    static let overrideSection: CGFloat = 28
    /// Die Fußzeilen-Blöcke des Paywalls.
    static let footerStack: CGFloat = 14
    /// Auswahlzeile und Begründungsliste des Override-Screens.
    static let choiceStack: CGFloat = 12
    /// Innenabstand innerhalb einer Paywall-Karte.
    static let cardInterior: CGFloat = 10

    // MARK: - Padding

    /// Horizontaler Zusatzeinzug für einen Textblock, projektweit.
    static let textInset: CGFloat = 24
    /// Primärbutton, vertikal — die Hälfte, die die gezeichnete Platte auf 44,3 pt bringt.
    static let plateY: CGFloat = 12

    // Das Innenmaß einer Schwebend-Platte, die um *eine* Aussage herumliegt — enger als
    // `textInset`, der einen Textblock einrückt. Stand zuvor als Literal an der
    // Sprechblase und war damit ein Einzelfall; seit die Statustext-Platte dieselben zwei
    // Zahlen trägt, sind es zwei Aufrufstellen und damit eine Rolle. Die zweite Stelle setzt sie
    // negativ an ihrem Hintergrund an, weil die Platte um den Text herumwachsen soll, ohne die
    // Spalte zu verschieben.
    static let plateInsetX: CGFloat = 14
    static let plateInsetY: CGFloat = 8

    // MARK: - Trefferfläche

    /// Die kleinste Trefferfläche, die ein Bedienelement haben darf — Apples HIG-Minimum, nicht
    /// verhandelbar. Eine Layout-*Höhe*, die zufällig 44 misst, ist nicht dieses Token:
    /// `OnboardingFlowView.headerHeight` bleibt aus genau diesem Grund ein eigenes Literal.
    static let hitMin: CGFloat = 44

    // MARK: - Corner-Radius

    /// Plate — trägt *eine* Handlung oder *eine* Aussage.
    static let radiusPlate: CGFloat = 16
    /// Karte — mehrzeiliger Inhaltsblock mit eigener Überschrift.
    static let radiusCard: CGFloat = 20
}
