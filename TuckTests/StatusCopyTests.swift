import Testing
@testable import Tuck

// Guards what the consolidation was for: one noun for the window, one sentence for the
// unarmed state, one sentence shape for a failure — all of it checkable before a second language
// exists to translate it into.
struct StatusCopyTests {
    // The line may name the window and may say it is entered, never that it is armed.
    @Test func thePendingSentenceNamesTheWindowAndClaimsNoBlock() {
        let line = StatusCopy.windowPending("06:30–07:30")

        #expect(line == "Sperrfenster 06:30–07:30 ist eingetragen, noch nicht scharf gestellt.")
        #expect(!line.contains("gesperrt"))
        #expect(!line.contains("aktiv"))
    }

    // The bedtime screen used to call the same window "Ruhe-Fenster".
    @Test func onlyOneNounIsUsedForTheWindow() {
        #expect(StatusCopy.blockWindowNoun == "Sperrfenster")
        #expect(!StatusCopy.windowPending("22:00–23:00").contains("Ruhe-Fenster"))
    }

    // Registration and selection are decoupled, so a confirmed flag over an empty picker used to
    // render the same confident line as a window that actually shields something. The line may name
    // the window and must name what is missing.
    @Test func theEmptySelectionLineNamesTheWindowAndWhatIsMissing() {
        let line = StatusCopy.windowWithoutApps("bis 07:30")

        #expect(line == "Sperrfenster bis 07:30 · noch keine Apps ausgewählt")
        #expect(line.contains(StatusCopy.emptyCount))
        #expect(!line.contains("gesperrt"))
        #expect(!line.contains("aktiv"))
        #expect(line != StatusCopy.windowPending("bis 07:30"))
    }

    // The registration failure on the alarm screen was the one site phrased as
    // "konnte noch nicht scharf gestellt werden" while three others said "ließ sich gerade nicht".
    // The raw SDK text is attributed rather than spliced onto the app's own
    // sentence with a colon — the frame is the app's voice, the reason is quoted as what it is.
    // It still has to arrive verbatim and at the end: the reason is the only actionable part.
    @Test func everyFailureReadsTheSameWayAndCarriesItsReason() {
        #expect(StatusCopy.failure(subject: "Der Wecker", verb: "stellen", reason: "kein Zugriff")
            == "Der Wecker ließ sich gerade nicht stellen. Das sagt iOS dazu: kein Zugriff")
        #expect(StatusCopy.failure(subject: "Der Zugriff", verb: "erteilen", reason: "abgelehnt")
            .hasSuffix("abgelehnt"))
    }

    // Two placeholders are allowed, but only along the rule that picks between them — the
    // placeholder keeps the form of the value it replaces, singular value against count.
    @Test func eachAbsencePlaceholderKeepsTheFormOfTheValueItReplaces() {
        #expect(StatusCopy.unsetValue == "noch offen")
        #expect(StatusCopy.emptyCount == "noch keine")
        #expect(StatusCopy.unsetValue != StatusCopy.emptyCount)
    }

    @Test func noLineShouts() {
        let lines = [
            StatusCopy.waitingForSystem,
            StatusCopy.unsetValue,
            StatusCopy.emptyCount,
            StatusCopy.windowPending("07:00–07:30"),
            StatusCopy.windowWithoutApps("07:00–07:30"),
            StatusCopy.failure(subject: "Der Wecker", verb: "stellen", reason: "—")
        ]
        for line in lines {
            #expect(!line.contains("!"))
        }
    }

    // An earlier review found the status set drifting into form-and-database
    // German — a value was "nicht gesetzt", a pending call was "Warte auf iOS …". The vocabulary
    // is what is pinned, not the sentence: the same words creeping back is how the drift started.
    @Test func noStatusLineReadsLikeAFormField() {
        let lines = [
            StatusCopy.waitingForSystem,
            StatusCopy.unsetValue,
            StatusCopy.emptyCount,
            StatusCopy.failure(subject: "Der Wecker", verb: "stellen", reason: "—")
        ]
        for line in lines {
            for word in ["nicht gesetzt", "Warte auf", "wird geprüft", "Fehler", "ungültig"] {
                #expect(!line.lowercased().contains(word.lowercased()), "\(line) contains \(word)")
            }
        }
    }

    // The frame is the app's own voice, the reason is quoted — so the failure line reads as two
    // sentences and never glues raw SDK text onto the app's with a colon.
    @Test func theFailureLineQuotesTheSystemInsteadOfSpeakingItsWords() {
        let line = StatusCopy.failure(subject: "Der Wecker", verb: "stellen", reason: "NSError 42")

        #expect(line.hasSuffix("NSError 42"))
        #expect(line.contains("stellen. "))
        #expect(!line.contains("stellen: "))
    }
}
