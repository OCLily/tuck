import Foundation

// Three "Begruendung"-Kategorien, one per submenu slot of the real iOS 26.4 shield submenu
// (ManagedSettings has exactly three secondarySubmenuItemPressed cases, see
// docs/build-plan-phase1.md). Shared rather than app-local since the shield-configuration
// extension renders the labels and the shield-action extension resolves the pressed case back
// into one of them - the three strings exist once, here.
enum OverrideReason: String, CaseIterable, Identifiable, Sendable {
    case notfall = "Notfall"
    case arbeit = "Arbeit"
    case anderes = "Anderes"

    var id: String { rawValue }

    // The rawValue is what ShieldOverrideRequest writes into the App Group, so it stays German and
    // untranslated — a localized rawValue would make a pending request unreadable after a language
    // change. Only this label reaches a screen, and both extensions render it, hence SharedCopy.
    var displayName: String {
        switch self {
        case .notfall: String(localized: "Notfall", table: "SharedCopy")
        case .arbeit: String(localized: "Arbeit", table: "SharedCopy")
        case .anderes: String(localized: "Anderes", table: "SharedCopy")
        }
    }

    var icon: String {
        switch self {
        case .notfall: "exclamationmark.triangle.fill"
        case .arbeit: "briefcase.fill"
        case .anderes: "ellipsis.circle.fill"
        }
    }
}
