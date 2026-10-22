import Foundation

// The shield is Apple's own template (docs/build-plan-phase1.md) — a title, a subtitle and two
// button labels are the entire writable surface, no SwiftUI and no layout. Keeping the strings in a
// pure value type is the only way any of this gets tested: ShieldConfigurationExtension itself runs
// in a system process that the Simulator never starts, because Family Controls does not work there.
enum ShieldCopy {
    // ShieldConfigurationLabel takes a plain String, so none of this can be a
    // LocalizedStringResource — String(localized:) is the only extractable form left. The table is
    // SharedCopy rather than the target's own Localizable because the shield is a separate bundle
    // and the copy needs one entry, not one per bundle (docs/design/design-system.md). Spelled out as a
    // literal at every call site, not via TuckIdentifiers.sharedCopyTable: the extractor only
    // records the table when it is a literal and files the keys under "Localizable" otherwise.

    struct Content: Equatable {
        let title: String
        let subtitle: String
        let primaryButton: String
        // nil means the shield shows no second button at all, which is the only honest rendering of
        // an exhausted quota: there is nothing left to offer.
        let secondaryButton: String?
    }

    // No number anywhere in the returned copy, deliberately. Two reasons, and they hold
    // independently: a count on the block screen turns the quota into a score to watch,
    // and the shield's read of the App-Group
    // container is not provable — an unprovisioned App Group falls back to the extension's own
    // empty defaults, where every quota reads full. Binary "empty or not" survives that; a printed
    // number would be a claim the extension cannot back.
    //
    // The decision record words the exhausted line as "Sperre bleibt bis [Endzeit]". The end time is
    // deliberately left out: the exhausted state settled on "Morgen ist wieder ein neuer Morgen"
    // instead, and one copy for one state beats two that drift apart — which is why OverrideFlowView
    // reads the two pieces below rather than keeping its own.
    static func content(for context: OverrideContext, allowance: UnlockAllowance) -> Content {
        let exhausted = allowance.isExhausted
        return Content(
            title: title(for: context),
            subtitle: exhausted ? exhaustedSubtitle(for: context) : subtitle(for: context),
            primaryButton: exhausted
                ? String(localized: "Schließen", table: "SharedCopy")
                : String(localized: "Ich lass es", table: "SharedCopy"),
            secondaryButton: exhausted
                ? nil
                : String(localized: "Ich brauche kurz Zugriff", table: "SharedCopy")
        )
    }

    private static func title(for context: OverrideContext) -> String {
        switch context {
        case .morning: String(localized: "Guten Morgen", table: "SharedCopy")
        case .bedtime: String(localized: "Gute Nacht", table: "SharedCopy")
        }
    }

    // Deci's three internalisation factors in two sentences (meaningful rationale, acknowledged
    // feeling, and the choice left with the user via the buttons below) — no "solltest", no
    // "musst", nothing about what the user failed to do.
    private static func subtitle(for context: OverrideContext) -> String {
        switch context {
        case .morning:
            String(localized: "Diese Zeit gehört dir, nicht dem Feed. Der Griff zum Handy ist normal, gerade morgens.",
                   table: "SharedCopy")
        case .bedtime:
            String(localized: "Diese Zeit gehört dem Schlaf, nicht dem Feed. Der Griff zum Handy ist normal, gerade abends.",
                   table: "SharedCopy")
        }
    }

    // Split into the two pieces the app's exhausted screen renders as a heading and a body, because
    // that screen used to carry its own copy of both in the app catalog — context-blind, so a free
    // user who spent the evening unlock read "ein neuer Morgen" at night, and the word-for-word
    // parity rested on two catalogs happening to agree. The shield has one subtitle slot and gets
    // them joined; the sentence it produces is unchanged in both languages.
    static var exhaustedHeading: String { String(localized: "Für heute aufgebraucht", table: "SharedCopy") }

    static func exhaustedBody(for context: OverrideContext) -> String {
        switch context {
        case .morning:
            String(localized: "Die Sperre bleibt bestehen. Morgen ist wieder ein neuer Morgen.",
                   table: "SharedCopy")
        case .bedtime:
            String(localized: "Die Sperre bleibt bestehen. Morgen ist wieder ein neuer Tag.",
                   table: "SharedCopy")
        }
    }

    private static func exhaustedSubtitle(for context: OverrideContext) -> String {
        "\(exhaustedHeading). \(exhaustedBody(for: context))"
    }
}
