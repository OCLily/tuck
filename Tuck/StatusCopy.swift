import Foundation

// The status lines the setup and morning screens share. Same reason ShieldCopy exists: held as
// literals at seven call sites, these three templates had already drifted apart on their own — two
// nouns for one and the same window, and one failure sentence in a tense of its own. A second
// language would have translated the drift instead of the copy.
enum StatusCopy {
    // "Sperrfenster" everywhere: the bedtime screen was alone in calling it "Ruhe-Fenster", against
    // the morning screen, the alarm screen and both store comments.
    static var blockWindowNoun: String { String(localized: "Sperrfenster") }

    // Says the same thing as the old "Warte auf iOS …" — the call is out and no answer is in — but
    // as a sentence somebody could say out loud. The old form was the app reporting its own
    // bookkeeping; this one keeps iOS named, because that is the honest reason for the wait.
    static var waitingForSystem: String { String(localized: "Einen Moment, iOS ist noch dran.") }

    // Two placeholders, one rule: the placeholder keeps the grammatical form of the value it stands
    // in for. A row whose value is one stored thing degrades to "noch offen"; a row whose value
    // is a count ("3 ausgewählt") degrades to "noch keine", because zero is a count too. Which one
    // applies is therefore readable off the row, not off taste.
    // "noch offen" rather than the older "nicht gesetzt": a value nobody has chosen yet is an open
    // question, not an empty database field, and the "noch …" form is what the count placeholder
    // beside it already uses.
    static var unsetValue: String { String(localized: "noch offen") }

    static var emptyCount: String { String(localized: "noch keine") }

    // Full hours, rounded down, and the same unit across the entire range. No switch to days above
    // 24 h: a unit that changes at a threshold is a level-up feeling, and this number has no levels
    // and no ceiling. Rounded down and never up, because it may not claim more time than has
    // passed. Below one hour it degrades like any other count — zero is a count too.
    static func fullHours(_ seconds: Int) -> String {
        let hours = seconds / 3600
        guard hours > 0 else { return emptyCount }
        return String(localized: "\(hours) Stunden")
    }

    // One axis further out than the two window lines below: those report what iOS did with a window
    // it was told about, this one says the message never left the app. Without the App Group the
    // stores write into a private container no extension can read, so every other line on the
    // morning screen would be a claim about a system that was never asked.
    static var sharedStorageMissing: String {
        String(localized: "Tuck kann seinen gemeinsamen Speicher gerade nicht öffnen. Solange das so ist, wird kein Sperrfenster eingetragen.")
    }

    // A stored window is the plan, never evidence. Neither the DeviceActivity schedule nor the
    // ManagedSettings write reports back that it took, so nothing may read as armed until the
    // registration flag says so.
    static func windowPending(_ window: String) -> String {
        String(localized: "\(blockWindowNoun) \(window) ist eingetragen, noch nicht scharf gestellt.")
    }

    // The same family, one axis further out: a registered window still shields nothing while the
    // picker is empty. Registration and selection are decoupled — BlockWindowMonitor.register never
    // reads FamilyActivitySelectionStore — so the flag alone confirmed a window over an empty
    // selection at all three screens that show it. Emptiness is
    // FamilyActivitySelectionStore.selectedActivityCount() == 0, all three token sets.
    static func windowWithoutApps(_ window: String) -> String {
        String(localized: "\(blockWindowNoun) \(window) · noch keine Apps ausgewählt")
    }

    // One axis further out than both lines above: those are about a window iOS may or may not have
    // armed, this one is about a day the app itself lets go by. The schedule is registered on all
    // seven days — DeviceActivitySchedule has no weekday parameter — so registration and selection
    // both say yes on a Saturday a Mo-Fr user never chose, and every line above would vouch for a
    // window the monitor extension is about to skip.
    //
    // Names the days rather than only denying the window: "heute nicht" alone leaves the user
    // guessing whether something broke.
    static func windowOffToday(_ days: String) -> String {
        String(localized: "\(blockWindowNoun): heute nicht — du hast \(days) gewählt.")
    }

    // Charcoal like every other line, never red, and always with the reason the SDK gave —
    // "hat nicht geklappt" alone leaves nothing to act on.
    // `verb` is a German infinitive here and an English past participle in the translation — the
    // sentence frame around it differs, the call sites pass whatever their own language needs.
    //
    // Two sentences instead of the old colon: `reason` is raw SDK text at all four call sites
    // (AlarmKit, DeviceActivity, AuthorizationCenter — always iOS), and a colon glued it onto the
    // app's own sentence, so the app appeared to be speaking that string. Attributing it instead
    // leaves the technical half exactly as it came — hiding it would be dishonest — while everything the
    // app says around it stays its own voice.
    static func failure(subject: String, verb: String, reason: String) -> String {
        String(localized: "\(subject) ließ sich gerade nicht \(verb). Das sagt iOS dazu: \(reason)")
    }
}
