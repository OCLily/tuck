import Foundation
import Testing
@testable import Tuck

// German is the source language, so every German literal in the sources IS its own catalog key —
// which makes the German runtime value the lookup key for the English one. That is the only way to
// check the translated pools without restating them here and letting the two copies drift.
struct EnglishLocalizationTests {
    private static let missing = "__MISSING__"

    // The one surface that states what the app is for: the onboarding welcome line. It is a view
    // literal with no pool behind it, so it is enumerated here — this file scans no source, an
    // unlisted line stays unchecked.
    //
    // It used to be two. The settings screen carried a rowless Section whose footer was a 44-word
    // statement of purpose; it is gone, so the second half of this set
    // is gone with it rather than pointing at a key nothing renders. The number check that rode
    // along with it (settings is not a second facts surface) went the same way: there is no
    // settings prose left to check for numbers.
    private static let onboardingIntentLine =
        "Der Morgen und der Abend sollen dir gehören, nicht dem Feed. Tuck trägt dafür zwei Sperrfenster ein — nach dem Wecker mindestens 30 Minuten, statt direkt Social Media."

    private static var intentLines: [String] { [onboardingIntentLine] }

    // Both permission dead-ends, listed once: three tests read them and each one used to carry its
    // own copy of the sentence, so a reworded line needed three edits to stay checked.
    private static let alarmDeniedLine =
        "Die Erlaubnis für den Wecker fehlt noch. Du kannst sie in den Systemeinstellungen geben — ohne sie weckt Tuck dich nicht."

    private static let accessDeniedLine =
        "Der Zugriff fehlt noch. Du kannst ihn in den Systemeinstellungen geben — bis dahin bleiben die Apps offen."

    private func english(_ key: String, table: String? = nil, in bundle: Bundle) -> String {
        bundle.localizedString(forKey: key, value: Self.missing, table: table)
    }

    private func appBundle() throws -> Bundle {
        try lprojBundle("en")
    }

    private func lprojBundle(_ language: String) throws -> Bundle {
        let url = try #require(Bundle.main.url(forResource: language, withExtension: "lproj"))
        return try #require(Bundle(url: url))
    }

    // The shield renders in its own process out of its own bundle: an English translation that only
    // reached the app would leave the one screen a blocked user actually reads in German.
    private func shieldBundle() throws -> Bundle {
        let plugIns = try #require(Bundle.main.builtInPlugInsURL)
        let appex = try #require(Bundle(url: plugIns.appendingPathComponent("TuckShield.appex")))
        let url = try #require(appex.url(forResource: "en", withExtension: "lproj"))
        return try #require(Bundle(url: url))
    }

    @Test func everyScreenPoolIsTranslated() throws {
        let bundle = try appBundle()
        let pools = MorningCopy.sublines
            + MorningCopy.wiedersehen
            + MascotStage.allCases.flatMap(\.encouragements)
            + MascotMilestone.allCases.map(\.celebration)
            + ReconsiderCopy.reasonReflections
            + [ReconsiderCopy.dismissChoice, ReconsiderCopy.unlockChoice]
            + [MorningCopy.screenTime, StatusCopy.blockWindowNoun, StatusCopy.waitingForSystem]
            + Self.intentLines
        for line in pools {
            #expect(english(line, in: bundle) != Self.missing, "untranslated: \(line)")
        }
    }

    // The rule that picks between the two placeholders only holds if both survive into the
    // second language as two distinct lines — one translation for both would collapse it silently.
    @Test func bothAbsencePlaceholdersStayDistinctInEnglish() throws {
        let bundle = try appBundle()
        let unset = english(StatusCopy.unsetValue, in: bundle)
        let empty = english(StatusCopy.emptyCount, in: bundle)

        #expect(unset == "not chosen yet")
        #expect(empty == "none yet")
        #expect(unset != empty)
    }

    // The same on the row that costs money: the unanswered state is the paywall's own line, so
    // the two screens may never drift into two English wordings for one unresolved entitlement.
    // It names the missing answer instead of an inspection in progress — the
    // German line dropped "Wird geprüft …", and the English one may not keep its register.
    @Test func theCheckingStateIsOneLineForBothScreens() throws {
        let checking = english("Noch keine Antwort", in: try appBundle())

        #expect(checking == "No answer yet")
        #expect(!checking.contains("!"))
    }

    // The same audit in the second language: the English set carried the same form-field register
    // ("not set", "Waiting for iOS …") and the raw SDK reason spliced on with a colon.
    @Test func noEnglishStatusLineReadsLikeAFormField() throws {
        let bundle = try appBundle()
        let waiting = english(StatusCopy.waitingForSystem, in: bundle)
        let unset = english(StatusCopy.unsetValue, in: bundle)

        #expect(waiting == "One moment, iOS is still on it.")
        #expect(unset == "not chosen yet")
        for line in [waiting, unset] {
            #expect(!line.contains("!"))
            for word in ["not set", "waiting for", "invalid", "error"] {
                #expect(!line.lowercased().contains(word), "\(line) contains \(word)")
            }
        }
    }

    // The bubble sets no width of its own — it sizes to its content and is only bounded by the
    // caller's .padding(.horizontal, 24), i.e. screen width - 48. Nothing in the layout enforces
    // the five-word limit itself; it holds as a copy rule alone, which is exactly why it has to
    // survive the translation: a longer English line breaks it silently and just grows taller.
    @Test func everyBubbleLineStaysUnderSixWordsInEnglish() throws {
        let bundle = try appBundle()
        let pool = MorningCopy.wiedersehen
            + MascotStage.allCases.flatMap(\.encouragements)
            + MascotMilestone.allCases.map(\.celebration)
        for line in pool {
            let translated = english(line, in: bundle)
            let words = translated.split(whereSeparator: \.isWhitespace)
            #expect(words.count <= 5, "\(translated) has \(words.count) words")
            #expect(!translated.contains("!"))
            #expect(!translated.contains { $0.isNumber })
        }
    }

    // The mascot's hint is the app's only promise of an action made to a screen reader, and since
    // the accessibility action honours it, the promise has to survive translation: an
    // untranslated hint would speak German at an English VoiceOver user on the one element whose
    // entire point is being spoken to.
    @Test func theMascotHintIsSpokenInBothLanguages() throws {
        let hint = english("Tippen für ein paar Worte", in: try appBundle())

        #expect(hint == "Tap for a few words")
        #expect(!hint.contains("!"))
    }

    // Same three rules the German line is tested against: the measurement behind it distinguishes
    // neither a phone call from scrolling nor duration from frequency, so the English line may not
    // reintroduce a magnitude, a frequency or a look back either.
    @Test func theEnglishScreenTimeLineNeitherQuantifiesNorLooksBack() throws {
        let line = english(MorningCopy.screenTime, in: try appBundle()).lowercased()

        #expect(line != Self.missing)
        #expect(!line.contains("!"))
        #expect(!line.contains("?"))
        for word in ["much", "a lot", "long", "often", "again", "always", "constantly", "too"] {
            #expect(!line.contains(word), "\(line) implies quantity or frequency via \"\(word)\"")
        }
        for word in [" was ", " were ", " had ", " spent "] {
            #expect(!line.contains(word), "\(line) looks back")
        }
    }

    // In English: the shield's exhausted subtitle is the app's exhausted screen read as one
    // sentence — in both contexts. The evening half used to be bracketed out, and it was the half
    // that was wrong: the app screen said "ein neuer Morgen" at night out of its own catalog.
    // Both sides compose the same two SharedCopy pieces, so what is left to check is that
    // the shield bundle really carries that table and that both pieces reached English there — a
    // translation that only landed in the app bundle would leave the block screen German.
    @Test func theExhaustedCopyIsWordForWordIdenticalOnBothSides() throws {
        let app = try appBundle()
        let shield = try shieldBundle()
        let table = TuckIdentifiers.sharedCopyTable

        let heading = english(ShieldCopy.exhaustedHeading, table: table, in: shield)
        #expect(heading != Self.missing)
        #expect(english(ShieldCopy.exhaustedHeading, table: table, in: app) == heading)

        for context in [OverrideContext.morning, .bedtime] {
            let body = english(ShieldCopy.exhaustedBody(for: context), table: table, in: shield)
            #expect(body != Self.missing)
            #expect(english(ShieldCopy.exhaustedBody(for: context), table: table, in: app) == body)
        }

        #expect(english(ShieldCopy.exhaustedBody(for: .morning), table: table, in: shield)
            != english(ShieldCopy.exhaustedBody(for: .bedtime), table: table, in: shield))
    }

    // The app's own button and the shield's second button say the same thing in German because both
    // read the same words; in English they read two different catalogs.
    @Test func theWayIntoTheAppIsWordedIdenticallyOnBothSides() throws {
        let key = "Ich brauche kurz Zugriff"
        let app = english(key, in: try appBundle())
        let shield = english(key, table: TuckIdentifiers.sharedCopyTable, in: try shieldBundle())

        #expect(app != Self.missing)
        #expect(app == shield)
    }

    // Same for the one dismiss word the app settled on.
    @Test func theDismissWordIsTheSameOnBothSides() throws {
        let app = english("Schließen", in: try appBundle())
        let shield = english("Schließen", table: TuckIdentifiers.sharedCopyTable, in: try shieldBundle())

        #expect(app != Self.missing)
        #expect(app == shield)
    }

    // This survives translation: the sentence may say the window is stored, never that it is armed.
    @Test func theEnglishPendingSentenceClaimsNoBlock() throws {
        let bundle = try appBundle()
        let format = english("%@ %@ ist eingetragen, noch nicht scharf gestellt.", in: bundle)
        #expect(format != Self.missing)

        let noun = english(StatusCopy.blockWindowNoun, in: bundle)
        let line = String(format: format, noun, "06:30–07:30")
        #expect(line == "Block window 06:30–07:30 is saved, not armed yet.")
    }

    // The empty-picker line travels with the same guarantee: it names the window, so the sentence
    // around it must keep saying that nothing is selected rather than that something is blocked.
    @Test func theEnglishEmptySelectionLineClaimsNoBlock() throws {
        let bundle = try appBundle()
        let format = english("%@ %@ · noch keine Apps ausgewählt", in: bundle)
        #expect(format != Self.missing)

        let noun = english(StatusCopy.blockWindowNoun, in: bundle)
        let line = String(format: format, noun, "until 07:30")
        #expect(line == "Block window until 07:30 · no apps selected yet")
        #expect(!line.contains("!"))
        for word in ["blocked", "blocking", "active", "armed"] {
            #expect(!line.lowercased().contains(word), "\(line) claims a block")
        }
    }

    // Same guarantee, other direction: the day-off line has to keep denying the window in English,
    // and it may not turn into a verdict on the days the user chose.
    @Test func theEnglishDayOffLineDeniesTheWindowRatherThanJudgingTheWeek() throws {
        let bundle = try appBundle()
        let format = english("%@: heute nicht — du hast %@ gewählt.", in: bundle)
        #expect(format != Self.missing)

        let noun = english(StatusCopy.blockWindowNoun, in: bundle)
        let line = String(format: format, noun, "Mon, Tue, Wed, Thu and Fri")
        #expect(line == "Block window: not today — you chose Mon, Tue, Wed, Thu and Fri.")
        #expect(!line.contains("!"))
    }

    // The one way from a window that is stored but not armed to the screen that can arm it. It may
    // name its destination and nothing else: a "Fix Screen Time access" would promise the repair
    // that granting the access only makes possible.
    @Test func theWayToTheAccessScreenNamesItsDestinationWithoutPromisingARepair() throws {
        let translated = english("Bildschirmzeit-Zugriff prüfen", in: try appBundle())

        #expect(translated != Self.missing)
        #expect(!translated.contains("!"))
        for word in ["fix", "repair", "will "] {
            #expect(!translated.lowercased().contains(word), "\(translated) promises a repair")
        }
    }

    // The failure frame is one template for four call sites: its English subjects and verbs
    // have to slot into the English sentence the same way the German ones do. That
    // sentence ends before the reason and quotes it, in both languages alike — the raw SDK string
    // arrives verbatim and last, it is only no longer spoken in the app's own voice.
    @Test func theEnglishFailureFrameReadsAsOneSentence() throws {
        let bundle = try appBundle()
        let format = english("%@ ließ sich gerade nicht %@. Das sagt iOS dazu: %@", in: bundle)
        #expect(format != Self.missing)

        let cases = [
            ("Der Wecker", "stellen", "Alarm could not be set just now. This is what iOS says: no access"),
            ("Der Zugriff", "erteilen", "Access could not be granted just now. This is what iOS says: no access"),
            ("Das Bettzeit-Fenster", "scharf stellen",
             "Bedtime window could not be armed just now. This is what iOS says: no access")
        ]
        for (subject, verb, expected) in cases {
            let line = String(format: format,
                              english(subject, in: bundle),
                              english(verb, in: bundle),
                              "no access")
            #expect(line == expected)
            #expect(line.hasSuffix("no access"))
            #expect(!line.contains("!"))
        }

        // The one subject built from the shared noun rather than written out: German carries the
        // article ("Das Sperrfenster"), English drops it so the noun keeps its sentence-initial
        // capital instead of reading "The Block window".
        let noun = english(StatusCopy.blockWindowNoun, in: bundle)
        let subject = String(format: english("Das %@", in: bundle), noun)
        let line = String(format: format, subject, english("scharf stellen", in: bundle), "no access")
        #expect(line == "Block window could not be armed just now. This is what iOS says: no access")
    }

    // The permission lines send the user to iOS's own Settings, and the noun is the only navigation
    // hint they have — while this app's own screen is called "Einstellungen", and the sheet carrying
    // these lines is presented from it. In English the collision was exact.
    @Test func thePermissionLinesNameTheSystemSettingsRatherThanTheAppsOwnScreen() throws {
        let bundle = try appBundle()
        #expect(english("Einstellungen", in: bundle) == "Settings")

        for german in [Self.alarmDeniedLine, Self.accessDeniedLine] {
            #expect(german.contains("Systemeinstellungen"))
            let translated = english(german, in: bundle)
            #expect(translated != Self.missing, "untranslated: \(german)")
            #expect(translated.contains("the Settings app"))
        }
    }

    // Both dead-ends used to open on the system's own verdict ("ist abgelehnt", "ist aus" / "is
    // denied", "is off") — accurate, blameless and still the register of an error dialog. What is
    // pinned is the register rather than the sentence, because that is how the fallback would come
    // back: the missing permission is the actionable half, the ruling on what the user did is not.
    @Test func neitherPermissionDeadEndOpensOnAVerdict() throws {
        let bundle = try appBundle()
        for german in [Self.alarmDeniedLine, Self.accessDeniedLine] {
            let translated = english(german, in: bundle)
            #expect(translated != Self.missing, "untranslated: \(german)")
            #expect(german.hasPrefix("Der") || german.hasPrefix("Die"))
            #expect(german.contains("fehlt noch"))
            #expect(translated.lowercased().contains("still missing"))
            for word in ["abgelehnt", "verweigert", "ist aus", "nicht erlaubt"] {
                #expect(!german.lowercased().contains(word), "\(german) reports a verdict")
            }
            for word in ["denied", "refused", "is off", "not allowed", "failed"] {
                #expect(!translated.lowercased().contains(word), "\(translated) reports a verdict")
            }
        }
    }

    // The two dead-end buttons that leave the app. The label may name the Settings app and nothing
    // past it: which row a permission sits on there is iOS's arrangement, and "Bildschirmzeit
    // erlauben" would promise a screen this app does not draw. It also has to read as the app's own
    // Settings screen's opposite — that one is "Einstellungen" / "Settings".
    @Test func theSettingsDeepLinkNamesItsDestinationWithoutPromisingWhatIsThere() throws {
        let bundle = try appBundle()
        let translated = english("Zu den Systemeinstellungen", in: bundle)

        #expect(translated == "Open the Settings app")
        #expect(!translated.contains("!"))
        for word in ["screen time", "alarm", "permission", "will "] {
            #expect(!translated.lowercased().contains(word), "\(translated) promises what is there")
        }
    }

    // The denied line lost its "weiter geht es trotzdem" when the wake step became a gate: inside
    // onboarding nothing continues until an alarm is stored, and the sentence has to hold in the
    // settings sheet as well, where nothing gates. What is left may state the permission and the way
    // back — never progress. The gate's own line is the only one that speaks about continuing, and
    // it names its condition instead of promising the outcome.
    @Test func theAlarmDenialPromisesNoProgressInEitherHost() throws {
        let bundle = try appBundle()
        let denied = english(Self.alarmDeniedLine, in: bundle)

        #expect(denied != Self.missing)
        #expect(!denied.contains("!"))
        for word in ["continue", "anyway", "either way"] {
            #expect(!denied.lowercased().contains(word), "\(denied) promises progress")
        }

        let gate = english("Weiter geht es, sobald der Wecker steht.", in: bundle)
        #expect(gate == "You can continue once the alarm is set.")
        #expect(!gate.contains("!"))
    }

    // The denied status finally has a line of its own, and it may only describe
    // the state. Without this authorization no shield can be applied at all, so any sentence about
    // apps being blocked would be exactly the overclaim to avoid.
    @Test func theDeniedAccessLineDescribesTheStateWithoutPromisingABlock() throws {
        let translated = english(Self.accessDeniedLine, in: try appBundle()).lowercased()

        #expect(translated != Self.missing.lowercased())
        #expect(!translated.contains("!"))
        for word in ["block", "shield", "lock", "will "] {
            #expect(!translated.contains(word), "\(translated) claims a block that cannot happen")
        }
    }

    // Both confirmations used to assert a ManagedSettings write that the SDK never
    // acknowledges — "Freigeschaltet" for a shield that may still stand, "Abends bleibt jetzt alles
    // offen" for one the app only asked to clear. Both are in the attempt form now, the same one
    // the arm side carries, and the translation has to keep it: a sentence about what the system
    // does would be the identical overclaim in the second language.
    @Test func theTwoConfirmationsStateWhatTheAppDidRatherThanWhatTheSystemDoes() throws {
        let bundle = try appBundle()
        let unlock = english("Freischaltung eingetragen", in: bundle)
        let bedtime = english("Bettzeit entfernt. Für den Abend ist nichts mehr eingetragen.", in: bundle)

        #expect(unlock == "Unlock recorded")
        #expect(bedtime == "Bedtime removed. Nothing is saved for the evening any more.")

        for line in [unlock, bedtime] {
            #expect(!line.contains("!"))
            for word in ["unlocked", "open", "lifted", "cleared", "will "] {
                #expect(!line.lowercased().contains(word), "\(line) claims what the write never confirms")
            }
        }
    }

    // An override tapped while no registered window is running still costs the 30 seconds and
    // the reason, but nothing else — so the confirmation may not report a spend. The English line
    // has to keep both halves: the count that did not move, and the window as the reason for it.
    // Never the shield — one that outlived its interval is the case this button exists for, and the
    // app can only read its own window.
    @Test func theUnspentOverrideLineNamesTheWindowRatherThanTheShield() throws {
        let bundle = try appBundle()
        let format = english(
            "Ohne laufendes Fenster kostet das keine Freischaltung. Noch %lld für heute übrig.",
            in: bundle
        )
        #expect(format != Self.missing)

        let line = String.localizedStringWithFormat(format, UnlockQuotaStore.morning.freeUnlockMaximum)
        #expect(line == "Without a running window this costs no unlock. 1 left for today.")
        #expect(!line.contains("!"))
        for word in ["shield", "blocked", "lifted"] {
            #expect(!line.lowercased().contains(word), "\(line) claims what the app cannot read")
        }
    }

    // The one settings row whose value is generated rather than written out: the number comes from
    // the enum, the word around it from the catalog, so an untranslated line would read "30 Minuten"
    // in an otherwise English list. The footer next to it may not promise the change reaches the
    // window that is running right now — that is exactly the unverified part.
    @Test func theWindowLengthRowIsTranslatedWithoutPromisingAnImmediateEffect() throws {
        let bundle = try appBundle()

        for line in ["Morgenfenster", "Länge", "%lld Minuten"] {
            #expect(english(line, in: bundle) != Self.missing, "untranslated: \(line)")
        }

        let footer = english("Zählt ab der Weckzeit, gilt ab morgen früh.", in: bundle).lowercased()
        #expect(footer != Self.missing.lowercased())
        #expect(!footer.contains("!"))
        for word in ["immediately", "right away", "now", "instantly"] {
            #expect(!footer.contains(word), "\(footer) promises an effect on the running window")
        }
    }

    // The eight settings footers are one short clause each, not a paragraph. The
    // rule is a copy rule — nothing in the layout enforces it, a longer line just grows taller and
    // the screen quietly turns back into the wall it was. It has to hold in the second language too,
    // where German compounds routinely become three English words.
    //
    // Ten words is the bar rather than a character count: it is what "one clause" means, and it
    // survives the length difference between the languages that a character count would not.
    // Only tokens that carry a letter count — the diagnostics line is an interpunct list, and its
    // separators are punctuation doing a comma's job, not words.
    @Test func everySettingsFooterStaysOneShortClauseInBothLanguages() throws {
        let bundle = try appBundle()
        let footers = [
            "Optional — ohne sie bleibt der Abend offen.",
            "Zählt ab der Weckzeit, gilt ab morgen früh.",
            "Gilt morgens und abends.",
            "Plus: kein Tageslimit, dazu das Bettzeit-Fenster.",
            "Auch Morgen mit Freischaltung zählen.",
            "Kommen mit den Morgen dazu und bleiben.",
            "Nur ganz durchgelaufene Fenster.",
            "Nur auf diesem Gerät. Für die Fehlersuche."
        ]
        for german in footers {
            let translated = english(german, in: bundle)
            #expect(translated != Self.missing, "untranslated: \(german)")
            for line in [german, translated] {
                #expect(!line.contains("!"))
                let words = line.split(whereSeparator: \.isWhitespace).filter { $0.contains(where: \.isLetter) }
                #expect(words.count <= 10, "\(line) has \(words.count) words")
            }
        }
    }

    // The section that is gone, asserted as gone. A rowless Section whose whole content was a
    // 44-word statement of purpose is exactly the kind of thing that gets re-added by someone who
    // remembers it fondly, and the catalog key is the only mechanical trace it leaves.
    @Test func theRemovedManifestSectionHasNoKeyLeftBehind() throws {
        let bundle = try appBundle()
        for key in ["Wofür Tuck gebaut ist",
                    "Zwei Zeiten am Tag sollen dir gehören: die Minuten direkt nach dem Wecker und die direkt vor dem Schlaf. Der Feed ist darauf gebaut, genau die zu bekommen. Tuck trägt dafür zwei Sperrfenster ein — mehr macht es nicht, und mehr soll es auch nicht."] {
            #expect(english(key, in: bundle) == Self.missing, "\(key) is still a key")
        }
    }

    // The paywall is the one screen that asks for money, so the tone rules have to hold there most
    // of all — and a translation is exactly where "Nur noch heute" gets smuggled in.
    @Test func theEnglishPaywallCopyNeitherShoutsNorHurries() throws {
        let bundle = try appBundle()
        let lines = [
            "Tuck Plus",
            "Freischaltungen ohne Tageslimit",
            "Das Bettzeit-Fenster am Abend",
            "Dieselbe Sperre, dieselbe Wartezeit, dieselbe Begründung",
            "Jederzeit kündbar",
            "Ohne Abo",
            "Wecker, Morgenfenster und Sperre",
            "%lld Freischaltung pro Tag",
            "Dein Tuck wächst mit jedem Morgen",
            "Plus abonnieren",
            "Plus wird abonniert …",
            "Du hast Plus.",
            "entspricht %@ pro Monat",
            "%@ / Monat",
            "%@ / Jahr",
            "Die Sperre selbst ist mit und ohne Abo gleich streng. Plus nimmt das Tageslimit weg, nie die Verzögerung und nie die Begründung.",
            // The business-model sentence. It has to be entered HERE by hand: this test reads a
            // hard-coded list, not a pool, so a new paywall line would go green translated or
            // untranslated alike. The tone rules apply to it like to every other line on this
            // screen, and a translation is exactly where a "hurry" gets smuggled in.
            "Tuck finanziert sich über das Abo und nicht über Aufmerksamkeit. Keine Werbung, keine Empfehlungen, nichts, was länger dauert als nötig.",
            // Guideline 3.1.2's three lines, under the same rule as the rest of the screen: the
            // legal copy states what the subscription is, and a translation is exactly where an
            // "act now" gets smuggled into a sentence nobody reads twice.
            "Nutzungsbedingungen",
            "Datenschutzerklärung",
            "Tuck Plus läuft einen Monat oder ein Jahr, je nach gewählter Periode, und verlängert sich zum selben Preis, solange es nicht spätestens 24 Stunden vor dem Ende der laufenden Periode gekündigt wird. Die Abrechnung läuft über deine Apple-ID. Kündigen geht jederzeit über „Abo verwalten“; die Kündigung gilt zum Ende der laufenden Periode."
        ]
        for line in lines {
            let translated = english(line, in: bundle)
            #expect(translated != Self.missing, "untranslated: \(line)")
            #expect(!translated.contains("!"))
            for word in ["only", "hurry", "right now", "last chance", "limited time", "miss out"] {
                #expect(!translated.lowercased().contains(word), "\(translated) hurries")
            }
        }
    }

    // Guideline 3.1.2 is checked in the language the reviewer reads: a translated renewal clause
    // that drops the period, the renewal or the way out fails review just as the missing German one
    // would, and the pool test above only proves that *something* was translated.
    // The end node falls through the net that holds every other morning line: it is not a pool
    // member but its own case in `MorningCopy.subline(…)`, before the pool fallback and after the
    // three milestone lines — exactly like "Erster Morgen." Without its own entry it would go green
    // translated or untranslated alike. `everyScreenPoolIsTranslated` does not reach it.
    @Test func theLineAfterTheWindowIsTranslatedAndStaysNeutral() throws {
        let german = "Das Morgenfenster ist vorbei. Der Rest vom Tag läuft ohne mich."
        let bundle = try appBundle()
        let translated = english(german, in: bundle)

        #expect(translated != Self.missing, "untranslated: \(german)")
        #expect(!translated.contains("!"))
        for word in ["sorry", "well done", "again", "come back", "miss", "great", "proud"] {
            #expect(!translated.lowercased().contains(word), "\(translated) judges or consoles")
        }
    }

    @Test func theEnglishRenewalClauseKeepsAllFourFactsReviewLooksFor() throws {
        let clause = english(
            "Tuck Plus läuft einen Monat oder ein Jahr, je nach gewählter Periode, und verlängert sich zum selben Preis, solange es nicht spätestens 24 Stunden vor dem Ende der laufenden Periode gekündigt wird. Die Abrechnung läuft über deine Apple-ID. Kündigen geht jederzeit über „Abo verwalten“; die Kündigung gilt zum Ende der laufenden Periode.",
            in: try appBundle()
        )
        #expect(clause != Self.missing)

        for fragment in ["one month or one year", "renews", "24 hours", "cancel", "Apple ID"] {
            #expect(clause.contains(fragment), "the English renewal clause does not say \(fragment)")
        }
        // The cancel route names the same control the button beneath it carries, in the same words.
        #expect(clause.contains(english("Abo verwalten", in: try appBundle())))
    }

    // The three trial notices. They are the app's only unprompted word about the subscription,
    // so the tone rules hold hardest there — and "your trial has expired, upgrade now" is the single most
    // standard sentence in the genre, i.e. exactly what a translation reaches for. Each of the three
    // says what stays rather than what is lost, and none of them counts anything down.
    @Test func theEnglishTrialNoticesSayWhatStaysWithoutHurryingAnyone() throws {
        let bundle = try appBundle()
        let lines = [
            "Deine Testphase läuft",
            "Die Testphase geht zu Ende",
            "Die Testphase ist vorbei",
            "Vierzehn Tage lang hat Tuck alles, was Plus hat: Freischaltungen ohne Tageslimit und das Bettzeit-Fenster am Abend.",
            "Danach gilt wieder %lld Freischaltung pro Tag. Wecker, Morgenfenster und Sperre bleiben, wie sie sind.",
            "Es gilt wieder %lld Freischaltung pro Tag. Wecker, Morgenfenster und Sperre bleiben, wie sie sind."
        ]
        for line in lines {
            let translated = english(line, in: bundle)
            #expect(translated != Self.missing, "untranslated: \(line)")
            #expect(!translated.contains("!"))
            for word in ["upgrade", "hurry", "don't miss", "expired", "lost", "last chance",
                         "act now", "unfortunately"] {
                #expect(!translated.lowercased().contains(word), "\(translated) hurries or mourns")
            }
        }

        // Both end lines carry the same constant the rest of the app carries, and it renders as one
        // — the free ceiling is 1 and the line is written without a plural for it.
        for line in lines.suffix(2) {
            let rendered = String.localizedStringWithFormat(
                english(line, in: bundle), UnlockQuotaStore.morning.freeUnlockMaximum
            )
            #expect(rendered.contains("1 unlock per day"))
            #expect(rendered.contains("stay as they are"))
        }
    }

    // The countdown is floored at one day while access is still granted (TrialStore), so the last
    // day is the case that actually renders — and a single %lld sentence gives "noch 1 Tage" there.
    // Both languages carry the plural, so both are checked.
    @Test func theTrialCountdownReadsCorrectlyOnItsLastDay() throws {
        let german = english("Testphase · noch %lld Tage", in: try lprojBundle("de"))
        #expect(String.localizedStringWithFormat(german, 1) == "Testphase · noch 1 Tag")
        #expect(String.localizedStringWithFormat(german, 14) == "Testphase · noch 14 Tage")

        let translated = english("Testphase · noch %lld Tage", in: try appBundle())
        #expect(String.localizedStringWithFormat(translated, 1) == "Trial · 1 day left")
        #expect(String.localizedStringWithFormat(translated, 14) == "Trial · 14 days left")
    }

    // The settings row that leads to the paywall used to render SubscriptionAccess.displayName,
    // whose German literals sit in a file the shield extension compiles too and therefore never
    // pass a catalog — an English user read a German status line for the whole trial, which is the
    // default first-run state and not an edge case. Every case has a key now, so every case is
    // checkable, and the footer beneath the row has to name both halves of what Plus is.
    @Test func theSubscriptionRowIsTranslatedForEveryAccessCase() throws {
        let bundle = try appBundle()

        #expect(english("Abo", in: bundle) == "Subscription")

        // The period word is the quota's, not the window's: dayRolloverHour is 0, so the allowance
        // resets at midnight and a window that spans it grants a second slot the same morning.
        let free = english("Frei · %lld pro Tag", in: bundle)
        #expect(free != Self.missing)
        #expect(String.localizedStringWithFormat(free, UnlockQuotaStore.morning.freeUnlockMaximum)
            == "Free · 1 per day")

        let trial = english("Testphase · noch %lld Tage", in: bundle)
        #expect(trial != Self.missing)
        #expect(String.localizedStringWithFormat(trial, TrialStore.lengthInDays) == "Trial · 14 days left")

        // The one case the row renders without a key: the product name is the same word in both
        // languages, and a key for it would only invite someone to translate it.
        #expect(SubscriptionTier.plus.displayName == "Plus")

        let footer = english("Plus: kein Tageslimit, dazu das Bettzeit-Fenster.", in: bundle)
        #expect(footer != Self.missing)
        #expect(!footer.contains("!"))
        #expect(footer.lowercased().contains("daily unlock limit"))
        #expect(footer.lowercased().contains("bedtime window"))
    }

    // The one screen that tells a user what they do not have. The tone rules hold there the same way
    // they hold on the paywall — and honesty twice over: the gate may neither promise what an evening
    // with Plus will do nor claim anything about the window that is or is not armed right now.
    @Test func theEnglishBedtimeGateExplainsWithoutPressureOrAPromise() throws {
        let bundle = try appBundle()
        let lines = [
            "Das Bettzeit-Fenster gehört zu Plus",
            "30 Minuten vor und 30 nach deiner Bettzeit bleiben dieselben Apps ruhig wie morgens. Mit Plus stellst du die Zeit hier ein.",
            "Plus ansehen",
            "Teil von Plus"
        ]
        for line in lines {
            let translated = english(line, in: bundle)
            #expect(translated != Self.missing, "untranslated: \(line)")
            #expect(!translated.contains("!"))
            for word in ["only", "hurry", "now", "upgrade now", "miss out", "will "] {
                #expect(!translated.lowercased().contains(word), "\(translated) hurries or promises")
            }
        }

        // The stored time is the user's own input and this row is the only place it shows, so
        // the gate stopped hiding it — but it may not stand there alone either, or the row reads as
        // an evening that is covered. Both halves in one value, and the lock word has to survive
        // the translation as much as the time does.
        let locked = String(format: english("%@ · Teil von Plus", in: bundle), "22:30")
        #expect(locked == "22:30 · Part of Plus")
        #expect(locked.contains(english("Teil von Plus", in: bundle)))
    }

    // The one thing the gated row may not do: read as a bedtime that is armed. It says the time and
    // the gate, never the evening — the removal button on the screen behind it is what acts on
    // the value, this row only keeps it visible.
    @Test func theLockedBedtimeRowShowsTheValueWithoutClaimingTheEvening() throws {
        let locked = String(format: english("%@ · Teil von Plus", in: try appBundle()), "22:30").lowercased()

        #expect(!locked.contains("!"))
        for word in ["blocked", "active", "armed", "tonight", "will "] {
            #expect(!locked.contains(word), "\(locked) claims the evening is covered")
        }
    }

    // The two colour lines are the ones a translation can quietly turn into a lie: the unlock makes
    // a colour available, the picker is what puts it on the animal. An English line that says the
    // mascot already wears it would claim a change nobody made yet.
    @Test func theEnglishColourUnlocksAnnounceAvailabilityRatherThanAChange() throws {
        let bundle = try appBundle()
        for milestone in [MascotMilestone.dustyBlue, .warmSand, .softLavender] {
            let translated = english(milestone.celebration, in: bundle).lowercased()
            #expect(translated != Self.missing.lowercased())
            for word in ["wears", "wearing", "changed", "turned", "will "] {
                #expect(!translated.contains(word), "\(translated) claims a change the picker makes")
            }
        }
    }

    // The colour row renders a name, never a raw value, so every name it can show has to exist in
    // both languages — the gap SubscriptionAccess.displayName once had, on a row that only appears
    // once someone has earned it and would therefore be seen late.
    @Test func theMascotSettingsCopyIsTranslatedForEveryNameItCanShow() throws {
        let bundle = try appBundle()

        for line in ["Dein Tuck", "Farbe", "Blätter",
                     "Kommen mit den Morgen dazu und bleiben."] {
            let translated = english(line, in: bundle)
            #expect(translated != Self.missing, "untranslated: \(line)")
            #expect(!translated.contains("!"))
        }

        let names = MascotColorVariant.allCases.map(\.displayName) + MascotBadge.allCases.map(\.displayName)
        for name in names {
            let translated = english(name, in: bundle)
            #expect(translated != Self.missing, "untranslated: \(name)")
            #expect(!translated.contains { $0.isNumber })
        }
        #expect(english("Staubblau", in: bundle) == "Dusty Blue")
        #expect(english("Vierteljahr", in: bundle) == "Quarter year")
    }

    // The row of markers that unlock nothing may not be named like a trophy shelf in either language
    // — "Abzeichen" / "Badges" was literally the trophy vocabulary the app rules out. The word it carries instead
    // is the one the celebration line already spoke, so the two surfaces name the same thing.
    @Test func theMarkerRowIsNamedAfterTheCelebrationRatherThanAfterATrophy() throws {
        let bundle = try appBundle()
        let title = english("Blätter", in: bundle)

        #expect(title == "Leaves")
        for word in ["Abzeichen", "Trophäe", "Auszeichnung", "Erfolge"] {
            #expect(english(word, in: bundle) == Self.missing, "\(word) is still a key")
        }
        for word in ["badge", "trophy", "achievement", "award"] {
            #expect(!title.lowercased().contains(word), "\(title) names a trophy")
        }
        #expect(MascotMilestone.quarterYearBadge.celebration.contains("Blatt"))
        #expect(english(MascotMilestone.quarterYearBadge.celebration, in: bundle).lowercased().contains("leaf"))
    }

    // The section heads sit beside their own footers, which are whole warm sentences, and two of them
    // read as a filing system next to that. "Freischaltungen" was the harder one: the section is the
    // way in when someone really has to get in, and naming the mechanism made a ledger of it. What
    // this pins is that neither head sells the subscription under its new warmth.
    @Test func theSettingsSectionHeadsCarryTheSameWarmthAsTheirFooters() throws {
        let bundle = try appBundle()

        #expect(english("Deine Zeiten", in: bundle) == "Your times")
        #expect(english("Zeiten", in: bundle) == Self.missing)

        let unlocks = english("Wenn es doch mal nötig ist", in: bundle)
        #expect(unlocks == "When you really need to get in")
        #expect(!unlocks.contains("!"))
        for word in ["plus", "upgrade", "only", "now", "free", "buy"] {
            #expect(!unlocks.lowercased().contains(word), "\(unlocks) sells instead of naming the case")
        }

        // The paywall keeps the mechanism as its own title: it is the screen about unlocks, and the
        // section head is the one place the word had no business standing.
        #expect(english("Freischaltungen", in: bundle) == "Unlocks")
    }

    // The reconsider line mirrors the reason the user picked, and the rule it carries is that it
    // mirrors rather than weighs — a property of the wording, so it has to be checked in the second
    // language too, where "you" is a single word away in every sentence and a question mark is a
    // single keystroke. The two choices next to it have to keep their weight: neither may turn into
    // an apology, and neither may presuppose the other.
    @Test func noEnglishReconsiderLineAddressesOrJudgesTheReader() throws {
        let bundle = try appBundle()
        for reason in OverrideReason.allCases {
            let line = ReconsiderCopy.reasonReflection(for: reason)
            let translated = english(line, in: bundle)
            #expect(translated != Self.missing, "untranslated: \(line)")
            #expect(!translated.contains("!"))
            #expect(!translated.contains("?"))
            // The mirror has to survive the translation: an English line that drops the reason word
            // stops being a mirror and becomes a generic sentence.
            let name = english(reason.displayName, table: TuckIdentifiers.sharedCopyTable, in: bundle)
            #expect(name != Self.missing, "untranslated reason: \(reason.displayName)")
            #expect(translated.contains(name), "\(translated) does not name \(name)")
            let words = translated.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init)
            for word in ["you", "your", "yours", "should", "must", "anyway", "justified", "really"] {
                #expect(!words.contains(word), "\(translated) addresses or judges the reader via \"\(word)\"")
            }
            for word in ["proves", "proof", "always", "everyone", "too much", "too often"] {
                #expect(!translated.lowercased().contains(word), "\(translated) judges the choice")
            }
        }

        #expect(english(ReconsiderCopy.dismissChoice, in: bundle) == "I'll leave it after all")
        #expect(english(ReconsiderCopy.unlockChoice, in: bundle) == "Unlock")
        // The house word it extends, from the shield's own catalog: one wording for leaving it.
        #expect(english("Ich lass es", table: TuckIdentifiers.sharedCopyTable, in: try shieldBundle())
            == "I'll leave it")
    }

    // The intent copy is one judgement away in either language: "too much", "finally", "again" all
    // turn a sentence about the feed into a sentence about how the reader has been living, which is
    // the shame mechanism the app refuses. Checked on both sides, because the German line can hold
    // the rule while a translation quietly drops it.
    // The number check covers the settings section alone (it is not a second facts surface);
    // the onboarding line keeps its "30 Minuten", which is the mechanism, not a fact.
    @Test func theIntentCopyJudgesTheFeedRatherThanTheReader() throws {
        let bundle = try appBundle()
        for line in Self.intentLines {
            let translated = english(line, in: bundle)
            #expect(translated != Self.missing, "untranslated: \(line)")
            for text in [line, translated] {
                #expect(!text.contains("!"))
                #expect(!text.contains("?"))
                let lowercased = text.lowercased()
                for phrase in ["zu viel", "zu oft", "too much", "too often"] {
                    #expect(!lowercased.contains(phrase), "\(text) judges the reader via \"\(phrase)\"")
                }
                let words = lowercased.split(whereSeparator: { !$0.isLetter }).map(String.init)
                for word in ["endlich", "wieder", "finally", "again", "schützt", "protects"] {
                    #expect(!words.contains(word), "\(text) judges the reader or overclaims via \"\(word)\"")
                }
            }
        }
    }

    // The counter's row says what the APP did, never what the user is like — that survives or dies
    // in the translation, so the header is checked word for word rather than only for presence.
    // The hour is the set's second real plural, and the unit may not switch to days anywhere: an
    // English "1 day" past 24 h would be the level-up feeling the row exists without.
    @Test func theProtectedTimeRowNamesTheAppAndKeepsOneUnit() throws {
        let bundle = try appBundle()

        // Not "saved": directly above a bare "14 hours", with the object elided, that reads as saved
        // screen time — the counterfactual the row exists without (docs/design/design-system.md).
        // The German "eingetragen" does not carry that reading, so only the translation had to move.
        let header = english("Was Tuck eingetragen hat", in: bundle)
        #expect(header == "What Tuck has set up")
        #expect(!header.lowercased().contains("saved"))
        #expect(english("Sperrfenster insgesamt", in: bundle) == "Block windows in total")

        let footer = english("Nur ganz durchgelaufene Fenster.", in: bundle)
        #expect(footer != Self.missing)
        #expect(!footer.contains("!"))
        // No "blocked" and no "gained" — the app cannot know either — and no address to the
        // reader, because the sentence is about what the app registered, not about them.
        for word in ["blocked", "gained", "saved you", "you ", "your "] {
            #expect(!footer.lowercased().contains(word), "\(footer) claims more than the app knows")
        }

        let german = english("%lld Stunden", in: try lprojBundle("de"))
        #expect(String.localizedStringWithFormat(german, 1) == "1 Stunde")
        #expect(String.localizedStringWithFormat(german, 14) == "14 Stunden")
        #expect(String.localizedStringWithFormat(german, 400) == "400 Stunden")

        let translated = english("%lld Stunden", in: bundle)
        #expect(String.localizedStringWithFormat(translated, 1) == "1 hour")
        #expect(String.localizedStringWithFormat(translated, 14) == "14 hours")
        #expect(String.localizedStringWithFormat(translated, 400) == "400 hours")
    }

    // No exclamation mark in the whole English set either — the rule is about the voice, not about
    // the German grammar it was first written in.
    @Test func nothingShoutsInEnglish() throws {
        let bundle = try appBundle()
        let lines = MorningCopy.sublines
            + MorningCopy.wiedersehen
            + MascotStage.allCases.flatMap(\.encouragements)
            + MascotMilestone.allCases.map(\.celebration)
            + ReconsiderCopy.reasonReflections
            + [ReconsiderCopy.dismissChoice, ReconsiderCopy.unlockChoice]
            + [BlocklistSuggestions.intro,
               BlocklistSuggestions.shortVideoExamples,
               BlocklistSuggestions.socialNetworksNote]
            + (BlocklistSuggestions.primary + BlocklistSuggestions.secondary).map(\.reason)
        for line in lines {
            let translated = english(line, in: bundle)
            #expect(translated != Self.missing, "untranslated: \(line)")
            #expect(!translated.contains("!"))
        }
    }

    // The one user-facing string that lives in Info.plist instead of in the sources: iOS renders it
    // verbatim in the alarm-authorization alert on the first-run path. Without a compiled
    // InfoPlist.strings iOS falls back to the raw plist value, so an English user reads German at the
    // one prompt they cannot skip.
    @Test func theAlarmUsageDescriptionIsLocalizedInBothLocales() throws {
        let key = "NSAlarmKitUsageDescription"
        let raw = try #require(Bundle.main.infoDictionary?[key] as? String)

        let german = english(key, table: "InfoPlist", in: try lprojBundle("de"))
        #expect(german != Self.missing, "de.lproj carries no InfoPlist.strings")
        // The German localization has to stay the plist fallback word for word — two German wordings
        // for the same alert is exactly the drift the design system forbids.
        #expect(german == raw)

        let translated = english(key, table: "InfoPlist", in: try appBundle())
        #expect(translated != Self.missing, "en.lproj carries no InfoPlist.strings")
        #expect(translated != german, "the English alert still shows the German sentence")
    }

    // The picker rows are Apple's own category names, so the translation is Apple's English wording
    // and not a translation of the German one — a "Social networks" row does not exist in the picker.
    @Test func theSuggestionLabelsUseApplesEnglishCategoryNames() throws {
        let bundle = try appBundle()
        #expect(english("Soziale Netze", in: bundle) == "Social")
        #expect(english("Unterhaltung", in: bundle) == "Entertainment")
        #expect(english("Spiele", in: bundle) == "Games")
        #expect(english("Informationen & Lesen", in: bundle) == "Information & Reading")
    }
}
