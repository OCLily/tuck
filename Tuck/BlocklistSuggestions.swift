import Foundation

enum BlocklistSuggestions {
    struct Suggestion: Equatable, Identifiable {
        let label: String
        let reason: String

        var id: String { label }
    }

    // Labels müssen wörtlich den Apple-Kategorien im Picker entsprechen, sonst findet der Nutzer
    // die vorgeschlagene Zeile dort nicht wieder — und der Picker spricht die Systemsprache. Die
    // Übersetzung ist deshalb keine Übersetzung, sondern Apples eigener englischer Kategoriename.
    static var primary: [Suggestion] {
        [
            Suggestion(
                label: String(localized: "Soziale Netze"),
                reason: String(localized: "Der klassische Griff um 6:30 — einmal aufmachen, zwanzig Minuten weg.")
            ),
            Suggestion(
                label: String(localized: "Unterhaltung"),
                reason: String(localized: "Hier liegen TikTok und YouTube: kein natürliches Ende, deshalb hört man nicht auf.")
            )
        ]
    }

    static var secondary: [Suggestion] {
        [
            Suggestion(
                label: String(localized: "Spiele"),
                reason: String(localized: "Eine Runde ist nie eine Runde.")
            ),
            Suggestion(
                label: String(localized: "Informationen & Lesen"),
                reason: String(localized: "Nachrichten als Erstes am Morgen setzen die Stimmung für den ganzen Tag.")
            )
        ]
    }

    // Kurzvideo ist keine Apple-Kategorie, deshalb nur Beispielzeile statt eigener Vorschlag.
    static var shortVideoExamples: String {
        String(localized: "Kurzvideos lassen morgens am schwersten wieder los — meist TikTok, Instagram Reels, YouTube Shorts.")
    }

    static var socialNetworksNote: String {
        String(localized: "Apple zählt auch Messenger wie WhatsApp und Nachrichten zu „Soziale Netze“. Wenn du morgens erreichbar bleiben willst, wähl lieber einzelne Apps aus.")
    }

    static var intro: String {
        String(localized: "Ein Vorschlag, keine Vorauswahl — such die Zeilen in der Liste selbst aus:")
    }

    // The one line the app-selection step still carries. Built from the same labels the
    // picker shows rather than written out, so a renamed Apple category cannot leave a suggestion
    // pointing at a row that is not there.
    static var primaryLine: String {
        let list = primary.map(\.label).joined(separator: String(localized: " und "))
        return String(localized: "Vorschlag: \(list).")
    }

    static var secondaryLine: String {
        let list = secondary.map(\.label).joined(separator: String(localized: " oder "))
        return String(localized: "Auch möglich, wenn du magst: \(list).")
    }
}
