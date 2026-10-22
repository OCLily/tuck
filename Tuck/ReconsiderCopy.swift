import Foundation

// The one screen between the breathing timer and the unlock. What it shows is the reason the user
// picked, mirrored back — nothing the app brought along, and nothing about the reader.
//
// It used to show a randomly drawn research fact. That was persuasion with no evidence behind it:
// the one study that carries this whole step (one sec, PNAS 2023) compared deliberation, waiting time, dismiss option and their combination,
// and the *dismiss option alone* had the largest effect. The fact on top of it was never the
// mechanism, and it contradicted the app's own promise that this is a delay, not a refusal. It also
// forced a stance the wording could not undo: a fact placed here reads as an argument against
// unlocking, which is an evaluation of the choice on the screen — for all three reasons alike, and
// so also in front of somebody who picked "Notfall". The pool itself was not wrong (it is kept
// for a later external page); this was the wrong place for it.
//
// What replaces it is the Deci triad minus its evaluative
// half: the reason is named, the freedom of the choice is stated, and nothing asks whether the reason is good enough. No question mark —
// a question here would be the retrospective-evaluative prompt that raised measurable shame in the
// field study this design draws on, and shame is the mechanism the app rejects. No "du", no "dein", no
// "solltest", the same vocabulary ban the shield subtitle carries (Shared/ShieldCopy.swift).
//
// Three literals rather than one interpolated line: each is its own catalog key that way, and the
// second language is checked against it word for word instead of against a format string.
//
// App target only, never Shared/: no extension draws this screen.
enum ReconsiderCopy {
    static func reasonReflection(for reason: OverrideReason) -> String {
        switch reason {
        case .notfall: String(localized: "Als Grund gewählt: Notfall. Beide Wege stehen weiter offen.")
        case .arbeit: String(localized: "Als Grund gewählt: Arbeit. Beide Wege stehen weiter offen.")
        case .anderes: String(localized: "Als Grund gewählt: Anderes. Beide Wege stehen weiter offen.")
        }
    }

    static var reasonReflections: [String] { OverrideReason.allCases.map(reasonReflection(for:)) }

    // The house word for leaving it, one word further than the shield's ("Ich lass es",
    // Shared/ShieldCopy.swift) because here something was already begun. Not in SharedCopy: no
    // shield renders this screen, so there is no reason for a second catalog entry.
    static var dismissChoice: String { String(localized: "Ich lass es doch") }

    // Plain "Freischalten", not "Trotzdem freischalten": the "trotzdem" presupposed that what stands
    // above is a reason against unlocking, which is the screen taking a side no matter how the line
    // above it is worded. The two ways carry the same weight, and the label may not undo that.
    static var unlockChoice: String { String(localized: "Freischalten") }
}
