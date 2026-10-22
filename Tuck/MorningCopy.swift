import Foundation

// Ton-Regel für jede Zeile hier: Aussagen über die Gegenwart, nie Aufforderungen, nie
// Versprechen über den Tag, kein Ausrufezeichen im ganzen Set.
enum MorningCopy {
    static func greeting(at date: Date, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)
        return (4...10).contains(hour)
            ? String(localized: "Guten Morgen")
            : String(localized: "Schön, dass du da bist")
    }

    // The full ranking of the subline slot, so it stands written down once: ScreenTimeNotice (in
    // `refreshSubline()`) -> milestone (1/7/30) -> end node -> pool. The milestone wins on purpose: a
    // line that appears once in a user's life may not be pushed aside by one that can appear on
    // every day with an alarm.
    //
    // `isPastBlockWindowToday` has NO default value, and that is deliberate against the house rule
    // for new parameters. A default would silence exactly the eight call sites at which a reviewer
    // can see that the new axis was considered everywhere — and "new parameters get a default"
    // is a rule about callers one does not know. Here there are eight, all in this repo.
    //
    // The name says what the three parts MEAN together, not how they were computed: whether a window
    // exists, whether it applies today, and whether it is over are three reads of state and of the
    // clock, and this file is Foundation-only and deterministic. The condition is evaluated in
    // `GutenMorgenView.refreshSubline()`, where `.now` and store access are already convention.
    static func subline(morningIndex: Int, completedMornings: Int, isPastBlockWindowToday: Bool) -> String {
        switch completedMornings {
        case 1: return String(localized: "Erster Morgen.")
        case 7: return String(localized: "Siebter Morgen.")
        case 30: return String(localized: "Dreißigster Morgen.")
        default:
            // Read it aloud assuming the user unlocked early this morning: it may not sound like
            // consolation, because consolation implies a harm. No number, no praise, no regret, no
            // invitation to come back — a statement about the day, in the app's own voice.
            if isPastBlockWindowToday {
                return String(localized: "Das Morgenfenster ist vorbei. Der Rest vom Tag läuft ohne mich.")
            }
            return sublines[((morningIndex % sublines.count) + sublines.count) % sublines.count]
        }
    }

    // Stable index for the morning `date` belongs to. Deliberately not derived from hashValue:
    // Swift seeds String/Date hashing per process launch, so the line would change on every
    // app restart instead of once per morning.
    static func morningIndex(for date: Date,
                             alarm: WakeAlarmStore.ScheduledAlarm?,
                             calendar: Calendar = .current) -> Int {
        if let alarm,
           let anchor = MorningBlockWindow.mostRecentStart(of: alarm.blockWindowStart,
                                                           atOrBefore: date,
                                                           calendar: calendar) {
            return Int(anchor.timeIntervalSince1970 / 86_400)
        }
        return calendar.ordinality(of: .day, in: .era, for: date) ?? 0
    }

    // The one pick every screen pool goes through, and the reason it exists: three of the four tone
    // choices in the app used to roll dice (`randomElement()`), which is a drift against the design rule "kein
    // Zufallselement — auch nicht in der Auswahl der Geste". It is not a variable-ratio violation —
    // the answer always comes, only its wording varies — but determinism is simply cheaper here: a
    // deterministic pick is testable, a random one is not.
    //
    // Same double modulo as `subline` above, for the same reason and with the same precedent test
    // (`negativeIndicesStayInsideThePool`).
    static func line(from pool: [String], index: Int) -> String {
        guard !pool.isEmpty else { return "" }
        return pool[((index % pool.count) + pool.count) % pool.count]
    }

    // Deliberately about the morning, not about the user: no "du hast", no question, nothing to
    // justify. The measurement behind it is a single cumulative-time threshold — it cannot tell a
    // phone call from scrolling, and it cannot tell frequency from duration either (40 minutes
    // straight and 40 minutes in twenty check-ins trip the same event), so no quantity or frequency
    // word belongs here (see ScreenTimeNotice). The reason this is not phrased as a look back:
    // evaluative reflection on one's own screen time raised shame in the field study this design
    // draws on, and shame is the mechanism this app rejects.
    static var screenTime: String { String(localized: "Das Handy ist heute Morgen mit dabei.") }

    static var wiedersehen: [String] {
        [
            String(localized: "Da bist du."),
            String(localized: "Schön."),
            String(localized: "Ich war hier."),
            String(localized: "Nichts hat sich geändert."),
            String(localized: "Alles noch da.")
        ]
    }

    static var sublines: [String] {
        [
            String(localized: "Das Licht braucht auch einen Moment."),
            String(localized: "Nichts davon läuft dir weg."),
            String(localized: "Erst wach werden, dann die Welt."),
            String(localized: "Der Tag fängt langsam an. Du auch."),
            String(localized: "Draußen wird es gerade hell."),
            String(localized: "Kein Grund zur Eile."),
            String(localized: "Die ersten Minuten gehören dir."),
            String(localized: "Alles, was wichtig ist, wartet."),
            String(localized: "Ein Morgen ohne Bildschirm ist trotzdem ein Morgen."),
            String(localized: "Still ist auch etwas."),
            String(localized: "Du musst hier nichts erreichen."),
            String(localized: "Der Rest kommt von allein.")
        ]
    }
}
