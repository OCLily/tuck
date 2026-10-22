# Audit-Log

Dauerhafte Kurzfassung der Code-Audits, Fixes und Entscheidungen, chronologisch von 2026-09-02 bis 2026-09-17. Der Log beginnt mit dem Audit des ersten Build-Schritts (Xcode-Scaffold). Diente als Referenzpunkt für spätere Cross-Checks — nicht als Ersatz für die ausführlichen Dokumente in `docs/`.

## 2026-09-02 — Audit entlang mehrerer Dimensionen + 2 Fix-Runden

**Methode:** Audit entlang vier Dimensionen (Code-Qualität, Security, Silent-Failure, Type-Design), jeder Fund gegen den echten Code gegenverifiziert, danach 2 Fix-Runden mit jeweils anschließender Nachprüfung.

**Ausgangsbefund:** 1 BLOCKER (Test-Target nicht baubar, Tests liefen nie im echten Projekt), 6 HIGH (u.a. `NSAlarmKitUsageDescription` lautlos verworfen, `@preconcurrency`-Unterdrückung eines echten Swift-6-Data-Race, `fatalError()` in der Shield-Action-Extension, hartkodierte Extension-Versionsnummern), mehrere LOW.

**Fix-Runde 1:** Alle 9 Findings adressiert. Die Nachprüfung fand: die Concurrency-„Lösung" war keine echte Lösung, sondern eine noch breitere Unterdrückung (`@retroactive @unchecked Sendable`, modulweit statt datei-weit) mit sachlich falschem Kommentar — plus zwei neue Findings (nicht-exhaustiver Switch in der Shield-Action-Extension, ein weiterer ungenauer Kommentar).

**Fix-Runde 2:** Alle 3 Restfunde behoben — echte Lösung für den Data Race gefunden (`nonisolated`-Helper-Funktion, liest `.shared` innerhalb eines nicht-isolierten Kontexts, keine Sendable-Unterdrückung nötig), Switch vollständig exhaustiv gemacht, Kommentar korrigiert.

**Endstand:** 0 BLOCKER, 0 HIGH. 3 triviale LOW-Reste (Kommentar-Ungenauigkeit, unerreichbarer `else`-Zweig, eine nicht ganz beweisbare Formulierung) — bewusst nicht weiter verfolgt, keine Sicherheitsrelevanz.

**Verifiziert, nicht nur behauptet:** Alle vier `MorningBlockWindow`-Tests liefen am Ende echt im Xcode-Projekt (`xcodebuild test`, xcresult auf Platte), nicht mehr nur in einem Ersatz-Harness außerhalb des Projekts.

## 2026-09-03 — Guten-Morgen-Feinschliff, Onboarding-Blocklist-Copy, Bettzeit-Fenster, erster echter Sperr-Mechanismus

**Methode:** durchgehend Bauen und Prüfen, jeder Build wurde nachgeprüft (Code lesen, selbst neu bauen/testen, bei UI-Fragen live im Simulator).

**Guten-Morgen-Feinschliff:** 3 Design-Richtungen verglichen, zusammengeführt und gebaut (Sonnenaufgang nach echtem Fensterfortschritt, Atem-Rig mit getrennten Transform-Ebenen, absteigende Tap-Interaktionen). Die Prüfung fand 2 HIGH (Bottom-Padding nur in DEBUG, Kontrast durch Opazität unter WCAG) + 2 MEDIUM (Timer-Races bei schnellen Taps, fehlendes VoiceOver-Label am Fortschrittsring) — alle behoben. Ring-Überlauf-Animation (weicher Übergang statt Hart-Reset an Wachstumsstufen) danach separat gebaut und freigegeben, nur LOW-Reste.

**Onboarding-Blocklist-Vorschläge:** recherchiert (Apple-Kategorie-Taxonomie aus dem echten SDK/Runtime verifiziert, Konkurrenzanalyse, Sucht-Forschung), Ergebnis widerlegte die ursprüngliche Prämisse (keine Kategorie-Vorauswahl technisch möglich) — Umsetzung als Erklärtext. Die Prüfung fand 3 HIGH (Dynamic-Type schnitt den Pflicht-Warnhinweis ab, "Weiter"-Button bei Accessibility-Textgrößen unerreichbar — beides Regression durch die neue Copy; ein drittes war eine akzeptierte Produktentscheidung, keine Änderung). Beide echten HIGH behoben, dabei fielen 3 weitere Vorkommen desselben Opazitäts-Kontrast-Musters auf und wurden mitgefixt.

**Bettzeit-Fenster (neues Feature):** Recherche widerlegte die eigene Ausgangsannahme, der Morgen-Sperr-Mechanismus sei bereits verdrahtet — im ganzen Repo existierte keine einzige `DeviceActivity`-/`ManagedSettings`-Call-Site. Bettzeit wurde damit zum Anlass, den Sperr-Mechanismus für Morgen UND Bettzeit gemeinsam zum ersten Mal echt zu bauen (App-Group/Family-Controls-Entitlements am App-Target, echte `FamilyActivitySelection`-Persistenz zwischen App und Extension, echte `DeviceActivityCenter`-Registrierung, echte Monitor-Extension-Logik).

**Erster Prüfdurchgang:** 4 HIGH — Screen behauptet ein scharfes Sperrfenster ohne Bestätigung der echten Registrierung; totes Nachrüst-Versprechen im Code-Kommentar plus eine Sackgasse (wer die Berechtigung im Onboarding aufschiebt, kommt in einem Release-Build nie wieder zur App-Auswahl); zwei bewiesene Kontingent-Bugs (Bettzeit-Änderung füllt das Abend-Kontingent wieder auf). Alle vier adressiert.

**Zweiter Prüfdurchgang:** 1 BLOCKER — der erste Kontingent-Fix schloss nur die eine Richtung, die eigene Regressionstests zufällig testeten; das Kontingent blieb über Alternieren der Bettzeit unbegrenzt farmbar (bewiesen: 10 Wiederholungen → 10 statt 1 Freischaltung), reproduzierbar über den echten UI-Pfad, keine Debug-Werkzeuge nötig. Plus 1 neuer HIGH (Registrierungs-Flag blieb nach Berechtigungsentzug fälschlich "bestätigt") und 3 verwandte LOW.

**Dritter Prüfdurchgang (finale Fassung):** BLOCKER durch strukturelle Neufassung behoben — der Kontingent-Anker ist jetzt eine reine Funktion von `(now, calendar)`, liest keinen vom Nutzer editierbaren Wert mehr. Mit 12 eigenen, gegen den alten Code kontrollierten Tests bewiesen (8 von 12 schlagen auf dem Vor-Fix-Stand fehl, alle bestehen danach). **Endstand: 0 BLOCKER, 0 HIGH.** 3 dokumentierte LOW-Reste, bewusst nicht weiterverfolgt: Zeitzonen-Wechsel könnte das Kontingent theoretisch erneut füllen (braucht Verlassen der App + iOS-Einstellungsänderung, kein Ein-Tap-Exploit mehr); ein Bettzeit-Fenster, das die 6-Uhr-Tagesgrenze selbst überspannt, gewährt einmalig einen zusätzlichen Slot (bewiesen begrenzt auf +1, nie mehr); der Wecker-Sheet gleicht als einziges der drei Sheets nicht beim Schließen ab (Asymmetrie, nicht funktional falsch).

## 2026-09-04 — Kompletter Repo-Review + 1 weiterer Fix-Durchgang

**Anlass:** Der Vorabend schloss mit "0 BLOCKER, 0 HIGH" (Eintrag oben). Der Review lief auf dem lokalen Repo-Zustand entlang fünf Prüfrichtungen, jeder Fund wurde einzeln kritisch gegengeprüft, Ergebnis als Bericht. Die fünf: Konformität mit den Konventionen des Projekts, Bug-Scan auf den Tages-Diff, Wiederholungs-Sweep bekannter Fehlermuster aus diesem Log, Doku-vs-Code-Abgleich, Kommentar-vs-Code-Abgleich. 42 Rohfunde, 8 überlebten die Gegenprüfung.

**Der wichtigste Fund:** Der Morgen-Kontingent-Anker hatte exakt denselben Fehler, der am Vorabend für die Bettzeit gefunden und gefixt wurde (Kontingent-Reset an einen vom Nutzer editierbaren Wert gekoppelt) — nur nie auf die Morgen-Seite übertragen. Reproduzierbar über die echte UI (Wecker neu stellen, klingeln lassen, abstellen → Kontingent voll, Streak +1, unbegrenzt wiederholbar), einzige Hürde ein echtes Wecker-Klingeln statt eines Ein-Tap-Edits.

**Zweiter, schwerwiegenderer Fund:** Der komplette Entsperr-Mechanismus (`OverrideFlowView`) verbrauchte eine bezahlte Freischaltung und zeigte "Freigeschaltet" — ohne dass irgendein Code-Pfad den Shield tatsächlich aufhob. Auf einem echten Gerät hätte jeder Override-Versuch die Freischaltung verbrannt, ohne je durchzulassen. Nicht als BLOCKER eingestuft, weil der Pfad im Simulator ohnehin nicht ausführbar ist (Family Controls fehlt), aber funktional bedeutender als ein klassischer BLOCKER, da er die zentrale Produktmechanik betrifft.

**Weitere Funde:** eine dokumentierte Architekturentscheidung (C1: Shield synchron aus der App setzen, nicht aus der Extension) beim Bau des Sperr-Mechanismus still nicht umgesetzt — als offene Architekturfrage weitergereicht, nicht eigenmächtig entschieden; 8 weitere Instanzen des Opazität-Kontrast-Musters (3 davon *nach* der eigenen Doku-Regel geschrieben — echte Regression unter Zeitdruck); ein durch nachträgliche Commits falsch gewordener Kommentar.

**Fix-Durchgang:** alle vier behebbaren Funde gefixt (Kontingent-Anker nach demselben bewiesenen Muster wie Bettzeit umgebaut, Shield-Clear beim Override-Abschluss ergänzt, Kontrast-Sweep, Kommentar korrigiert), anschließend gegengeprüft — inklusive eigener Kontrollgruppe gegen den Vor-Fix-Stand (40 Wiederholungen: `spent → 80` vorher, `spent == 2` nachher). **Endstand: 0 BLOCKER.** 6 neue LOW-Funde dokumentiert, keiner davon eine Farming-Lücke:
- 30-Sekunden-Grenzfall: ein Override-Tap in den letzten 30s vor einem Fenster-Wechsel kann das falsche Fenster leeren (bestehende Kontingent-Unschärfe, jetzt auch für den Shield). Das Fenster war ursprünglich 12s und wurde mit der Verzögerung auf 30s ebenfalls auf 30s verbreitert — dieselbe Unschärfe, größere Trefferfläche.
- `unlock()` würde auch bei leerem Kontingent den Shield aufheben — heute unerreichbar, weil die UI vorher sperrt, nicht das Modell.
- Die Reconcile-Begründung am Override-Sheet ist ungenau formuliert (Ergebnis stimmt, Begründung nicht).
- **Nicht abschließend geklärt:** die "15pt @ 700 = WCAG-Großtext"-Einstufung, die vier Fix-Runden trägt, beruht möglicherweise auf einer CSS-pt-vs-iOS-pt-Verwechslung — ungeprüft, ob das auf dieser Palette überhaupt erreichbar ist. Entweder bewusst so akzeptieren oder die Textfarbe abdunkeln.
- `BedtimeProgressStore`s Kommentar behauptet noch die jetzt falsche Asymmetrie zur Morgen-Seite ("Morgen füllt sich per echter Nutzerhandlung, Abend braucht lazy Reset") — beide Stores sind jetzt strukturell identisch bis auf zwei Konstanten. Zusammenlegen beim dritten Auftreten dieser Form, nicht jetzt (chirurgischer Scope).

## 2026-09-04 — Settings-Ansicht, Store-Merge, erste StoreKit-Integration

**Settings-Ansicht + Store-Merge:** `Tuck/SettingsView.swift` konsolidiert Weckzeit/Bettzeit/App-Auswahl hinter einem Einstiegspunkt (ersetzt drei Einzel-Buttons auf dem Guten-Morgen-Screen), `MorningProgressStore`/`BedtimeProgressStore` zu `Shared/UnlockQuotaStore.swift` zusammengelegt (UserDefaults-Keys unverändert, Testabdeckung nach Aussage der Prüfung sogar strikt stärker als vorher). Prüfung: PASS, 0 BLOCKER, 0 HIGH, 3 triviale LOW (2 direkt nachgezogen).

**Paywall/StoreKit (erste Abo-Integration des Projekts):** lokale `.storekit`-Testkonfiguration (zwei Abo-Stufen nach B7, 0,99€/2 Freischaltungen, 2,99€/5), StoreKit-2-Statusschicht (`SubscriptionController`), `PaywallView`, Verdrahtung der Stufe in `UnlockQuotaStore`. Erste Prüfung: GO mit Auflagen — 2 HIGH (abgelaufenes Abo wird in einem laufenden Prozess nie bemerkt; Downgrade kappt das Restkontingent nicht, fälschlich als B5-Konsequenz in einem Test festgeschrieben), 7 LOW. Beide HIGH plus zwei billige LOW-Aufräumarbeiten behoben, zweite Prüfung: **0 BLOCKER, 0 HIGH.**

Zwei neue, bewusst nicht weiterverfolgte LOW-Reste aus der zweiten Prüfung:
- Der gecappte Kontingent-Wert wird beim Verbrauch dauerhaft persistiert — trifft nur, wenn StoreKit einmal transient kein Entitlement liefert und in diesem Moment verbraucht wird; Fehlerrichtung ist konservativ (zu streng, nie zu großzügig).
- Das Leeren der Kauf-Hinweismeldung beim Öffnen der Paywall löscht ungewollt auch einen laufenden "Ask to Buy"-Wartezustand (Tage dauernd, keine andere Anzeigefläche).

**Nie geklärt, jetzt dokumentiert (offene Fragen, nicht Teil dieses Exports):** B7 sagt nirgends, was ein Nutzer ohne aktives Abo bekommt. Arbeitsstand im Code: kein Abo = Standard-Kontingent (2), die Abo-Schicht hebt nur an, sperrt nie. Bewusst als Arbeitsstand markiert, nicht als Entscheidung verkauft — echte Alternative (0 Freischaltungen ohne Abo) ist ein Produktentscheid mit echtem Gewicht.

**Engagement-/Feature-Lücken-Recherche** (nicht Teil dieses Exports): getrennt von den Build-Runden — Wettbewerbsanalyse, Verhaltensforschung, Code-vs-Doku-Inventur. Wichtigster Fund: der Shield-Screen (der Screen, den ein blockierter Nutzer tatsächlich sieht) ist bis heute leer (`ShieldConfiguration()` ohne Titel/Mascot), und der B8-Entsperrpfad (Shield→App) ist nie verdrahtet — die Shield-Action-Extension gibt für jede Aktion `.defer` zurück. Alle Override-Fixes dieser Runde sind dadurch von einem echten Shield aus unerreichbar. Top-Empfehlung der Recherche, nächster Baustein.

## 2026-09-04, Fortsetzung — Shield-Screen + B8-Entsperrpfad

Umsetzung der Top-Empfehlung aus der Engagement-Recherche: echter Shield-Screen (Titel, Palette, statisches Mascot-Icon, B6-Erschöpft-Zustand — bewusst ohne Zahl, da das App-Group-Lesen der Extension im Fehlerfall lautlos auf "voll" zurückfällt) und der bisher nie verdrahtete B8-Entsperrpfad (Shield→App über `.openParentalControlsApp`, ab iOS 26.5 — verifiziert gegen das echte SDK, nicht angenommen). Drei-Gründe-Submenü routet wie der Sekundärbutton in die App, löst nichts in der Extension selbst auf.

**Erste Prüfung:** B8 hält, strukturell auf vier unabhängigen Wegen bestätigt (keine Extension kann selbst entsperren, kein `ShieldActionResponse`-Wert gewährt Zugriff, der einzige Nebeneffekt ist ein rechtelos gültiger 5-Minuten-UserDefaults-Eintrag, der Verzögerungs-Timer läuft immer vollständig). Kein BLOCKER, 2 HIGH: ein `DispatchQueue.main.sync` beim Laufzeit-Rendern des Mascot-Icons in der Extension (Hänge-Risiko), und die eine Code-Zeile, die B8 in der App durchsetzt, hatte keinen Test.

**Fix-Runde:** Mascot als vorgerendertes PNG-Asset statt Laufzeit-`ImageRenderer` (SHA-256-identisch mit einer neu erzeugten Kontrollversion — beweist, dieselbe Zeichnung, kein Redesign), B8-Entscheidung in eine reine, testbare Funktion gezogen und mit einem Mutationstest abgesichert (`thePreselectedPathCanNeverOpenAlreadyConfirmed` — schlägt nachweislich fehl, wenn `.confirmed` statt `.breathing` zurückgegeben würde), plus ein echter Bug behoben (eine Shield-Entsperr-Anfrage ging verloren, wenn beim Foregrounding gerade die Einstellungen offen waren). **Zweite Prüfung: 0 BLOCKER, 0 HIGH, B8 erneut bestätigt intakt.**

Vier neue LOW-Reste, bewusst nicht weiterverfolgt:
- Der B8-Regressionstest sichert die extrahierte Funktion, nicht zwingend jeden künftigen Aufrufer — ein Test, der `OverrideFlowView` selbst konstruiert statt nur die Funktion, wäre die engere Absicherung.
- Dasselbe verlorene-Anfrage-Muster wie beim Einstellungs-Sheet besteht spiegelbildlich beim Override-Sheet selbst (milder, der Nutzer steckt dort bereits im Flow).
- Der 5-Minuten-Gültigkeitsdeckel der Übergabe wurde im Fix-Bericht nicht erwähnt (aus "sofort verloren" wird "nach 5 Minuten verloren", kein vollständiger Fix der Zeitdimension).
- Zwei Doku-Querverweise zeigen nach der Konsolidierung auf die falsche/veraltete Liste.

## 2026-09-04, Fortsetzung — Backlog-Runde (Override-Dauer, Bettzeit-Onboarding, Token-Verfall, Doku-Drift) + Umgehungswege-Recherche

**Backlog, fünf unabhängige Aufgaben:** Override-Verzögerung 12s → 30s (Produktentscheidung, dabei einen echten Sync-Bug gefunden — der Atem-Text stand die ganze Zeit auf "Einatmen" fest, nie "Ausatmen"; Fix-Runde ergänzte außerdem Reduce-Motion-Unterstützung, die vorher komplett fehlte). Bettzeit-Onboarding-Schritt nachgebaut (fehlte trotz entschiedenem v1-Scope). Token-Verfall-Behandlung für die App-Auswahl (`Shared/TokenRefresh.swift`) — erste Berührung von `ManagedSettingsStore.refresh(_:)` im Projekt, SDK-Fakten sauber verifiziert. Doku-Drift in der ursprünglichen Produktspezifikation und in der README korrigiert (behaupteten weiterhin "Phase 1 abgeschlossen"). Alle fünf: 0 BLOCKER, 0 HIGH nach Fix-Runden, nur LOW-Reste.

**Umgehungswege-Recherche:** "Sanft erkennen und ansprechen" wie entschieden — Ergebnis widerlegt die technische Prämisse. `DeviceActivityEvent` kann nur explizite Ziel-Mengen oder buchstäblich alles messen, nie "alles außer der Auswahl" (keine Negation, anders als bei `ShieldSettings`), und der Callback liefert keine App-Identität. Echte Umgehungserkennung ist damit strukturell nicht baubar, nicht nur schwierig. Nebenbefund: die `.swiftdoc`-Dateien (bisher im Projekt nie gelesene Quelle) klären zwei vorher offene Geräte-Fragen ganz ohne Gerät — 15-Minuten-Mindestintervall, 20-Activities-Obergrenze pro App.

**Gebaute, ehrlichere Alternative** (`Shared/ScreenTimeNotice.swift`): ein einmaliger, sich selbst löschender Hinweis auf dem Guten-Morgen-Screen, wenn die kumulierte Bildschirm-Vordergrundzeit im Morgenfenster eine Schwelle (2/3 des Fensters) überschreitet — ohne Zahl, ohne Vergleich, ohne Wertung. Die Prüfung fand 2 HIGH: (1) Tucks eigene Vordergrundzeit (Mascot-Animation, Override-Timer, Settings) zählt auf denselben Schwellwert wie echte Ablenkung — die App könnte sich damit selbst falsch vorwerfen, "viel Handy" gewesen zu sein. **Bewusst nicht gefixt, bleibt offene Produktfrage bis zum Geräte-Killkriterium** (in der Liste offener Punkte nachgetragen, nicht Teil dieses Exports). (2) Ein Cold-Launch-Race konnte den Hinweis lautlos verbrauchen, ohne dass er je sichtbar wurde — behoben. Nach der Fix-Runde fiel zusätzlich auf, dass die Copy ("...oft im Spiel") eine Häufigkeits-Aussage traf, die die Messung (ein einzelner Zeit-Schwellwert) grundsätzlich nicht tragen kann — direkt selbst korrigiert, kein eigener Fix-Durchgang nötig.

**Endstand:** 0 BLOCKER auf dem ganzen Strang. HIGH-1 bleibt der einzige offene Punkt dieser Runde, explizit als Entscheidung an den Projektinhaber weitergereicht, nicht stillschweigend übergangen.

## 2026-09-05 — Fix-Runde auf den Voll-Audit: die Berechtigungs- und Setup-Fehlerpfade

**Anlass:** `docs/full-app-audit-2026-09-05.md` §4.1 — die Punkte, die ein Review-Tester in den ersten fünf Minuten trifft. Vier Funde dieser Runde: H1, H2, H6, L25. Die Produktentscheidungen aus §4.2 sind bewusst unangetastet geblieben; wo ein Fix an eine grenzt, ist nur die Bugfix-Hälfte gebaut.

**H1 — Fehler-Zweig verdeckt die Denied-Zeile**: Die Zweig-Reihenfolge war `if let authorizationError` → `.approved` → `.denied`, und der Fehler wurde nur bei Erfolg gelöscht. Eine Ablehnung meldet sich zweimal — als geworfener Fehler *und* als Status —, also ersetzte der einzige Button des Screens den einzigen Satz, der den Weg zurück nennt, durch die rohe `localizedDescription`. Jetzt vier gleichrangige Zustände in einem `switch` (die Form, die `WakeAlarmSetupView.statusLine` schon hat), Status schlägt Fehler, und `.onAppear` räumt den Fehler ab. Die Auflösung ist eine reine Funktion (`FamilyControlsAccessState.resolve`) und damit prüfbar ohne die Autorisierung, die der Simulator nie erteilt — drei Tests, darunter der Mutationsfall „denied schlägt den Fehler, den es geworfen hat". **Kein Deep-Link in die Systemeinstellungen** — das ist §4.2 Punkt 6 und nicht entschieden.

**H2 — Auto-Dismiss über eine fehlgeschlagene Registrierung**: `status = .scheduled(fireDate)` stand außerhalb des inneren `do/catch`, also schloss der Sheet 1,2 s später und der Grund war für immer weg. Drei Teile: der Erfolgsfall trägt jetzt die Antwort der Hälfte, die scheitern kann (`.scheduled(Date, blockWindowArmed: Bool)`, Dismiss hängt an `isScheduledWithArmedWindow`); Apples `recoverySuggestion` wird gelesen statt verworfen (`DeviceActivityCenter.MonitoringError` ist ein `LocalizedError` mit **beiden** Hälften — im echten `.swiftinterface` nachgesehen, `localizedDescription` liefert nur die erste); und die Pending-Zeile bekommt einen dauerhaften Weg zur `AccessAndAppSelectionView`, in derselben verschachtelten Sheet-Form, die `BedtimeSetupView` für ihre Paywall schon nutzt, mit `reconcile()` beim Schließen. Der Onboarding-Pfad bleibt immun (`dismiss()` ist dort ein No-Op, daran hat sich nichts geändert). Vier neue Tests, einer davon gegen das echte SDK. **Nur auf dem Wecker-Screen gebaut:** die Pending-Zeile auf dem Morgen-Screen ist H3 und damit §4.2 Punkt 2.

**H6 — 19,33 pt Accessibility-Frame unter einer 51,33-pt-Platte** (§8 A25): Modifier an drei Stellen in die `label:`-Closure gezogen. **Vorher/Nachher gemessen**, nicht argumentiert — XCUITest an einer isolierten Kopie des Projekts (iPhone 17 / iOS 26.2, Standard-Textgröße): 123,67 × 19,33 → 155,67 × 51,33 („Zugriff erlauben"), 112,67 × 19,33 → 144,67 × 51,33 („Wecker stellen"), 115,0 × 19,33 → 147,0 × 51,33 („Bettzeit setzen"), Kontrollplatte unverändert 370 × 39,33. Die Vorher-Werte reproduzieren die Zahlen des Audits exakt.

**L25 — „Einstellungen" → „Systemeinstellungen"**: beide Wecker-Erlaubnis-Sätze plus die zwei englischen Fassungen („in Settings" → „in the Settings app", die Formulierung der Denied-Zeile). Das Substantiv ist der einzige Navigationshinweis, den beide Sätze haben, und es hieß bis dahin genauso wie der eigene Screen, aus dem der Sheet präsentiert wird.

**Verifikation:** vor jedem Commit alle vier Targets frisch gebaut (`-sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO`, 4 × BUILD SUCCEEDED) und die volle Suite gefahren. **298 Tests in 42 Suites → 307 Tests in 44 Suites, 0 Failures, 0 Skips.**

## 2026-09-05 — Fix-Runde auf den Voll-Audit: Screenreader, Onboarding-Scroll, Kontingent-Wort

**Anlass:** dieselbe §4.1-Liste, die zweite Hälfte — Punkte 4, 5 und 10 (H8, H7 + L18, L23), auf Dateien, die die vorige Runde nicht angefasst hat. §4.2 blieb auch hier unangetastet.

**H7 + L18 — die Sprechblase war stumm und der Hinweis des Maskottchens ein leeres Versprechen** (§8 A26): SwiftUI sagt eingefügten Text nicht von selbst an, also blieb die Blase für VoiceOver unsichtbar — inklusive der Meilenstein-Feier, der einzigen Ankündigung, die ein freigeschalteter Idle-Beat je bekommt. Alle drei `bubbleText`-Schreibstellen laufen jetzt über ein `say(_:)`, das die `AccessibilityNotification.Announcement` neben die Animation stellt; die Ansage lebt unabhängig vom Element, der 2,8-s-Dismiss kann sie also nicht abschneiden. Dazu die `.accessibilityAction`, die `.isButton` plus „Tippen für ein paar Worte" versprachen: sie sitzt am Host (dort entsteht das Element, `children: .ignore` verwürfe jede Aktion aus `MascotView`), zählt aber nicht selbst — sie reicht eine Aktivierung an `MascotView` weiter, das seinen vorhandenen `handleTap(at:)` fährt. Damit bleiben Tipp- und VoiceOver-Folge **eine** Zählung, und die Reaktion, die ein Tap zeichnet, spielt auch für VoiceOver. Nebeneffekt: die App verlässt sich nicht länger still darauf, dass VoiceOvers synthetischer Touch die `.onTapGesture` trifft. **Was geprüft ist und was nicht:** geprüft ist der Code an den vier Stellen und die englische Fassung des Hinweises (ein neuer Pin in `EnglishLocalizationTests`; der angesagte Textbestand hängt bereits an `everyScreenPoolIsTranslated`). **VoiceOver lief nicht** — es gibt kein UI-Test-Target für den Screenreader, und diese Runde hat daran nichts geändert. Ob eine Ansage im Betrieb von einer anderen verdrängt wird, ist Geräte-Nachholung. §6.3s „kein offener Punkt mehr" stimmt damit wieder, jetzt mit dieser Grenze daneben.

**H8 — jeder Onboarding-Schritt erbte den Scroll-Offset des vorigen** (§8 A27): sechs der sieben Schritte rendern in dieselbe ScrollView, deren Identität den Schrittwechsel überlebt. **Vorher am laufenden Simulator reproduziert und nachher gemessen** (iPhone 17 / iOS 26.2, Deutsch, `UICTContentSizeCategoryAccessibilityXXXL`, XCUITest an einer isolierten Kopie des Projekts — das Projekt selbst enthält weiterhin kein UI-Test-Target): Titel Schritt 2 minY **−72,33 → 173,33**, Titel Schritt 6 minY **−227,0 → 172,0**, dort zusätzlich `hittable=false → true`. Die Screenshots zeigen genau die Bilder, die der Audit beschrieben hat — Schritt 2 begann mit einem von der Statusleiste angeschnittenen „Bildschirm-", Schritt 6 mit einer angeschnittenen Picker-Zeile über „Bettzeit setzen". Fix: `ScrollViewReader` plus **konstanter** Anker und `scrollTo(anchor: .top)` im `onChange(of: step)`. Nicht `.id(step)`: das setzt den Offset zwar auch zurück, wirft aber die ScrollView-Identität pro Schritt weg, an der die 0,6-s-Schrittanimation hängt. **A16 gegengeprüft** an Screenshots 0,25 s nach dem Tap: der abgehende Schritt blendet vor wie nach dem Fix unter dem ankommenden aus, in beiden geprüften Übergängen. Regel steht jetzt in §6.4 — der Wrapper macht Inhalt erreichbar, der Offset-Reset ist die zweite Hälfte.

**L23 — „pro Morgen" → „pro Tag"**: `UnlockQuotaStore.morning` hat `dayRolloverHour: 0`; das Kontingent hängt bewusst am Kalendertag, nicht am Fenster, und ein Fenster über die Rollover-Stunde gibt einen zweiten Slot am selben Morgen. Die Settings-Zeile war der einzige Ausreißer gegen Paywall und Shield — und einen Tap von der Paywall entfernt, die „pro Tag" sagt. Katalogschlüssel und englische Fassung („Free · 1 per day") mitgezogen, Test-Pin mit ihnen.

**Verifikation:** pro Fix alle vier Targets gebaut (`-sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO`, je 4 × BUILD SUCCEEDED) und die volle Suite gefahren. **307 Tests in 44 Suites → 308 Tests in 44 Suites, 0 Failures, 0 Skips.** Kein `xcodegen generate` nötig — keine Datei kam dazu oder fiel weg.

**Nicht gebaut, weil §4.2:** kein Deep-Link (Punkt 6), keine Copy-Entscheidung an den Pending-Zeilen (Punkt 2), kein Gate im Wecker-Schritt (Punkt 3) — H8 macht den Schritt nur sichtbar, es ändert nichts daran, ob man ohne Wecker weiterkommt.

## 2026-09-05 — Fix-Runde auf den Voll-Audit: die geteilten Dateien

**Anlass:** dieselbe §4.1-Liste, die Punkte 6, 7 und 8 (H9, L12, L24) — alle in `Shared/`, disjunkt zu den zwei vorigen Runden. §4.2 blieb unangetastet.

**H9 — der Kommentar, der das Invariant begründet, benannte die falsche Extension und das falsche Entitlement-Bild**: `Shared/SubscriptionTier.swift` sagte, keine der beiden Shield-Extensions deklariere die App Group, und der Store bleibe App-Group-auflösbar, „so the shield-action extension can decrement the quota". Beide Hälften gegen die Quellen geprüft, nicht gegen die Meldung: **beide** `.entitlements`-Dateien tragen `com.apple.security.application-groups` = `group.com.example.tuck` und sind über `CODE_SIGN_ENTITLEMENTS` verdrahtet; `TuckShieldAction` kompiliert weder `UnlockQuotaStore.swift` noch `SubscriptionTier.swift` und dekrementiert nichts. Der Leser ist `TuckShield` — nur lesend, über `OverrideContext.current()` → `context.quota.allowance()`, um die richtige Sperr-Copy zu wählen. `consumeUnlock` hat genau **einen** Aufrufer, `OverrideFlowView`, in der App. Offen und richtig bleibt der Futur-Teil: die Gruppe ist nicht provisioniert, das braucht den Developer-Account. **Dritte Fundstelle, die der Audit nicht meldete:** derselbe Satz steht ein weiteres Mal im Kopf von `SubscriptionTierStore` (`:64-66`, „before it decrements") — mitkorrigiert, weil es dieselbe Falschaussage in derselben Datei ist. Der Nachbarkommentar in `UnlockQuotaStore.swift` ist mitgezogen. **Das Invariant selbst wurde nicht angefasst** (kein StoreKit-Import in den Extensions, alle zehn geteilten Dateien im Shield-Target importieren nur `Foundation`/`ManagedSettings`). Kein Test: die Aussage ist eine Target-Mitgliedschaft in `project.yml`, und das Test-Target hängt nur am App-Target — ein YAML-Parser im Testbestand wäre ein neues Muster, kein vorhandenes.

**L12 — `defer { clear }` löschte auch, was nie gelesen wurde**: in `ShieldOverrideRequest.take` und `ScreenTimeNotice.take` stand das Löschen vor dem Gültigkeits-Guard, und Swift führt `defer` auf **jedem** Ausgang aus, auch `return nil`. Die App ruft beide bei jedem Foregrounding, der Nichts-gefunden-Pfad ist also der häufige. Es widerspricht direkt dem Design, das der Code selbst beschreibt (`GutenMorgenView.swift:52-56`: eine Anfrage, die im falschen Moment nicht gezeigt werden kann, überlebt und wird beim Schließen des Settings-Sheets eingelöst). Löschen ist jetzt in beiden Fällen der letzte Schritt des Erfolgspfads. **Der Preis, offen benannt:** ein abgelaufener Eintrag bleibt liegen, bis das nächste `record` ihn überschreibt — ein bzw. zwei stale Schlüssel im Container gegen eine Anfrage, die die App löschen konnte, bevor sie sie je lesen konnte. Die zwei Tests, die das alte Verhalten festhielten (`aStaleRequestIsClearedRatherThanKept`, `aStaleNoticeIsClearedRatherThanKept`), sind umgedreht statt gelöscht; dazu je einer für das Retry-Fenster selbst (fehlgeschlagener Read → derselbe Eintrag ist beim nächsten Read noch da). **Nicht eskaliert:** die Gerätefragen 13/18 (Sichtbarkeit von App-Group-Schreibvorgängen) bleiben offen — sie entscheiden, ob dieser Fund LOW oder HIGH war, nicht ob der Fix richtig ist.

**L24 — der Erschöpft-Screen war kontextblind** (§8 A28): siehe A28. Kurz: `ShieldCopy` trennt Kopf und Fließtext, der Fließtext verzweigt nach `context`, der Shield fügt beides für seinen einen Untertitel-Slot zusammen — der Satz auf dem Sperrbildschirm ist in beiden Sprachen byte-gleich geblieben. Die `if context == .morning`-Klammer im G6-Test ist weg; der Abend-Kontext, den sie ausschloss, war genau der falsche. Die Parität ist ab hier strukturell, der Test prüft dafür, was strukturell **nicht** garantiert ist: dass beide Teile im Shield-Bundle auf Englisch ankommen.

**Verifikation:** pro Fix alle vier Targets gebaut (`-sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO`, je 4 × BUILD SUCCEEDED) und die volle Suite gefahren; abschließend ein echter Kaltbau aus leerem `-derivedDataPath` (alle vier Produkte neu erzeugt, drei `.appex` im App-Bundle). **308 Tests in 44 Suites → 311 Tests in 44 Suites, 0 Failures, 0 Skips.** Kein `xcodegen generate` nötig — keine Datei kam dazu oder fiel weg.

**Nicht gebaut, weil §4.2:** L24 berührt Punkt 7 (Wortwahl „Freigeschaltet"/„Bettzeit entfernt") an keiner Stelle — geändert wurde allein der Erschöpft-Zweig; die Bestätigungs-Copy ist unverändert. Kein Deep-Link, keine Pending-Zeilen-Copy, `activityCount()` unverändert.

## 2026-09-05 — Fix-Runde auf den Voll-Audit: der Doku-Sanierungs-Batch (und die Runde als Ganzes)

**Anlass:** `docs/full-app-audit-2026-09-05.md` §4.1 Punkt 11, der letzte Punkt der Bugfix-Liste — elf LOW-Funde plus zwei Rand-Befunde, alle mechanisch, alle Doku. Dazu die eine Zahl, die der Bericht in §4.2 Punkt 1 ausdrücklich **als Bugfix vorzieht**: die falsche Kontrastangabe für den hellen Himmel, getrennt von der Entscheidung, was daraus folgt.

**Zwei Zahlen selbst nachgerechnet statt übernommen.** Der Bericht verlangte das für die helle Sprechblasen-Zahl ausdrücklich. Methode wie `design-system.md` §2.4 und `DarkContrastTests`: WCAG 2.1, sRGB, transluzente Fläche zuerst über die Seite komponiert, Projekt-Rundung auf zwei Stellen.
- **Sprechblase hell:** Charcoal auf Weiß @0,9 über Cream = **4,47265 → 4,47**, nicht 4,46. **Die 4,46 war schlicht falsch, nicht abgeschnitten** — Abschneiden hätte 4,47 ergeben, genau wie Runden; die Hundertstel lässt sich aus keiner Rechenweise über diesen Farben herleiten. Die dunkle Schwester im selben Kommentarblock war dagegen wirklich abgeschnitten statt gerundet: 5,64523 → abgeschnitten 5,64, gerundet **5,65** — die Zahl, die der gepinnte Test seit jeher führt. Beide Werte waren in demselben Commit, der sie schrieb, gegen die eigenen Quellen gedriftet.
- **Himmelsgradient hell:** dafür musste die Oklab-Mischung nachgebaut werden, weil zwei der vier Stops mit dem Fortschritt mischen. Gegen die drei gepinnten Dämmerungstöne aus §2.2 **byte-exakt** validiert (`#B6C2B3` / `#EDD3C8` / `#F9F5EF`), dann 101 Fortschrittswerte × 1001 Bildschirmhöhen: **2,44:1** (p=0, oberer Rand, Dawn Shadow) bis **4,16:1** (p=1, oberer Rand, Day Sky), 3:1-Kreuzung bei p=0 auf y=0,358. Reproduziert die Zahlen des Berichts auf die Stelle. `~3,5:1 (Maximum)` war in beide Richtungen falsch und stand an vier Doku-Stellen und in zwei Code-Kommentaren. **Nur die Zahl ist korrigiert** — §8 A29 hält den Befund offen, die drei Optionen bleiben §4.2 Punkt 1. Mitgemessen und in den Code geschrieben, weil es die Reichweite eingrenzt: unterhalb y = 0,8, wo beide Buttons stehen, fällt der Grund bei keinem Fortschritt unter 3,40:1 — betroffen ist Statustext, kein Bedienelement.

**Neun weitere Doku-Funde, jeder gegen den aktuellen Code neu gelesen.** Das war nicht formal: zwei Anker waren in den drei Fix-Runden davor noch einmal verrutscht. L4 (§5.2 zählte eine label-gehängte Sage-Plate statt zwei), L5 (§5.1 und A12 schrieben `.tint(tuckCream)` vor, wo der Code das Rollen-Token nutzt — das Basis-Token wäre in Dunkel ein 2,1:1-Spinner), L8 (A11 führte als offene Aufgabe, was A8 erledigt hatte, mit zwei Ankern auf ein `#Preview` und eine schließende Klammer), L19 (§6.4 nannte den Zugriffs-Sheet als einzige Fläche ohne eigene Scroll-Ebene, seit einem früheren Umbau falsch), L18s Doku-Hälfte (§5.10s Accessibility-Anker), L6s Doku-Hälfte (`SettingsView.tierValue` existiert nicht mehr, plus A20s Fundstellen), L28+L29 (drei fehlende Meilenstein-Schlüssel in der Inventur, eine falsche Typ-Aussage, „zwölf" gegen die eigenen 16, zwei stale Zitate — und die flock-Begründung, die an drei Stellen eine Extension nannte, die das Lock gar nicht nehmen kann), L30 (zwei Checklisten-Boxen als offen, obwohl beide Capabilities in allen vier `.entitlements` stehen), L31 (die als erschöpfend formulierte Datenliste ließ vier Datensätze aus, darunter `trialStartedAt`), L33 (die Test-Baseline stand als Präsens-Zustand bei 162, real 311).

**Drei Korrekturen am Bericht, offen benannt:** `SettingsView.tierValue` stand an **zwei** Doku-Stellen, nicht an drei — A20 trug das Symbol nie (gegen den damaligen Code geprüft). §2.4s Einleitung zitierte zwei weitere Kontrast-Kommentare an falschen Zeilen, was der Bericht nicht meldete; mit H5 mitkorrigiert, weil es derselbe Absatz und dieselbe Fehlerklasse ist. Und die Test-Dateizahl in L33s Beleg ist heute 36, nicht 34 — die zwei kamen aus den Fix-Runden dieser Runde selbst; alle 36 sind im generierten Target.

**Was der Batch nicht löst, ausdrücklich:** eine Zeilennummer in Prosa ist kein Anker, der mit dem Code wandert. Diese Klasse Drift kommt beim nächsten Umbau wieder; dagegen hilft nur, Symbole statt Zeilen zu zitieren (notiert in §8 A30).

**Nicht gebaut, weil §4.2:** die Entscheidung zum Himmel (Punkt 1) — nur die Zahl ist wahr gemacht, keine Farbe, kein Gradient, kein `§3.1`-Satz angefasst und kein Hell-Pendant zum Dunkel-Pin angelegt. Kein Deep-Link, keine Pending-Zeilen-Copy, `activityCount()` unverändert, Deployment-Target unverändert.

**Verifikation:** vor jedem Commit mit Swift-Anteil die volle Suite gefahren, abschließend ein Kaltbau aller vier Targets aus leerem `-derivedDataPath` (`-sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO`, 4 × BUILD SUCCEEDED) plus die volle Suite. **311 Tests in 44 Suites → 311 Tests in 44 Suites, 0 Failures, 0 Skips.** Kein neuer Test: alle Funde dieses Batches sind Prosa-Aussagen über Code, keine auflösbaren Behauptungen — die einzige, die es hätte werden können, ist die helle Himmels-Zahl, und ein Pin darauf wäre die Entscheidung aus §4.2 Punkt 1 vorweggenommen. Drei Swift-Dateien geändert, ausschließlich Kommentare. Kein `xcodegen generate` nötig.

### Die Runde als Ganzes — `docs/full-app-audit-2026-09-05.md` §4.1, vollständig abgearbeitet

Vier Fix-Runden auf einen Bericht, der 42 verifizierte Funde führte: 0 BLOCKER, 9 HIGH, 33 LOW. Alle elf Punkte der §4.1-Bugfix-Liste sind erledigt; alle zwölf Punkte aus §4.2 sind **unangetastet** geblieben, und wo ein Fix an einen grenzte, ist nur die Bugfix-Hälfte gebaut und das in der jeweiligen Runde benannt.

| Runde | Funde |
|---|---|
| 1 — Berechtigungs- und Setup-Fehlerpfade | H1, H2, H6, L25 |
| 2 — Screenreader, Onboarding-Scroll, Kontingent-Wort | H7 + L18, H8, L23 |
| 3 — die geteilten Dateien | H9, L12, L24 |
| 4 — Doku-Sanierung + die falsche Himmels-Zahl | L4, L5, L6, L8, L9, L18 (Doku), L19, L28, L29, L30, L31, L33, H5 (nur die Zahl) |

**Test-Bilanz über die Runde:** 298 Tests in 42 Suites → **311 Tests in 44 Suites**, 0 Failures, 0 Skips, nie eine Verringerung. Zwei neue Test-Dateien (`FamilyControlsAccessStateTests`, `WakeAlarmSchedulerTests`).

**Offen und ausdrücklich nicht entschieden:** die vier verbliebenen HIGHs sind Produktentscheidungen, keine Bugs — H3 (Copy bei leerer App-Auswahl), H4 (Onboarding ohne Wecker), H5 (was aus der 2,44–4,16-Spanne folgt) und die neun übrigen §4.2-Punkte. §8 A29 hält H5s Befund als offene Zeile im Design-System.

**Grenzen dieser Runde, wie schon im Bericht:** VoiceOver lief nie live (kein UI-Test-Target), `.denied` von Family Controls ist im Simulator unerreichbar, und die Gerätefragen 13/18 bleiben das Eskalationskriterium für L12.

## 2026-09-05 — Erste Entscheidungs-Runde auf den Voll-Audit: H3, H4 und der Deep-Link

**Anlass:** `docs/full-app-audit-2026-09-05.md` §4.2, Punkte 2, 3 und 6 — Produktentscheidungen, keine Bugfixes. Entschieden wurde: H3 → eigene Zeile in der `windowPending`-Familie; H4 → „Weiter" gaten (Option a, nicht die vorgeschlagene Degradation b); Deep-Link → ja, an den Berechtigungs-Sackgassen. Umgesetzt wurde genau das. Die neun übrigen §4.2-Punkte (L26, L27, L1/L3/L7, L14, L32, H5, L20, L21, L22) sind unangetastet.

**H3 — die leere Auswahl hat jetzt eine eigene Zeile**. Am Code bestätigt, was der Bericht behauptet: `BlockWindowMonitor.register` liest den `FamilyActivitySelectionStore` an keiner Stelle — Registrierung und Auswahl sind vollständig entkoppelt, also bestätigte `blockRegistrationSucceeded()` ein Fenster, das über leerem Picker nichts sperrt. **Nichts an der Registrierung wurde angefasst**, nur was die drei Flächen darüber sagen. Neue Quelle `StatusCopy.windowWithoutApps(_:)`, an allen drei Stellen dieselbe Zeile: „Sperrfenster ⟨Fenster⟩ · noch keine Apps ausgewählt" / „Block window ⟨window⟩ · no apps selected yet". Interpunkt wie in „Testphase · noch 3 Tage", und „noch keine" ist wörtlich `StatusCopy.emptyCount` — dieselbe Vokabel, die §5.4 für eine Null-Anzahl vorschreibt. Der Pending-Zweig bleibt unberührt: ein *nicht* scharf gestelltes Fenster ist die wichtigere Wahrheit und behält seinen Satz.

**Was „leer" heißt, ist Korrektheit und keine Wahl**: eine Auswahl trägt etwas, sobald **irgendeines** der drei Token-Sets nicht leer ist. Die Definition liegt jetzt einmal in `FamilyActivitySelectionStore.selectedActivityCount(in:)`, und der Nebenbefund derselben Familie ist damit derselbe Fix: `SettingsView.activityCount()` summierte `applicationTokens + categoryTokens` und konnte „noch keine" melden, während ein reiner Web-Domain-Shield aktiv war. Die private Hilfsfunktion ist ersatzlos weg, beide Aufrufstellen lesen den Store. **Testbar war die Domäne, nicht die Summe:** Tokens lassen sich ohne echte Family-Controls-Autorisierung nicht erzeugen, also hält `theCountCoversEveryTokenSetASelectionCarries` per `Mirror` fest, dass `FamilyActivitySelection` genau diese drei Token-Sets hat — ein viertes im nächsten SDK reißt genau dieses Loch wieder auf und lässt den Test fallen.

**H4 — der Wecker-Schritt ist die erste harte Sperre im Flow**. „Weiter" bleibt deaktiviert, bis `WakeAlarmStore.scheduledAlarm() != nil` — über `disabledWithoutDimming(_:)`, also ohne die Deckkraft-Absenkung, die §3.1 verbietet. Der Fall, den der Bericht ausdrücklich mitentschieden haben wollte, braucht keinen eigenen Zweig: wer „Wecker stellen" drückt und den iOS-Dialog ablehnt, speichert nichts (`WakeAlarmScheduler` schreibt erst nach `.authorized`), also hält dasselbe Gate. Weil ein Gate keine Verlaufsform hat, in die das Label wechseln könnte, trägt eine eigene Zeile die Bedingung: „Weiter geht es, sobald der Wecker steht." — sie steht nur, solange das Gate steht.

**Die Folge, die der Entscheid erzwang:** die Wecker-Ablehnung hatte **zwei** Fassungen für **einen** Zustand, und beide versprachen etwas, was unter dem Gate falsch ist — „weiter geht es trotzdem" (nach dem abgelehnten Dialog) und „bis dahin bleibt alles andere nutzbar" (beim frischen Öffnen nach einer früheren Ablehnung). Der Bericht nannte nur die erste; die zweite ist derselbe Zustand und derselbe Bruch, und sie ist die Fassung, die ein gesperrter Nutzer tatsächlich sieht, weil das Onboarding bei jedem Start wieder bei `.welcome` beginnt. Beide sind jetzt ein Satz, in der Form aus §8 A14 (Zustand · Weg zurück · ehrliche Folge): „Wecker-Erlaubnis ist aus. Du kannst sie in den Systemeinstellungen wieder geben — ohne sie weckt Tuck dich nicht." Er hält im Onboarding wie im Settings-Sheet. Welcher der beiden Pfade vorliegt, entscheidet `WakeAlarmPermission.isDenied` — eine reine Funktion, aus demselben Grund wie `FamilyControlsAccessState`: AlarmKit autorisiert im Simulator nie.

**Wie ein gegateter Nutzer ohne Wecker-Erlaubnis das Onboarding erlebt, offen benannt:** er kommt an diesem Schritt nicht vorbei — das ist der Entscheid, nicht ein Nebeneffekt. Der Screen sagt ihm beides: warum („Wecker-Erlaubnis ist aus … ohne sie weckt Tuck dich nicht.") und was das Weiterkommen kostet („Weiter geht es, sobald der Wecker steht."), plus den Button, der die Systemeinstellungen öffnet. Was er **nicht** hat, ist ein Weg an der App vorbei: ohne erteilte Erlaubnis endet das Onboarding nicht, und die App startet bis dahin bei jedem Öffnen wieder im Flow. Das ist der Preis der Option (a), und er gehört zur Entscheidung.

**Deep-Link — der erste `UIApplication.open` der App** (§8 A31). Zwei Stellen, nicht drei: `FamilyControlsAccessSection` im `.denied`-Zustand und `WakeAlarmSetupView` bei abgelehnter Wecker-Erlaubnis. Die dritte Sackgasse braucht keinen eigenen Button — die Kette ist am Code geprüft: die Pending-Zeile trägt „Bildschirmzeit-Zugriff prüfen" → `AccessAndAppSelectionView` → bei fehlender Autorisierung `FamilyControlsAccessSection` → `.denied` trägt den Link. **Verifiziert statt angenommen:** `UIApplication.openSettingsURLString` steht im UIKit-Header ohne Doku-Kommentar, im iOS-26.5-Runtime aber als `app-settings:` — die eigene Seite dieser App; die Nachbarkonstanten `app-settings:notifications` und `app-settings:default-applications` sind Unterseiten derselben Seite. **Grenze, ausdrücklich:** ob die Bildschirmzeit-Berechtigung auf dieser Seite selbst liegt oder unter Bildschirmzeit → „Apps mit Bildschirmzeit-Zugriff", ist ohne Gerät nicht geprüft — deshalb verspricht das Label allein sein Ziel („Zu den Systemeinstellungen" / „Open the Settings app").

**Verifikation:** pro Phase alle vier Targets in einem frischen Build-Verzeichnis gebaut (`-sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO`, je 4 × BUILD SUCCEEDED) und die volle Suite gefahren. **311 Tests in 44 Suites → 323 Tests in 46 Suites, 0 Failures, 0 Skips.** Zwölf neue Tests, zwei neue Test-Dateien (`WakeAlarmPermissionTests`, `SystemSettingsLinkTests`). Drei neue Dateien insgesamt — `Tuck/OpenSystemSettingsButton.swift` dazu —, also `xcodegen generate` gefahren; die Regenerierung ohne neue Dateien erzeugt keinen Diff, vorher geprüft.

## 2026-09-05 — Zweite Entscheidungs-Runde auf den Voll-Audit: L20, L21, L22

**Anlass:** `docs/full-app-audit-2026-09-05.md` §4.2, Punkte 7, 8 und 9. Entschieden wurde: L21 → „nicht belasten, wenn kein Shield stand"; L20 → „in die Versuchs-Form ziehen"; L22 → „ja, plus Zeit sichtbar lassen". Umgesetzt wurde genau das. Die verbliebenen §4.2-Punkte (L26, L27, L1/L3/L7, L14, L32, H5) sind unangetastet.

**L21 — die Freischaltung wird nur für ein Fenster belastet, das wirklich läuft** (§8 A32). Das Prädikat ist neu, seine beiden Hälften sind es nicht: `OverrideContext.shieldIsStanding(now:calendar:in:)` liest das gespeicherte Registrierungs-Flag (`WakeAlarmStore` / `BedtimeStore.blockRegistrationSucceeded`) — dasselbe, an dem `BlockWindowReconciler` armt und disarmt — und `MorningBlockWindow.contains(now:calendar:)`, dieselbe Methode, mit der `applyPendingMorningDuration` ein laufendes Fenster erkennt und mit der `OverrideContext.current` die Abend-Zuordnung trifft. Keine zweite Definition von „läuft gerade". **Was ausdrücklich unverändert bleibt:** die 30 Sekunden und die Begründung laufen auf jedem Pfad vollständig — die Reibung ist das Produkt, der Zähler ist es nicht —, der Shield-Clear läuft **unbedingt** weiter, und der Rollover bleibt allein aus `now` abgeleitet. Der Clear ist die Hälfte, die nicht bedingt werden durfte: ein Shield, das sein Intervall überlebt hat, ist laut L21s vierter Korrektur der Grund, warum dieser Button außerhalb des Fensters überhaupt erreichbar sein muss.

**Die Grenze des Prädikats, offen benannt:** es liest **das Fenster, nie den Shield**. Ob eine Sperre wirklich steht, ist nicht rücklesbar (`ShieldApplication`), und genau im Stale-Shield-Fall wäre „es läuft gerade keine Sperre" falsch — deshalb entscheidet die Antwort nur, ob etwas abgebucht wird, und die Copy sagt „Ohne laufendes Fenster kostet das keine Freischaltung. Noch 1 für heute übrig." / „Without a running window this costs no unlock. 1 left for today." Der Bericht verlangte diese Zeile nur, falls der Screen sonst eine unbewegte Zahl als Ergebnis meldet — er tat es: „Noch 1 für heute übrig." stand dort unverändert und las sich als Bilanz einer Buchung.

**L20 — beide Bestätigungen in der Versuchs-Form** (§8 A33). Zwei Instanzen, wie die Korrektur im Bericht festhält: „Freigeschaltet" (`OverrideFlowView`) und „Bettzeit entfernt. Abends bleibt jetzt alles offen." (`BedtimeSetupView`) — beide auf demselben stillen, nicht werfenden `ManagedSettings`-Schreibvorgang. Jetzt: „Freischaltung eingetragen" / „Unlock recorded" und „Bettzeit entfernt. Für den Abend ist nichts mehr eingetragen." / „Bedtime removed. Nothing is saved for the evening any more." Beide sagen, was **diese App getan hat**, in derselben Vokabel wie die Scharf-Seite („eingetragen" / „saved", `StatusCopy.windowPending`), und ausdrücklich **nichts** darüber, was das System daraus macht — auch kein „wird abgebaut". Kein Shield zeigt eine der beiden Zeilen (`ShieldCopy` hat keine Bestätigungsfläche), G6 verlangt also keinen `SharedCopy`-Eintrag; die zwei alten Schlüssel sind aus `Localizable.xcstrings` entfernt statt stehengelassen.

**L22 — die gespeicherte Bettzeit ist hinter dem Gate sichtbar und entfernbar** (§8 A34). Der `locked`-Zweig trägt denselben „Bettzeit entfernen"-Button auf demselben einen Pfad wie der `setup`-Zweig (`BedtimeScheduler.clearBedtime` → `BlockWindowMonitor.cancel` + `BedtimeStore.clear`); die Settings-Zeile zeigt „22:30 · Teil von Plus" statt nur des Gate-Worts. **Die zuvor festgehaltene Gate-Gestaltung (offene Fragen, nicht Teil dieses Exports) bleibt sonst unangetastet:** eine nicht entfernte Bettzeit wird weiterhin behalten und bei zurückkehrendem Plus wieder scharf gestellt — das stille Wiederscharfstellen ist nicht abgeschafft, sondern erstmals abwählbar. Danach gibt es nichts zu re-armen: der Arm-Zweig von `reconcile()` hängt an `if let bedtime = BedtimeStore.bedtime()`, und `clear` nimmt Zeit, beide Fensterenden und das Registrierungs-Flag mit.

**Was am Rand des Entscheids lag und bewusst nicht gebaut wurde:** die zweite in L21 genannte Option (eine Copy-Zeile im Reason-Picker, die sagt, dass gerade keine Sperre läuft) — sie behauptet genau das, was die App nicht lesen kann, und die Bestätigungszeile deckt den Fall in der zulässigen Formulierung ab. Ebenso unangetastet: `UnlockQuotaStore` selbst (kein Schlüssel, keine Rollover-Stunde, keine Sperre gegen Mehrfachverbrauch angefasst) und die Registrierung beider Fenster.

**Verifikation:** pro Phase alle vier Targets in einem frischen `SYMROOT`/`OBJROOT` (`-sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO`, je 4 × BUILD SUCCEEDED) plus die volle Suite. **323 Tests in 46 Suites → 332 Tests in 46 Suites, 0 Failures, 0 Skips.** Neun neue Tests, keine neue Datei — also kein `xcodegen generate` nötig. Fünf davon liegen in `OverrideContextTests` (Belastung im Fenster, keine Belastung außerhalb, unregistriertes Fenster, Abend-Registrierung, Rollover unberührt), zwei in `BedtimeGateTests`, zwei in `EnglishLocalizationTests`; zwei bestehende Tests sind mitgezogen: `aConfirmedOverrideClearsTheShieldOfTheWindowItSpentTheUnlockOn` heißt jetzt `…ItBelongsTo`, weil der Clear seit L21 gerade **nicht** mehr am Verbrauch hängt.

**Grenze dieser Runde:** kein Gerätelauf. Ob ein Shield sein Intervall in der Praxis überlebt (`intervalDidEnd`-Zuverlässigkeit) bleibt die offene Gerätefrage aus der Liste der nächsten Schritte (nicht Teil dieses Exports) — L21s Fix macht diesen Fall billiger, beantwortet ihn aber nicht.

## 2026-09-05 — Dritte Entscheidungs-Runde auf den Voll-Audit: H5 (und die Entscheidungs-Runde als Ganzes)

**Anlass:** `docs/full-app-audit-2026-09-05.md` §4.2 Punkt 1, dazu zwei Prosa-Funde aus der Nachprüfung der eigenen Doku. Entschieden wurde: H5 → **Option (c), bewusst akzeptieren und in §8 eintragen**; die Zusatzfrage des Berichts (Hell-Pendant zum Dunkel-Pin) → ja. Umgesetzt wurde genau das: **keine Farbe, kein Gradient, kein Layout und kein View angefasst** — die Änderung ist eine Entscheidung, ein Test und drei ehrlichere Absätze.

**H5 — der helle Himmel bleibt, wie er ist, und das steht jetzt so da** (§8 A29). A29 ist von einer offenen Zeile zu einem entschiedenen Tradeoff mit Datum geworden, und der Zuschnitt ist der Punkt: akzeptiert sind **vier Bedingungen zusammen** — Statustext (Begrüßung, Subline, Sperrfenster-Zeile) · bei Accessibility-Textgrößen, wo die Spalte über den stehenden Himmel scrollt · im oberen Band des Bildschirms · in **Hell**. Ausdrücklich **nicht** gedeckt: jedes Bedienelement (unterhalb y = 0,8, wo „Einstellungen" und der Override stehen, bleibt der Grund bei jedem Fortschritt über 3,40:1), der Fließtext jeder anderen Fläche, und Dunkel, das mit 3,36:1 Minimum durchgängig über der Marke liegt. Ein künftiges Element auf diesem Grund fällt nicht unter die Akzeptanz, sondern braucht einen eigenen Entscheid. Verworfen sind damit die zwei anderen Optionen aus §4.2 Punkt 1: Ink abdunkeln (trifft die Signaturfarbe) und den Gradienten oben heller deckeln (trifft das Kernbild „Dämmerung").

**Der Preis wurde bezahlt, nicht weggeschrieben:** §3.1 behauptete „AA für großen Text (3:1) wird erfüllt". Der Satz ist verengt statt gestrichen — die 3:1 hält auf **jedem** Grund der App außer diesem einen, und die Ausnahme steht jetzt so im selben Absatz, dass ein Leser sie nicht für eine Fußnote halten kann, samt der Begründung, warum die Regel hier nicht greifen *kann*: sie regelt den Text, und das Problem ist der Grund. Kein Schriftgrad und kein Gewicht hebt ein Verhältnis. Mitgezogen, weil sie sonst falsch geworden wären: §2.4s Schlusssatz („nicht entschieden" → entschieden mit Zuschnitt), §2.4.1s Asymmetrie-Absatz, die §8-Kopfzeile (A29 ist aus der Offen-Liste raus, aber **geschlossen ist es durch einen Entscheid, nicht durch eine bessere Zahl** — die Zeile bleibt deshalb ungestrichen), der A24-Absatz über die Grund-Hälfte der Kontrast-Achse und der Kontrast-Kommentar über „Einstellungen" in `GutenMorgenView`.

**Der Pin dokumentiert einen Boden, keine bestandene Schwelle**. `LightSkyContrastTests.theSkyGradientsLightRangeIsTheAcceptedOneAndItsFloorIsUnderTheThreshold` iteriert dieselben 101 Fortschrittswerte über dieselben vier Stops wie der Dunkel-Pin, gegen die in Hell aufgelösten Tokens, und hält **2,44 als Minimum und 4,16 als Maximum** fest — beide reproduzieren die Zahlen des Berichts auf die Stelle, jetzt mechanisch statt nachgerechnet. Die dritte Zusicherung ist die eigentliche: `worst < 3.0`. Sie steht da, damit der Test nicht als Beleg gelesen werden kann, dass die Spanne die Marke erreicht — er hält fest, was akzeptiert wurde, und lässt es fallen, sobald Palette oder Gradient sich bewegen; dann wird die Akzeptanz neu erteilt statt stillschweigend mitzuwandern. Die vom Bericht gemeldete Abdeckungs-Asymmetrie (Dunkel gepinnt, Hell gar nicht) ist damit weg.

**Zwei Prosa-Korrekturen an den eigenen Aufzeichnungen, beide nachgerechnet:**
- **Die helle Sprechblasen-Zahl 4,46 war falsch, nicht abgeschnitten**. Der Eintrag oben erklärte sie mit demselben „ebenfalls abgeschnitten statt gerundet" wie die dunkle Schwester. Das trägt nicht: 4,472650 abgeschnitten ist 4,47, gerundet ebenfalls 4,47 — aus keiner Rechenweise über diesen Farben kommt 4,46. Nur die dunkle 5,64 war wirklich ein abgeschnittenes 5,64523. Eine wahre Erklärung deckte zwei verschiedene Fehler zu; sie deckt jetzt den einen, für den sie gilt.
- **Die A25-Framehöhe ist kein Sollwert auf die Hundertstel**. §5.2 und A25 führten „51,33 pt" als Prosa-Zahl; ein zweites Messrig maß für dieselben drei Buttons 52,33. Der Wert hängt an Gerät, Systemversion und Textgröße — die **Differenz** hängt an nichts davon: 2 × 16 pt auf beiden Achsen, das Default-`.padding()`. Beide Stellen nennen jetzt die Invariante (das Element deckt die gezeichnete Platte, ~51 pt statt ~19 pt) und die Messung als das, was sie ist: eine Ablesung in einer Umgebung.

**Die Entscheidungs-Runde als Ganzes — sieben Entscheidungen in drei Phasen, alle mit Ausgang:**

| §4.2 | Entscheidung | Ausgang |
|---|---|---|
| 2 | H3 — Copy bei leerer App-Auswahl | eigene Zeile in der `windowPending`-Familie, an allen drei Stellen dieselbe; `webDomainTokens` zählen mit |
| 3 | H4 — Onboarding ohne Wecker | **(a) gaten** statt der vorgeschlagenen Degradation (b); die zwei Denied-Fassungen zu einer zusammengeführt |
| 6 | Deep-Link in die Systemeinstellungen | ja, an zwei der drei Sackgassen — die dritte führt über eine bestehende Kette dorthin |
| 8 | L21 — Override außerhalb jedes Fensters | nicht belasten, wenn kein Shield stand; 30 s, Clear und Rollover unverändert |
| 7 | L20 — „Freigeschaltet" / „Bettzeit entfernt" | beide in die Versuchs-Form |
| 9 | L22 — `locked`-Zweig | „Bettzeit entfernen" plus die Zeit in der Settings-Zeile |
| 1 | H5 — heller Himmel unter 3:1 | **(c) bewusst akzeptiert**, mit Zuschnitt in §8 A29, verengtem §3.1 und Hell-Pin |

**Was aus §4.2 weiterhin offen ist und keiner anfassen darf, bis es entschieden ist:** **L26** (Deployment-Target auf 26.5 heben oder Copy für 26.2–26.4 schreiben — eine Reichweiten-Entscheidung), **L27** (Ersatzformulierung für den „Simulator"-Satz), **L1/L3/L7** (drei Design-System-Ausnahmen: dokumentieren oder angleichen), **L14** (`FamilyActivitySelectionStore.clear` behalten oder löschen) und **L32** (`ITSAppUsesNonExemptEncryption` — eine Export-Compliance-Erklärung, die allein der Projektinhaber abgeben kann). Fünf Punkte, keiner davon in dieser Runde berührt.

**Verifikation:** alle vier Targets in einem frischen `SYMROOT`/`OBJROOT` (`-sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO`, 4 × BUILD SUCCEEDED, drei `.appex` im App-Bundle) plus die volle Suite. **332 Tests in 46 Suites → 333 Tests in 47 Suites, 0 Failures, 0 Skips.** Ein neuer Test, keine neue Datei — kein `xcodegen generate` nötig. Über die ganze Entscheidungs-Runde: 311 Tests in 44 Suites → 333 Tests in 47 Suites.

**Grenze dieser Entscheidung, ausdrücklich:** die akzeptierte Position ist rekonstruiert, nicht fotografiert. Bewiesen sind die Farbwerte, die Gradienten-Geometrie und dass `progress = 0` bei jedem Erscheinen des Screens sekundenlang gerendert wird; wo der Textblock bei Accessibility-Textgrößen genau steht, ist aus §6.4s Simulator-Protokoll erschlossen. Das ändert nichts am Entscheid — akzeptiert ist die Spanne, nicht eine bestimmte y-Koordinate.

## 2026-09-05 — A3 noch einmal: der Disabled-Zustand hatte eine Annahme statt eines Mechanismus

**Anlass:** die Verifikations-Runde nach dem H4-Entscheid, am laufenden iPhone 17 / iOS 26.5, Deutsch, Standard-Dynamic-Type, Pixel-Histogramme. Das gegatete „Weiter" maß **1,37:1** — Platte `#6B7A6E → #AEB7AE`, Label `#F5EFE6 → #D2D3CA`. Eine erzwungen deaktivierte Sage-Plate maß **3,71:1 → 1,83:1**. Beides ist genau die Deckkraft-Absenkung, die §3.1 verbietet und die A3 am selben Tag behoben zu haben glaubte.

**Was wirklich gilt, in der Reihenfolge, in der es belegbar ist.** `.disabled(_:)` ist im ausgelieferten `SwiftUICore.swiftinterface` (iPhoneSimulator26.5.sdk) `@inlinable` und damit im Klartext lesbar: `modifier(_EnvironmentKeyTransformModifier(keyPath: \.isEnabled, transform: { $0 = $0 && !disabled }))`. Es schreibt einen Umgebungswert und dimmt **nichts**. Gedimmt wird von dem, der den Wert liest. `PlainButtonStyle` ist ein `PrimitiveButtonStyle` mit opakem `makeBody`-Rückgabetyp — das Interface **kann** nicht sagen, was er zeichnet, und sagt es auch nicht. Das ist der ehrliche Stand: der Rest ist nur messbar, nicht lesbar. Gemessen (isolierte Probe-App, dieselbe Palette, sechs Varianten nebeneinander): der plain-Style zeichnet jedes Primitiv des Labels bei Alpha 0.5, beim Druck bei 0.75.

**Die alte Behebung war nie mehr als eine Beobachtung auf 26.2.** „Das Label rendert wie geschrieben" stand in `DisabledWithoutDimming.swift` und in §5.3 als Tatsache; zugesichert hat es nie jemand. Betroffen waren **alle fünf** Aufrufstellen — vier transiente Working-Zustände (Wecker, Bettzeit, Kauf, Wiederherstellen) und das H4-Gate, das als einziges **stehen bleibt**: wer die Wecker-Erlaubnis ablehnt, sah ein Bedienelement-Label unbegrenzt auf 1,37:1. Nach A3, §5.3 und A29s ausdrücklicher „kein Bedienelement"-Klausel war das nie akzeptierbar.

**Der Ersatz ist gemessen, nicht angenommen**. Ein `ButtonStyle` — kein `PrimitiveButtonStyle` — ersetzt den Körper des Buttons; `PlainButtonStyle`s Behandlung steht dann gar nicht mehr im Baum. In der Probe rendert ein durchreichender Style einen deaktivierten Button **byteweise identisch** zum aktivierten (`#6B7A6E` / `#F5EFE6`), und zwar auch für einen Textbutton ohne Fläche. Das ist `TuckButtonStyle` in `Tuck/DisabledAppearance.swift`. Damit gehört die Optik der App — und ein Element, das nicht bedienbar ist, darf nicht aussehen wie eines, das es ist. Gezeichnet wird sie vom **Disabled-Paar** (§2.1.1): hell `#D8E2D3` + `#6B7A6E` = **3,40:1**, dunkel `#2A3830` + `#CDD3C9` = **8,06:1**, dazu eine Platte, die Präsenz abgibt (hell 3,96:1 → 1,17:1 gegen die Seite, dunkel 2,10:1 → 1,36:1). Gewählt wird sie dort, wo gezeichnet wird: `PrimaryButtonPlate` ist jetzt ein `ViewModifier` und liest `@Environment(\.isEnabled)`, weshalb **keine** Aufrufstelle des Primärbuttons angefasst werden musste.

**Warum in Hell die Tinte kippt und in Dunkel nicht.** Charcoal Green ist die dunkelste Tinte dieser Palette. Eine gefüllte Platte, die ein lesbares Label behalten soll, kann in Hell also nur *heller* werden — und dann trägt Cream nicht mehr. Die Kurve ist monoton: je blasser die Platte, desto besser das Label, bis zum Maximum 3,96:1 bei „Platte = Seite", also bei „keine Platte mehr". Voll deckendes Sage ist der präsenteste Punkt darauf, der die 3:1 noch mit Reserve hält. In Dunkel ist Moon Sage schon die helle Hälfte des Paars; jede Bewegung würde nur Kontrast kosten, also bewegt sich dort allein die Platte.

**Zwei Dinge werden dabei bezahlt und stehen als Preis in §5.2:** an den zwei Sage-Platten ist die Disabled-Fläche etwas **kräftiger** als die aktive (1,08:1 → 1,17:1 gegen die Seite) und das Label fällt von 3,71:1 auf 3,40:1. Die Alternativen waren schlechter: eine blassere Platte läge bei 1,04:1 und wäre keine mehr, eine unveränderte hieße, ein totes Bedienelement pixelgleich wie ein lebendes zu zeichnen. Und der **Pressed**-Zustand ist jetzt unserer: 0,75 Deckkraft, die Stärke des Frameworks, aber auf die Gruppe statt auf jedes Primitiv — das Label/Platte-Verhältnis bleibt während des Drucks bei 3,96:1 statt auf 2,13:1 zu fallen. §5.1s Zeile „SwiftUI-Default (kein eigener ButtonStyle)" ist damit hinfällig und ersetzt.

**Die fünfte Stelle hatte nie eine Fläche.** „Käufe wiederherstellen" ist ein Textbutton, und auf Cream gibt es keine Tinte, die schwächer als Charcoal ist und §3.1 noch erfüllt — das ist kein Designspielraum, sondern der Kopf der Palette. Der Zustand kann dort nur in die Copy: „Käufe werden wiederhergestellt …" / „Restoring purchases …". Damit ist der Rest geschlossen, den A3 **und** A12 seit ihrer ersten Behebung offen führten, und §5.3 hat keine Stelle ohne Signal mehr.

**Verifikation.** Alle vier Targets in frischem `SYMROOT`/`OBJROOT` (`-sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO`): 4 × BUILD SUCCEEDED. **333 Tests in 47 Suites → 336 Tests in 48 Suites, 0 Failures, 0 Skips.** `xcodegen generate` war nötig (Datei umbenannt), der zweite Lauf erzeugt keinen Diff. Nachgemessen am Simulator, in **beiden** Darstellungen, an einer isolierten Kopie des Projekts mit UI-Test-Target (das Projekt selbst enthält weiterhin keins): gegatetes „Weiter" hell `#D8E2D3`/`#6B7A6E` = 3,40:1 und dunkel `#2A3830`/`#CDD3C9` = 8,06:1, erzwungen deaktivierte Sage-Plate dieselben zwei Paare, aktiver Primärbutton unverändert bei `#6B7A6E`/`#F5EFE6` (3,96:1) und `#47544C`/`#CDD3C9` (5,21:1). Die Werte sind byteweise die Tokens, nicht ihre Näherung.

**Grenze dieser Runde, ausdrücklich:** warum `PlainButtonStyle` sich zwischen 26.2 und 26.5 anders verhält, ist **nicht** belegt — das Interface sagt über `makeBody` nichts, und zwei Messungen an zwei Systemversionen sind kein Änderungsnachweis. Belegt ist, was heute gilt und dass der neue Mechanismus nicht davon abhängt: ein eigener `ButtonStyle` ersetzt den fremden Körper, egal was der täte.

## 2026-09-05 — Die letzten fünf Entscheidungen aus §4.2, und damit ist die Liste zu

**Anlass:** Entscheidung des Projektinhabers über die fünf Punkte, die nach den drei vorigen Runden aus §4.2 des Voll-Audits offen standen und die keiner anfassen durfte, bis sie entschieden waren. Alle fünf sind hier umgesetzt, keiner davon eigenmächtig gewählt.

**L26 — Deployment-Target auf 26.5 gehoben** (§8 A39). Zwölf Stellen in `project.yml`: der Projektblock und beide Schlüssel auf jedem der fünf Targets. Bezahlt wird mit Reichweite unter 26.5 — heute hypothetisch, weil nichts im Feld ist und keine Tester existieren. Bekommen wird der Wegfall der Versionsspanne, in der `.openParentalControlsApp` nicht existiert und der Shield den zweiten Button deshalb ganz ausblenden musste. **Vier Verfügbarkeits-Gates werden dadurch konstant und sind entfernt:** `ShieldActionRouting.canOpenApp()` samt dem `.defer`-Zweig in `response(for:)`, der Pass-Through in `TokenRefresh.refreshed(_:)` und die `#available(iOS 26.4, *)`-Hälfte des Guards in `ShieldConfigurationExtension`. Dessen **`else`-Zweig bleibt** — er trägt weiterhin den erschöpften Zustand (B6), und genau das ist der Unterschied zwischen „Gate weg" und „Zweig weg". Zwei Aufrufer folgen mit, weil die Konstante sie dazu zwingt und nicht aus Ordnungsliebe: `ShieldCopy.content` verliert den `canOpenApp`-Parameter, und `opensApp(for:)` war zu einem exakten Alias von `routesToApp` geworden. Dazu zwei vakuum gewordene `#available`-Guards in `ShieldActionRoutingTests`. **Kein verwaister Katalog-Schlüssel, und das ist gemessen, nicht angenommen:** die `.stringsdata` aller Nicht-Test-Targets gegen beide Kataloge gestellt — `Localizable` 216 Schlüssel, `SharedCopy` 13, in beiden Richtungen null Waisen. Der Grund ist der Fund selbst: die unterdrückte Spanne hatte nie eigene Copy, das war ja die Meldung. (Die drei `#if DEBUG`-Strings des Entwickler-Sheets erscheinen in der Extraktion und nicht im Katalog — Vorzustand, unberührt.)

**Testziel bewegt.** Ab jetzt `-destination 'platform=iOS Simulator,OS=26.5,name=iPhone 17'`. Geändert in den **lebenden** Dateien, die es als aktuelles Ziel führten: der Audit-Konfiguration (sagte „iPhone 17 / iOS 26.2"), `docs/design/design-system.md:66` („Deployment-Target 26.2") und die Liste offener Fragen (nicht Teil dieses Exports; neuer Absatz: Option 3 ist nicht mehr der Fallback für alte Systemversionen). **Nicht angefasst,** weil sie Zustände von ihrem Datum protokollieren und keine Vorgabe machen: `docs/full-app-audit-2026-09-05.md`, `docs/build-plan-phase1.md`, `docs/product-decisions-2026-09-02.md` (B8 hält dort fest, dass die Unterdrückung 2026-09-02 bewusst gewählt war — A39 löst das ab, statt die Herleitung zu überschreiben), die Mess-Protokolle in §5.3/§6.4/A25/A27 des Design-Systems und alle älteren Einträge dieser Datei. **Ein Punkt der Vorgabe traf nicht zu:** die ursprüngliche Produktspezifikation enthält gar keine Deployment-Target-Aussage — nur „`.openParentalControlsApp` (iOS 26.5, gegen das echte SDK verifiziert)", was unverändert stimmt und jetzt sogar ohne Vorbehalt. Dort eine Versionszahl **neu** einzuführen wäre eine zweite Quelle neben `project.yml` gewesen, also die Drift-Klasse, an der dieses Projekt schon dreimal hing. Bewusst nicht getan.

**Was sich zwischen den Laufzeiten unterschied — vollständig, weil es die letzte Gelegenheit war, es zu messen.** Vor der Änderung lief die Suite auf **beiden** Runtimes: iOS 26.2 (iPhone 17 Pro) und iOS 26.5 (iPhone 17), beide **336 Tests in 48 Suites, 0 Failures, 0 Skips**. Kein Test schlug unterschiedlich aus; unterschiedlich war nur, welcher Zweig *innerhalb* dreier Tests lief — `theResponseIsOpenParentalControlsAppExactlyWhereTheCaseExists` prüfte auf 26.2 `.defer` und auf 26.5 `.openParentalControlsApp`, und die beiden Submenü-Tests liefen auf 26.2 vakuum durch ihren `guard #available`. Alle drei sind jetzt ungegatet, weil ihre andere Hälfte nicht mehr erreichbar ist: `xcodebuild` findet für dieses Schema **kein** 26.2-Ziel mehr (`Unable to find a destination matching the provided destination specifier`). Damit ist die Frage „welcher Test verhält sich zwischen Runtimes anders" nicht mehr stellbar, und die Antwort für den letzten Moment, in dem sie es war, steht hier.

**L27 — der „Simulator"-Satz ersatzlos gestrichen**. `Tuck/AccessAndAppSelectionView.swift:159` sagt jetzt „Die Auswahl erscheint hier, sobald der Zugriff erlaubt ist." / „The picker appears here once access is allowed.", alter Schlüssel im Katalog zurückgezogen, englische Hälfte parallel gekürzt. Kein Test hing daran (gegen `TuckTests/` und `docs/` geprüft), es war also kein Pin zu verschieben. Der Rest des Satzes trägt allein — und die einzige Route dorthin ist der Onboarding-Schritt nach „Später erlauben, weiter", also genau der Weg eines App-Review-Testers, der den Screen-Time-Dialog ablehnt. Von 18 Simulator-Erwähnungen im Repo war dies die einzige, die einen Bildschirm erreichte; jetzt keine.

**L1 / L3 / L7 — alle drei dokumentiert, keine angeglichen** (§8 A35/A36/A37). Der Entscheid lautet „so lassen und benennen", und die drei Einträge stehen deshalb **ungestrichen** — das ist ihr Endzustand, kein Zwischenstand.
- **A35, und der Fund war größer als gemeldet:** es sind **neun** `.sheet(isPresented:)`-Stellen, nicht acht und nicht die sieben, die §5.11 und A15 beide zählten. Die achte kam mit dem Plus-Gate, die **neunte** mit der H2-Behebung derselben Fix-Runde — `WakeAlarmSetupView` → `AccessAndAppSelectionView`, ein zweites verschachteltes Sheet, das niemand nachgetragen hatte. Beide tragen die zwei Präsentations-Modifier aus §5.11; die Form hat die Verschachtelung überlebt, die Buchführung nicht. **Die Regel ist mitverengt worden**, und das ist der eigentliche Gewinn: §5.11s Don't hieß „kein zweites Sheet über ein offenes stapeln" und verbot damit mehr, als die Shield-Runde vom 2026-09-04 bewiesen hatte — bewiesen war, dass ein *Präsentator* kein zweites Sheet öffnen kann, während sein erstes steht. Eine Präsentation *aus* präsentiertem Inhalt heraus ist reguläres SwiftUI. Die alte Fassung verbot also zwei ausgelieferte Aufrufstellen, die funktionieren; jetzt heißt sie „kein zweites Sheet beim **selben Präsentator**".
- **A36:** die fünfte Flächen-Alpha (Sage `0.6`, Atem-Kreis, `OverrideFlowView.swift:213`) steht jetzt in §2.3 als benannte Ausnahme. Mechanisch angleichen hieße, §2.3s eigener Regel zu folgen und eine nicht antippbare Dekoration auf `0.25` zu legen — das Fokus-Element einer geführten Atemübung wäre danach fast weg. §2.3 behauptet außerdem nicht mehr, seine vier Stufen seien die vollständige Elevation der App.
- **A37:** der Onboarding-Gradient (`Cream → Sage@0.35`) ist die einzige zweite Seitenhintergrund-Behandlung. Es ist eine Inventur-Lücke, kein Regelbruch — §2.3 erlaubt Alpha ausdrücklich auf Gradienten. **Selbst nachgerechnet statt aus dem Audit übernommen:** der untere Stopp kompositiert über Cream zu `#EBEADF`, Charcoal Green darauf **3,75:1**; die Fläche ist wie der Himmel eine Spanne, **3,96:1** oben bis **3,75:1** unten, nirgends unter 3:1.

**L14 — `FamilyActivitySelectionStore.clear()` bleibt** (§8 A38). Mit Test. Vermerkt als bewusste API-Symmetrie zu den drei anderen Stores, nicht als toter Code, der zu entfernen wäre: vier Stores mit demselben Schnitt sind leichter richtig zu benutzen als drei mit einem Loch, und Löschen zöge `FamilyActivitySelectionStoreTests.swift:48` mit.

**L32 — `ITSAppUsesNonExemptEncryption: false` erklärt**. Die Erklärung gehört dem Projektinhaber; entschieden wurde sie am **2026-09-05**, auf Grundlage des Audit-Befunds: über alle fünf Targets null Netz- und null Krypto-APIs, einziger ausgehender Verkehr ist StoreKits eigenes HTTPS zu Apple — der Ausnahmefall selbst. Umgesetzt als `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption: NO` in `project.yml`, **am App-Target allein**. Warum das reicht, ist nachgeschlagen und nicht geraten: Xcodes eigene Build-Setting-Spezifikation (`CoreBuildSystem.xcspec` im XCBuild-Plugin) definiert die `INFOPLIST_KEY_*`-Familie als wirksam „when `GENERATE_INFOPLIST_FILE` is enabled" — und `xcodebuild -showBuildSettings` zeigt `GENERATE_INFOPLIST_FILE = YES` nur beim App-Target, `NO` bei allen drei Extensions, die handgeschriebene `Info.plist`s ausliefern. Dort wäre der Schlüssel ein No-op; bewertet wird ohnehin das App-Bundle. **Am gebauten Produkt bewiesen:** `plutil -p .../Tuck.app/Info.plist` → `"ITSAppUsesNonExemptEncryption" => false`, und die drei `.appex` haben ihn erwartungsgemäß nicht. Festgehalten in `docs/privacy-manifest-notes.md` §6 Punkt 5 und in der Apple-Developer-Checkliste (nicht Teil dieses Exports), jeweils mit Datum und Beleg — und mit der Grenze: das nimmt Apples Prüfung vorweg, es ersetzt sie nicht.

**Verifikation.** `xcodegen generate` war zweimal nötig (beide `project.yml`-Änderungen), der jeweils zweite Lauf erzeugt keinen Diff. Alle vier Targets einzeln, `clean build`, frische `SYMROOT`/`OBJROOT`, `-sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO`: **4 × BUILD SUCCEEDED**, drei `.appex` im App-Bundle, Warnungen unverändert die drei bekannten `appintentsmetadataprocessor`-Notizen. Suite auf `OS=26.5,name=iPhone 17`: **336 Tests in 48 Suites → 335 Tests in 48 Suites, 0 Failures, 0 Skips.** Der eine entfallene Test ist `withoutAWayToOpenTheAppNoSecondButtonIsOffered` — er pinnte `canOpenApp: false`, einen Parameter und einen Zustand, die es nicht mehr gibt. Damit liegt die Suite weiter über dem Rundenanfang (333 in 47).
*(Die Arbeit lief über Mitternacht und reicht bis in den 2026-09-06. Entschieden und gearbeitet wurde am 2026-09-05, deshalb dieses Datum.)*

**Alle zwölf Entscheidungen aus §4.2 des Voll-Audits vom 2026-09-05 sind damit getroffen und umgesetzt:** H5, H3, H4, L26, L27, der Systemeinstellungen-Deep-Link, L20, L21, L22, L1/L3/L7, L14, L32 — vier Runden, keine offene Zeile mehr.

## 2026-09-06 — Das Privacy-Manifest ist angelegt, in allen vier Bundles

**Anlass:** Entscheidung des Projektinhabers. `docs/privacy-manifest-notes.md` lag seit dem 2026-09-05 als Entwurf vor und sagte in §7 selbst, die Datei sei „noch nicht angelegt". Entschieden wurden zwei Dinge: **dass** sie angelegt wird, und **dass alle vier Targets** sie tragen. §4 hatte alle vier nur empfohlen; §6.1 hält weiterhin fest, dass Apples Dokumentation für mitgelieferte eigene Extensions keine eindeutige Aussage macht. Die Frage bleibt damit offen, die Entscheidung darüber ist getroffen — auf den sicheren Weg, weil ein überflüssiges Manifest nichts kostet und ein fehlendes ein Ablehnungsgrund ist. Was das Manifest erklärt, erklärt der Projektinhaber gegenüber Apple, nicht der Code.

**Der Entwurf wurde vor dem Schreiben gegen den aktuellen Stand nachgeprüft, nicht übernommen.** §1s Greps noch einmal gelaufen: **null** Netz-APIs (`URLSession`, `URLRequest`, `NWConnection`, `CFNetwork`, `dataTask`, `WKWebView`, `CloudKit`, `NSUbiquitous`, `Firebase`), **null** weitere Required-Reason-APIs (`systemUptime`, `mach_absolute`, `modificationDate`, `creationDate`, `volumeAvailable`, `statfs`, `activeInputModes`, `UITextInputMode`, `attributesOfItem`), **null** Krypto-APIs. Jeder Store-Zugriff außerhalb der Tests geht auf `UserDefaults(suiteName: TuckIdentifiers.appGroupSuiteName) ?? .standard`, dazu der eine Schlüssel `hasCompletedOnboarding` über `@AppStorage` in `UserDefaults.standard` — beide Gründe des Manifests tragen also weiterhin. **Eine Zahl ist gewandert und ist bewusst nicht geändert worden:** §1 und §4 zählen „16" Suite-Zugriffe, gemessen sind es heute **17** Aufrufstellen in 15 Nicht-Test-Dateien. (Der Grep über die fünf Nicht-Test-Verzeichnisse meldet 18 Treffer in 16 Dateien — der eine Überhang ist der Kommentar in `TuckShield/ShieldConfigurationExtension.swift:29`, der die API nennt statt sie zu rufen.) Am Manifest ändert das nichts — es hängt daran, *dass* der Suite-Pfad benutzt wird, nicht wie oft — und die Zeile ist §1s eigene Beweisführung, die zu korrigieren nicht Teil dieser Änderung war. Hier notiert, damit die Drift nicht das nächste Mal unbemerkt weiterläuft.

**Eine Datei, vier Targets** (`Shared/PrivacyInfo.xcprivacy`). Dieselbe Form, die `Shared/SharedCopy.xcstrings` schon trägt: in `project.yml` unter `sources:` jedes der vier Targets gelistet, das Test-Bundle bewusst nicht. Vier Kopien derselben Erklärung wären genau die Drift-Klasse, an der dieses Projekt schon mehrfach hing.

**Die Build-Phase ist nachgesehen und nicht angenommen — das war der eine Punkt, an dem eine Annahme teuer gewesen wäre.** XcodeGen 2.46 sortiert `.xcprivacy` von sich aus in die Resources-Phase; ein ausdrückliches `buildPhase: resources` war nicht nötig und steht deshalb auch nicht da. Beleg in der generierten `project.pbxproj`: **vier `PBXBuildFile`-Einträge auf einer einzigen `PBXFileReference`**, jeder „`in Resources`", verteilt auf die Resources-Phasen genau der vier Targets (`CE15EFB8` → `Tuck`, `C54FA691` → `TuckMonitor`, `ACBBB8C3` → `TuckShield`, `7775AD32` → `TuckShieldAction`) — und `grep -c "PrivacyInfo.xcprivacy in Sources"` = **0**. Eine Compile-Phase hätte die Datei nicht ins Bundle gelegt, sondern zu übersetzen versucht. `xcodegen generate` zweimal gelaufen, der zweite Lauf erzeugt keinen Diff.

**Am gebauten Produkt bewiesen, nicht am Projektfile.** Ein `clean` über alle Targets, danach alle vier einzeln gebaut (`-sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO`) — 4 × BUILD SUCCEEDED. `find` über `Tuck.app` findet **vier** `PrivacyInfo.xcprivacy`: eine in der App-Wurzel, je eine in der Wurzel von `TuckMonitor.appex`, `TuckShield.appex` und `TuckShieldAction.appex` unter `PlugIns/`. `plutil -p` auf alle vier: identisch, `NSPrivacyTracking => false`, beide Arrays leer, genau ein Eintrag unter `NSPrivacyAccessedAPITypes` mit `NSPrivacyAccessedAPICategoryUserDefaults` und den Gründen `1C8F.1` und `CA92.1`. Die Bundle-Wurzel ist unter iOS die Stelle, an der Apple liest — ein Manifest ein Verzeichnis tiefer wäre vorhanden und trotzdem unwirksam. (Nebenbefund beim ersten Anlauf, festgehalten weil er leicht zu einem falschen Beweis geführt hätte: `xcodebuild clean build` **pro Target** mit gemeinsamem `SYMROOT` räumt das Verzeichnis vor jedem Target wieder leer, am Ende liegt nur das letzte Produkt da. Einmal `clean`, dann vier `build` — sonst beweist der `find` nur den letzten Lauf.)

**Gepinnt** (`TuckTests/PrivacyManifestTests.swift`). Vier Tests, jeder über alle vier Bundles: die App aus `Bundle.main`, die drei Extensions aus `builtInPlugInsURL` — derselbe Weg, den `EnglishLocalizationTests` zum Shield nimmt, und der einzige, den es für zwei Extensions gibt, die der Simulator nie startet. Gelesen wird direkt von `bundleURL`, **nicht** über `url(forResource:)`: das durchsucht Unterverzeichnisse und würde ein falsch platziertes Manifest finden und für richtig halten. Geprüft wird pro Bundle genau das, was §§2–4 festlegen, die Gründe als Menge. **Der Rot-Lauf ist gefahren, nicht behauptet:** in einer Arbeitskopie außerhalb des Repos das Manifest aus `TuckShieldAction` entfernt, neu generiert, Suite gelaufen — alle vier Tests rot, jeder mit dem vollen Pfad des fehlenden `TuckShieldAction.appex/PrivacyInfo.xcprivacy`. Der echte Baum wurde dafür nicht angefasst. Das ist der Fall, für den der Test existiert: ein fehlendes Manifest ist in den Quellen unsichtbar, weil die Datei in `Shared/` weiter korrekt aussieht.

**Verifikation.** Suite auf `OS=26.5,name=iPhone 17`: **335 Tests in 48 Suites → 339 Tests in 49 Suites, 0 Failures, 0 Skips.** Die vier neuen sind die dieses Eintrags; kein bestehender Test hat sich bewegt.

**Was damit nicht erledigt ist:** §6.1 (die Frage selbst, nicht die Entscheidung) und §6.2 der Notizen bleiben offen. Das **App-Privacy-Label** in App Store Connect ist eine zweite, separate Angabe im Portal — Manifest ≠ Nutrition Label, erwarteter Stand dort „Data Not Collected", gemacht ist sie nicht. Und wie bei der Export-Compliance gilt: das ist die Erklärung, nicht ihre Bestätigung durch Apple.

## 2026-09-06 — Der Atem-Timer endet auf einem Fakt und einer Wahl, nicht mehr auf einer Freischaltung

**Anlass:** Entscheidung des Projektinhabers. Zwischen den 30 Sekunden und dem `unlock()` steht seit heute ein Schritt, der einen echten, zitierfähigen Fakt über Doomscrolling zeigt und zwei Wege anbietet: „Ich lass es doch" (Flow zu, Kontingent unangetastet, Shield bleibt) und „Trotzdem freischalten" (wie bisher). Der Plan (nicht Teil dieses Exports) ist vor dem Bau durch einen Review gegangen (kein BLOCKER, vier Pflicht-Vorgaben eingearbeitet). **Die tragende Mechanik ist nicht der Fakt, sondern die Wahl:** die Dismiss-Option ist die am stärksten belegte Einzelmechanik dieser Kategorie (one sec, PNAS 2023, in der Engagement-Recherche als Empfehlung 1.1 geführt).

**Vier Entscheidungen, alle bewusst:**

1. **Alle drei Gründe durchlaufen den Schritt — keine Ausnahme für „Notfall".** Ursprünglich sollte der Notfall überspringen. Ein Review-Durchgang fand, dass genau das der Grund-Auswahl zum ersten Mal einen **mechanischen** Vorteil gäbe: wer einmal merkt, dass „Notfall" schneller ist, wählt künftig immer „Notfall", und die Begründung, die B8 verlangt, wird zur Formsache. Revidiert auf uniform; die Architektur wurde dadurch nebenbei einfacher (keine Reason-Fallunterscheidung). Festgehalten in der reinen Funktion `FlowPhase.afterBreathing(reason:)` — dasselbe Muster wie `FlowPhase.initial`, und die Stelle, an der die Uniformität mechanisch statt nur in Prosa steht (`ReconsiderStepTests.everyReasonLeavesTheTimerOnTheReconsiderStepRatherThanUnlocked`).
2. **Sieben Fakten statt neun.** Der Gedächtnis-Cluster (5.1 Google-Effekt, 5.2 Museums-Fotografieren) ist nach dem Review-Fund gestrichen: thematisch nicht Scrollen, sondern Nachschlagen und Fotografieren. Ebenso raus: **4.4** (Instagram/Teenager-Mädchen — Journalismus über geleaktes, nicht-peer-reviewtes Firmenmaterial, laut Recherche selbst angreifbar) und die vier relativierten Mythen R1–R4. Was bleibt, ist Konfidenz Hoch/Mittel-Hoch aus fünf der sechs Cluster: 1.2, 2.1, 3.1, 4.1, 4.2, 4.3, 6.1. Copy-Grenze aus der Recherche übernommen: nur 4.1 und 4.2 sind sauber kausal, also sagt keine Zeile „beweist", und 2.1 nennt seine Jugendlichen-Stichprobe statt sie zu verallgemeinern. Quelle je Fakt (Autor, Jahr, Link) steht als Code-Kommentar — auditierbar, nicht user-facing.
3. **„Doch nicht" schließt den Flow vollständig.** `dismiss()`, wie die bestehenden „Schließen"-Buttons. `context.unlock()` wird in diesem Zweig nie gerufen: kein Kontingent-Abzug, kein Shield-Clear. Bewusst **kein Lob und keine Gutschrift** für den Ausstieg — der Kipp-Punkt, an dem aus Autonomie eine Punktejagd würde, steht in derselben Empfehlung 1.1.
4. **Der Fakten-Pool ist app-generell, nicht app-spezifisch — und das ist keine Einschränkung.** Family Controls gibt App-Namen aus Datenschutzgründen nie als String heraus, nur als opakes `ApplicationToken`, das ausschließlich Apples eigene `Label`-View rendern darf. Der Override-Flow kennt schon heute nur Fenster und Grund, nie die App. Ein „Instagram frisst deinen Morgen" ist technisch nicht baubar, nicht bloß nicht gebaut.

**Der Screen entkoppelt Timer-Ende und Buchung zeitlich unbegrenzt — vermerkt, nicht behoben.** Wer nach den 30 Sekunden auf dem Reconsider-Screen stehen bleibt, kann beliebig lange stehen bleiben und erst danach „Trotzdem freischalten" tippen; gebucht wird dann mit `now` von diesem Moment. Das ist der analoge, aber unbegrenzte Fall zum bestehenden 30-Sekunden-Fenster-Ende-Grenzfall (Eintrag vom 2026-09-04). Kein Code-Fix: die Buchung liest das Fenster zum Buchungszeitpunkt, kostet also außerhalb jedes laufenden Fensters nichts (L21, mit `ReconsiderStepTests.theUnlockBranchOutsideEveryWindowCostsNothing` gepinnt — bis 2026-09-07 hieß der Test `…theUnlockAnywayBranch…`, s. den Eintrag von diesem Tag), und der Shield fällt bei `intervalDidEnd` ohnehin von selbst. Die einzige Folge ist, dass die Bestätigung dann die ehrliche „ohne laufendes Fenster"-Zeile zeigt.

**Zwei Vorgaben aus dem Review, die den Bau geprägt haben:**

- **Der B8-Guard behält seine Richtung.** `FlowPhaseTests.thePreselectedPathCanNeverOpenAlreadyConfirmed` hat einen exhaustiven `switch`, den der neue Case bricht. `.reconsider` ist in den `Issue.record`-Zweig gewandert, **nicht** in den sicheren `break` — der Screen ist nur über `.breathing` erreichbar und trägt den Freischalt-Button, ein Start auf ihm wäre derselbe Bruch eine Ebene früher. Die bequeme „Reparatur" hätte den Guard geschwächt statt ihn zu erweitern.
- **Die Buchung ist ein Wert, keine zwei Zuweisungen.** Der alte Auto-Pfad schrieb `spentUnlock` und `allowance` nebeneinander; mit dem zweiten Aufrufort wären es zwei handgeschriebene Paare gewesen, und genau so verliert eines davon still die Kontingent-Neulesung, die `confirmed(for:)` rendert. Jetzt: `OverrideContext.bookUnlock(…) -> UnlockBooking`.

**Lokalisierung vollständig.** Sieben Fakten plus zwei Button-Zeilen in `Tuck/Localizable.xcstrings`, DE als Quellsprache, EN übersetzt. Die beiden Katalog-Tests in `EnglishLocalizationTests` **scannen keine Datei, sondern zählen Pools auf** — beide Pools sind entsprechend erweitert, sonst wären die neun Zeilen unentdeckt ungeprüft geblieben. Dazu ein eigener Test, der die Copy-Regel in der zweiten Sprache hält (kein „you"/„your"/„should", kein „proves"): eine Übersetzung ist genau die Stelle, an der aus einer Studienbeschreibung eine Ansprache wird. Der Ausstieg heißt „I'll leave it after all" und bleibt damit das Hauswort des Shields („I'll leave it") eine Stufe weiter.

**Kein Dark Pattern in Gegenrichtung.** Beide Wege sind Sage-Plates nach §5.2: gleiche Schrift, gleiche Fläche, gleiche Breite, untereinander, Ausstieg zuerst. Ein Primär-plus-Textbutton-Paar hätte den Screen zu einem Schubs Richtung Freischalten gemacht — das Gegenteil seines Zwecks. Kontrast unverändert im Bestand: 3,96:1 für den Fakt auf Cream, ~~3,66:1~~ 3,67:1 für beide Platten (§2.4). *(Zahl angeglichen 2026-09-14: keine Drift, sondern die Methoden-Deklaration in §2.4 — 3,66 ist die Hex-Handrechnung, 3,67 die Laufzeitrechnung, die ab dann verbindlich ist.)*

**Verifikation.** `xcodegen generate` (zwei neue Quelldateien), danach `xcodebuild test -scheme Tuck -destination 'platform=iOS Simulator,OS=26.5,name=iPhone 17'`: **339 Tests in 49 Suites → 349 Tests in 50 Suites, 0 Failures, 0 Skips, `** TEST SUCCEEDED **`.** Die zehn neuen sind die dieses Eintrags; kein bestehender Test hat sich bewegt außer dem angepassten B8-Guard.

**Nicht geprüft:** der Screen ist nicht am Gerät und nicht bei Accessibility-Textgrößen angesehen worden — er sitzt in derselben `scrollableWhenTallerThanScreen()`-Spalte wie der Rest des Flows, aber das ist eine Ableitung, keine Messung. Gehört in den nächsten Dynamic-Type-Durchgang nach §6.4.

**Prüfdurchgang, selbes Datum.** Build und Suite erneut selbst gefahren: **349 Tests in 50 Suites, 0 Failures** bestätigt. Einheitliches Verhalten, Kontingent-Verhalten in beiden Zweigen, das Gleichgewichts-Constraint (bis AX5 gemessen, nicht nur gelesen) und der verschärfte B8-Guard: alle vier bestätigt. Gesamt-Verdikt: bereit für den Nutzer, kein BLOCKER, kein HIGH. Fünf LOW, drei davon hier behandelt:

- **Zwei Copy-Präzisierungen** (`ReconsiderCopy.swift`, `Localizable.xcstrings`, DE+EN): Fakt 2.1 sprach von „vielen Likes unter einem Foto" — die Studie zeigte **eigene** Fotos mit **simulierten** Likes; präzisiert. Fakt 4.3 sagte „senkte die Stimmung" — die Recherche selbst reserviert saubere Kausalität für 4.1/4.2 und formuliert 4.3 als Vorhersage („sagte einen Rückgang … voraus"); die Copy jetzt ebenso. Beides Präzisionsverluste ohne Übertreibung, keine Bau-Fehler — der Plan selbst hatte die zweite Formulierung so vorgegeben.
- **§5.2-Zahl korrigiert:** „Sechs Instanzen" stand über einer Aufzählung, die schon vor diesem Feature neun listete und durch den Reconsider-Screen auf elf wuchs, ohne dass die Zahl mitgezogen wurde — dieselbe Fehlerklasse wie der Eintrag vom 2026-09-06 weiter oben (Privacy-Manifest-Zahl). Auf „Elf" korrigiert, gegen die Aufzählung im selben Satz nachgezählt.
- Suite nach allen drei Korrekturen erneut grün: 349/50, 0 Failures.

**Zwei LOW-Befunde bewusst offen, nicht behoben:**
- **AX5-Render-Durchgang fehlt weiterhin** (bereits oben unter „Nicht geprüft" vermerkt) — Family Controls autorisiert im Simulator nicht, der Screen ist nur nach Onboarding + gestelltem Wecker erreichbar. Gehört an ein reales Gerät, keine Simulator-Aufgabe.
- **`theDismissBranchLeavesTheQuotaAndTheShieldUntouched` ist beweisschwächer, als sein Name verspricht** — er prüft, dass nach einem Timer-Ablauf ohne Buchungsaufruf nichts sich bewegt hat, ruft den Dismiss-Zweig selbst aber nie auf (es gibt ohne UI-Test-Target oder View-Inspection-Bibliothek keinen Weg, `Button { dismiss() }` auszuführen und zu beobachten). Der Zweig ist eine einzige Umgebungs-Aktion ohne eigene Logik — direkt am Code lesbar, hier durch den Prüfdurchgang bestätigt. Eine Test-Infrastruktur (View-Inspection oder ein UI-Test-Target) eigens für diese eine Zeile aufzubauen wäre unverhältnismäßig; akzeptiert, nicht nachgerüstet.

## 2026-09-06 — Die Absicht steht jetzt dauerhaft da (K1), und ein Wirkungs-Signal über die App (K2)

**Anlass:** Tuck sagte an keiner Stelle dauerhaft, **wofür** es gebaut ist — das Onboarding sagte einmal, was mechanisch passiert, danach nie wieder — und es sagte nirgends, was **es selbst** getan hat. Jedes vorhandene Signal war entweder flüchtig (`ScreenTimeNotice`: einmal lesen, dann weg) oder eine Aussage über den Nutzer (`MorningProgressStore`, `MascotStage.progressDescription`). Entschieden wurde, **beide** Signale zu bauen. Der Plan (nicht Teil dieses Exports) ging durch drei Review-Runden.

**Der Befund, der die Aufgabenstellung korrigiert hat.** Die Wunsch-Formulierung „insgesamt X Stunden **durch Tuck blockierte Bildschirmzeit**" ist unter G3 nicht baubar, aus zwei unabhängigen Gründen. Erstens weiß die App nie, ob eine Sperre stand: der `ManagedSettingsStore`-Schreibvorgang ist nicht werfend und still, im Monitor und im Override-Flow ausdrücklich so vermerkt, und der L20-Entscheid hält schon fest, dass eine Bestätigung sagt, was *diese App getan hat*, nie was iOS daraus macht. Zweitens wäre „Bildschirmzeit" eine Kontrafaktik — wie viel ohne die Sperre entstanden wäre, misst niemand. **Konsequenz, nicht verhandelbar:** der Zähler misst **eingetragene, durchgelaufene Sperrfenster-Zeit**, in der Projektvokabel „eingetragen". Das ist eine schwächere Behauptung als die skizzierte, und die einzige, die die App belegen kann.

**K1 — zwei Flächen, reine Copy-Arbeit**. Der Onboarding-Kernsatz trägt jetzt den Zweck vor der Mechanik; der `explain`-Schritt bleibt vollständig der Berechtigungs-Erklärung. Dazu ein ruhiger Abschnitt in den Einstellungen — eine `Section` **ohne Zeilen**, Header und Fußzeile tragen alles, kein Chevron, kein Button, keine Alpha-Absenkung. Platziert unterhalb von „Dein Weg" und „Dein Tuck" als Schlusswort des Screens: ein Manifest über der Weckzeit-Zeile wäre ein Werbebanner in einem Einstellungsdialog. **Nicht angefasst:** der Shield (`ShieldCopy.subtitle` trägt die Absicht bereits explizit und ist in zwei Sprachen und zwei Bundles gepinnt — dort ist keine Lücke zu füllen, nur ein Risiko einzugehen) und der Morgen-Screen (der Morgen ist ein Gruß, kein Leitbild). Sechs harte Copy-Constraints, jeder gegen eine Fundstelle: der Satz bewertet den Feed, nie den Nutzer; „du"/„dein" bleiben erlaubt, weil die Sperre im Faktenpool für *Studienbeschreibungen* gilt; kein Ausrufezeichen, keine Knappheit; keine Zahl und kein Fakt im Einstellungs-Abschnitt; nichts behaupten, was die App nicht tut; beide Sprachen im Katalog **aufgezählt**, weil `EnglishLocalizationTests` keine Datei scannt.

**K2 — der Zähler, und warum verzögerte Verrechnung beim Lesen**. Zwei Alternativen sind ausgeschlossen worden, nicht übersehen: die **Monitor-Extension** (die Datei sagt selbst, warum sie nicht zählt — „duplicating it here would inflate the streak from a foreign process whose reliability is still unverified"; dazu kompiliert das Monitor-Target die nötigen Stores gar nicht) und **`StopWakeAlarmIntent`** (feuert am *Anfang* des Fensters; die volle Länge dort gutzuschreiben hieße Zeit zu behaupten, die noch nicht vergangen ist). Gewählt ist exakt das Muster, das der Bestand für dieselbe Problemlage schon hat: `UnlockQuotaStore`s lazy refill — „the evening has no user action to hang it on — nobody dismisses a bedtime".

**Getrennt vom Mascot-System, und das ist eine Review-Regel, kein Test.** `MorningProgressStore` zählt Morgen des Nutzers und speist über `MilestoneStore` Belohnungen; `ProtectedTimeStore` zählt Fenster der App und speist nichts. Keine neue Datei importiert `MascotMilestone`, kein Meilenstein liest den Wert, keine Sprechblase erwähnt ihn — ein Wert, der Belohnungen auslöst, ist ein Ziel. Mechanisch pinnen lässt sich das in Swift nicht (alles im App-Target ist modulweit sichtbar); pinnbar ist der **Datenbestand**, und genau das tut der Key-Test.

**Das tragende Prinzip für alle elf Aufruforte:** *verrechnet wird nur eine Spanne, für die die Registrierung nachweislich durchgehend lebte; ist das zweifelhaft, wird sie nicht gutgeschrieben, aber `countedThrough` rückt trotzdem über sie hinweg.* Untererfassung statt Übererfassung — dieselbe Richtung, die G3 verlangt. Das eine Prinzip erklärt alle Platzierungen ohne Ausnahmeliste: **vor** einer Längenänderung (danach ist die Länge, mit der die Registrierung lebte, nicht mehr lesbar), **vor** einem `false → true`-Flip, **vor** einem `true → false`-Flip (deshalb steht die Verrechnung im genehmigten Pfad vor dem Re-Arm-Block und deckt den `.disarm`-Zweig mit), und **nach** einem Arm in ein bereits laufendes Vorkommen. Sechs **verrechnende** `accrue`-Platzierungen (`applyPendingMorningDuration` als erste Anweisung, `WakeAlarmScheduler` vor `clear()`, `BedtimeScheduler.setBedtime` vor `store()`, `clearBedtime` als erste Anweisung, `reconcile()` zweimal), fünf Skip-Orte. Im Code stehen insgesamt **acht** `accrue`-Aufrufe: diese sechs plus zwei rein lesende in `SettingsView` (Initialwert des `@State` und `reconcileAndRefresh()` nach jedem Sheet), die nichts platzieren, sondern den Stand holen — die Funktion ist Lesen und Schreiben in einem, deshalb sind das keine zusätzlichen Verrechnungsorte.

**Richtigstellung, die aus dem Review kam:** die frühere Begründung für den entzogenen Zweig — „vor dem Autorisierungs-Guard, sonst gehen die Tage verloren" — war **invertiert**. Vor dem Guard stehen die Flags noch auf `true`, und die App weiß nicht, *wann* der Zugriff entzogen wurde; sie hätte also genau die Vorkommen gutgeschrieben, die nach dem Entzug lagen und nichts getragen haben. Übererfassung, G3-Bruch. Die Verrechnung steht jetzt als **letzte** Anweisung vor dem `return`, nach beiden `recordBlockRegistration(succeeded: false)`. Der Preis ist bekannt und gewollt: die Vorkommen, die vor dem Entzug echt scharf waren, fallen mit weg.

**Der Post-Arm-Skip, der zweite Review-Fund.** Jeder Arm eines Fensters mitten in dessen eigenem laufenden Vorkommen hätte dieses beim nächsten Durchlauf mit der **vollen** `durationSeconds` gutgeschrieben, obwohl höchstens ein Teil überwacht war. Zwei reale Formen: Bettzeit um 22:45 auf 23:00 gesetzt (das Fenster 22:30–23:30 läuft in dem Moment schon), und um 07:45 die Morgenlänge von 30 auf 60 Minuten geändert — der bestehende Guard prüft das **alte** Fenster (07:00–07:30, vorbei), das neue 07:00–08:00 enthält 07:45 sehr wohl. `skipRunningOccurrence(endingAt:)` rückt `countedThrough` auf das absolute Ende dieses Vorkommens und **fasst die Summe nie an**. Entschieden wurde: das Vorkommen **ganz** überspringen statt es anteilig zu zählen — dieser Zähler hat keine Teilstücke. Der Skip steht immer **nach** `accrue`, nie davor: davor stünde `countedThrough` in der Zukunft und `accrue` wäre bis `end` ein No-op, also derselbe eingefrorene Zustand wie bei einer rückwärts gestellten Uhr.

**`reconcile()` friert ein `now` pro Durchlauf ein** und reicht es an jede Verrechnung, jeden Skip und den Tail-Call `applyPendingMorningDuration` weiter. Ohne das wäre dessen eigene Verrechnung eine zweite, winzige Runde mit einer um Mikrosekunden weitergelaufenen Uhr — harmlos klein, aber sie hätte den Idempotenz-Test genau an der Stelle umgangen, an der er gebraucht wird.

**Die drei Entscheidungen (2026-09-06):**
1. **Positionierung bleibt auf die zwei Fenster zugeschnitten**, keine „Bildschirmzeit insgesamt"-Erzählung. Die App beschreibt sich als Morgen-/Abend-Produkt; eine breitere Erzählung wäre eine zweite daneben, und C5 verbietet, mehr zu behaupten, als die App tut. Folge: `docs/concept.md` und der Store-Metadaten-Entwurf (nicht Teil dieses Exports) **nicht** angefasst.
2. **Quantifizierung wird gebaut.** Die drei Bedingungen neutralisieren die dokumentierten Kippmechanismen: Silverman & Barasch greift nicht (ein monotoner Zähler kann nicht brechen), das Dashboard-Muster ist durch die Platzierung entschärft (zwei Taps tief, keine Tagesdifferenz, bewegt sich nur nach einem Fensterende). Offen blieb **Etkins Befund**, dass Quantifizierung intrinsisch motivierten Tätigkeiten den Genuss entzieht — er betrifft die Quantifizierung *der eigenen Tätigkeit*, K2 quantifiziert die Tätigkeit **der App**. **Diese Unterscheidung ist eine Ableitung, keine gemessene Sache; das ist bekannt und akzeptiert und steht hier, damit es nicht als bewiesen weitergereicht wird.** Sie ist zugleich der Grund für Entscheidung 3.
3. **Freischaltungen ändern nichts** (der aufgelöste BLOCKER). Jedes eingetragene, durchgelaufene Fenster zählt, unabhängig davon, ob es freigeschaltet wurde. Der Verrechnungspfad liest **keinen** Freischaltungs-Zustand, braucht keinen dritten Key und keinen Hook im Override-Flow — `OverrideFlowView` ist von K2 nicht angefasst. Dieselbe Linie wie die bestehende Fußzeile des Morgen-Zählers („Jeder abgeschlossene Morgen zählt, auch die mit einer Freischaltung"). Ein Zähler, der auf Entsperr-Verhalten reagiert, wäre eine Bewertung des Nutzers — G4-Bruch, und genau das, was diese Zahl nicht sein soll.

**Bedingung 2 mechanisch statt als bloße Regel.** Der Store hat **genau zwei** Keys (`protectedSecondsTotal`, `protectedTimeCountedThrough`) und **eine** Funktion, die eine Zahl herausgibt, und die liefert eine Summe. Die Oberfläche hat drei öffentliche Funktionen: `accrue` (die eine Zahl-liefernde), `skipRunningOccurrence` (schreibt nur `countedThrough`, gibt nichts zurück) und `runningOccurrenceEnd(of:at:calendar:)` (liest und schreibt nichts). Die dritte verstößt nicht gegen Bedingung 2: sie gibt kein Ergebnis aus dem **gespeicherten Zustand** heraus, sondern rechnet ausschließlich über ihre Parameter — dasselbe Fenster und dieselbe Zeit ergeben dasselbe Datum, egal was in der Suite steht. Aus ihr ist kein Verlauf und kein Vergleich zu gewinnen, weil sie den Zähler gar nicht anfasst. Kein Zeitraum-Parameter, keine Aufschlüsselung, keine Historie — ein Vergleich ist nicht „verboten", sondern nicht ausdrückbar. Gepinnt ist das über den Key-Test: nach einem Durchlauf über beide Fenster, mit Übersprüngen, Längenwechsel und Freischaltung dazwischen, enthält die Wegwerf-Suite exakt diese zwei Keys und keinen weiteren. Fällt er beim Erweitern um, ist das die Absicht — eine Historie kann nicht entstehen, ohne dass jemand diesen Test anfasst.

**Die fünf Grenzen der Monotonie — benannt, nicht weggebaut:**
1. **Uhr weit vorwärts gestellt** → der Stand ist zu hoch, sinkt aber nicht. Eine Korrektur nach unten wäre der Rückschritt, den G4 verbietet, und teurer als der Schaden.
2. **Uhr danach zurückgestellt** → der Zähler ist **eingefroren**, bis die reale Zeit `countedThrough` einholt; echte Fenster in dieser Spanne werden nie gutgeschrieben. Der Preis der Monotonie, als Test festgehalten statt als Bug entdeckt.
3. **Backup-Restore** → der Stand kommt kleiner zurück, und dagegen gibt es keine Ratsche. **Das ist kein Nachteil gegenüber `MilestoneStore`:** dessen Ratsche vergleicht mit `MorningProgressStore.completedMornings`, beide Keys liegen in derselben App-Group-Suite, ein Restore bringt beide gemeinsam kleiner zurück. K2 **teilt** diese Lücke, es hat sie nicht zusätzlich — eine bestandsweite Grenze, kein Defekt dieses Zählers.
4. **DST-`nil`** → das betroffene Fenster wird in diesem Durchlauf nicht verrechnet, `countedThrough` rückt trotzdem vor. Der teure Fehler wäre das Gegenteil gewesen: ein früher `return` hätte die Verrechnung dauerhaft eingefroren. **Nachgemessen statt angenommen:** dieser `nil`-Zweig ist auf diesem Pfad faktisch unerreichbar — `Calendar.date(bySettingHour:minute:second:of:)` hat als Default `matchingPolicy: .nextTime`, die nicht existierende Stunde löst also vorwärts auf statt `nil` zu liefern. **Korrektur aus dem Prüfdurchgang (2026-09-06):** die frühere Fassung dieser Zeile behauptete, das Vorkommen werde dann „normal gezählt", und der Test dazu benutzte ein Fenster `02:30–03:00`, dessen **Ende** (03:00) an diesem Tag existiert — er berührte die Kante gar nicht. Liegt das Ende wirklich in der Lücke (Europe/Berlin, 2026-03-29, Fenster `02:00–02:30`), gehen **zwei** Vorkommen verloren, nicht eines: am Übergangstag löst der Anker von 02:30 auf 03:00 vorwärts auf, am Folgetag fällt er auf 02:30 zurück, und beide Tagesabstände sind 0. Nachgemessen, jetzt so gepinnt. Der Guard bleibt, weil `mostRecentStart` ein Optional zurückgibt und eine künftige Matching-Policy nicht Sache dieses Stores ist. Der Test pinnt weiterhin die **Eigenschaft** (der Zähler bleibt in Bewegung — am 31.03. läuft er wieder), nicht den Zweig, und dazu jetzt den Preis.
5. **Zeitzonenwechsel — ±1, einmalig pro Wechsel.** Fenster-Enden werden in der Wall-Clock der aktuellen `Calendar` gerechnet, `countedThrough` ist ein absoluter `Date`. **Wird nicht behoben:** die Korrektur bräuchte eine gespeicherte Zone pro Vorkommen und damit einen dritten Key, also einen Bruch von Bedingung 2. Dazu kommt eine zweite benannte Kante derselben Klasse: `countedThrough` ist **ein** Schlüssel für **beide** Fenster, ein Skip kann also ein Ende des anderen Fensters mitverschlucken — nur bei Überlappung, höchstens ein Vorkommen, in der gewollten Richtung.

**Das eingefrorene `now` in `scheduleWakeAlarm` — als „akzeptierte Untererfassung" beschrieben, tatsächlich eine Übererfassung, behoben (Prüfdurchgang, 2026-09-06).** Zwischen der Übergabe von `now` und dem Verrechnungs-Aufrufort liegt der Authorization-Prompt, der beim ersten Mal Minuten dauern kann. Die Richtung war falsch dargestellt: nicht nur die Verrechnung, auch der **Post-Arm-Skip** hing an diesem veralteten `now`, und `runningOccurrenceEnd` prüft `contains(now)`. Läuft das Fenster zum eingefrorenen Zeitpunkt noch nicht und zur echten Registrierungszeit schon (Wecker 07:00 um 06:55 gesetzt, Erlaubnis um 07:10 erteilt), fällt der Skip aus und der nächste Durchlauf schreibt das ganze Vorkommen voll gut — 30 Minuten, die nie überwacht waren. G3-Bruch in der teuren Richtung. **Fix:** `scheduleWakeAlarm` nimmt statt `now: Date` eine injizierbare Uhr `clock: @Sendable () -> Date = { .now }`; nach `await requestAuthorization()` wird sie **einmal** gelesen, und genau dieses Datum geht an `accrue` und an den Skip. Die Testinjektion bleibt erhalten, das Argument gegen ein nacktes `Date.now` also auch. Gepinnt durch `aPromptThatOutlastsTheWindowStartStillSkipsTheRunningOccurrence` (Store-Ebene, wie alle Skip-Tests): das Szenario einmal mit dem veralteten Zeitpunkt (volle 30 Minuten, der Bug) und einmal mit der frischen Uhr (0).

**Was nicht testbar ist und so benannt gehört.** Die **Reihenfolge** der Aufrufe innerhalb von `reconcile()` lässt sich nur indirekt prüfen, weil beide Pfade `AuthorizationCenter.shared` berühren. **Und alle fünf Skip-Aufruforte sind im Testlauf nicht erreichbar:** der Skip hängt an `register(...) == true`, und `register` geht durch `BlockWindowMonitor.register`, das nicht injizierbar ist und im Simulator zuverlässig `.unauthorized` wirft. **Der Plan behauptet das, und es stimmt — nachgeprüft, nicht übernommen.** Kein Loch in der Korrektheit: scheitert der Arm, steht das Flag auf `false`, und die Verrechnung überspringt das Fenster ohnehin — dieselbe Wirkung, anderer Weg. Konsequenz: die Skip-Tests laufen **auf Store-Ebene**, in genau der Reihenfolge, in der die Aufruforte sie fahren, und die *Platzierung* wird durch Kommentar und Review getragen, nicht durch einen Test, der etwas anderes prüft, als sein Name sagt — dieselbe Ehrlichkeit wie beim LOW-Befund zu `theDismissBranchLeavesTheQuotaAndTheShieldUntouched` im Eintrag oben. Der Längenwechsel-Test gegen `applyPendingMorningDuration` bleibt, was er ist: der Nachweis für den Verrechnungs-Aufrufort M1, nicht für den Skip S5.

**K3 und K4 ausdrücklich abgesagt**, damit sie nicht in einer künftigen Runde versehentlich wieder auftauchen. **K3 (Maskottchen reagiert auf Schwellen-Überschreitungen): nein** — das Schwellen-Ereignis kann nur akkumulierte Vordergrundzeit ohne App messen, „a phone call, Maps on the way to the train and twenty minutes of scrolling raise the exact same flag" (`ScreenTimeNotice.swift:12-15`); eine Mascot-Reaktion darauf ist per Definition eine Bewertung (G4, Mascot-Don'ts, Copy-Regel „keine Mengen-, keine Häufigkeitsaussage"). **K4 (Stats-Screen mit Woche-gegen-Woche): nein** — die eigene Recherche nennt ihn namentlich als eine von exakt zwei gefährdeten Stellen der App (nicht Teil dieses Exports), und ein Woche-gegen-Woche-Vergleich **kann sinken**, was G4 und die Mascot-Don'ts ausschließen. K2 ist die Bauform, die diesen Screen **ersetzt** und nicht vorbereitet — deshalb hat der Store keine Zeitraum-API.

**Verifikation.** Suite auf `OS=26.5,name=iPhone 17`: **349 Tests in 50 Suites → 368 Tests in 52 Suites, 0 Failures, 0 Skips.** Neu: 14 Store-Tests (`ProtectedTimeStoreTests`), 3 Darstellungs-Tests (`ProtectedTimeDisplayTests`), 2 Lokalisierungs-Tests. Kein bestehender Test hat sich bewegt. `xcodegen generate` gelaufen (**eine** neue Quelldatei, `Shared/ProtectedTimeStore.swift`, und zwei neue Testdateien). Der Override-Flow wird nicht angefasst — er ist an K2 nicht beteiligt.

**Prüfdurchgang danach (2026-09-06), drei HIGH-Funde, alle behoben:** das eingefrorene `now` in `scheduleWakeAlarm` (oben, mit Regressionstest), der DST-Test, der die Kante nicht berührte (oben, jetzt auf ein Fenster-Ende in der Lücke umgestellt und der Preis von zwei Vorkommen gepinnt), und die englische Kopfzeile „What Tuck has **saved**" direkt über einer nackten Stundenzahl — mit elidiertem Objekt liest sich das als eingesparte Bildschirmzeit, genau die Kontrafaktik, die L20 verbietet. Das deutsche „Was Tuck eingetragen hat" trägt diese Lesart nicht, also ist nur die Übersetzung bewegt worden: „What Tuck has set up", im Test zusätzlich gegen das Wort „saved" gepinnt. **Stand danach: 369 Tests in 52 Suites, 0 Failures, 0 Skips.**

## 2026-09-07 — Der Fakt fliegt aus dem Reconsider-Schritt; die Wahl bleibt

**Anlass:** ein weiterer Review des am 2026-09-06 gebauten Reconsider-Schritts. Drei vorangegangene Reviews haben denselben Screen freigegeben — alle drei haben **Vokabular** geprüft (kein „du", kein „beweist", kein Ausrufezeichen) und keine davon die **Rahmung**. Das ist der eigentliche Fund dieses Eintrags: eine Copy-Regel, die nur Wörter verbietet, kann einen Screen durchwinken, dessen Aufbau die Bewertung trägt, die die Wörter vermeiden.

**Die drei Lecks, unverändert übernommen, weil sie stimmen:**
1. **„Trotzdem freischalten" setzt eine Wertung voraus.** Das „trotzdem" behauptet, der Satz darüber sei ein Grund **gegen** das Freischalten. Das ist unabhängig vom Wortlaut des Satzes eine Stellungnahme des Screens zur Wahl — auf einer Fläche, deren dokumentiertes hartes Constraint (`design-system.md` §5.14) gerade **gleiches Gewicht beider Wege** ist. Die Fläche war gleich, das Wort nicht.
2. **Uniformität über alle drei Gründe verschärft das.** Der Pool war bewusst kontextblind. Für „Notfall" heißt das: wer telefonieren will, liest vorher „stiegen dort die gemessenen Anzeichen für Depression und Angst". Kein Wortproblem, ein **Platzierungsproblem** — und keine Umformulierung des Fakts löst es, weil das Problem der Ort ist.
3. **Der Fakt hat keinen Beleg.** Die einzige Stützstudie des ganzen Schritts (one sec, PNAS 2023) hat Deliberation, Wartezeit, Dismiss-Option und Kombination verglichen; **die Dismiss-Wahl allein** hatte den stärksten Effekt. Der Fakt obendrauf war Persuasion ohne Evidenz — und widersprach dem eigenen Store-Text („Das ist eine Verzögerung, keine Verweigerung").

**Was geändert wurde.** Der Faktenpool ist aus `Tuck/ReconsiderCopy.swift` **entfernt** (samt `randomFact()` und dem `@State fact` in `OverrideFlowView`), an seiner Stelle steht `reasonReflection(for:)`: eine ruhige Rückspiegelung des Grundes, den der Nutzer selbst gewählt hat — „Als Grund gewählt: **Notfall/Arbeit/Anderes**. Beide Wege stehen weiter offen." (EN: „Reason chosen: **Emergency/Work/Something else**. Both ways stay open."). Der Grund liegt an dieser Stelle bereits vor (`reconsider(for:)`-Parameter), es wird also **nichts neu erhoben** und nichts gespeichert. Der Unlock-Button heißt „Freischalten" / „Unlock". Drei vollständige Literale statt eines `%@`-Format-Strings, damit jeder Satz ein eigener Katalog-Schlüssel ist und die zweite Sprache Wort für Wort geprüft werden kann.

**Was ausdrücklich nicht angefasst wurde:** die `.reconsider`-Phase selbst, der 30-Sekunden-Atemtimer davor, die Buchungslogik (`bookUnlock`, L21) und die zwei gleichgewichtigen Wege als Choice-Architektur. Das ist der belegte Teil, und er ist der Grund, warum der Screen existiert.

**Die Ersatz-Rahmung ist Empfehlung 1.2 der Engagement-Recherche (nicht Teil dieses Exports) ohne deren bewertende Hälfte.** Deci-Triade: Grund anerkennen, Wahlfreiheit betonen — aber **keine Frage**, denn eine Frage an dieser Stelle wäre der rückblickend-bewertende Prompt, der im Feldexperiment messbar Scham erhöht hat (dort §1.3), und Scham ist der Mechanismus, den G4 ablehnt. Die volle Umsetzung von dort §1.4 (If-Then-Plan im Onboarding, wiederholt auf dem Morgen-Screen) ist damit **nicht** gebaut — das ist ein eigenes Feature, und dieser Eintrag hält fest, dass es offen bleibt und nicht etwa hier erledigt wurde.

**Die Recherche bleibt gültig, nur der Verwendungsort fällt weg.** Die Faktenrecherche (nicht Teil dieses Exports) ist unverändert: sieben kuratierte Fakten mit Autor, Jahr, Link und Konfidenz. Sie gehören auf eine externe Webseite, wo jemand sie **aufsucht**, statt in einen Moment, in dem jemand bereits entschieden hat, dass er etwas braucht. Die sieben Katalog-Einträge sind aus `Tuck/Localizable.xcstrings` entfernt, weil nichts mehr auf sie zeigt — sonst wären es sieben tote Übersetzungen im Substrat.

**Tests: gleiche Garantien, neuer Gegenstand.** Die drei Pool-Tests sind ersetzt, nicht gestrichen — `everyReasonHasItsOwnLineAndTheLineNamesThatReason` (drei verschiedene Zeilen, jede nennt ihren Grund), `noReflectionAddressesTheReaderOrRaisesItsVoice` (dieselbe Vokabel-Sperre wie vorher, plus Fragezeichen-Verbot), `noReflectionJudgesTheReasonOrClaimsProof` (kein „beweist", kein „gerechtfertigt", kein „trotzdem"). In der zweiten Sprache prüft `noEnglishReconsiderLineAddressesOrJudgesTheReader` dasselbe **und zusätzlich, dass die englische Zeile den übersetzten Grund weiterhin nennt** — eine Übersetzung, die das Grundwort verliert, ist kein Spiegel mehr, sondern ein Allgemeinplatz, und genau das würde ein reiner Vorhandenseins-Test durchlassen. Zwei Tests wurden umbenannt, weil ihr Name den verschwundenen Button zitierte (`theUnlockAnywayBranch…` → `theUnlockBranch…`); die Belegstelle im Eintrag vom 2026-09-06 ist nachgezogen.

**Verifikation.** Suite auf `OS=26.5,name=iPhone 17`: **369 Tests in 52 Suites, 0 Failures, 0 Skips** — unverändert zur Referenz, weil vier Tests ersetzt und keine hinzugekommen sind. `xcodegen generate` war nicht nötig (keine neue oder gelöschte Quelldatei).

## 2026-09-07 — Vier Statuszeilen, die wie ein Formular klangen

**Anlass:** Wholesome-Leitbild-Audit vom 2026-09-07. Reine Copy-Runde, kein Verhaltens- und kein Architektur-Eingriff — kein Aufruf, kein Zustand und kein Zeitpunkt hat sich geändert, nur was auf vier Zeilen steht.

**Der Befund in einem Satz:** an vier Stellen sprach nicht die App, sondern ihre Buchhaltung. `"nicht gesetzt"` ist ein leeres Datenbankfeld, `"Wird geprüft …"` eine Vorgangsmeldung im Passiv, `"Warte auf iOS …"` die App, die sich beim Warten selbst zusieht — und der Fehlersatz klebte rohen SDK-Text mit einem Doppelpunkt an seinen eigenen Satz, sodass die App den technischen String im eigenen Mund führte. Alle vier waren regelkonform: kein Ausrufezeichen, keine Übertreibung, nichts Unwahres. Das ist derselbe Fundtyp wie am Vormittag beim Reconsider-Screen — eine Regel, die Wörter verbietet, prüft nicht das Register.

**Was jetzt dasteht (alt → neu, DE / EN):**
- `StatusCopy.unsetValue`: „nicht gesetzt" → **„noch offen"** / „not set" → **„not chosen yet"**. Damit stehen beide Platzhalter der Formregel aus §5.4 in derselben „noch …"-Form; die Regel selbst (Einzelwert gegen Anzahl) bleibt unverändert.
- Der unbeantwortete Abo-Zustand (`PaywallView.statusTitle`, `SettingsView.subscriptionValue`, eine Copy für beide): „Wird geprüft …" → **„Noch keine Antwort"** / „Checking …" → **„No answer yet"**. Genauer und nicht nur wärmer: die App prüft dort nichts, es ist bloß noch nichts von StoreKit zurückgekommen. Der Detailsatz darunter („Solange das offen ist, ändert sich nichts an deinem Zugang.") nimmt das Wort schon vorher auf.
- `StatusCopy.waitingForSystem`: „Warte auf iOS …" → **„Einen Moment, iOS ist noch dran."** / „Waiting for iOS …" → **„One moment, iOS is still on it."**. iOS bleibt benannt, weil es der ehrliche Grund für das Warten ist (G3).
- `StatusCopy.failure(subject:verb:reason:)`: „«X» ließ sich gerade nicht «Y»: \(reason)" → **„«X» ließ sich gerade nicht «Y». Das sagt iOS dazu: \(reason)"** / „… just now: \(reason)" → **„… just now. This is what iOS says: \(reason)"**.

**Der Fehlersatz ist der interessante Fall, weil sein hässlicher Teil nicht verhandelbar ist.** `reason` ist an allen vier Aufrufstellen roher SDK-Text (AlarmKit, DeviceActivity, `AuthorizationCenter` — immer iOS), und G3 verbietet, ihn zu verstecken oder zu glätten: er ist das einzig Handlungsrelevante an der Zeile. Geändert ist deshalb nicht der Text, sondern seine **Zuschreibung**: der Doppelpunkt hinter dem Verb ist ein Punkt, und der Grund steht hinter einem Rahmen, der ihn als Fremdaussage ausweist. Der Satz der App bleibt warm, der Satz von iOS bleibt wörtlich, und die Zeile behauptet nicht mehr, beides käme aus demselben Mund. Der Grund steht weiterhin am Ende und ungekürzt — als Test gepinnt, damit eine spätere Runde ihn nicht „aufräumt".

**Nicht angefasst, bewusst:** die Berechtigungs-Sackgassen („Zugriff ist abgelehnt.", „Wecker-Erlaubnis ist aus.") und die Settings-Abschnittsköpfe („Freischaltungen", „Entwickler") — Label-Fragen mit eigener Abwägung, aus derselben Audit-Liste, aber nicht aus dieser Runde. *(Nachgeholt am selben Tag — bis auf „Entwickler", siehe den Eintrag unten.)* Ebenfalls stehen geblieben: `StatusCopy.emptyCount` („noch keine") — es war nie das Problem und ist die Vokabel, an der sich die drei anderen jetzt ausrichten — sowie „Preis wird geladen …" im Paywall-Button, das eine Aktion und keinen Zustand beschreibt. Mascot-Meilensteine, Fortschrittsring, Verhalten und Architektur: unberührt.

**Tests: drei neue, zwei nachgezogen.** Neu sind `StatusCopyTests.noStatusLineReadsLikeAFormField` und `EnglishLocalizationTests.noEnglishStatusLineReadsLikeAFormField` — sie sperren das **Register** („nicht gesetzt", „Warte auf", „wird geprüft", „Fehler", „ungültig" bzw. „not set", „waiting for", „error", „invalid") statt nur den Satz zu pinnen, weil der Rückfall genau über diese Wörter käme; dazu `theFailureLineQuotesTheSystemInsteadOfSpeakingItsWords` (zwei Sätze, kein Doppelpunkt hinter dem Verb, Grund unverändert am Ende). Nachgezogen: `eachAbsencePlaceholderKeepsTheFormOfTheValueItReplaces`, `everyFailureReadsTheSameWayAndCarriesItsReason`, `bothAbsencePlaceholdersStayDistinctInEnglish`, `theCheckingStateIsOneLineForBothScreens` (prüft jetzt den englischen Wortlaut statt nur dessen Existenz) und `theEnglishFailureFrameReadsAsOneSentence`.

**Verifikation.** Suite auf `OS=26.5,name=iPhone 17`: **372 Tests in 52 Suites, 0 Failures, 0 Skips** (369 + 3 neue). Vier Katalog-Schlüssel sind umbenannt statt dupliziert, in beiden Sprachen vollständig — kein toter Eintrag bleibt zurück. `xcodegen generate` war nicht nötig (keine neue oder gelöschte Quelldatei).

---

## 2026-09-07 — Die drei Label-Fragen, die die Statuszeilen-Runde liegen ließ

**Anlass:** Wholesome-Leitbild-Audit vom 2026-09-07, dritte Runde des Tages. Wieder reine Copy: kein Aufruf, kein Zustand, kein Zeitpunkt, keine Datei mehr und keine weniger — nur Wortlaut, dazu vier umbenannte Katalog-Schlüssel und ein neuer.

**Der Befund in einem Satz:** eine Vokabel, die das Produkt ausdrücklich ausschließt, stand als Label im Bestand, und zwei Sackgassen sprachen im Register einer Fehlermeldung. Alle drei waren regelkonform — dieselbe Sorte Fund wie am Vormittag: eine Regel, die Behauptungen verbietet, prüft nicht die Wortwahl.

**Was jetzt dasteht (alt → neu, DE / EN):**

- **Die Meilenstein-Marken** (`SettingsView.badgeRow`): „Abzeichen" → **„Blätter"** / „Badges" → **„Leaves"**. „Abzeichen" ist wörtlich die Trophäen-Vokabel, die G4 ausschließt, auf einer Zeile, die nichts freischaltet, nichts gated und von nichts gelesen wird. Das neue Wort ist nicht erfunden, sondern das der Feier-Zeile, die es seit dem Meilenstein-Bau ohnehin spricht („Ein Blatt für unseren Weg.") — und das des Glyphs daneben (`leaf.fill`). Damit nennen Blase, Glyph und Zeile dasselbe Ding gleich. Die Swift-Namen (`MascotBadge`, `badgeRow`, `unlockedBadges`) bleiben, wie sie sind: sie sind Identität im Store, kein Bildschirmtext, und ein Rename hätte die Persistenzschlüssel angefasst.
- **Family-Controls-Sackgasse** (`AccessAndAppSelectionView.statusLine`): „Zugriff ist abgelehnt. Du kannst ihn in den Systemeinstellungen wieder geben — bis dahin bleiben die Apps offen." → **„Der Zugriff fehlt noch. Du kannst ihn in den Systemeinstellungen geben — bis dahin bleiben die Apps offen."** / „Access is denied. You can grant it again in the Settings app — until then the apps stay open." → **„Access is still missing. You can grant it in the Settings app — until then the apps stay open."**
- **Wecker-Sackgasse** (`WakeAlarmSetupView.permissionDeniedLine`): „Wecker-Erlaubnis ist aus. Du kannst sie in den Systemeinstellungen wieder geben — ohne sie weckt Tuck dich nicht." → **„Die Erlaubnis für den Wecker fehlt noch. Du kannst sie in den Systemeinstellungen geben — ohne sie weckt Tuck dich nicht."** / „Alarm permission is off. You can give it again in the Settings app — without it Tuck does not wake you." → **„The alarm permission is still missing. You can grant it in the Settings app — without it Tuck does not wake you."**
- **Abschnittskopf „Zeiten"**: → **„Deine Zeiten"** / „Times" → **„Your times"**. Dieselbe Possessiv-Form, die „Dein Weg" und „Dein Tuck" im selben Screen tragen, und dieselbe Aussage wie der Zweck-Absatz am Ende („Zwei Zeiten am Tag sollen dir gehören").
- **Abschnittskopf „Freischaltungen"**: → **„Wenn es doch mal nötig ist"** / „Unlocks" → **„When you really need to get in"**. Der Kopf benennt jetzt den Fall statt des Mechanismus. Der Schlüssel „Freischaltungen" bleibt trotzdem im Katalog — er ist weiter der Titel des Paywall-Screens, und dort ist der Mechanismus tatsächlich der Gegenstand.

**Die beiden Sackgassen sind ein Fund, nicht zwei.** Beide waren G3-konform und schuldfrei; was sie trennt, ist die Reihenfolge: „ist abgelehnt" / „ist aus" beginnt mit dem Urteil über eine frühere Entscheidung des Nutzers, „fehlt noch" beginnt mit dem, was handlungsrelevant ist. Der Rest des Satzes ist unverändert — Zustand, Weg zu den Systemeinstellungen, ehrliche Folge, alle drei Teile stehen vollständig da (§8 A14). „fehlt noch" ist außerdem die Form, an die sich am selben Tag schon `StatusCopy.unsetValue` („noch offen") und die Antwort-Zeile („Noch keine Antwort") angeglichen haben: was fehlt, steht aus.

**Warum „Blätter" und nicht „Besonderheiten".** Beide erfüllen die Vorgabe (warm, nicht spielerisch), aber „Besonderheiten" wäre ein neues Wort für eine Sache, die in der App schon eines hat. „Blatt" steht seit dem Meilenstein-Bau in zwei der sieben Feier-Zeilen und als Glyph in der Zeile selbst — die Umbenennung fügt damit nichts hinzu, sie räumt eine zweite Vokabel weg. Preis, offen benannt: „Blätter" ist als Zeilentitel poetischer und weniger selbsterklärend als „Abzeichen"; das ist auf einer Zeile, die nichts tut und die nur sieht, wer 90 Morgen hinter sich hat, der bessere Handel.

**Nicht angefasst, bewusst:** „Entwickler" / „Entwickler-Status" (nur im `#if DEBUG`-Build, kein Nutzerpfad — technisch soll technisch bleiben), „Morgenfenster" und „Apps" (Namen von Dingen, kein Register-Problem; „Apps" steht ohnehin über der Zeile „Apps, die warten", die die Wärme trägt), der Paywall-Titel „Freischaltungen" und jede Zeile, die eine Zahl, einen Zustand oder eine Sperre beschreibt. Verhalten, Architektur, Persistenz, Mascot-Mechanik: unberührt.

**Tests: zwei neue, drei nachgezogen.** Neu sind `EnglishLocalizationTests.neitherPermissionDeadEndOpensOnAVerdict` (pinnt das **Register** in beiden Sprachen: „fehlt noch" / „still missing" muss dastehen, „abgelehnt"/„verweigert"/„ist aus" bzw. „denied"/„refused"/„is off"/„failed" dürfen es nicht — der Rückfall käme genau über diese Wörter) und `.theMarkerRowIsNamedAfterTheCelebrationRatherThanAfterATrophy` (kein „badge"/„trophy"/„achievement"/„award" im Titel, kein „Abzeichen"-Schlüssel mehr im Katalog, und der Titel muss das Wort der Feier-Zeile sein). Dazu `.theSettingsSectionHeadsCarryTheSameWarmthAsTheirFooters`, das den neuen Kopf gegen Verkaufsvokabeln hält und den Paywall-Titel als bewusst stehengebliebenen Schlüssel festhält. Nachgezogen: `thePermissionLinesNameTheSystemSettingsRatherThanTheAppsOwnScreen`, `theAlarmDenialPromisesNoProgressInEitherHost`, `theDeniedAccessLineDescribesTheStateWithoutPromisingABlock` — die drei trugen je eine eigene Kopie der beiden Sätze, jetzt lesen sie zwei Konstanten.

**Verifikation.** Suite auf `OS=26.5,name=iPhone 17`: **375 Tests in 52 Suites, 0 Failures, 0 Skips.** Vier Katalog-Schlüssel umbenannt statt dupliziert, einer neu, in beiden Sprachen vollständig — kein toter Eintrag bleibt zurück. `xcodegen generate` war nicht nötig (keine neue oder gelöschte Quelldatei). **Verifiziert in einer sauberen, separaten Arbeitskopie auf diesem Stand:** im Hauptbaum lag zur selben Zeit noch nicht ins Projekt aufgenommene Arbeit (`Tuck/MascotSurfaces.swift`), an der der Build unabhängig von dieser Runde scheiterte.

## 2026-09-07 — Ein reicheres Rig als Zwischenschritt, und das erste App-Icon

**Anlass:** Wholesome-Leitbild-Audit vom 2026-09-07, zwei freigegebene Punkte in einem Durchgang. Erster Punkt: das Mascot war seit dem Scaffold eine flache Zwei-Stopp-`LinearGradient` mit einem Glanzlicht. Zweiter Punkt: der 1024er-Slot in `AppIcon.appiconset/Contents.json` hatte **kein `filename`** — die App hatte kein Icon, seit es sie gibt.

**Die Entscheidung hinter Punkt 1, damit sie nicht verlorengeht.** Kein echter Illustrator, noch nicht (offene Fragen, nicht Teil dieses Exports). Statt darauf zu warten: eine spürbar reichere Code-Fassung als **Zwischenschritt**, ehrlich als das, was sie ist — SwiftUI-Formen, keine Illustration. Sie ersetzt keine Illustration und nimmt ihr nichts vorweg.

**Was gebaut wurde.** `Tuck/MascotSurfaces.swift`, fünf palettenfreie Bausteine (`MascotBodySurface`, `MascotEarSurface`, `MascotEarRootShadow`, `MascotCheek`, `MascotContactShadow`) plus `MascotGrain`. Vollständig beschrieben in `docs/design/design-system.md` §5.10.1. Kurz: mehrschichtige Radial-/Linearverläufe statt zwei Stopps, Ambient-Occlusion an Ohransatz und Boden, warmes Bounce-Light vom Untergrund, zweilagige Wangen, zweilagiger Fußschatten, feines deterministisches Korn.

**Warum die Datei kein einziges Palette-Token nennt.** Sie wird von zwei Zielen kompiliert: vom App-Target und von `tools/render-app-icon.sh` für macOS. Jede Farbe kommt als Parameter herein. Das ist derselbe Schnitt, aus dem `ShieldMascotIcon` `Color.LightPalette` liest (§2.5) — und der Grund, warum das Icon die Schattierung der App **teilt** statt sie zum dritten Mal abzuschreiben.

**Was ausdrücklich nicht angefasst wurde:** die Palette, die Proportionen und die Silhouette, die Stufen-Tokens (`saturation`, `scale`, `eyesOpen`, `cheekOpacity`, Sprosse) und **jede Zeile** Animations-, Idle-, Tap- und Reduce-Motion-Logik. Es ist eine Verfeinerung der Darstellung einer Pose, kein Eingriff ins Verhalten. `TuckShield/ShieldMascotIcon.swift` bleibt flach: **A13 sagt „erwähnen, nicht eigenmächtig zusammenlegen"**, also ist die Shield-Zeichnung ab heute sichtbar schlichter als die App-Zeichnung — eine benannte offene Kante, keine Drift.

**Punkt 2, das Icon.** `tools/AppIconComposition.swift` + `tools/render-app-icon.sh`/`.swift`, nach dem Muster von `render-shield-mascot.sh` gebaut und nicht neu erfunden; `Contents.json` trägt jetzt `"filename" : "AppIcon.png"`, das echte PNG liegt im Repo. Details in §5.10.2. Drei Punkte, die dort nicht offensichtlich sind:
- **Der Alphakanal muss weg.** `ImageRenderer` liefert immer Alpha, und ein App-Icon mit Alphakanal wird beim Upload abgelehnt, auch bei durchgehend deckenden Pixeln. Der Renderer zeichnet deshalb in einen `CGContext` mit `noneSkipLast` um. Das war das eine technische Hindernis dieser Runde und es ist behoben, nicht umgangen.
- **256 pt bei `scale = 4`, nicht 160 pt bei 6,4×.** Sonst skaliert das Korn mit und wird zu Flecken. Erste Fassung hatte 200 grobe Punkte bei 0,05 Deckkraft und sah genau so aus; 900 feine Punkte bei 0,03 lesen sich als Textur.
- **Der Icon-Hintergrund weicht bewusst von der Bildschirm-Optik ab.** Salbei auf Cream liegt im „wenig Kontrast"-Band der Palette — auf einem Screen richtig, für ein 40-px-Homescreen-Icon zu schwach. Der Verlauf startet oben deshalb auf **Dawn Shadow**, einem bestehenden abgeleiteten Ton, nicht auf einem neuen Wert.

**Verifikation.** `xcodebuild build` auf `OS=26.5,name=iPhone 17` grün; `assetutil` bestätigt `AppIcon.png` im gebauten `Assets.car` samt der von `actool` abgeleiteten Größen. Suite: **376 Tests in 53 Suites, 0 Failures, 0 Skips** — 375 vorgefunden plus ein neuer. `xcodegen generate` war nötig (zwei neue Quelldateien im Projekt).

**Eine Zahl stimmt im Eintrag darüber nicht.** Der Eintrag vom Vormittag nennt 372 Tests; gemessen wurden vor dieser Runde **375**, ohne dass zwischendurch Tests hinzugekommen wären. Die Differenz ist hier festgehalten statt stillschweigend übernommen — der Eintrag oben bleibt unverändert, weil er den Stand seiner eigenen Runde beschreibt.

**Neu im Testbestand:** `AppIconAssetTests.theAppIconIsSquareAtFullSizeAndCarriesNoTransparency` — der eine Fehler an diesem Asset, den weder der Build noch das Auge fängt. Er liest über `#filePath` die **eingecheckte** Datei, nicht die gebaute: `actool` backt daraus flache Größen (`AppIcon60x60@2x.png`), hochgeladen wird aber die eingecheckte, und nur deren Alphakanal entscheidet. Für die Schattierung selbst gibt es keinen Test und kann es keinen geben, der etwas wert wäre — sie ist visuell und wird visuell abgenommen.

## 2026-09-07 (nachmittags) — Das Icon wird kräftig genug für einen Homescreen

**Anlass:** Sichtprüfung des vormittags gebauten App-Icons durch den Projektinhaber. Am 1024er-Bild sah es stimmig aus; als Homescreen-Icon bei 40–60 px zwischen fremden, meist kräftigen Icons verschwamm der helle Salbei-Körper mit dem hellen Dawn-Shadow→Cream-Verlauf. Lesbar blieben Augen und Mund, sonst nichts. Der Befund ist berechtigt und war am großen Bild nicht zu sehen — deshalb steht er hier.

**Zwei Änderungen, beide nur am Icon.**
- **Hintergrund: voll Charcoal Green statt heller Verlauf.** Heller Körper auf dunklem Grund, das gängige und tragfähige Icon-Muster. `#6B7A6E` ist der dunkelste Wert der hellen Palettenhälfte, der Körper steht darauf bei **3,40:1** — dasselbe Paar wie der deaktivierte Button (§5.3), kein neuer Farbwert. Dazu ein Radialverlauf, der den Grund hinter der Schulter um 12 % Richtung Salbei anhebt, damit die Fläche ein Raum ist und keine Platte.
- **Kontur kräftiger: 0,55 Tinte bei 2,5 pt am Körper, 0,55 bei 1,5 pt an den Ohren.** Damit die Silhouette auch ohne Hintergrund-Kontrast für sich steht.

**Die Gegenprobe wurde gerendert, nicht behauptet.** Zweite Variante (volles Salbei als Grund) gebaut, auf 60 px heruntergerechnet und nebeneinander verglichen. Sie verliert klar: Körper und Grund sind derselbe Ton, es trennt sie nur die Kontur, und das Mascot liest als gezeichnete Linie statt als Form. Die Wahl ist damit gemessen, nicht geraten.

**Wie die Kontur ohne Duplikat-Drift stärker wurde.** `MascotBodySurface`/`MascotEarSurface` haben jetzt `outlineInk`/`outlineWidth`. **Die Defaults sind der Bildschirm-Stand und byte-identisch zu vorher** — nur `tools/AppIconComposition.swift` überschreibt sie. Kein zweites Rig, keine kopierte Zeichnung. Das In-App-Mascot ist unverändert; **G1 gilt auf dem Schirm weiter**, das Icon ist der eine Ort, an dem laut zu sein die richtige Antwort ist, weil es gegen fremde Icons antritt und nicht gegen die eigene Seite.

**Was nicht angefasst wurde:** Proportionen, Silhouette, Gesicht, Schattierung, Korn, Stufen-Wahl, die Palette selbst, jede Zeile Animations-/Idle-/Tap-Logik, `ShieldMascotIcon.swift` (A13 gilt weiter). Der Alphakanal ist weiterhin plattgemacht.

**Verifikation.** `xcodebuild build` grün. Suite auf `OS=26.5,name=iPhone 17`: **376 Tests in 53 Suites, 0 Failures, 0 Skips** — unverändert zur Vormittagsrunde. `AppIconAssetTests` blieb ohne Anpassung grün: er pinnt Kantenlänge und Alphakanal, keine Farbwerte — genau deshalb übersteht er eine Umfärbung. `xcodegen generate` war nicht nötig (keine neue Quelldatei). Das Ergebnis ist visuell abgenommen, bei 1024 px und heruntergerechnet auf 60 px; für die Optik selbst gibt es weiterhin keinen Test, der etwas wert wäre.

## 2026-09-07 (abends) — Der abgeschlossene Morgen antwortet sofort

**Anlass:** eine Gestaltungsvorgabe vom 2026-09-07. Der Moment, in dem ein Morgen abgeschlossen ist — Wecker aus, kein TikTok, kein Instagram — soll sich sofort und warm anfühlen. Die Norm, unter der das gebaut wurde: unmittelbare Belohnung am Ereignis, nie am Dauerdisplay, nie zufällig, nie mit Verlust gekoppelt. Ausdrücklich nicht die Mechanik der Apps, gegen die diese App gebaut ist.

**Der Befund vor dem Bau.** Die Feier hing vollständig am Stufenwechsel (`MascotStage.ringSweepsOnStageChange`), und der passiert zweimal: Morgen 7 und Morgen 30. An jedem anderen Morgen stand der Ring beim Öffnen bereits auf seinem neuen Wert. Der Kaltstart — der Pfad, der real trägt, weil der Wecker abgeschaltet wird, während die App nicht vorn ist — konnte es gar nicht anders: `ringTrimEnd` wurde aus dem schon erhöhten Zähler initialisiert, es gab keinen alten Wert mehr, von dem aus sich animieren ließe. Der Vordergrund-Pfad hatte immerhin 1,4 s Trim-Änderung über einen Siebtel- bzw. Dreiundzwanzigstel-Bogen — ohne Aufblühen, ohne Reaktion des Tiers.

**Gebaut** (`docs/design/design-system.md` §6.6 ist die ausführliche Fassung): ein Ring, der jeden gezählten Morgen von dem Stand losläuft, den der Nutzer zuletzt gesehen hat (1,1 s `easeOut`, Strich für gut zwei Sekunden heller und dicker), plus **eine** Freude-Geste des Tiers aus dem bestehenden Tap-Repertoire — Wangen warm, Lächel-Squint, kurzes Anheben mit Ohren-Flare. Danach ist der Screen wieder still.

**Drei Entscheidungen, die keine Formulierung sind.**
- **Die Reaktion hängt am Morgen, nicht am Ring.** Ab Morgen 30 ist der Ring dauerhaft voll. Hinge sie am Ring, hörte sie ausgerechnet bei den längsten Nutzern auf. Die Trim-Animation läuft dann ins Leere, das Aufblühen und die Geste kommen unverändert.
- **Der Ring muss sich merken, was er schon gezeigt hat.** Neuer Store-Slot `acknowledgedMornings` (App-Group, Ratsche wie `MilestoneStore`, nur aufwärts), bewusst `Int?`: ein Bestandsinstall mit vierzig Morgen hat keine Aufzeichnung darüber und würde sonst vierzig Morgen auf einmal feiern. `nil` → nichts, und quittiert wird beim ersten Blick.
- **Der Ring startet sofort, das Tier wartet auf seine Entrance.** Beim Kaltstart schläft es noch; ein strahlendes Gesicht hinter geschlossenen Augen ist kein Wärmesignal, sondern ein Glitch. Der Beat wird gepuffert und in dem Moment ausgelöst, in dem die Entrance übergibt — dieselbe Stelle, an der der Eingangsgruß spricht.

**G4 vollständig, und zwar geprüft statt behauptet.** Kein Zufallselement, auch nicht in der Auswahl der Geste (es gibt genau eine). Keine Zahl, keine Frist, kein Countdown. An einem ausgelassenen Morgen passiert weiterhin gar nichts. Ein zurückgefallener Zähler ist kein Ereignis, sondern `.none` — weder Feier noch Fehlstelle; dieselbe Ratschen-Logik, die `MilestoneStore` benutzt, hier gegen die Doppelfeier statt gegen den Rückschritt.

**G5 ohne Bedeutungsverlust.** Unter Reduce Motion landet der Trim ohne Reise auf dem neuen Wert, das Aufblühen bleibt — die Skalierung des Rings wird gepinnt, sie war die einzige der drei Achsen, die Bewegung ist (Deckkraft und Strichstärke sind es nicht). Die Freude-Geste hat kein eigenes Gate: was übrig bleibt, wenn `tapScale` und `earFlare` an den bestehenden Pins hängen, sind wärmere Wangen und gefaltete Augen — Formwechsel, keine Bewegung (§8 A17). Dass kein Zustand zu Schweigen wird, hält ein eigener Test fest, nicht ein Kommentar.

**Was nicht angefasst wurde:** die Copy (keine einzige neue Zeile, keine Katalog-Änderung), die Sprechblase und ihre zwei Besitzer (Gruß, Meilenstein), der Stufenwechsel-Sweep selbst, die Palette, das Rig, jede andere Fläche der App. Der Stufenwechsel bekommt allerdings eine echte Ergänzung: beim Kaltstart lief bisher weder Sweep noch Bloom, weil `stage` als State nie wechselte — jetzt löst derselbe Pfad beides aus.

**Verifikation.** `xcodegen generate` (eine neue Quelldatei), `xcodebuild build` grün. Suite auf `OS=26.5,name=iPhone 17`: **392 Tests in 54 Suites, 0 Failures, 0 Skips** (vorher 376/53; 16 neue in `MorningCelebrationTests`). Die neue Suite pinnt die Auslöse-Matrix, die Ratsche, den `nil`-Fall des Bestandsinstalls, den Rückwärts-Zähler, die Reduce-Motion-Abbildung und — erschöpfend über alle Paare 0…60 — dass eine Füllung nie rückwärts läuft.

**Offen:** Die Optik selbst ist nicht im Simulator abgenommen worden, nur die Logik. Was ein Test hier nicht kann, kann er auch bei jeder anderen Animation dieser App nicht; die Werte sind bewusst aus dem Bestand übernommen (Federparameter des Taps, Aufblühen des Sweeps) statt neu erfunden. Ein Sicht-Durchgang bei nächster Gelegenheit ist trotzdem angeraten. Die naheliegende Kollision ist nachgerechnet und keine: beim Kaltstart liegt der erste Idle-Zug 3,5–7 s nach der Entrance, die Geste dauert 1,5 s. Auf dem Vordergrund-Pfad läuft die Idle-Schleife bereits, und ein gleichzeitig gezogenes Gähnen könnte die Wangen früher löschen — dieselbe Klasse von Überlappung, die der Tap-Pfad seit jeher hat, und sie kostet Wärme, nie Bedeutung.

### Nachtrag 2026-09-07 (Prüfdurchgang) — der Stufenwechsel-Morgen unter Reduce Motion

**Quelle:** konsolidierter Prüfdurchgang 2026-09-07 über das oben gebaute Feature. Ein HIGH, drei Doku-Funde.

**Der HIGH.** Genau der Fall, den der Eintrag darüber als geschlossen führt („jetzt löst derselbe Pfad beides aus"), war unter Reduce Motion offen. `celebrateStageChange()` stand *im* `.sweep`-Zweig des Präsentations-Switch, und unter Reduce Motion ist die Präsentation `.flourishOnly`. Ablauf: Reduce Motion an, Kaltstart, Morgen 7. Der Trim landet ohne Reise auf `progressTowardNext(7)` — an der Schwelle **0**, also auf einem leeren Bogen; das Aufblühen brightet einen Ring der Länge 0, was nachgemessen (`ImageRenderer`) null sichtbare Pixel ergibt; und der Bloom feuert nicht, weil `stage` beim Kaltstart schon im View-Init auf dem neuen Wert steht und `.onChange(of: stage)` deshalb nie läuft — genau die Lücke, die der `.sweep`-Zweig mit seinem expliziten Aufruf schloss. Sichtbar blieb: ein leerer Ring und sonst nichts, am Morgen mit dem meisten Gewicht. Das liest sich als Verlust und ist damit der exakte Anti-Fall der Norm, unter der das Feature gebaut wurde („nie mit Verlust gekoppelt"), und ein G5-Verstoß dazu.

**Der Fix.** Der Bloom-Aufruf steht jetzt **außerhalb** des Switch und hängt an der Ursache statt an einer Darstellung: `if kind == .stageSweep { celebrateStageChange() }`. Nicht dupliziert in den `.flourishOnly`-Zweig — die Kopplung an einen einzelnen Zweig war der Fehler, nicht seine Belegung. `.fill` bleibt bloomfrei: ohne Stufenwechsel wäre das Licht unmotiviert. Auf dem Vordergrund-Pfad feuern `.onChange(of: stage)` und dieser Aufruf im selben Update, der zweite Task canceled den ersten — ein Bloom wie bisher.

**Der Test.** `MorningCelebrationTests.reduceMotionNeverTurnsAReactionIntoSilence` deckte den Fehler nicht ab: er prüft die reine Präsentations-Funktion, und die war korrekt — falsch war die Verdrahtung. Neue Suite `MorningCelebrationWiringTests` mit zwei Tests: einer über die pure Entscheidung des Szenarios (Morgen 7, Reduce Motion → `.stageSweep`/`.flourishOnly`, Ring von ~0,86 auf 0), einer über die Verdrahtung selbst — er liest `GutenMorgenView.swift` über `#filePath` (dieselbe Technik wie `AppIconAssetTests`, weil die Reaktion in `@State` lebt, den nur eine gerenderte View bewegt) und hält fest, dass der Bloom-Aufruf hinter dem Switch steht und an `.stageSweep` hängt. Gegengeprüft: gegen den alten Stand der View ist er rot (zwei Issues), gegen den neuen grün.

**Drei Doku-Funde, mitbehoben.**
- §8: die Liste der bewusst ungegateten Reduce-Motion-Stellen — Falsch-Positiv-Schutz für künftige Audits — nannte zwei, es sind seit dem Morgen-Abschluss **vier**: `MascotView.beam()` und `GutenMorgenView.flourishRing()` fehlten. Wer sie „repariert", macht die Reaktion unter Reduce Motion stumm; das ist der teuerste der drei Funde, weil er einen späteren Auditor in einen echten G5-Verstoß geführt hätte.
- §6-Kopf: „44 `duration:`-Literale" → **63** (`grep -o "duration: [0-9.]*"` über App- und Extension-Quellen).
- §8: Zeilenanker des Bloom-Pins `GutenMorgenView.swift:43,45` → `:44,46`. Dieselbe Drift-Klasse wie A30, dieselbe Lehre: Zeilennummern in Prosa wandern nicht mit.

**Verifikation.** `xcodegen generate` (eine neue Quelldatei), Suite auf `OS=26.5,name=iPhone 17`: **394 Tests in 55 Suites, 0 Failures, 0 Skips** (vorher 392/54).

**Offen bleibt** dasselbe wie oben: die Optik ist weiterhin nicht im Simulator abgenommen. Der Prüfdurchgang hat die Null-Pixel-Aussage per `ImageRenderer` nachgemessen, nicht am laufenden Screen — die Konsequenz (Bloom trägt den Moment) ist Logik, kein Sicht-Durchgang.

## 2026-09-09 — Jahrespreis 29,99 €

**Quelle:** Entscheidung des Projektinhabers.

**Die Änderung.** Genau eine Zahl: `Tuck.storekit`, `com.example.tuck.plus.yearly`, `displayPrice` von `19.99` auf `29.99`. Der Monatspreis (3,99 €, `…plus.monthly`) bleibt. Damit fällt der Jahresrabatt gegenüber zwölf Monatszahlungen von 58 % auf 37 % — bei 19,99 € war das Monatsabo faktisch entwertet, und der Ankerpreis der einzigen bezahlten Stufe lag unter dem, was sie trägt.

**Warum der Code nichts merkt.** `PaywallView` rendert ausschließlich `product.displayPrice` (`:259`, `:260`) und trägt seit dem Bau die Notiz, dass eine hartkodierte Zahl an dieser Stelle falsch wäre. Kein Test pinnt einen Preis, keine Swift-Datei nennt einen. Der einzige Ort, an dem die alte Zahl im Repo stand, war Prosa.

**Prosa nachgezogen:** die ursprüngliche Produktspezifikation (2×), `docs/product-decisions-2026-09-02.md` (B7-Kaufoptionen plus ein datierter Absatz zur Begründung), die offenen Fragen und die Engagement-Recherche (beide nicht Teil dieses Exports).

**Eine Korrektur an der Prämisse.** Der Store-Metadaten-Entwurf (nicht Teil dieses Exports) war als „nennt keine Preise" geführt und ist das für die Store-Texte auch — die Abo-Absätze sind preisfrei geschrieben, genau damit dieser Tag sie nicht falsch macht. Die *Begründung* dieser Entscheidung zitierte die konkreten Zahlen aber selbst und wäre stehen geblieben als einzige veraltete Preisangabe im Repo. Die Zeile ist deshalb mitgezogen, ohne dass eine Zeile Store-Copy angefasst wurde.

## 2026-09-09 — Der Trial startet, wo das Produkt nein sagt

**Quelle:** Entscheidung des Projektinhabers.

**Was falsch war.** Die 14 Tage liefen ab `.task { TrialStore.startIfNeeded() }` in `TuckApp` — ab dem ersten App-Start. Der Kommentar dort verteidigte das ausdrücklich („somebody who abandons onboarding halfway has still had the app"), und genau das ist der Fehler: die Testphase existiert, um ein Argument zu machen, und sie lief bei Leuten ab, die das Argument nie gehört hatten. Wer die App öffnet, die Screen-Time-Abfrage ablehnt und drei Wochen später wiederkommt, hatte einen abgelaufenen Trial und nie einen Sperrbildschirm gesehen.

**Die Trigger-Frage, und warum die Antwort zwei Stellen sind.** Vorgeschlagen war ein Auslöser: das Bettzeit-Setup. Der Bestand widerlegt das. Plus hat **zwei** Grenzen — das Abendfenster und das Tageslimit für Freischaltungen — und `PaywallView` wirbt in ihrer ersten Zeile mit dem Limit (`capabilityLine("Freischaltungen ohne Tageslimit")`, `:127`), das Abendfenster kommt danach. Ein Nutzer, der nur wegen des Limits an die Grenze stößt und den Bettzeit-Screen nie öffnet, hätte unter dem Ein-Trigger-Entwurf **nie** einen Trial bekommen: dauerhaft 1 Freischaltung/Tag, während `SettingsView` und `PaywallView` weiter eine Testphase beschreiben, die er nicht mehr erreichen kann. Beide Grenzen lösen deshalb aus, über eine gemeinsame Funktion (`TrialTrigger.plusBoundaryReached`), damit die Regel einen Ort hat statt zwei Meinungen.

**Zwei Feinheiten, die der Bestand vorgab, nicht die Wahl:**
- **Bettzeit: Ankunft, nicht der Tap auf „Bettzeit setzen".** Der Picker liegt hinter dem Gate — ein Auslöser auf die Handlung könnte nie feuern, weil ohne Zugang niemand den Knopf erreicht, der den Zugang gäbe. Gelesen wird im `@State`-Initialisierer statt aus einem `.task`, weil ein `.task` nach dem ersten Render läuft und dem Nutzer für einen Frame den `locked`-Zweig zeigen würde, obwohl er gleich Zugang bekommt. Tragfähig nur, weil `startIfNeeded` idempotent ist — SwiftUI darf diesen Pfad beliebig oft betreten.
- **Kontingent: nur wenn erschöpft, und in einer eigenen Funktion.** `OverrideContext.allowanceReachingTheCeiling` fragt beim Öffnen des Entsperr-Flows einmal und startet nur, wo die Antwort „nein" ist. Ein Override mit freiem Slot ist keine Absage. Der Auslöser durfte **nicht** in `quota.allowance()` — die Shield-Configuration-Extension ruft das für jeden Sperrbildschirm auf, den sie zeichnet, und ein Systemprozess darf niemandes 14 Tage starten. Das war schon die Begründung dafür, dass `TrialStore.state` nie startet; hier ist dieselbe Grenze noch einmal.

**Nicht ausgelöst wird durch das Öffnen der Paywall.** Sie hängt an der Einstellungszeile „Abo"; die aus Neugier am ersten Tag anzutippen ist dasselbe Nicht-Ereignis wie ein App-Start, das gerade abgeschafft wurde.

**Bestandsinstalls: keine Migration, und das ist geprüft, nicht angenommen.** Beide Regeln schreiben denselben Schlüssel (`trialStartedAt`) in derselben App-Group-Suite über dasselbe idempotente `startIfNeeded`. Eine laufende Testphase behält ihren Start; eine abgelaufene bleibt abgelaufen und wird durch den ersten Bettzeit-Aufruf nach dem Update nicht neu gewährt. Beide Richtungen sind eigene Tests.

**Copy: keine Zeile geändert.** Keine Zeile der App hat je „14 Tage ab Installation" versprochen — `PaywallView` und `SettingsView` zeigen den Countdown und die Testphase, beide abgeleitet aus `SubscriptionAccess`, beide sagen nichts über den Startpunkt.

**Verifikation.** `xcodegen generate` (eine neue Quelldatei), Suite auf `OS=26.5,name=iPhone 17`: **406 Tests in 56 Suites, 0 Failures, 0 Skips** (vorher 394/55). Neue Suite `TrialTriggerTests`, zwölf Tests: der erste Kontakt, die Idempotenz über zwölf Tage plus den Kontakt nach Ablauf, beide Grenzen einzeln, der Override mit freiem Slot als Nicht-Ereignis, der Lesepfad der Extension, die zwei Bestandsinstall-Richtungen, der Vorrang des Abos — und drei Verdrahtungs-Tests, die den Quelltext über `#filePath` lesen (Technik aus `MorningCelebrationWiringTests`, weil beide Trigger in `@State`-Initialisierern leben, die nur eine konstruierte View ausführt). Gegengeprüft: mit wiederhergestelltem `.task { TrialStore.startIfNeeded() }` in `TuckApp` ist `theLaunchPathNoLongerStartsATrial` rot.

**Offen / bewusst nicht gebaut.** Der `exhausted`-Screen im Entsperr-Flow hat weiterhin keinen Weg zur Paywall — nur „Schließen". Das war vor dieser Änderung so und ist es danach; für den Trial ist es jetzt egal (die Grenze löst aus, bevor der Screen erscheint), für die Konversion bleibt es eine offene Lücke. Ein Nutzer sieht ab dem zweiten Freischaltungsversuch eines Tages unbegrenzte Freischaltungen, ohne dass ihm jemand sagt, dass gerade eine Testphase begonnen hat — der Countdown steht nur in den Einstellungen und auf der Paywall. Ob das eine stille Freundlichkeit oder eine verpasste Ansage ist, ist eine Produktfrage, keine Code-Frage.

## 2026-09-09 (abends) — Der Name ist Tuck

Der Produktname **Tuck** ist projektweit durchgezogen. Kein Verhaltens-, kein Logikwechsel — eine reine Umbenennung, gemessen an einer Testsuite, die vorher und nachher identisch ist: **406 Tests in 56 Suites, 0 Failures, 0 Skips**, davor wie danach, `OS=26.5,name=iPhone 17`. Auch die Warnungszahl ist beidseitig null.

**Was mit umgezogen ist — vollständig, weil eine halbe Umbenennung schlimmer wäre als keine.**
- **Projekt und Ziele:** `project.yml` `name: Tuck`; die fünf Ziele heißen `Tuck`, `TuckMonitor`, `TuckShield`, `TuckShieldAction`, `TuckTests`. `Tuck.xcodeproj` wird von `xcodegen generate` aus `project.yml` erzeugt; `project.yml` ist die Quelle, auch bei einer Umbenennung.
- **Ordner und Dateien** über `git mv`, damit die History an den Dateien hängen bleibt: die fünf Ziel-Verzeichnisse, die StoreKit-Konfiguration (jetzt `Tuck.storekit`), die vier `.entitlements`, die App-Datei (jetzt `Tuck/TuckApp.swift`) und die Identifier-Datei (jetzt `Shared/TuckIdentifiers.swift`).
- **Bundle-IDs:** `com.example.tuck` und die drei Extension-Suffixe `.monitor`, `.shield`, `.shieldaction`. `bundleIdPrefix` bleibt `com.example`.
- **App-Group:** `group.com.example.tuck`, in `TuckIdentifiers` und allen vier `.entitlements` gleichzeitig — vier Bundles, ein Wert, sonst finden sie sich nicht mehr.
- **StoreKit:** `com.example.tuck.plus.monthly`/`.yearly` in `Tuck.storekit` **und** in `Shared/SubscriptionTier.productID`. Die beiden IDs müssen zeichengleich sein, sonst löst kein Produkt auf; `internalID` und `subscriptionGroupID` blieben bei der Umbenennung unangetastet, sie sind Apple-Seite und tragen den Namen nicht (in diesem Export stehen in `Tuck.storekit` dafür Platzhalterwerte).
- **Swift-Symbole, die den Produktnamen trugen:** Identifier-Typ, App-Typ und Button-Stil heißen jetzt `TuckIdentifiers`, `TuckApp` und `TuckButtonStyle`, und die rund 150 Farb-Token tragen das Präfix `Color.tuck*`. Namen ohne Produktbezug (`MascotBadge`, `MorningBlockWindow`, …) sind unberührt.
- **Sichtbare Kopie** in beiden Sprachen: `Localizable.xcstrings`, `InfoPlist.xcstrings`, `Info.plist`, `SharedCopy.xcstrings`. Der Mascot heißt mit: „Dein Tuck". Ein Anzeigename musste nicht gesetzt werden: `PRODUCT_NAME = $(TARGET_NAME)`, und das Ziel heißt jetzt Tuck.

**Die eine Konsequenz, die nicht im Code steht.** Bundle-IDs und App-Group sind Identitäten, die Apple und iOS führen, nicht nur Zeichenketten im Repo. Eine Migration von Daten unter anderen Identitäten ist nicht gebaut; die App ist nie ausgeliefert worden.

## 2026-09-09 (Phase 2.4/2.5/2.7) — Der Flow bekommt eine Kopfzeile, der Morgen ein Zahnrad

Drei Punkte aus dem Produktionsreife-Plan (nicht Teil dieses Exports), alle drei Komposition statt Logik. **Suite vorher 453 Tests in 61 Suites, nachher 464 in 63, jeweils 0 Failures** (`OS=26.5,name=iPhone 17`). Keine Verhaltensregel, kein Speicherformat und kein Zeitpfad ist angefasst.

**2.4 — das Onboarding neu komponiert.**
- **Zurück-Navigation, die es nie gab.** Sieben Schritte, zwei davon mit einem Systemdialog davor, und kein Weg zurück: eine vertippte Weckzeit war nur zu korrigieren, indem man den Flow zu Ende ging und den Screen in den Einstellungen wiederfand. Die Kopfzeile trägt links ein `chevron.left` in 44 × 44 (§9 K4) und mittig sieben Punkte statt „Schritt 3 von 7" — VoiceOver behält den Satz als Label. Sie steht **außerhalb** der ScrollView: bei großen Textgrößen scrollt alles, was drin liegt, aus der Reichweite, und das wäre ausgerechnet der Weg zurück.
- **Top-Alignment (§9 K1/K2).** Jeder Schritt zentrierte seinen Inhalt zwischen einem Spacer-Paar — auf dem Explain-Schritt gemessen 22 % Inhalt und zwei tote Bänder à ~33 %. Die Inhaltsspalte beginnt jetzt fest 96 pt unter der Safe Area (davon 44 pt Kopfzeile); der eine Spacer über dem Button bleibt.
- **Der App-Auswahl-Schritt.** ~90 Wörter Fließtext in Gewicht 700 teilten sich den Screen 50/50 mit dem `FamilyActivityPicker`, weil beide gleichberechtigte Kinder eines VStack waren. Der Text nannte großenteils die Kategorien, die im Picker daneben standen. Übrig: die Frage, eine Vorschlagszeile (`BlocklistSuggestions.primaryLine`, aus denselben Labels gebaut, die der Picker zeigt) und die WhatsApp-Notiz in einer standardmäßig geschlossenen `DisclosureGroup` — das Einzige, was der Picker nicht sagen kann. Der Picker bekommt `.layoutPriority(1)`.
- **Leere Auswahl.** Der Flow ließ sich mit `hasCompletedOnboarding = true` beenden, ohne dass je eine App gewählt wurde — ein registriertes Fenster über einer leeren Auswahl sperrt nichts. Der Schritt bleibt passierbar (diese App bestraft nicht), aber der Button heißt dann „Ohne Auswahl weiter" und eine Zeile unter dem Picker sagt, was das bedeutet.
- **Was ausdrücklich nicht gebaut wurde: die Ein-Tipp-Vorauswahl.** Sie ist nicht baubar, nicht nur aufwendig: `ActivityCategoryToken` ist `ManagedSettings.Token<ActivityCategory>` und hat im iOS-26.5-Interface **keinen öffentlichen Initializer** — nur `init(from: Decoder)`. Apples Kategorien lassen sich aus Code heraus in keine `FamilyActivitySelection` legen. Ein Blob zu dekodieren wäre gerätespezifisch und undokumentiert. Der Hinweis oben ist der Ersatz, den die Plattform zulässt.

**2.5 — Zahnrad statt Textbutton.** `Button("Einstellungen")` trug exakt die drei Modifier der Statuszeile über sich, ohne Fläche, ohne Glyph, ohne Navigationsleiste, mit einer Trefferfläche unter der Hälfte des HIG-Minimums. „Es gibt keine Einstellungen" war eine korrekte Lesart. Jetzt ein 44 × 44-Overlay oben rechts; der Textbutton entfällt ersatzlos. **Eine Zutat steht nicht im Plan und ist bewusst dazugekommen:** die Platte unter dem Zahnrad. Der alte Textbutton saß am **unteren** Rand des Himmels, wo Charcoal Green nie unter 3,40:1 fällt; oben ist das eine Band, wo es das tut — ~~**2,48:1**~~ **2,44:1** auf Dawn Shadow bei `progress = 0`. *(Zahl und Herleitung korrigiert 2026-09-14: „gerechnet wie §8 A29 den Rest dieses Gradienten rechnet" war die Begründung, aber nicht die Rechnung. 2,48 entsteht aus einer naiven, komponentenweise LINEAREN Mischung von Sage und Charcoal — `Color.mix(with:by:)` mischt per Default perzeptuell. Perzeptuell und ungerundet, also so wie §2.4 es seit 2026-09-14 deklariert und wie `LightSkyContrastTests` es misst, sind es 2,44. Eine Hex-Handrechnung gegen `#B6C2B3` ergibt übrigens 2,45 — auch das ist kein Gegenbeweis, sondern die dritte Methode.)* Ohne Platte hätte der Umzug ein Trefferflächen-Problem gegen ein Kontrastproblem getauscht, am selben Bedienelement. Die Platte ist die schwebende Stufe, die die Sprechblase längst benutzt (§2.3, §5.9). Himmel, Ambiente und Spalte bleiben unberührt.

**2.7 — Gradient und Übergang.**
- Der erste Screen jedes neuen Nutzers lief Cream → `Sage.opacity(0.35)`, was keine sichtbare Bewegung ist. Jetzt `0.6`, dieselbe Cream→Sage-Bewegung, auf der `MorningSky` endet. **§8 A37 ist mitgezogen statt stehengelassen:** der Entscheid „dokumentieren, nicht angleichen" gilt weiter, nur Wert und Zahl ändern sich — unterer Stopp kompositiert zu `#E4E7DB`, Charcoal darauf **3,55:1** (vorher 3,75:1). Jede Zeile des Flows steht bei ≥14 pt / 700, wo die Schwelle 3:1 ist.
- Die Schrittanimation geht von 0,6 s auf **0,25 s**. 0,6 s entstand, als drei Flow-Übergänge als eine Aufgabe behandelt wurden (§8 A16); sieben Schritte hintereinander sind aber keine Meldung, sondern eine Bedienfolge. Der Override behält 0,6 s. **Zwei Werte, weil die Aufgaben verschieden sind, nicht weil sie auseinandergelaufen sind** — beide stehen jetzt in §6.1. §8 A27 bleibt intakt: der konstante Anker und das `scrollTo` haben den Umbau überlebt, und `OnboardingCompositionTests` pinnt, dass sich kein `.id(step)` als bequemere Schreibweise eingeschlichen hat.

**Am Simulator gegengeprüft — und ein Befund, der offen bleibt.** Vier Screenshots auf iPhone 17e / iOS 26.5, Dynamic Type „Large", Onboarding-Schritt über `defaults write … onboardingStep` gesetzt: Kopfzeile, Chevron ab Schritt 2, sieben Punkte, Top-Alignment, „Ohne Auswahl weiter", Zahnrad — alles wie gebaut. **K2 ist damit aber nicht erfüllt, sondern nur halbiert:** aus zwei Bändern à ~33 % ist *ein* Band geworden, und das misst auf dem Explain-Schritt **~280 pt ≈ 37 % der Safe Area** (Willkommen: ~213 pt ≈ 28 %) zwischen dem Ende des Fließtexts und dem Button. Top-Alignment plus ein einzelner Spacer kann das strukturell nicht besser: der gewonnene Raum sammelt sich unten statt oben und unten. Der Plan sagt selbst, was fehlt (§5.2: „den gewonnenen Raum mit dem Maskottchen oder einer Dialog-Vorschau füllen statt mit Luft") — das ist **Inhalt, keine Layout-Schraube**, und damit eine Design-Entscheidung, die hier bewusst nicht nebenbei getroffen wurde. K1 (fester Inhaltsstart), K4 (44 pt) und K5 (App-Auswahl stellt wieder eine Frage) sind erfüllt; K3 steigt von 22 % auf ~33 % Ink und bleibt unter dem 50-%-Ziel.

**Was ehrlich nicht verifiziert ist.** Der `FamilyActivityPicker` rendert ohne erteilte Family-Controls-Berechtigung nichts Echtes — der Simulator zeigt den Nicht-erlaubt-Zweig. `.layoutPriority(1)`, die 50/50-Teilung, die es beheben soll, und die Leer-Auswahl-Zeile unter dem Picker sind deshalb **nur gelesen, nicht gesehen**; sie brauchen ein Gerät mit Entitlement. Ebenso ungeprüft: alle Schritte bei `AccessibilityXXXL` (dort greift die ScrollView, und die Kopfzeile soll stehen bleiben), Reduce Motion, Dunkelmodus und wie die Zahnrad-Platte über dem Himmel bei fortgeschrittenem `skyProgress` wirkt — der Screenshot zeigt einen einzigen Zeitpunkt.

**Bewusst liegengelassen.** `BlocklistSuggestions.intro`, `.shortVideoExamples`, `.secondary` und `.secondaryLine` rendern nach 2.4 nirgends mehr, bleiben aber stehen: drei Testsuiten prüfen sie als Copy-Inventar, und ihr Löschen wäre eine Copy-Entscheidung, keine Layout-Änderung. Gehört entschieden, nicht nebenbei mitgenommen.

## 2026-09-10 (Phase 1.3) — Das Abendfenster fragt jetzt auch dort nach Plus, wo es sperrt

**Der Befund.** `BlockWindowReconciler.bedtimeWindowAction` gatet das Abendfenster seit 2026-09-05 korrekt — aber nur im App-Prozess, und der läuft nur, wenn jemand die App nach vorne holt. Eine Registrierung, die unter Plus entstanden ist, feuert danach weiter: iOS ruft `intervalDidStart` in `TuckMonitor`, und die Extension legte den Shield bedingungslos an. Ein Trial, der abläuft, während die App wochenlang nicht geöffnet wird, sperrt also gratis weiter. **Kein Free-Nutzer steht dadurch schlechter da als vorher** — wer nie Plus hatte, hat auch nie ein Abendfenster registriert (`docs/SSOT.md`); die Änderung betrifft ausschließlich den Zustand nach einem abgelaufenen Zugang.

**Wo es wirklich saß.** Der Plan nennt `TuckShield/` als Zielort. Falsch: `TuckShield` zeichnet den Shield-Screen, `intervalDidStart` liegt in `TuckMonitor/DeviceActivityMonitorExtension.swift`. `SubscriptionAccess.swift`/`SubscriptionTier.swift` standen in `TuckShield`s `sources:` schon drin — gefehlt haben sie in `TuckMonitor`, wo sie jetzt ergänzt sind.

**Was gebaut ist.** `Shared/BlockWindowEntitlement.swift`, eine reine Funktion `action(for:access:)` → `.shield` / `.release`, gelesen aus `SubscriptionAccess.current()` im Moment des Callbacks. In `Shared/`, nicht in der Extension, aus demselben Grund wie `ShieldActionRouting`: der Simulator startet keine App-Extension, eine Entscheidung in `TuckMonitor` wäre von keinem Test erreichbar. Der Morgen ist nie gegatet — er ist das Produkt und er ist frei. Der `.release`-Zweig **löscht** den Store, statt nur `return` zu machen: eine Occurrence, deren `intervalDidEnd` nie ankam, ließe sonst einen Shield stehen, den niemand mehr abbaut. Der Zähler `.intervalsStarted` bleibt über dem Gate — sonst zählte die Fünf-Tage-Beobachtung erfolgreiche Shields unter dem Namen „iOS hat geantwortet".

**Welches Signal beweist, dass es passiert ist.** Für die Entscheidung: `BedtimeGateTests` (4 neue Fälle). Für die Verdrahtung: `BedtimeGateWiringTests` liest `intervalDidStart` über `#filePath` und prüft die Reihenfolge Gate → Apply, den Clear im gesperrten Zweig und den Zähler oberhalb — dieselbe Technik wie `MorningCelebrationWiringTests`, und hier alternativlos. **Kontrollgruppe gefahren:** gegen die Vor-Fix-Extension sind die Wiring-Tests rot; mit einer auf `.shield` festgenagelten Entscheidung ist `theMonitorReleasesTheEveningWindowOnceAccessIsGone` rot. **Suite 527 → 530 Tests in 71 Suites, 0 Failures** (`OS=26.5,name=iPhone 17`), Warnungs-Baseline unverändert.

**Was ohne Gerät offen bleibt.** Dass `intervalDidStart` überhaupt gerufen wird, dass `ShieldApplication.clear` einen laufenden Shield wirklich fallen lässt und ob die Extension die App-Group liest — alles drei ist im Simulator strukturell nicht prüfbar. Die Tests belegen die Entscheidung und ihre Verdrahtung, nicht die Sperre.

## 2026-09-10 (Phase 3.8) — Die Wochentage, und die Sperre, die ihnen folgen muss

Der Wecker klingelte an sieben Tagen, weil `.weekly(...)` mit allen sieben Wochentagen fest im Code
stand — die einzige wiederkehrende Form, die AlarmKit kennt, aber eben auch die einzige, die je
gesetzt wurde. Jetzt wählt der Nutzer die Tage, und **beide** Seiten folgen der Auswahl. **Suite
vorher 523 Tests in 70 Suites, nachher 537 in 71, jeweils 0 Failures** (`OS=26.5,name=iPhone 17`,
Simulator `iPhone 17`, alleiniger Lauf). Warnungen unverändert auf der Baseline: die drei bekannten
`appintentsmetadataprocessor`-Notices, sonst keine.

**Die architektonische Besonderheit, die den halben Aufwand ausmacht.** `DeviceActivitySchedule`
hat keinen Wochentag-Parameter — `repeats: true` heißt jeden Tag, und mehrere Registrierungen pro
Woche liefen in Richtung `excessiveActivities` (Begründung unverändert: `docs/bedtime-window-2026-09-03.md:125`).
Das Sperrfenster bleibt deshalb **jeden Tag registriert**, und `intervalDidStart` feuert auch an
einem Samstag, den niemand ausgewählt hat. Ohne den zweiten Teil hätte die Auswahl nur den Wecker
stummgeschaltet und trotzdem jeden Tag gesperrt. Die Prüfung liegt darum in der Monitor-Extension,
vor `ShieldApplication.apply` und **hinter** den beiden Diagnose-Zählern: die zählen, dass iOS
überhaupt gesprochen hat (0.6), und ein Zähler hinter dem Guard wäre ein Zähler erfolgreicher
Shields unter dem Namen des Callbacks.

**Was gebaut wurde.**
- `Shared/WakeAlarmWeekdays.swift`, kompiliert in App **und** Monitor-Extension: `WakeAlarmWeekday`
  trägt Calendars eigene Nummerierung (1 = Sonntag), weil die Extension nur
  `Calendar.component(.weekday, from:)` hat und `Locale.Weekday` ein String-Enum ohne Zahl ist.
  `WakeAlarmWeekdayStore` speichert im App-Group-Suite, gleiche Form wie `MorningBlockDurationStore`.
- **Kein Zustand verengt sich versehentlich:** abwesender Schlüssel, leeres Array und unlesbare
  Zahlen lösen alle zu *allen sieben Tagen* auf — genau das, was jede Installation von vor dieser
  Einstellung schon tat. Eine leere Auswahl wird beim Schreiben abgelehnt, nicht gespeichert: sie
  wäre ein Wecker, der nie klingelt, unter einem Screen, der weiter „Wecker klingelt …" sagt. Alles
  abschalten hat sein eigenes Bedienelement („Wecker ausschalten"), das das Fenster mitnimmt.
- **Die Auswahl wird erst nach dem `schedule()` geschrieben**, nie auf dem abgelehnten oder
  fehlgeschlagenen Pfad: ein früherer Schreibvorgang würde die Sperre auf Tage verengen, an denen
  der noch lebende vorherige Wecker klingelt. Gepinnt durch eine Reihenfolge-Prüfung im Quelltext.
- `WakeAlarmDate.nextFireDate` filtert die Wochentage über derselben Tagessuche, statt auf Wochentag
  und Uhrzeit gleichzeitig zu matchen — die vier DST-Tests (Sprung-Lücke, wiederholte Stunde) hängen
  an genau diesem Verhalten und bleiben unangetastet. Das gespeicherte `fireDate` ist damit auch bei
  „nur montags" eine wahre Aussage darüber, wann als Nächstes geklingelt wird.
- `eventDidReachThreshold` trägt denselben Guard: an einem Tag, an dem kein Shield stand, spräche
  die Bildschirmzeit-Notiz über ein Fenster, das nichts zurückgehalten hat.
- **UI:** sieben Umschalter im Wecker-Setup, sortiert nach `Calendar.firstWeekday`, beschriftet aus
  `shortWeekdaySymbols` — keine zweite Kopie der Wochentagsnamen zum Übersetzen. 44 pt Höhe,
  VoiceOver bekommt den vollen Namen plus `.isSelected`. Der letzte verbleibende Tag lässt sich hier
  nicht abschalten. Die Statuszeile sagt „jeden Morgen" nur noch, wenn es stimmt, sonst „Mo, Mi und
  Fr" — und sie liest den **gespeicherten** Stand, nicht die Umschalter, die wie der Zeit-Picker bis
  zum Tippen auf die Platte unangewendet sind. Eine Zeile unter der Reihe sagt die nicht
  offensichtliche Hälfte: an den anderen Tagen bleibt auch das Sperrfenster aus.

**Welches Signal beweist, dass es wirklich passiert ist.** Auf der Wecker-Seite: keines, das der
Simulator liefern kann — `AlarmManager` autorisiert dort nie, kein Test in diesem Projekt hat je
einen gestellten Wecker beobachtet. Gepinnt ist deshalb die reine Abbildung (Set → sortiertes
`[Locale.Weekday]`) plus die Verdrahtung im Quelltext: die eine `.weekly(...)`-Aufrufstelle trägt
den hereingereichten Wert, und die alte „alle sieben"-Konstante existiert nirgends mehr, auf die
etwas zurückfallen könnte. Auf der Sperr-Seite ebenso zweiteilig: die reine Entscheidung
(`morningBlockApplies`) für ausgewählte wie nicht ausgewählte Tage inkl. eines Fensters über
Mitternacht, plus die strukturelle Aussage, dass der Guard **vor** `ShieldApplication.apply` steht.
Die Extension ist ein Systemprozess, den der Simulator nie startet und der nicht ins Testbundle
kompiliert wird — die Position im Quelltext ist die stärkste verfügbare Evidenz, nicht ein Ersatz
für einen Gerätelauf.

**Was ehrlich unverifiziert bleibt.** Ob AlarmKit eine echte Teilmenge tatsächlich nur an diesen
Tagen klingeln lässt, ob `intervalDidStart` an einem nicht gewählten Tag überhaupt feuert (die
ganze Annahme, auf der der zweite Teil ruht), und ob der Guard dort greift: alles drei nur am Gerät
über mehrere Tage prüfbar, keins davon im Simulator. **Der Diagnose-Zähler ist an dieser Stelle neu
zu lesen:** ein übersprungener Tag zeigt sich als „Intervall gestartet, kein Shield" — dieselbe
Form, die ein echter Plattformausfall hat. Beim Gerätelauf müssen die Zahlen gegen die tatsächlich
gewählten Tage gerechnet werden, nicht gegen den Kalender. Ein fünfter Zähler dafür wurde bewusst
nicht gebaut: er hätte die Diagnosezeile in den Einstellungen mitgeändert, und während der
Fünf-Tage-Beobachtung steht die Auswahl ohnehin auf allen sieben Tagen.

**Bewusst nicht angefasst.** Die Zeile „Weckzeit" in den Einstellungen zeigt weiter nur die Uhrzeit.
Sie behauptet nichts Falsches — sie sagt nie „jeden Morgen" — und der Screen dahinter nennt die
Tage vollständig; „07:00 · Mo, Di, Mi und Do" wäre in einer Listenzeile unlesbar. Die Bettzeit
bleibt wochentagslos (E2): die gemeinsame Wochentags-Differenzierung für beide Zeiten ist
ausdrücklich eine spätere, gemeinsame Ausbaustufe.

### Nachtrag 2026-09-10 (Prüfdurchgang) — der übersprungene Tag gibt den Shield nicht zurück

Eine Prüfrunde hat die beiden Features (Wochentagsauswahl und
Bettzeit-Trial-Gate) zusammengeführt geprüft und drei Befunde gemeldet. Alle drei sind in einem
Folgeschritt behoben.

**B1 (der teure).** Der Wochentags-Guard stand **über** `guard let storeName` und machte ein nacktes
`return`. `intervalDidEnd` des Morgenfensters fällt dokumentiert aus — genau die Begründung, mit der
der Abo-Guard aus 1.3 im selben Callback `ShieldApplication.clear(storeName)` aufruft, bevor er
returnt. Für einen Mo-Fr-Nutzer heißt das: Freitags kommt kein `intervalDidEnd`, Samstag feuert
`intervalDidStart`, der Wochentags-Guard greift zuerst — und der Freitags-Shield steht das ganze
Samstag-Morgenfenster. *A missed block costs one window, a stranded shield blocks forever*
(`Tuck/BlockWindowMonitor.swift`). Der Guard sitzt jetzt unter dem Store-Lookup und räumt auf. Der
Selection-Guard darunter war genauso nackt und räumt aus demselben Grund mit auf.

**Die Testlücke dahinter (B2).** Der bestehende Pin prüfte nur die *Reihenfolge* Guard → Apply, und
die war die ganze Zeit korrekt. Der neue Pin prüft die **ganze Methode** statt einen benannten
Guard: jeder Ausstieg unterhalb des Store-Lookups muss vorher `clear` gerufen haben, egal welcher
Guard ihn hinzufügt und wann. Kontrollgruppe gegen den Vor-Fix-Stand: rot
(`everyGuardExitAfterTheStoreIsKnownClearsTheShield`, „Expectation failed: clearedHere";
`theWeekdayGuardKnowsTheStoreItHasToClear`, storeName 21 < weekday 18).

**H4.** `ProtectedTimeStore.armedWindows` entschied allein am Registrierungs-Flag, und das steht auf
allen sieben Tagen, weil `DeviceActivitySchedule` nichts Engeres sagen kann. Ein Mo-Fr-Nutzer bekam
damit ~29% geschützte Zeit gutgeschrieben, die die App bewusst nicht geschützt hat — Über-Zählung,
in der einen Richtung, die diese Datei ausschließt. Occurrences werden jetzt einzeln durchlaufen und
jede nach ihrem eigenen Wochentag gefragt, mit derselben `morningBlockApplies`, die der Monitor
benutzt. Kontrollgruppe gegen den Vor-Fix-Stand: rot mit „5400 == 1800".

**H5.** `GutenMorgenView` sagte an einem übersprungenen Tag weiter „Sperrfenster bis 07:30" — der
Screen, den der Nutzer morgens tatsächlich liest. Angepasst worden war nur die Statuszeile im
Wecker-Setup. Die Zeile lautet an so einem Tag jetzt „Sperrfenster: heute nicht — du hast Mo, Di, Mi,
Do und Fr gewählt."

**Korrektur zum Absatz oben:** der fünfte Diagnose-Zähler wurde jetzt doch gebaut
(`weekdaysSkipped`), und die Diagnosezeile hat damit fünf Zahlen. Die Begründung von gestern hielt
nicht: übersprungener Tag, abgelaufener Zugriff und stummer `deviceactivityd` sehen ohne ihn alle
gleich aus („Intervall gestartet, kein Shield"), also drei Befunde hinter einer Differenz. Dass
während der Fünf-Tage-Beobachtung ohnehin alle sieben Tage gewählt sind, ist eine Annahme über das
Verhalten des Beobachters, keine Eigenschaft des Instruments.

### Nachtrag 2026-09-10 — die pbxproj kannte die eigenen Tests nicht

Nach dem Merge lief `xcodebuild test` gegen `master` mit **545 von 563 Tests** und
meldete trotzdem „TEST SUCCEEDED". Die fehlenden 18 waren die komplette `WakeAlarmWeekdayTests`-
Suite — inklusive der drei Kontrollgruppen-Tests, die den B1-Fix aus dem Nachtrag oben beweisen.
Ursache: der 9-Commit-Rebase des Folge-Branches hatte `xcodegen generate` laufen
lassen (Output bestätigt „Created project at …"), aber die dabei neu geschriebene
`project.pbxproj` wurde nie committet, bevor der Branch gepusht und gemergt wurde — der lokale
Testlauf vor dem Push sah die frische, aber uncommittete Registrierung; der gemergete Commit auf
`master` nicht. `WakeAlarmWeekdayTests.swift` kompilierte, stand aber in keiner
`PBXSourcesBuildPhase`.

**Kontrollgruppen-Beweis statt Behauptung:** den Fund erst gegen den tatsächlich gemergeten
`master`-Stand verifiziert (0 Treffer für `WakeAlarmWeekdayTests` in `project.pbxproj`, Testlauf
545/563 grün — die stille Form des Ausfalls, die als Kernfehlerklasse dieses Projekts gilt:
Erfolgsmeldung ohne bestätigtes Signal), erst danach den Fix committet und erneut auf 563/563
verifiziert.

**Lehre für das Arbeiten auf Branches:** `xcodegen generate` nach einem Rebase reicht nicht — das
Ergebnis muss vor dem Push auch committet werden. Ein Drift-Check
(`xcodegen generate && git diff --exit-code Tuck.xcodeproj/project.pbxproj`) direkt vor jedem Push
eines Branchs mit Struktur-Änderungen hätte das hier sofort gezeigt.

### Nachtrag 2026-09-10 — Nachtrag zu 0.2: schon am 09.09. gebaut, nie eingetragen

Ein Prüfdurchgang hatte 0.2 (App-Group-Health-Check) als möglicherweise offenes systemisches Risiko
geflaggt, gestützt auf einen älteren Commit-Kommentar, der behauptete, `UserDefaults(suiteName:
"bogus")` liefere `nil` zurück — empirisch falsch, dieser Initialisierer gibt für jeden syntaktisch
gültigen Namen eine nutzbare (private) Suite zurück. Vor dem Nachbauen dieses vermeintlichen Funds
den aktuellen Code gelesen statt der eigenen alten Zusammenfassung vertraut: ein Commit vom
09.09. hatte die Diagnose bereits umgestellt, auf `FileManager.default.containerURL(
forSecurityApplicationGroupIdentifier:) != nil` — dieselbe Probe, die `UnlockQuotaStore` schon für
ihr Lock-File nutzte, hier zur eigentlichen Diagnose erhoben. `TuckApp.init()` bricht in Debug mit
`fatalError` ab, wenn die Group nicht provisioniert ist; `GutenMorgenView` zeigt in Release
stattdessen die ehrliche `StatusCopy.sharedStorageMissing`-Zeile statt eines behaupteten
Sperrfensters. Gedeckt von `AppGroupHealthTests.swift` (zwei Tests: die Suite antwortet für den
tatsächlich benutzten Container, die Ausweich-Zeile behauptet kein Fenster). Der Commit war nie in
diesem Log eingetragen und der Produktionsreife-Plan (nicht Teil dieses Exports) führte 0.2 weiter als
offenen Blocker — beides jetzt korrigiert.

**Lehre:** ein eigener Fund aus einer vorherigen Runde ist eine Behauptung mit Verfallsdatum, keine
Quelle — vor dem Nachbauen immer gegen den aktuellen Code re-verifizieren, nicht nur gegen die
eigene Zusammenfassung davon.

### Nachtrag 2026-09-10 — die Migration meldete sich, niemand hörte hin

`Migrations.runIfNeeded()` (3.2) liest nach dem eigenen Schreiben zurück und liefert `.failed`,
wenn der Schreibvorgang das nicht überlebt hat — das Instrument existiert. `TuckApp.init()` rief die
Funktion aber ohne den Rückgabewert aufzufangen, genau die Lücke, die die Funktion selbst schließen
sollte: eine erkannte Fehlschreibung, die am Aufrufort wieder im Schweigen verschwindet.

Kontrollgruppen-Beweis: neuer Wiring-Test (`SchemaMigrationTests.theStartupCallSiteNoticesAMigrationThatDidNotPersist`,
liest `Tuck/TuckApp.swift` als Quelltext, im selben Stil wie `theAppRunsTheMigrationAtStartup`)
rot gegen den unveränderten Aufruf (zwei Erwartungen fehlgeschlagen: der Rückgabewert wird nicht
aufgefangen, kein `#if DEBUG`-Guard danach), grün nach dem Fix. Die Prüfrunde hat den
Kontrollgruppen-Lauf selbst wiederholt (eigene Arbeitskopie, gleicher roter Ausschlag) und zusätzlich
eine Mutation geprüft, die den Wert zwar auffängt, aber nie inspiziert (`_ = migrationOutcome`) — der
Test schlägt auch dort fehl, ist also nicht tautologisch.

Fix folgt exakt dem Muster der App-Group-Prüfung zwei Zeilen darüber in derselben `init()`: laut in
Debug (`fatalError`), unverändert in Release — ein Produktionsbuild darf nicht über eine
Migrationsschreibung abstürzen, die heute (0 Migrationsschritte, `SchemaVersion.current == 1`)
folgenlos bleibt, wenn sie fehlschlägt. Die Prüfrunde hat zusätzlich einen Release-Build gefahren
(`-configuration Release`), um das klassische „unbenutzte Variable, nur in `#if DEBUG` referenziert"-
Warnungsrisiko auszuschließen: baut sauber, keine neue Warnung.

**Bewusst offen gelassen, für die nächste Migration:** in Release bleibt `.failed` weiterhin
folgenlos. Heute richtig (nichts ist zu migrieren), aber sobald `SchemaVersion.current` das erste
Mal über einen echten Schritt angehoben wird, verdient dieses Schweigen eine eigene Entscheidung —
nicht automatisch mit übernehmen.

### Nachtrag 2026-09-10 — 3.7 abgeschlossen: der letzte Kandidat bleibt, wo er ist

3.7 („View-Initializer, die Nebeneffekte schreiben, nach `.task {}` verschieben") war halb erledigt:
`OverrideFlowView` verschoben, `BedtimeSetupView` bewusst behalten (Begründung im
Log oben: `.task` würde dort für einen Frame den `locked`-Zweig zeigen). Offen blieb der dritte
Kandidat, `SettingsView.swift:37` — `@State private var protectedSeconds = ProtectedTimeStore.accrue()`.

**Entschieden: bleibt im Initializer.** Der Grund ist nicht Aufwand, sondern dass die beiden
Schreibvorgänge nicht dieselbe Art Schreibvorgang sind. Was 3.7 aus `OverrideFlowView` herausgeholt
hat, war `allowanceReachingTheCeiling()` — das startet eine Vierzehn-Tage-Uhr, und der **erste**
Aufruf legt ein Datum fest, das niemand zurücknehmen kann; eine ungewollte Auswertung verbrennt
Trial-Tage, die der Nutzer nie gesehen hat. `accrue()` bucht die Spanne, die vergangen ist, und
sonst nichts. Der Store sagt das selbst (`Shared/ProtectedTimeStore.swift:36`): „Idempotent, so an
extra call is a no-op and never a second entry." Ein Aufruf zu einem Zeitpunkt, den niemand gewählt
hat, schreibt im Normalfall genau das, was ein gewählter Zeitpunkt geschrieben hätte — über eine
Sommerzeit-Umstellung nicht: die Tagesabstands-Arithmetik ist dort nicht additiv, gepinnt in
`aSpringForwardPassKeepsTheCounterMovingAndCostsTwoOccurrences` (bis zu 2 Occurrences/Jahr
Differenz, nur für ein Fenster erreichbar dessen Ende in die Umstellungslücke fällt — bei der
~07:30-Morgenzeit nie, nur über eine ~02:30-Bettzeit), immer in Richtung Unter-Zählung (die
G3-Disziplin dieser Datei) und von jeder der acht anderen `accrue()`-Aufrufstellen gleichermaßen
realisiert — ändert also nichts an der Entscheidung, nur an der Stärke der Behauptung. Dass `accrue`
einen Skip nicht überschreibt, hängt am `guard now > countedThrough` vor dem Anker-Write (`:83` vor
`:98`).

**Was ein Umzug gekostet hätte:** `StatusCopy.fullHours(0)` ist `emptyCount`, also „noch keine".
Ein Platzhalter würde der Zeile „Sperrfenster insgesamt" für einen Frame „noch keine" geben — die
eine Zeile auf dem Screen, deren ganzer Zweck ist zu sagen, was die App eingetragen hat. Der Screen
würde sich selbst untertreiben, auf einem Wert, den er schon hat. `SettingsView` hat heute gar kein
`.task`; eins allein dafür anzulegen, hätte Korrektheit nicht verbessert, nur Stil verändert.

**Kontrollgruppen-Beweis statt Behauptung.** Zwei Tests in `ProtectedTimeStoreTests.swift`:
`aBurstOfUnchosenReadsLandsOnTheSameSumAsOneSettledRead` (differenziell: ~76 stündliche Aufrufe über
drei Occurrence-Enden müssen exakt auf der Summe eines einzigen Reads landen — bricht nach oben bei
Doppelzählung, nach unten bei einem Anker, der ohne Gutschrift weiterrückt) und
`theSettingsRowStillAccruesFromItsStateInitialiser` (strukturell, gleiche Form wie
`TrialTriggerTests.theBedtimeGateReadsItsAccessThroughTheTrigger`, das 3.7s andere Ausnahme pinnt).
Gegen eine naive Alternative rot gefahren — `occurrences` aus dem Tagesabstand
`countedThrough → now` statt Fenster-Ende → Fenster-Ende — und zwar in beiden Richtungen sichtbar:
`settled → 5400` statt 7200 (eine verlorene Occurrence) und `burst → 0` gegen `settled → 5400`, die
Burst-Variante verschluckt unter der naiven Fassung **jede** Occurrence. Danach zurückgebaut,
565/565 grün (vorher 563), Simulator `iPhone 17`, OS 26.5, keine neue Warnung.

**Nicht bewiesen:** dass SwiftUI die Struct hier tatsächlich häufiger rekonstruiert als das Sheet
geöffnet wird. Das ist der dokumentierte SwiftUI-Vertrag und der Grund, aus dem 3.7 überhaupt
existiert, aber gemessen wurde es in diesem Projekt nie — die Entscheidung hängt nicht daran,
weil sie für jede Häufigkeit dieselbe ist.

### 2026-09-10 — 2.3 zu Ende gebracht: elf Bedienelemente mit 18 pt Trefferfläche

**Fund.** §9 K4 verlangt 44 × 44 pt für jedes tippbare Element; §9.4 nennt das die eine Regel des
Kompositionskapitels, die mechanisch greifbar ist ("eine Trefferfläche ist ein `minHeight`/`frame`
an der Aufrufstelle und per Grep auffindbar"). `PrimaryButtonPlate` wurde am 09.09. repariert
(40,3 → 44,3 pt), 2.3 galt danach als erledigt. Elf Aufrufstellen trugen weiterhin gar nichts:

| Datei (Vor-Fix-Zeile) | Bedienelement |
|---|---|
| `Tuck/BedtimeSetupView.swift:116`, `:181` | „Bettzeit entfernen" (Gate- und Setup-Zweig) |
| `Tuck/GutenMorgenView.swift:267` | „Ich brauche kurz Zugriff" |
| `Tuck/WakeAlarmSetupView.swift:107`, `:115` | „Wecker ausschalten", „Bildschirmzeit-Zugriff prüfen" |
| `Tuck/OverrideFlowView.swift:366`, `:488` | „Schließen" (Kontingent erschöpft, Freischaltung eingetragen) |
| `Tuck/PaywallView.swift:370`, `:378` | „Käufe wiederherstellen", „Abo verwalten" |
| `Tuck/PaywallView.swift:351`, `:356` | „Nutzungsbedingungen", „Datenschutzerklärung" (3.1.2-Pflichtangaben aus 1.1) |

**Fix.** Jede Stelle von der Kurzform `Button("…")` / `Link("…", destination:)` auf eine
Label-Closure umgestellt und dort `.frame(minHeight: 44)` + `.contentShape(Rectangle())` gesetzt —
**am Label, innerhalb des Buttons**. Das ist keine Stilfrage: der A8-Fund aus §5.2 steht im
Kommentar von `PrimaryButtonPlate` und sagt genau das Gegenteil dessen, was die Kurzform zulässt —
außerhalb des Buttons gehängte Modifier vergrößern die Layoutbox, nicht die Trefferfläche. `.frame`
bewusst **ohne** `maxWidth: .infinity`: die Höhe wächst, die Breite bleibt die Textbreite (die an
jeder der elf Stellen ohnehin über 44 pt liegt), damit keine Zeile horizontal umbricht oder ihre
Ausrichtung wechselt. Typografie, Farbe, Copy: unverändert.

Zwei Stellen absichtlich nicht angefasst, beide im Test als erlaubt festgehalten: der
`Button("Wecker ausschalten")` **innerhalb des `confirmationDialog`** und das Toolbar-„Schließen"
des Paywalls — iOS zeichnet und bemisst beide selbst.

**Kontrollgruppe, Quellebene.** `TuckTests/HitTargetTests.swift`, zwei parametrisierte Tests über
neun Site-Einträge (elf Kontrollen). Gegen den **Vor-Fix-Stand rot**: 17 Issues, u. a.
`Tuck/BedtimeSetupView.swift: 2 shorthand "Bettzeit entfernen" control(s), expected 0` und
`Tuck/PaywallView.swift:371 "Käufe wiederherstellen" has no minHeight: 44`. Nach dem Fix grün.

**Kontrollgruppe, gerenderte Pixel.** Der Quelltext-Scan beweist die Modifier, nicht die Fläche.
Deshalb zusätzlich am Simulator gemessen (iPhone 17, `<simulator-udid>`, iOS 26.5, 1206 × 2622 px = @3x),
Abstand der Label-Mitten in einem `VStack` bekannter `spacing` — die Boxhöhe ist die Differenz
minus dem Spacing:

| Stelle | vorher | nachher |
|---|---|---|
| „Wecker ausschalten" ↔ „Bildschirmzeit-Zugriff prüfen" (spacing 8) | 772,8 / 798,8 → 26,0 pt Abstand → **18,0 pt Box** | 657,5 / 709,5 → 52,0 pt → **44,0 pt Box** |
| „Bettzeit entfernen" unter der „Bettzeit setzen"-Platte (spacing 20) | — | Plattenunterkante 730,7, Label-Mitte 772,7 → **44,0 pt Box** |
| „Käufe wiederherstellen" ↔ „Abo verwalten" (spacing 14) | — | Oberkanten 388,3 / 446,7 → 58,4 pt → **44 pt Box** |
| „Nutzungsbedingungen" ↔ „Datenschutzerklärung" (spacing 14) | — | Oberkanten 738,0 / 796,0 → 58,0 pt → **44 pt Box** |

Die „vorher"-Zeile stammt aus einem echten Kontroll-Build: die fünf View-Dateien gestasht, neu
gebaut, installiert, dieselbe Stelle angesteuert, gemessen, danach `git stash pop`.

**Ein Nebenbefund, der die Messmethode rettet:** ein Tipp 9,5 pt **oberhalb** der 18-pt-Zeilenbox
löste auch im Vor-Fix-Build noch den Dialog aus — UIKit hat unter dem SwiftUI-Button eine
undokumentierte Touch-Slop. Ein „ich habe danebengetippt und es ging trotzdem"-Test taugt hier also
nicht als Beweis; die Geometrie tut es. Die Slop hilft außerdem weder VoiceOver noch Voice Control
noch Switch Control: die bekommen die Element-Bounds, und die waren 18 pt.

**Drei bestehende Tests mussten mitwandern**, weil sie die Kurzform-Syntax selbst festhielten, die
der Fix ersetzt — jeweils auf dieselbe Absicht neu verankert, nicht abgeschwächt:
`SubscriptionAccessTests.bothLegalLinksAreRenderedOnThePaywallItself` prüft jetzt Label + zugehöriges
`Link(destination:` und schließt einen `Button` weiterhin aus;
`TrialTriggerTests.theExhaustedScreenOffersAWayToThePaywall` prüft `Text("Schließen")` plus
`dismiss()`;
`WakeAlarmCancellationTests.theOffSwitchIsOfferedOnlyForAStoredAlarmAndNotWhileWorking` misst den
Abstand zwischen Gate-Zeile und Button (≤ 2) — dafür wurde der neue Kommentar **über** das `if`
gesetzt statt dazwischen, der Test blieb unverändert.

**Prüfung.** Volle Suite 565/565 grün in 75 Suites (`platform=iOS Simulator,OS=26.5,name=iPhone 17`,
Simulator `<simulator-udid>`). Warnungen: keine neuen — nur die sieben bekannten
`appintentsmetadataprocessor`-Notices. `xcodegen generate` zweimal hintereinander: identische
Prüfsumme, Diff gegen HEAD ausschließlich die vier `HitTargetTests.swift`-Zeilen.

**Was das nicht beweist:** dass ein Daumen die Fläche trifft. Gemessen ist die gerenderte Geometrie
bei Dynamic Type „Large" auf einem Simulator; der VoiceOver-/Größten-Dynamic-Type-Durchgang am
Gerät, der vor jedem Release vorgesehen ist, steht weiter aus.

### Nachtrag 2026-09-10 — 3.1 (Token-Invalidierung beim Gerätewechsel): der Prüfdurchgang, den es nie gab — 1 HIGH, offen

`DeviceChangeGuard`, `DeviceIdentity` und die 18 Tests dazu
liegen seit dem 09.09. auf `master`, hatten aber weder einen Eintrag in dieser Datei noch den
zweiten, getrennten Prüfdurchgang, der für Änderungen am Sperr-Mechanismus vorgesehen ist.
Dies ist dieser Durchgang, auf Simulator
`iPhone 17, OS 26.5` (das Ziel aus `scripts/test.sh`). Er endet nicht bei null.

**Was 3.1 tut.** Ein iPhone, das aus dem Backup eines anderen wiederhergestellt wurde, bringt die
komplette App Group mit: Wecker, Fenster, `morningBlockRegistrationSucceeded == true` und eine
`FamilyActivitySelection`, deren `ApplicationTokens` dem alten Gerät gehören und hier nichts
auflösen. Von innen ist daran nichts als falsch erkennbar — der Shield-Write gelingt, `TokenRefresh`
gibt die toten Tokens unverändert zurück, der Screen sagt weiter „Sperrfenster bis 07:30" über Apps,
die alle aufgehen. Die Asymmetrie, die das auffliegen lässt, ist ein Keychain-Item mit
`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`: die App Group wandert mit, dieses Item nicht.
Weichen beide voneinander ab, fallen die Auswahl und beide Registrierungs-Flags; Wecker und Bettzeit
bleiben (Absicht des Nutzers, keine Behauptung über eine Sperre).

**HIGH, offen — `SystemDeviceIdentityKeychain` hebelt genau die Sicherung aus, die `action()` hat.**
`DeviceChangeGuard.action` (`DeviceChangeGuard.swift:30-44`) ist per Hand über alle acht
Kombinationen von (Identität lesbar/nicht · `lastKnown` gleich/anders/fehlt · Auswahl ja/nein)
geprüft und **korrekt**: keine Kombination löscht die Auswahl eines echten, unveränderten Geräts.
Sie hat sogar eine ausdrückliche Sicherung dafür — `deviceIdentity == nil` ⇒ `.leave`, mit der
Begründung, ein Keychain-Fehler sage nichts darüber aus, welches Gerät das hier ist. Diese nil
erreicht die Funktion nur nie:

- `identity()` (`DeviceIdentity.swift:37`) faltet **jeden** `SecItemCopyMatching`-Status ungleich
  `errSecSuccess` zu nil zusammen. `errSecItemNotFound` („war nie eins da") und
  `errSecInteractionNotAllowed` / `errSecNotAvailable` / `errSecMissingEntitlement` („ist da, ich
  komme gerade nicht ran") sind danach nicht mehr unterscheidbar.
- `current()` (`:66-70`) beantwortet diese nil mit `store(UUID().uuidString)`.
- `store()` (`:52`) ruft `SecItemDelete` **unbedingt** und verwirft das Ergebnis, bevor `SecItemAdd`
  (`:58`) über den Rückgabewert entscheidet. Ein fehlgeschlagener Write lässt die alte Identität
  also nicht in Ruhe — er entfernt sie.

Ergebnis: eine einzige vorübergehende Lesestörung ändert die Identität des Geräts dauerhaft. Der
Schaden ist um einen Start verzögert und deshalb für die bestehende Suite unsichtbar. Start 1:
Keychain kann weder lesen noch schreiben → `.leave`, genau wie entworfen — aber das Item ist weg.
Start 2, dasselbe unveränderte Telefon, gesunder Keychain: leeres Fach, frische UUID, Vergleich
gegen das `lastKnownDeviceIdentity`, das die App Group noch hält → **`.invalidate`**. Die Blockliste
des Nutzers ist gelöscht, ohne dass sich irgendetwas am Gerät geändert hat. Das ist die
Kernfehlerklasse dieses Projekts, nur umgedreht: nicht „meldet Erfolg und tut nichts", sondern
„macht schweigend etwas rückgängig".

**Warum die 18 bestehenden Tests das nicht sehen.** `FakeKeychain.store` weist nur bei Erfolg zu,
modelliert das unbedingte `SecItemDelete` also nicht — der Fake ist an genau der Stelle
nachsichtiger als der Typ, für den er einsteht. `aDeadKeychainLeavesAnArmedDeviceAlone` ist grün,
weil der Fake vergisst zu löschen. Zusätzlich kann das Protokoll `DeviceIdentityKeychain`
(`identity() -> String?`) die Unterscheidung „nicht da" / „nicht lesbar" gar nicht ausdrücken: die
Abstraktionsgrenze liegt exakt dort, wo die eine Information verloren geht, auf die es ankommt.

**Kontrollgruppen-Beweis statt Behauptung.** Vier neue Tests in
`TuckTests/DeviceChangeGuardTests.swift`, alle vier **rot auf dem aktuellen Stand**, mit den echten
Meldungen des Laufs:

- `aTransientKeychainFaultCostsTheSelectionOnTheNextLaunch` (Fake, der `SecItemDelete` mitmodelliert):
  `(keychain.stored → nil) == (identityBeforeTheFault → "E29F3F3E-…")`, dann
  `(run(…) → .invalidate) == .leave` und `(load(from: defaults) → nil) != nil`.
- `anItemThatCannotBeReadIsNotAnAbsentOne` (echter Keychain, Item mit Bytes `FF FE`, das sauber
  liest, aber keine UTF-8-Identität ist): `(DeviceIdentity.current(…) → "7DFED4AF-…") == nil`.
- `anUnreadableItemDoesNotSurviveTheReadThatFailedOnIt`: `(item as? Data → 36 bytes) == (… → 2 bytes)`
  — das vorhandene Item ist durch eine frische UUID ersetzt worden.
- `anUnreadableItemCostsTheSelectionOnTheDeviceThatOwnsIt`: `(decision → .invalidate) == .leave`.

Die drei Keychain-Tests benutzen das nicht lesbare Item als das einzige Nil, das sich im Simulator
deterministisch herstellen lässt; die realistischen Auslöser sind die drei verschluckten
Status-Codes, die dasselbe nil erzeugen.

**Reichweite, ehrlich.** Auf dem heutigen Call-Graph ist der Auslöser schwer zu erreichen:
`DeviceChangeGuard.run` hängt nur an `BlockWindowReconciler.reconcile()`, und das läuft
ausschließlich aus SwiftUI-Vordergrundpfaden (`GutenMorgenView.swift:315`, `:360`,
`SettingsView.swift:225`, `WakeAlarmSetupView.swift:167`) — also immer nach dem ersten Entsperren,
wo `AfterFirstUnlock` erfüllt ist. Was heute schützt, ist der Aufrufgraph, nicht der Code. Und
`DeviceIdentity.swift:16` behauptet ausdrücklich das Gegenteil: „`AfterFirstUnlock` rather than
`WhenUnlocked` because this is read from a launch that can happen while the screen is locked."
Für die aktuellen Aufrufer ist dieser Satz falsch; wer ihn liest und danach handelt — den Guard aus
einem Hintergrund- oder Vor-Entsperr-Start aufruft, was für eine Wecker-App naheliegt — macht den
latenten Defekt scharf. **Kein Fix in dieser Runde:** der Mechanismus kann die Konfiguration eines
echten Nutzers löschen. Der Stand ist bewusst
rot auf genau diesen vier Tests, bis die Richtung des Fixes entschieden ist.

**Die vier Punkte, die kein Befund sind — geprüft, bestätigt korrekt.**

1. **Wahrheitstabelle `action()`**: alle acht Kombinationen von Hand gegen den Code gelaufen. Kein
   Ausgang löscht die Auswahl eines echten, aktuellen Geräts, solange `deviceIdentity` stimmt.
   `("A", "B", false)` → `.invalidate` ist der einzige ungetestete Zweig (löscht eine nicht
   existierende Auswahl und setzt beide Flags auf false) — untestet, aber richtig, weil auf einem
   fremden Gerät ein mitgereistes `true` genauso wertlos ist wie die Tokens. Testlücke, kein Defekt.
2. **Reihenfolge und Absturzsicherheit** (`:70`): die Behauptung stimmt. `.invalidate` schreibt
   `clear` → beide Flags → Identität zuletzt; stirbt der Prozess davor, wiederholt der nächste Start
   dieselbe Invalidierung (idempotent). Stirbt er zwischen `clear` und den Flags, behaupten die
   Flags kurzzeitig ein Fenster über einer leeren Auswahl — sichtbar wird das nie, weil
   `reconcile()` in `GutenMorgenView.swift:315` **vor** `blockRegistrationConfirmed = …` steht und
   den Zustand erst aufräumt. Nuance, die der Kommentar überzeichnet: alle vier Writes gehen in
   dieselbe Suite, also in dieselbe Plist, die als Ganzes geschrieben wird — die Reihenfolge trägt
   nur, falls `CFPreferences` mitten in der Folge flusht. Richtig geschrieben, schwächer garantiert
   als der Kommentar suggeriert.
3. **`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`**: laut Apples eigener Dokumentation zu
   diesem Attribut wandern so markierte Items nicht auf ein neues Gerät und fehlen nach dem
   Wiederherstellen eines fremden Backups — die Wahl trägt also genau das, was 3.1 von ihr braucht,
   und `theStoredItemIsMarkedThisDeviceOnly` pinnt sie am echten Keychain. **Belegstand:**
   aus der Dokumentation, am Gerät hier unverifiziert (ein Restore auf ein zweites iPhone ist der
   einzige echte Beweis und wurde nie gefahren). Nebenwirkung, bewusst: „Alle Inhalte & Einstellungen
   löschen" mit anschließendem Restore auf **dasselbe** Telefon löscht das Item ebenfalls und führt
   zu `.invalidate` — richtig, weil die Tokens danach ohnehin tot sind, aber nirgends notiert.
4. **Allererster Start**: `("A", nil, false)` → `.adopt`, gedeckt von `aFreshInstallOnlyRecordsItself`.
   Auf einem frischen Gerät kommt der erste `run()` ohnehin erst nach dem Onboarding, und der Picker
   stempelt die Identität schon in `.onChange` (`AccessAndAppSelectionView.swift:216-223`), direkt
   nach dem Speichern der Auswahl. Nichts wird gelöscht, was der Nutzer gerade erst angelegt hat.
5. **Zusammenspiel mit der nicht provisionierten App Group (H2/0.2)**: kein Problem, und zwar aus
   einem strukturellen Grund. `run()` liest `lastKnown` und `hasStoredSelection` aus **demselben**
   `defaults`-Objekt — die beiden können sich nie darüber uneinig sein, in welchen Container sie
   schauen. Fällt `UserDefaults(suiteName:) ?? .standard` zurück (oder liefert eine private Suite,
   wie empirisch festgehalten), sieht der Guard einen leeren Container: `lastKnown` nil,
   keine Auswahl → `.adopt`. Die echten App-Group-Daten werden dabei nicht angefasst. Die einzige
   Container-Asymmetrie ist Keychain gegen Defaults, und die Keychain-Seite kann nur eine *frische*
   Identität liefern, nie eine fremde alte — also nie `.invalidate` aus diesem Grund allein.

**Zwei kleinere Funde, mitkorrigiert bzw. notiert.**
`SystemDeviceIdentityKeychainTests` fuhren zu dritt auf demselben einen Keychain-Item, während Swift
Testing standardmäßig parallelisiert — sie waren nur zeitlich grün. Suite jetzt `.serialized`
(nötig, um die neuen Tests überhaupt kollisionsfrei danebenstellen zu können). Und: die Suite hat
**18** Tests, nicht die 21, mit denen sie zu Beginn dieser Runde zitiert wurde — nachgezählt am Lauf
(`Test run with 18 tests in 2 suites`), nicht am Auge.

**Verifiziert:** voller Lauf vor der Änderung `563/563` grün (`TEST SUCCEEDED`), Warnungs-Baseline
unverändert. Nach der Änderung 567 Tests, 4 rot — die vier oben, alle mit der erwarteten Meldung.
`xcodegen generate` ließ `project.pbxproj` unverändert (kein neues File, nur eine geänderte).

**Lehre:** eine Sicherung, die eine reine Funktion sauber implementiert, ist nur so viel wert wie
die Schicht, die ihre Argumente liefert. `action()` fragt korrekt „ist die Identität lesbar?" — und
bekommt von `current()` eine Antwort, die diese Frage gar nicht beantworten kann, weil das Protokoll
dazwischen den Unterschied schon weggeworfen hat. Beim nächsten Review dieser Art zuerst prüfen, ob
der Wert, über den entschieden wird, die Unterscheidung überhaupt noch trägt, die die Entscheidung
braucht.

### Nachtrag 2026-09-10 — 3.1, der Fix: die Schicht unter dem Guard kann „nicht da" jetzt von „nicht lesbar" unterscheiden

Der Fix zum HIGH aus dem Eintrag darüber, auf demselben
Simulator (`iPhone 17, OS 26.5`, das Ziel aus `scripts/test.sh`).
`DeviceChangeGuard.action` ist **unverändert** — die Funktion war korrekt. Falsch war die Antwort,
die sie bekam.

**Der Defekt in einem Satz.** `SystemDeviceIdentityKeychain.identity()` faltete jeden
`SecItemCopyMatching`-Status ungleich `errSecSuccess` zu `nil`, `DeviceIdentity.current()`
beantwortete dieses `nil` mit einer frisch geprägten UUID, und `store()` rief vorher unbedingt
`SecItemDelete`. Eine einzige vorübergehende Lesestörung ersetzte damit die Identität des Geräts
dauerhaft; der nächste Start verglich die frische UUID gegen das `lastKnownDeviceIdentity`, das die
App Group noch hielt, und löschte die Blockliste eines Nutzers, an dessen Telefon sich nie etwas
geändert hatte.

**Der Fix, drei Änderungen, alle in `Tuck/DeviceIdentity.swift`.**

1. `DeviceIdentityLookup` (`.found(String)` / `.absent` / `.unreadable`) ersetzt `String?` im
   Protokoll `DeviceIdentityKeychain`. Nur `errSecItemNotFound` heißt `.absent`. Jeder andere
   Status — `errSecInteractionNotAllowed`, `errSecNotAvailable`, `errSecMissingEntitlement` — und
   auch ein Item, dessen Bytes zurückkommen, aber keine nicht-leere UTF-8-Identität sind, heißt
   `.unreadable`. Die Unterscheidung existiert jetzt genau an der Abstraktionsgrenze, an der sie
   vorher verloren ging.
2. `current()` prägt nur noch bei `.absent`. Bei `.unreadable` gibt es `nil` zurück — und das ist
   exakt die `nil`, für die `action()` seit dem ersten Tag seine `.leave`-Sicherung hat. Die
   Sicherung war nie kaputt, sie war nur unerreichbar.
3. `store()` ist nicht mehr destruktiv: `SecItemAdd` zuerst, bei `errSecDuplicateItem`
   `SecItemUpdate` auf Wert und Accessibility. Kein `SecItemDelete` mehr. Ein fehlgeschlagener
   Write kann das Fach jetzt nicht mehr leeren, egal an welcher Stelle er scheitert.

**Warum 18 grüne Tests darüber lagen.** Zwei Gründe, und der zweite ist der eigentliche.
`FakeKeychain.store()` wies nur bei Erfolg zu und modellierte das unbedingte `SecItemDelete` des
echten Typs nicht — der Fake war an genau der Stelle nachsichtiger als das, wofür er einstand.
Wichtiger aber: `identity() -> String?` konnte den Unterschied „nicht da" / „nicht lesbar"
**gar nicht ausdrücken**, also konnte auch kein Fake ihn ausdrücken, egal wie sorgfältig er
geschrieben war. Ein Fake kann nur so präzise sein wie das Protokoll, das er erfüllt. `FakeKeychain`
hat jetzt ein `readsAreUnreadable`, weil das Protokoll die Unterscheidung jetzt trägt — und
`anUnreadableKeychainRecordsNothingAndOverwritesNothing` fährt sie: `recordCurrentDevice` über einem
belegten, gerade nicht lesbaren Fach schreibt nichts (`writes == 0`) und lässt die vorhandene
Identität stehen.

**Kontrollgruppen-Beweis statt Behauptung.** Voller Lauf gegen den Vor-Fix-Stand (die vier
Tests bereits drin), Meldungen des Laufs verbatim:

```
✘ aTransientKeychainFaultCostsTheSelectionOnTheNextLaunch :281 (keychain.stored → nil) == (identityBeforeTheFault → "50D9C104-759B-48D2-A10A-1EE9C27AB9C9")
✘ aTransientKeychainFaultCostsTheSelectionOnTheNextLaunch :284 (DeviceChangeGuard.run(keychain: keychain, in: defaults) → .invalidate) == .leave
✘ aTransientKeychainFaultCostsTheSelectionOnTheNextLaunch :285 (FamilyActivitySelectionStore.load(from: defaults) → nil) != nil
✘ aTransientKeychainFaultCostsTheSelectionOnTheNextLaunch :286 WakeAlarmStore.blockRegistrationSucceeded(in: defaults → <NSUserDefaults: 0x107f43db0>)
✘ anItemThatCannotBeReadIsNotAnAbsentOne :387 (DeviceIdentity.current(keychain: SystemDeviceIdentityKeychain()) → "0BE8F8AE-54C4-4280-A359-5C5ECE881A55") == nil
✘ anUnreadableItemDoesNotSurviveTheReadThatFailedOnIt :406 (item as? Data → 36 bytes) == (Data([0xFF, 0xFE]) → 2 bytes)
✘ anUnreadableItemCostsTheSelectionOnTheDeviceThatOwnsIt :426 (decision → .invalidate) == .leave
✘ anUnreadableItemCostsTheSelectionOnTheDeviceThatOwnsIt :427 (FamilyActivitySelectionStore.load(from: defaults) → nil) != nil
✘ anUnreadableItemCostsTheSelectionOnTheDeviceThatOwnsIt :428 WakeAlarmStore.blockRegistrationSucceeded(in: defaults → <NSUserDefaults: 0x107f43db0>)
✘ Test run with 567 tests in 74 suites failed after 2.642 seconds with 9 issues.
```

Derselbe Lauf nach dem Fix, ohne dass eine einzige Zusicherung dieser vier Tests angefasst wurde:

```
✔ Test aTransientKeychainFaultCostsTheSelectionOnTheNextLaunch() passed after 0.001 seconds.
✔ Test anItemThatCannotBeReadIsNotAnAbsentOne() passed after 0.002 seconds.
✔ Test anUnreadableItemDoesNotSurviveTheReadThatFailedOnIt() passed after 0.001 seconds.
✔ Test anUnreadableItemCostsTheSelectionOnTheDeviceThatOwnsIt() passed after 0.003 seconds.
✔ Test run with 570 tests in 74 suites passed after 2.349 seconds.
```

**Welches Signal beweist, dass es wirklich passiert ist.** Nicht der grüne Lauf — der beweist nur,
dass die vier Tests nicht mehr auslösen. Der Beweis, dass sie es aus dem richtigen Grund nicht mehr
tun, ist `anUnreadableItemDoesNotSurviveTheReadThatFailedOnIt`: der Test liest das Keychain-Item
**nach** `DeviceIdentity.current()` direkt über `SecItemCopyMatching` zurück und verlangt exakt die
zwei Bytes, die vorher hineingeschrieben wurden. Ein Fix, der die Störung nur anders beantwortet
hätte, aber weiter geschrieben hätte, wäre hier rot geblieben. Und in die Gegenrichtung:
`anEmptySlotIsAbsentAndIsMintedInto` (neu) verlangt am echten Keychain `.absent` für ein leeres Fach
und liest die geprägte Identität als `.found(minted)` zurück — sonst wäre „gib immer `.unreadable`
zurück" ein Fix, der alle vier Tests bestanden und den Guard dabei tot gelegt hätte.

**Was der Fix bewusst nicht tut.** Ein Item, dessen Bytes dauerhaft keine Identität sind, wird
**nicht** überschrieben — `anUnreadableItemDoesNotSurviveTheReadThatFailedOnIt` pinnt genau das. Auf
so einem Gerät ist der Gerätewechsel-Schutz damit dauerhaft aus (immer `.leave`). Das ist die
richtige Seite des Trade-offs und kostet nichts an der Stelle, an der 3.1 wirkt: ein aus einem
fremden Backup wiederhergestelltes Telefon hat wegen `ThisDeviceOnly` ein **leeres**, kein kaputtes
Fach — dort greift `.absent` → prägen → `.invalidate` unverändert.

Eine zweite, kleinere Verhaltensänderung gehört in dieselbe Rechnung, gefunden vom Prüfdurchgang: eine Auswahl, die getroffen wird während das Keychain-Item gerade `.unreadable` ist
(z. B. eine Momentaufnahme während `recordCurrentDevice` läuft), wird vom **neuen** Code beim
nächsten Start invalidiert — `recordCurrentDevice` schreibt bei `.unreadable` nichts, `lastKnown`
bleibt `nil` neben einer inzwischen existierenden Auswahl, der nächste Lauf liest das als
Gerätewechsel. Der **alte** Code hätte in genau dieser Sequenz geprägt, gespeichert und notiert und
wäre bei `.leave` geblieben. Begrenzt (braucht ein bereits leeres App-Group-Fach, also einen
Reinstall, plus ein unlesbares Keychain-Item genau während der Auswahl-Sitzung) und die Art Kosten,
die `action()`s eigener Kommentar (Zeilen 36–41) für den Reinstall-Fall ohnehin akzeptiert — ein
einmaliges erneutes Durchlaufen des Pickers, kein Datenverlust. Aber es ist eine echte
Verhaltensänderung, nicht nur eine Verschärfung, und gehört hier genannt.

**Testlücke aus dem Eintrag darüber geschlossen.** `("A", "B", false)` → `.invalidate`, der einzige
ungetestete Zweig von `action()`, hat jetzt
`aDeviceChangeWithoutASelectionStillDropsTheClaims`: die reine Entscheidung plus der Durchlauf durch
`run()` — keine Auswahl zum Löschen, aber beide Registrierungs-Flags fallen, die Identität wird
notiert, und der zweite Durchlauf liest `.leave`.

**Verifiziert.** `570/570` grün, `** TEST SUCCEEDED **` (567 vorher, plus die drei neuen Tests).
Warnungs-Baseline unverändert: 3 `warning:`-Zeilen bei einem sauberen Build, alle
`Metadata extraction skipped. No AppIntents.framework dependency found.` (eine je Extension) — die
bekannte Baseline, keine neue. `xcodegen generate` ließ `Tuck.xcodeproj/project.pbxproj`
unverändert (keine neue Datei).
**Am Gerät weiterhin unverifiziert** — der einzige echte Beweis für 3.1 als Ganzes bleibt ein Restore
auf ein zweites iPhone, und der wurde nie gefahren.

**Offen geblieben, bewusst.** `DeviceIdentity.swift:17` behauptet weiter, die Identität werde „from a
launch that can happen while the screen is locked" gelesen — für die heutigen Aufrufer (alle im
SwiftUI-Vordergrund) ist der Satz falsch. Er ist jetzt harmlos, weil ein Vor-Entsperr-Start
`.unreadable` → `.leave` bekommt statt einer Neuprägung, aber er bleibt eine unbelegte Behauptung im
Code. Nicht in dieser Runde angefasst (bewusst kein Nebenbei-Umbau); wer das nächste Mal in dieser Datei
ist, korrigiert ihn mit.

**Lehre:** ein Fake kann nur so genau sein wie das Protokoll, das er erfüllt. Wenn ein Test-Double
eine reale Fehlersituation nicht darstellen kann, liegt der Fehler fast nie im Double, sondern im
Typ, der die Unterscheidung schon weggeworfen hat — und dann sind alle Tests, die durch dieses
Double laufen, in genau dieser Hinsicht blind, egal wie viele es sind.

---

### 2026-09-10 — 2.1 zu Ende gebracht: das Token, das seit einem Tag auf zwei Zeilen wartete

**Ausgangslage.** `tuckInk` (`#5A665C`) existiert seit dem 2026-09-09, die Regel dazu
steht in `docs/design/design-system.md` §2.1.3, und `BodyInkContrastTests` belegt, dass der Wert auf
jedem Textgrund der App ≥4,5:1 erreicht. **Angewendet war es an zwei Stellen** — den Footern in
`SettingsView.swift` und der Wochentagszeile in `WakeAlarmSetupView.swift`. Alles andere stand
weiter auf Charcoal Green bei Gewicht 700. Der Zweck des Tokens ist aber nicht die Kontrastzahl,
sondern die fehlende Hierarchie: solange der Fließtext bei 15 pt/700 steht und die Überschrift
darüber bei 20 pt/600, ist der Fließtext **pro Punkt schwerer gesetzt als seine eigene Überschrift**,
und der Screen liest sich als eine Wand gleich lauter Prosa. Das war die ursprüngliche Beschwerde,
und sie war bis heute unverändert wahr.

**Was gemacht wurde.** 24 Aufrufstellen in sechs Dateien auf
`.font(.subheadline.weight(.regular))` + `.foregroundStyle(Color.tuckInk)` umgestellt — das Muster,
das `SettingsView.footer()` seit dem 09.09. trägt und das §3.2 als „Fließtext-Token" führt. Jede
Stelle einzeln beurteilt, nicht gesucht-und-ersetzt: umgestellt wurde, was gelesen werden will;
stehen geblieben ist, was benennt, zählt oder bedient.

| Datei | umgestellt | bewusst bei Gewicht 700 geblieben |
|---|---|---|
| `OnboardingFlowView.swift` | 4 (Willkommens- und Erklär-Absatz, Wecker-Gate-Zeile, Schluss-Zeile) | Chevron-Glyph der Kopfzeile |
| `AccessAndAppSelectionView.swift` | 5 (Statuszeile, Vorschlagszeile, WhatsApp-Notiz, „nichts gewählt", „Auswahl erscheint hier") | „Zugriff erlauben"-Plate, DisclosureGroup-Label „Zählt WhatsApp dazu?" |
| `PaywallView.swift` | 6 (Status-Detail, `capabilityLine` — eine Aufrufstelle, rendert sieben Zeilen: vier in der Plus-Karte, drei bei „Ohne Abo" —, Hinweis-Detail, 3.1.2-Absatz, Schluss-Satz, Testphasen-Banner-Detail) | Kartentitel, „Dein Stand", Plan-Zeilen und Preise, alle Buttons und beide Rechts-Links, Haken-Glyph, die zwei Platzhalter im Kaufbutton-Slot |
| `BedtimeSetupView.swift` | 4 (Gate-Absatz, Fenstersatz und Entfernt-Zeile im Gate, Statuszeile im Setup) | „Plus ansehen", „Bettzeit setzen", „Bettzeit entfernen" (2×) |
| `OverrideFlowView.swift` | 3 (Schluss-Satz des Pickers, Ausgeschöpft-Body, Kontingent-Zeile der Bestätigung) | Kontingent-**Zähler** des Pickers, Atem-Label, Sekunden, Reflexionszeile, alle Plates |
| `WakeAlarmSetupView.swift` | 2 (Statuszeile, Registrierungs-Fehlerzeile) + Wochentagszeile von 13 auf 15 pt | „Wecker stellen", „Wecker ausschalten", „Bildschirmzeit-Zugriff prüfen", Wochentags-Toggles |
| `GutenMorgenView.swift` | **0 — und das ist das Ergebnis, nicht eine Lücke** | alle fünf, s. u. |

**Warum der Guten-Morgen-Screen nicht mitgeht — und ein Korrektur an der eigenen Begründung.**
Vier der fünf Stellen (Subline, `blockWindowLine`, Override-Button, Zahnrad-Glyph) sitzen direkt auf
dem Himmel, und §2.4 hält den bewusst aus der Ink-Tabelle heraus: ein Vier-Stopp-Gradient von
2,44:1 bis 4,16:1, dessen in §8 A29 akzeptierte Spanne gegen `tuckCharcoalGreen` gemessen ist und es
bleibt. Gewicht 400 dort gäbe den Großtext-Pfad (≥14 pt bei 700, Schranke 3:1) auf dem einen Grund
der App auf, der die Kleintext-4,5:1 nicht zurückzahlen kann.

Die fünfte Stelle, die `SpeechBubble`, trägt diese Begründung nicht — ihr Grund ist nicht der Himmel,
sondern `tuckFloatingPlate.opacity(0.9)`, und die steht in §2.4s Ink-Tabelle bei 5,94:1: auf `tuckInk`
bliebe sie deutlich über 4,5:1, auch bei Gewicht 400. Ein Prüfdurchgang hat diese falsche
Prämisse gefunden, die `BodyInkSweepTests` mechanisch fixiert hätte (der Test schließt die ganze
Datei aus, nicht Stelle für Stelle). Der echte Grund, warum die Blase trotzdem bei 700 bleibt, ist
ein anderer: fünf Wörter direkter Maskottchen-Zuruf sind Stimme, nicht Fließtext/Footer/Erklärzeile
im Sinne von §2.1.3 — die Regel trifft eine Rollen-Unterscheidung, keine reine Kontrastrechnung, und
eine Umstellung wäre eine eigene Stimme-Entscheidung, keine Anwendung der bestehenden. Nicht
getroffen, solange dafür kein eigenes Go vorliegt. Kommentar an der Stelle und in
`BodyInkSweepTests.excludedFiles` jetzt entsprechend zweigeteilt.

Die vier Himmel-Stellen bleiben bei 700 aus Kontrastgründen, die Sprechblase aus einem Stimme-Grund
— beide landen im selben Test, aber nicht mehr hinter derselben Behauptung. **Folge, offen und
benannt:** auf den vier Himmel-Stellen ist die ursprüngliche Beschwerde nicht behoben und kann es ohne
eine Palettenentscheidung für den Himmel nicht werden.

**Zwei Urteile, die anders hätten ausfallen können.** (1) Der Kontingent-**Zähler** des
Override-Pickers („3 von 3 heute übrig") bleibt bei 700, die Kontingent-**Zeile** der
Bestätigungsseite wird umgestellt: die erste ist ein Wert und steht allein, die zweite ist die
Erklärzeile unter einem Titel und trägt in einem ihrer beiden Zweige einen ganzen Satz. (2) „Du hast
Plus." und „Preis wird geladen …" bleiben bei 700, obwohl beides Sätze sind — sie stehen im Slot des
Kaufbuttons und behalten dessen Rang; eine Zeile bei Gewicht 400 dort läse sich als Bildunterschrift
statt als „hier gehört etwas hin". Beide Urteile sind mit je einer Zeile umkehrbar, falls sie am
Gerät anders wirken.

**Eine Korrektur an einer der zwei alten Stellen.** Die Wochentagszeile stand auf `.footnote`
(13 pt). §3.2 nennt `.footnote`/`.caption` ausdrücklich als für Fließtext nicht verwendbar, und die
Größenleiter der App ist 20 → 17 → 15. Sie steht jetzt wie jede andere umgestellte Zeile auf
`.subheadline.weight(.regular)`. Damit gibt es **eine** Form des Fließtext-Tokens, keine zwei.

**Der eine Fall, der nicht mit einem Zeilentausch zu lösen war.** In `WakeAlarmSetupView` hängen
Schrift und Farbe an einem `VStack`, in dem zwei Prosa-Kinder **und zwei sekundäre Buttons** stehen.
Ein Tausch am Container hätte die Buttons mitgenommen. Die zwei Prosa-Kinder tragen das Token
deshalb einzeln, der Container behält Charcoal/700 für die Buttons. Am Simulator ist das der
sichtbarste Einzelgewinn der Runde: vorher waren Statuszeile, Fehlermeldung, „Wecker ausschalten"
und „Bildschirmzeit-Zugriff prüfen" typografisch nicht unterscheidbar, jetzt lesen sich die zwei
Bedienelemente als Bedienelemente.

**Kontrollgruppe.** `TuckTests/BodyInkSweepTests.swift` (neu, 4 parametrisierte Tests über 26
gepinnte Stellen und 3 ausgenommene Dateien) auf den **Vor-Fix-Stand** kopiert, in einer
eigenen Arbeitskopie `xcodegen generate`, gleicher Simulator:

```
✘ Test everySweptLineCarriesTheInkTokenAtWeight400(site:) with 26 test cases failed after 0.022 seconds with 25 issues.
✘ Test noSweptFilePutsRunningTextBelowTheLadder(file:) with 7 test cases failed after 0.007 seconds with 1 issue.
✘ Test run with 8 tests in 2 suites failed after 0.038 seconds with 26 issues.
```

25 von 26 Stellen rot — die eine grüne ist der `SettingsView`-Footer, der schon vorher umgestellt
war. Genau diese eine Ausnahme ist der Beleg, dass der Test nicht trivial rot ist, sondern die
Umstellung misst. Der zweite rote Test ist die 13-pt-Wochentagszeile. Nach dem Fix beide grün.

**Welches Signal beweist, dass es wirklich passiert ist.** Nicht der grüne Lauf: ein Test, der nur
`Color.tuckInk` zählt, wäre auch von einer Zeile erfüllt, die das Token trägt und bei Gewicht 700
stehen bleibt — und das wäre die Ratio ohne die Hierarchie, also der halbe Fix mit dem ganzen
Anschein. `everySweptLineCarriesTheInkTokenAtWeight400` verlangt deshalb **beides in derselben
Modifier-Kette** und lehnt ein `.weight(.bold)` darin ab; die Kette ist dabei hart auf die Zeilen
begrenzt, die mit `.` beginnen, weil ein breiteres Fenster das legitime Gewicht 700 des
Nachbar-Texts derselben `VStack` als das eigene gelesen hätte (genau das ist beim ersten Lauf
passiert und war der Grund für zwei Korrekturen an der Testmechanik). Und in die Gegenrichtung:
`noFileCarriesAnInkSiteThatIsNotPinned` verbietet, dass eine Stelle das Token bekommt, ohne in der
Liste zu stehen — ein Token, das sich aus Gewohnheit ausbreitet, hätte den Rollen-Split aus §2.1.3
wieder aufgehoben.

**Ein Grund neu nachgerechnet.** Die vier Onboarding-Zeilen stehen nicht auf Cream, sondern auf dem
Verlauf des Flows, der auf Sage 0.6 über Cream endet — ein Grund, den §2.4 nie geführt hat, weil
dort bis heute nur Charcoal bei 700 stand. `tuckInk` erreicht darauf **4,80:1**, gerechnet mit
derselben WCAG-2.1-sRGB-Methode wie die übrige §2.4 und seit dieser Runde als sechste Zeile in
`BodyInkContrastTests` gepinnt. Dieser Zusatz ist kein Fix, sondern die Dokumentation einer Tatsache,
die vorher niemand geprüft hatte — er ist folgerichtig auf **beiden** Ständen grün.

**Visuell geprüft, nicht nur behauptet.** Signierter Debug-Build für den Simulator, installiert und
gestartet auf **iPhone 17, iOS 26.5 (`<simulator-udid>`)** — derselbe Simulator, auf dem die Tests laufen.
18 Screenshots über den vollständigen Onboarding-Durchlauf, Einstellungen, Paywall und
Override-Picker; jeder angesehen, nicht nur abgelegt. Befund: auf jedem Screen mit umgestellter
Copy liegt der Fließtext sichtbar leichter als Titel und Buttons desselben Screens, keine Zeile
beschnitten, keine unleserlich, keine Layout-Verschiebung. Der Paywall-Fußbereich ist der deutlichste
Beleg — „Käufe wiederherstellen", „Abo verwalten", „Nutzungsbedingungen" und „Datenschutzerklärung"
heben sich jetzt von den zwei Absätzen zwischen ihnen ab, die vorher dasselbe Gewicht trugen. Der
Guten-Morgen-Screen sieht unverändert aus, wie beabsichtigt. Keine Regression gefunden, also keine
zu beheben.

**Verifiziert.** `579/579` grün, `** TEST SUCCEEDED **` (575 vorher — nicht 563, das war mehrere
Einträge alt, s. bereits `570` weiter oben in dieser Datei —, plus die vier neuen
`BodyInkSweepTests`-Funktionen, die zusammen 16 parametrisierte Fälle laufen).
Warnungs-Baseline unverändert: 3 `warning:`-Zeilen, alle
`Metadata extraction skipped. No AppIntents.framework dependency found.` (eine je Extension). Die
`xcodegen generate`-Differenz in `Tuck.xcodeproj/project.pbxproj` ist **genau** die erwartete: vier
Zeilen, die `BodyInkSweepTests.swift` in das Testziel eintragen — dieselbe Form wie im Nachtrag von heute Vormittag,
und der Schritt, dessen Auslassen die neuen Tests lautlos
übersprungen hätte. Kontrollgruppe in einer eigenen Arbeitskopie, danach entfernt.

**Am Gerät unverifiziert.** Das gilt hier enger als sonst: Kontrast und Trefferflächen sind
gerechnet und gepinnt, aber ob 15 pt bei Gewicht 400 in `tuckInk` auf einem echten Display bei
Tageslicht so ruhig liest wie im Simulator, sagt kein Test. Der vor Releases vorgesehene
Accessibility-Durchgang — VoiceOver, größte Dynamic-Type-Stufe, Reduce Motion am Gerät — steht für diese
Änderung noch aus und ist der Punkt, an dem sie zurückgenommen oder auf Gewicht 500 gehoben werden
müsste, falls sie dort zu leicht wirkt.

**Lehre:** ein Token ist nicht gebaut, wenn es kompiliert und seinen Kontrasttest besteht — es ist
gebaut, wenn es an den Stellen steht, für die es erfunden wurde. Zwischen „Token gebaut"
und „Fließtext nicht mehr auf Gewicht 700 gezwungen" lagen einen Tag lang 24 Aufrufstellen, und der
Produktionsreife-Plan (nicht Teil dieses Exports) führte 2.1 in dieser Zeit als zur Hälfte erledigt. Die ehrlichere Buchung wäre
gewesen: die Hälfte, die der Nutzer sieht, war noch gar nicht angefangen.

### 2026-09-11 — Der Trefferflächen-Test, zu Ende geprüft: zwei Lücken zu, eine falsche Anschuldigung raus

**Dieser Eintrag beschreibt keine Verhaltensänderung.** Insgesamt
ist genau **eine** Code-Datei angefasst worden:
`TuckTests/HitTargetTests.swift` (dieser Eintrag selbst ist die zweite Datei). Kein
Produktionscode, keine Copy, kein `project.yml`, keine neue Datei. Geändert hat sich ausschließlich,
**was der Test noch durchgehen lässt**. Das gehört trotzdem
hierher: seit dem 2.3-Eintrag vom 10.09. ist dieser Test die einzige *fortlaufende* Absicherung von
§9 K4 — die Pixelmessung am Simulator dort war eine einmalige Momentaufnahme, der Test ist das, was
bei der nächsten Änderung an einer der fünf View-Dateien noch da ist.

**Lücke 1 (MEDIUM, aus dem Prüfdurchgang): ein Fenster von fünf Zeilen statt einer Struktur.**
Der Scan suchte `.frame(minHeight: 44)` und `.contentShape(Rectangle())` in den fünf Zeilen nach dem
Label. Beide Modifier **unter** die schließende Klammer der Label-Closure zu schieben blieb im
Fenster — und ist exakt der A8-Fund aus §5.2, den 2.3 geschlossen hat: außerhalb des Buttons wachsen
sie die Layoutbox, nicht die Trefferfläche. Kontrollgruppe, Mutation an
`Tuck/OverrideFlowView.swift:369` („Schließen"), gegen den Vor-Härtungs-Stand: **✔ 2 Tests grün**.
Nach der Härtung:

```
✘ everyBareControlCarriesA44ptHitArea :194 (frame → nil) != nil
  ↳ Tuck/OverrideFlowView.swift:370 "Schließen" has no minHeight: 44 inside its label closure
    (:369–:371) — there is one below the label closure's closing brace at :371, where it grows
    the layout box and not the hit area (§5.2, A8)
```

**Lücke 2 (MEDIUM): jede Zeile, die mit `Text(` anfängt, galt als Bedienelement.** Für neun der elf
Kontrollen prüfte nichts, ob überhaupt ein Button darum steht. Den `Button { … } label: {`-Wrapper zu
löschen und ein nacktes `Text("…").frame(minHeight: 44).contentShape(Rectangle())` stehen zu lassen —
eine 44-pt-Box, die kein Bedienelement ist — ging durch. Kontrollgruppe, dieselbe Mutation an
`Tuck/GutenMorgenView.swift:267` („Ich brauche kurz Zugriff") gegen den Vor-Härtungs-Stand:
**✔ 575 Tests in 75 Suites grün**. Der einzige Weg aus einem Sperrfenster hatte aufgehört, ein
Bedienelement zu sein, und nichts im Projekt hat es gemerkt. Nur die zwei Rechts-Links waren
abgedeckt, durch `SubscriptionAccessTests.bothLegalLinksAreRenderedOnThePaywallItself`.

**Fix, Runde 1.** Beide Tests lösen jetzt zuerst den *umschließenden Klammerblock* der
Label-Zeile auf — ein Scanner, der Klammern in String-Literalen und hinter `//` ignoriert und dessen
Bilanzprüfung laut fehlschlägt, falls eine Datei je `"""` oder `/* */` bekommt. Die Modifier müssen
zwischen Label und schließender Klammer stehen, in dieser Reihenfolge; der Block selbst muss eine
Link-Content-Closure oder eine `label:`-Closure mit Button sein.

**Was die zweite Prüfung danach im Fix selbst fand: eine falsche Anschuldigung.** Der Wrapper-Test
sah **genau eine Ebene** nach oben. Ein ganz normaler Icon-plus-Text-Button —
`Button { … } label: { HStack { Image(…); Text("Schließen")… } }` — fiel damit durch, obwohl er
sauber in einem Button steckt: der Block, in dem das Label steht, ist der HStack, der Button sitzt
eine Ebene weiter außen. Heute ist keine der neun Stellen so gebaut, also war nichts rot — aber der
Test war fail-closed auf einer Form, die er akzeptieren **muss**, und benannte im Fehlerfall den
Falschen. Für jeden, der Testausgaben liest, ist das der teurere Teil
des Fehlers: die Meldung schickt ihn zum HStack, wo es nichts zu reparieren gibt.

**Reproduktion — rot, aus dem falschen Grund.** Dieselbe Stelle wie Mutation 1,
`Tuck/OverrideFlowView.swift:369`, diesmal in die Icon-plus-Text-Form gebracht, gegen den
**ungefixten** Test aus Fix-Runde 1:

```
✘ Test everyLabelSitsInsideARealButtonOrLinkWrapper(site:) recorded an issue with 1 argument
  site → Tuck/OverrideFlowView.swift — Schließen at HitTargetTests.swift:221:29: Issue recorded
  ↳ Tuck/OverrideFlowView.swift:372 "Schließen" is not wrapped in a Button or Link: the closure
    it sits in is not a Button label closure and not a Link — it opens with `HStack(spacing: 6) {`
✘ Test run with 3 tests in 1 suite failed after 0.036 seconds with 1 issue.
```

Der Nachsatz der Meldung ist die falsche Behauptung: der Text *ist* in einem Button.

**Fix, Runde 2.** Der Wrapper-Test läuft jetzt die **ganze Kette** umschließender Blöcke
von innen nach außen (`enclosingBlocks`) und ist zufrieden, sobald *irgendein* Vorfahre eine
Button-Label-Closure oder ein `Link(destination:` ist (`opensAControl`). Nur wenn **kein** Block um
das Label herum eine Kontrolle ist, ist es ein Fund — und die Meldung nennt dann den innersten Block,
weil dort jemand zu suchen anfängt. Die Modifier-Prüfung bleibt unverändert am innersten Block.
Dieselbe Icon-plus-Text-Mutation danach: **✔ 3 Tests grün**, die falsche Anschuldigung ist weg.

**Regressionsprüfung — der Fix darf den ursprünglichen Defekt nicht mit blind machen.** Mutation 2
aus Fix-Runde 1 noch einmal gefahren (Button-Wrapper in `Tuck/GutenMorgenView.swift` durch ein nacktes
`VStack` ersetzt), gegen den **gefixten** Test:

```
✘ Test everyLabelSitsInsideARealButtonOrLinkWrapper(site:) recorded an issue with 1 argument
  site → Tuck/GutenMorgenView.swift — Ich brauche kurz Zugriff at HitTargetTests.swift:237:29
  ↳ Tuck/GutenMorgenView.swift:268 "Ich brauche kurz Zugriff" is not wrapped in a Button or Link:
    no closure around it is a Button label closure and none is a Link — the innermost opens with
    `VStack {`
✘ Test run with 3 tests in 1 suite failed after 0.041 seconds with 1 issue.
```

Weiterhin rot, und die Meldung stimmt jetzt auch wörtlich: **keine** Closure um das Label herum ist
eine Kontrolle. Das ist der Beweis, dass die Kette nach oben nicht einfach alles durchwinkt — über
dieser Stelle stehen VStack, ZStack und `body`, aber kein Button.

**Prüfung.** Beide Mutationen zurückgenommen, `git status --porcelain` danach nur noch die Testdatei.
Volle Suite **576/576 in 75 Suites, `** TEST SUCCEEDED **`**,
`platform=iOS Simulator,OS=26.5,name=iPhone 17`, Simulator `<simulator-udid>`
(allein benutzt, keine parallele Testrunde auf demselben Gerät). Sauberer Build: 3 `warning:`-Zeilen,
alle `Metadata extraction skipped. No AppIntents.framework dependency found.` — die bekannte
Baseline, je eine pro Extension, keine neue. `xcodegen generate` ließ
`Tuck.xcodeproj/project.pbxproj` unverändert (keine neue Datei).

**Bewusst offen geblieben**, beide vom Prüfdurchgang als LOW/latent eingestuft und hier nicht
angefasst:

1. *Modifier an einer Geschwister-View.* `everyBareControlCarriesA44ptHitArea` verlangt die beiden
   Modifier irgendwo zwischen Label-Zeile und schließender Klammer, nicht nachweislich **am Label**.
   Diese Lücke wird durch Runde 2 breiter statt enger: die Icon-plus-Text-Form, die jetzt zu Recht
   durchgeht, ist genau die, in der ein `.frame(minHeight: 44)` am `Image` statt am `Text` hinge und
   der Test es nicht auseinanderhalten könnte. Heute existiert keine solche Stelle.
2. *Einzeiler.* Ein Bedienelement, das komplett auf einer Zeile steht, wird vom Blockscan nicht als
   eigene Closure gesehen (`openLine < index` schließt den Block auf der Label-Zeile aus) — die Kette
   fängt dann eine Ebene zu weit außen an. Auch dafür gibt es heute keine Stelle.
3. *Fremder Button.* Ein weiterer Prüfdurchgang (auf Fix-Runde 2, dem Fix für den
   ursprünglichen Ein-Ebenen-Fehler) fand einen neuen, von diesem Fix selbst eingeführten Nebeneffekt:
   `everyLabelSitsInsideARealButtonOrLinkWrapper` prüft seit Fix-Runde 2 „liegt in *irgendeinem*
   umschließenden Bedienelement", nicht mehr „liegt im *eigenen*". Konstruiert und real gefahren:
   den eigenen `Button` an einer Stelle entfernt und den nackten `Text` drei Blöcke tief in die
   Label-Closure eines unbeteiligten Buttons verschoben — der Test bleibt grün, obwohl ein Tipp auf
   die Zeile jetzt die falsche Aktion auslöst (genau die Hausfehlerklasse: der Screen liest sich
   richtig, tut aber etwas anderes). Kein aktueller Aufrufort ist so gebaut; nicht behoben, weil ein
   dritter Fix an derselben Stelle das Risiko erhöht, eine vierte Lücke aufzumachen, statt die dritte
   zu schließen — abnehmender Grenznutzen gegenüber echter Produktarbeit.

**Was das weiterhin nicht beweist:** dass ein Daumen die Fläche trifft. Der Test pinnt die Form an
der Aufrufstelle, nicht die gerenderte Geometrie; der VoiceOver- und Größten-Dynamic-Type-Durchgang
am Gerät steht unverändert aus.

**Lehre.** Ein fail-closed-Test ist nur so gut wie seine Definition von „richtig". Diese hier war um
genau eine Ebene zu eng — und der Schaden wäre nicht der rote Lauf gewesen, sondern die Meldung, die
in die falsche Datei zeigt. Ein Test, der den falschen Schuldigen nennt, kostet mehr Zeit als einer,
der schweigt.

### 2026-09-11 — Der Explain-Schritt bekommt das Tier, der Schrittwechsel eine Richtung (2.4-Dichte, 2.7)

Zwei Änderungen, eine Datei (`Tuck/OnboardingFlowView.swift`), getrennt committet. Simulator `<simulator-udid>` (iPhone 17, iOS 26.5),
allein benutzt — keine parallele Testrunde auf demselben Gerät.

**2.4, die Dichte: das 40-pt-SF-Symbol ist raus, das Maskottchen steht da.** Der Explain-Schritt
öffnete mit `Image(systemName: "hand.raised.fill")` bei 40 pt. Ersetzt durch exakt den Aufruf, mit
dem der Willkommens-Schritt davor öffnet — `MascotView(stage: .start, saturation: MascotStage.start.saturation)`,
dieselbe Stufe, dasselbe Argument. **Kein neues Asset**, also keine Abhängigkeit von 2.8; und der
Nutzer trifft auf den ersten beiden Screens dieselbe Figur statt auf eine Figur und ein Systemglyph.

**Gemessen statt geschätzt, vorher und nachher.** Beide Stände als signierter Debug-Build
installiert (vorher: eigene Arbeitskopie auf dem Vor-Änderungs-Stand, `xcrun simctl uninstall` vor jeder
Installation), Screenshot je Schritt bei Dynamic Type „Large", dann zeilenweise ausgewertet: eine
Bildzeile zählt als „Ink", sobald ein Pixel darin vom eigenen Zeilengrund abweicht — das ist die
Vereinigung der Inhalts-Bounding-Boxen über die Safe-Area-Höhe, also die Methode aus §9.

| Schritt | Größtes Leerband (K2 ≤20 %) | Ink-Anteil (K3 ≥50 %) |
|---|---|---|
| Explain, vorher | 395 pt = **50,5 %** | **24,1 %** |
| Explain, nachher | 302 pt = **38,7 %** | **32,9 %** |
| Willkommen (unverändert) | 290 pt = 37,2 % | 32,6 % |

**Was das heißt und was nicht.** Der Explain-Schritt war der leerste des Flows und ist jetzt so
dicht wie der Willkommens-Schritt — der Unterschied *zwischen* den beiden ist weg. **K2 und K3 sind
weiterhin auf beiden verfehlt**, und keine Änderung an Explain allein kann das ändern: der
Willkommens-Schritt ist baugleich und liegt gleich weit daneben. Der Rest ist Inhalt (§9: „Der Weg
zu 50 % führt über Mascot, Vorschau und Picker — nicht über mehr Wörter"), kein Layout-Handgriff.
**Nebenbefund, der den Produktionsreife-Plan (nicht Teil dieses Exports) korrigiert:** die dort bisher zitierten „~37 % Leerraum,
~33 % Ink" für den Explain-Schritt treffen nach dieser Messung den *Willkommens*-Schritt. Der
Explain-Schritt stand schlechter da, als das Dokument sagte.

**Visuell durchgesehen, nicht nur gerechnet.** Das Rig rendert auf dem Explain-Schritt vollständig:
Körper, Ohransatz, geschlossene Augen (Stufe `.start`), Wangen und der Kontaktschatten darunter,
mittig, nichts abgeschnitten, nichts über den Rahmen hinaus. Titel und Fließtext rutschen um die
Höhendifferenz nach unten und bleiben vollständig sichtbar; der Button steht, wo er stand.

**2.7, die Richtung: der ankommende Schritt fährt ein, der abgehende blendet aus.** Die Richtung
wird an **einer** Stelle gesetzt — im Setter von `step`, vor dem Überschreiben von `storedStep`.
Damit sind alle sieben Aufrufstellen abgedeckt, ohne dass eine davon angefasst werden musste. Die
geschaltete Spalte (`content`) bekommt ein `.id(step)` und die `.transition`; Dauer (0,25 s) und
Reduce-Motion-Gate bleiben unverändert (§8 A16).

**Der Befund, der diese Runde gerechtfertigt hat: die naheliegende, symmetrische Fassung war
falsch.** Gebaut war zuerst genau das, was jede Anleitung schreibt —
`.asymmetric(insertion: .move(edge: forward ? .trailing : .leading), removal: .move(edge: forward ? .leading : .trailing))`.
Am Gerät sah das vorwärts richtig aus. **Rückwärts kreuzten sich die beiden Screens.** Grund: eine
Removal-Transition wird von der View gelesen, die *verschwindet* — also aus deren letztem Render, und
dort steht noch die Richtung des **vorigen** Wechsels. Der erste „Zurück"-Tipp nach beliebig vielen
„Weiter" schickte den alten Screen nach links, während der neue ebenfalls von links hereinkam.

**Nicht abgeleitet, sondern gefilmt.** `xcrun simctl io … recordVideo` über den Tipp, mit `ffmpeg`
in 60-fps-Einzelbilder zerlegt, und je Bild der Abstand zum ersten und zum letzten Bild gerechnet;
„mitten in der Animation" ist, was sich von beiden unterscheidet.

- Vorwärts, defekte Fassung (`fwd.mp4`, f162–f178, 16 Bilder ≈ 0,27 s): Explain zieht nach links ab,
  Permission kommt von rechts. Richtig.
- Rückwärts, defekte Fassung (`back.mp4`, b150–b162): in b153 steht Permission bereits nach **links**
  versetzt („Bildschirmzeit-Zugriff" am linken Rand angeschnitten) und wandert weiter nach links,
  während Explain **ebenfalls** von links einfährt. Zwei Screens, die aneinander vorbeilaufen.
- Rückwärts, gefixte Fassung (`back2.mp4`, c144–c155): Permission steht mittig und blendet aus,
  Explain fährt von links ein. Vorwärts danach gegengeprüft (`fwd2.mp4`, d157–d171): Explain steht
  mittig und blendet aus, Permission fährt von rechts ein.

Der Fix ist deshalb `removal: .opacity` — die Einfahrt trägt die Richtung, weil sie zur View gehört,
die gerade gebaut wird, und die einzige Hälfte ist, der man trauen kann. Das steht als Kommentar an
der Stelle **und** als Test, weil die symmetrische Schreibweise beim nächsten Lesen wieder die
„aufgeräumtere" aussieht.

**Kontrollgruppe.** Testdatei in eine separate Arbeitskopie auf dem Vor-Fix-Stand kopiert,
`xcodegen generate`, nur diese Suite gefahren:

```
✘ theConstantScrollAnchorSurvivedTheRecomposition() :74 (stepIDs.count → 0) == 1
✘ theDirectionIsDecidedBeforeTheStepIsOverwritten() :111 body.firstIndex { $0.contains("movingForward =") } → nil
✘ theStepTransitionIsDirectionalAndReversible() :140 lines[contentRange].firstIndex { $0.contains(".transition(") } → nil
✘ Test run with 12 tests in 1 suite failed after 0.015 seconds with 3 issues.
```

Dazu zwei gezielte Mutationen gegen den **gefixten** Test, beide am echten Code, nicht an einer
Kopie der Idee:

1. *Reihenfolge im Setter vertauscht* (`storedStep` zuerst, Richtung danach — die Fassung, in der die
   Richtung immer „vorwärts" wäre): `✘ :114 (direction → 2) < (overwrite → 1)`. Genau eine Meldung,
   an genau der Zeile.
2. *`.id(step)` auf den ScrollView-Inhalt gehängt* (der A27-Defekt, den diese Runde nicht einreißen
   darf): `✘ (stepIDs.count → 2) == 1`, `✘ (contentRange → 163..<193).contains(index → 154)`,
   `✘ !((stepsRange → 136..<163).contains(index → 154))` — die Meldung nennt die Zeile und die
   Ebene. Der Test prüft seit heute die **Ebene** statt der bloßen Abwesenheit von `.id(step)`;
   in der alten Fassung wäre er an dieser Runde rot geworden, ohne dass ein Defekt vorlag.

**Reduce Motion, am laufenden Simulator umgeschaltet, nicht nur im Code nachgelesen.** Über
Einstellungen → Bedienungshilfen → Bewegung → „Bewegung reduzieren" eingeschaltet (Screenshot des
Schalters im Zustand „an"; `defaults read com.apple.Accessibility ReduceMotionEnabled` → `1`), dann
derselbe Schritttipp gefilmt: **411 Bilder bei 60 fps, kein einziges Zwischenbild.** t206 zeigt den
alten Schritt, t207 den neuen, vollständig an seinem Platz — ein harter Schnitt, keine Fahrt und
kein Überblenden. Das ist das erwartete Verhalten des bestehenden `nil`-Gates (§6.2, zweites
Muster), nicht des Transition-Codes; die `.opacity`-Variante der Transition kommt gar nicht zum
Tragen, weil ohne Animation nichts zu interpolieren ist. Schalter danach zurückgestellt
(`ReduceMotionEnabled` → `0`). Zwei Nebenwirkungen auf dem Simulator, beide zurückgesetzt bzw.
harmlos: ein Fehltipp hatte „Nachrichteneffekte ausführen" ausgeschaltet (wieder an, `= 1`), und der
Umweg über die Einstellungen hat den Schlüssel `ReduceMotionReduceSlideTransitionsPreference = 0`
angelegt — ein Standardwert, keine Verhaltensänderung.

**Prüfung.** Volle Suite **580/580 in 76 Suites vorher → 583/583 in 76 Suites nachher**, beide
`** TEST SUCCEEDED **`, `platform=iOS Simulator,OS=26.5,name=iPhone 17`. Die drei neuen Tests sind
die drei oben. Sauberer Build: 3 `warning:`-Zeilen, alle
`Metadata extraction skipped. No AppIntents.framework dependency found.` — die bekannte Baseline, je
eine pro Extension, keine neue. `xcodegen generate` ließ `Tuck.xcodeproj/project.pbxproj`
unverändert (keine neue Datei — die Tests sind in die bestehende `OnboardingCompositionTests.swift`
gewandert, wo der A27-Pin schon wohnt).

**Was das nicht beweist.** Alles hier ist Simulator. Ob das Maskottchen auf einem echten Display in
Bewegung genauso ruhig wirkt, ob die Einfahrt bei aktiviertem VoiceOver den Fokus richtig setzt und
wie beides bei der größten Dynamic-Type-Stufe aussieht, ist unverifiziert — der Geräte-A11y-Durchgang
nach §6.4 steht unverändert aus. Zwei Dinge, die beim Durchsehen der Bilder aufgefallen sind und
bewusst so bleiben: beim Wechsel Willkommen → Explain sind für ~0,25 s **zwei Maskottchen**
gleichzeitig zu sehen (das eine blendet mittig aus, das andere fährt rechts ein) — Folge davon, dass
jetzt beide Schritte dasselbe Rig tragen; und der `permission`-Schritt dahinter ist mit Abstand der
leerste des Flows, was diese Runde nicht angefasst hat.

#### Nachtrag 2026-09-11 — Was die Prüfrunde an dieser Runde gefunden hat

Vier Funde, alle bestätigt und behoben, plus eine Test-Härtung.
Simulator wie oben, `<simulator-udid>` (iPhone 17, iOS 26.5), allein benutzt.

**HIGH — das `.id(step)` war nie tragend, und es hat A27 seine Regel gekostet.** Der Eintrag oben
schreibt „Die geschaltete Spalte (`content`) bekommt ein `.id(step)`", gebaut auf der Annahme, ohne
wechselnde Identität feuere die `.transition` nie. Die Annahme ist falsch: ein `switch` in einem
`@ViewBuilder` ist ein `_ConditionalContent`, dessen Identität schon mit dem Zweig wechselt — genau
das Entfernen-und-Einsetzen, das eine `.transition` braucht — und `Group` reicht den Modifier an
dieses Kind durch, statt eine stabile Hülle davorzusetzen. Schwerer als das überflüssige `.id`
wiegt, was mit der falschen Annahme begründet wurde: §6.4 und A27 sagten vorher glatt
**„Nicht `.id(step)`"**, und die Änderung hat daraus eine Ebenen-Regel gemacht („die Ebene
entscheidet, nicht das Wort") und den Test `theConstantScrollAnchorSurvivedTheRecomposition` von
*Abwesenheit* auf *höchstens eins, an der richtigen Stelle* umgeschrieben. Eine Regel, die seit
2026-09-05 aus einem echten Fehler stammt, wurde also gelockert, um einen Code zu erlauben, der sie
gar nicht brauchte. Das `.id(step)` ist raus; Regelwortlaut in §6.4 und A27-Zelle sind wieder exakt
der Stand von vor dieser Runde; der Test steht wieder auf der harten Abwesenheitsprüfung.

**Selbst nachgemessen, nicht von der Prüfrunde übernommen.** Signierter Debug-Build des
*eigenen* gefixten Standes installiert (`xcrun simctl uninstall` davor), `simctl io … recordVideo`
über beide Richtungen (explain → permission und zurück), `ffmpeg` in Einzelbilder zerlegt. Je Bild
die horizontale Verschiebung des **ankommenden** Screens gegen dessen eingerastetes Standbild
gemessen: Spaltenprofil der Ink im Band y = 500–1750 px, normierte Kreuzkorrelation über Shifts von
±420 px, Ergebnis in Punkten (3 px/pt).

| Bild | vorwärts: `permission` | zurück: `explain` |
|---|---|---|
| 1 | **+140,0 pt** (corr 0,54) | **−136,0 pt** (corr 0,85) |
| 2 | +114,7 (0,84) | −122,7 (0,96) |
| 3 | +79,3 (0,94) | −86,0 (0,97) |
| 4 | +49,3 (0,98) | −54,7 (0,98) |
| 5 | +26,0 (0,99) | −30,0 (0,99) |
| 6 | +10,7 (0,999) | −13,3 (0,99) |
| 7 | +2,0 (1,000) | −3,3 (0,997) |
| 8 | 0,0 (1,000) | 0,0 (1,000) |

Vorwärts monoton von der Trailing-Kante herein, rückwärts monoton von der Leading-Kante — ohne das
`.id(step)`. Der **abgehende** Screen steht in beiden Richtungen bei 0 pt und blendet nur aus; im
Mittenbild der Rückwärts-Fahrt steht „Bildschirmzeit-Zugriff" mittig und blass, während der
Explain-Titel links angeschnitten hereinkommt. Kein Kreuzen. Die Ablation der Prüfrunde ist damit
am tatsächlich committeten Code bestätigt, nicht nur übernommen.

**MEDIUM — der Reduce-Motion-Kommentar im Code war schlicht falsch.** Er behauptete „Under Reduce
Motion the travel goes and the fade stays". Es bleibt auch kein Fade: `.animation(nil, value: step)`
eine Ebene höher lässt nichts zu interpolieren übrig, der Wechsel ist ein harter Schnitt — genau das,
was der Absatz oben („411 Bilder bei 60 fps, kein einziges Zwischenbild") und §6.1 schon korrekt
sagen. Kommentar korrigiert. Weil im Zweifel der Code gilt, ist er die Quelle, der ein
späterer Leser glaubt; ein falscher Kommentar neben richtigem Code ist deshalb die teuerste Variante
dieses Widerspruchs.

**LOW — die Richtung las den unsanitisierten Wert.** Der Setter verglich
`newValue.rawValue >= storedStep`, also gegen den **rohen** gespeicherten Int, obwohl der Getter drei
Zeilen darüber durch `OnboardingStep.resuming(from:)` läuft, dessen eigener Doc-Kommentar erklärt,
warum ein Wert außerhalb des Bereichs zu `.welcome` auflösen muss. Bei gespeichertem 99 (Downgrade
von einem neueren Build, fremder Schreiber) zeigte der Screen den Willkommens-Schritt, und das erste
„Los geht's" rechnete `1 >= 99` → falsch: der allererste Tipp des Flows fuhr von der Zurück-Seite
herein. Jetzt `newValue.rawValue >= step.rawValue`, weiterhin vor dem Überschreiben gelesen.

**LOW — die Zeilennummer in der Kontrollgruppe oben stimmte nicht** (`:140` für
`theStepTransitionIsDirectionalAndReversible`). Der rote Lauf ist mit den heutigen Tests neu
gefahren — Testdatei in eine separate Arbeitskopie auf dem Vor-Fix-Stand kopiert, `xcodegen generate`, nur diese Suite:

```
✘ theDirectionIsDecidedBeforeTheStepIsOverwritten() :103:29 body.firstIndex { $0.contains("movingForward =") } → nil
✘ theStepTransitionIsDirectionalAndReversible()    :134:25 lines[contentRange].firstIndex { $0.contains(".transition(") } → nil
✘ Test run with 12 tests in 1 suite failed after 0.024 seconds with 2 issues.
```

Zwei statt drei Meldungen, und das ist die ehrlichere Zahl: `theConstantScrollAnchorSurvivedTheRecomposition`
ist seit heute wieder der **alte** Test von 2026-09-05, kein neuer — er ist auf dem Vor-Fix-Stand
grün, weil er dort nie etwas zu beanstanden hatte. Rot gegen den Vor-Fix-Stand sind genau die zwei
Tests, die diese Runde neu gebracht hat.

**Mutationen gegen den gefixten Code, in eigener Arbeitskopie** — jede einzeln angewandt,
Suite gefahren, Quelle danach byte-gleich zurückgeschrieben:

| Mutation | Ergebnis |
|---|---|
| Setter-Reihenfolge vertauscht | ✘ `:106` `(direction → 2) < (overwrite → 1)` |
| Richtung liest wieder `storedStep` | ✘ `:108` `.contains("newValue.rawValue >= step.rawValue")`, ✘ `:110` `!(… .contains("storedStep"))` |
| `.id(step)` zurück auf die geschaltete Spalte | ✘ `:69` `!(code.contains { $0.contains(".id(step)") })` |
| `.id(step)` auf den ScrollView-Inhalt (der A27-Defekt) | ✘ `:69`, dieselbe Meldung |
| `removal: .move(…)` statt `.opacity` | ✘ `:182`, `:183`, `:185` |
| `.transition` über elf Zeilen umgebrochen, Semantik unverändert | ✔ **grün**, 12/12 |

Die zweite Zeile ist die Kontrollgruppe für den `storedStep`-Fund: der Test wäre gegen die alte
Fassung rot gewesen. Ein Live-Repro dafür gibt es nicht zu bauen — die beiden Ausdrücke
unterscheiden sich nur auf Werten, die der Getter dem Rest der View nie zeigt.

**Test-Härtung (dieselbe Klasse, die den A27-Test schon einmal getroffen hat).**
`theStepTransitionIsDirectionalAndReversible` verglich eine exakte Quellzeile
(`insertion: .move(edge: movingForward ? .trailing : .leading).combined(with: .opacity)`) und nahm
starr `prefix(4)` Zeilen. Jetzt wird der `.transition(…)`-Aufruf klammerbalanciert eingesammelt und
in seine Teile zerlegt: Insertion mit `.move`, richtungsabhängig über `movingForward`, beide Kanten,
kombiniert mit `.opacity`; Removal mit `.opacity`, ohne `.move` und ohne `movingForward`. Die letzte
Mutation oben ist der Beleg, dass das etwas ändert: gegen den reinen Umbruch liefert die **alte**
Zusicherung `block.contains(<exakter String>)` → `False`, die neue in allen sechs Teilprüfungen
`True` (nachgerechnet an genau dieser umgebrochenen Quelle).

**Prüfung.** Volle Suite **583/583 in 76 Suites**, `** TEST SUCCEEDED **`,
`platform=iOS Simulator,OS=26.5,name=iPhone 17`. Sauberer Build des App-Targets: 3 `warning:`-Zeilen,
alle `Metadata extraction skipped. No AppIntents.framework dependency found.` — die bekannte
Baseline, je eine pro Extension, keine neue. `xcodegen generate` ließ
`Tuck.xcodeproj/project.pbxproj` unverändert.

**Was das nicht beweist, und ein Fund, der stehen bleibt.** Alles Simulator; der Geräte-A11y-Durchgang
nach §6.4 steht unverändert aus, und ob der Reduce-Motion-Schnitt am Gerät genauso hart ist, ist hier
nicht erneut gemessen worden (die Messung oben im Haupteintrag gilt weiter — an ihr hat sich im Code
nichts geändert, nur der Kommentar). **Bewusst nicht angefasst:** der Kommentar über dem
`ScrollViewReader` in `steps` spricht von „the 0.6 s step animation … cross-fades across" — beides
veraltet (0,25 s seit 2026-09-09, richtungsgebend seit heute). Die Zeile stammt aus einer früheren Runde, nicht
aus dieser, und fällt damit unter „nur anfassen, was der Task verlangt"; sie gehört in die
nächste Doku-/Kommentar-Runde.

### 2026-09-13 (Design-Handoff, Phase 1) — Der Keim am Morgen null, ein Atem fürs ganze Haus, und drei Doku-Zeilen, die der Code längst überholt hatte

**Eine Änderungsserie**, fünf Schritte (plus dieser Nachtrag, der die Zahlen unten nach dem
Rebase geradezieht). Die ersten drei sind gebaut und je einzeln nachgeprüft worden (am Artefakt,
nicht an der Zusammenfassung des Bauenden); der vierte
schließt, was dieser Prüfdurchgang an LOW zurückgab, der fünfte zieht den
Konfliktfreiheits-Satz nach, der sich beim Aufschreiben selbst ungültig gemacht hatte. Kein BLOCKER, kein HIGH.

**Der Sprössling fängt bei Morgen null an, als Keim.** `sprout(sway:)` öffnete mit
`if stage != .start`: die Wachstums-Mechanik, auf der das Produktkonzept steht, zeichnete in der
ersten Nutzerwoche **gar nichts**. Stufe 0 trägt jetzt einen 8,4-pt-Keim (0,06 des 140-pt-Körpers)
in Sage mit der 0,5-Ink-Kontur des Blattes, auf einem Stiel bei 0,6 Länge. Das ist nicht die dritte
Stufe derselben Skalierung: ein einzelnes `.scaleEffect(stage == .eingespielt ? 1.0 : 0.6)` schrumpfte
Stiel und Blatt gemeinsam, „Warm geworden" konnte also keinen längeren Stiel haben, ohne zugleich ein
kleineres Blatt zu behalten als die Stufe darüber. Die drei Stiellängen (0,6 / 0,8 / 1,0) sind seitdem
eine eigene Achse, der `scaleEffect` ist weg und nicht ersetzt. Der Shield zeichnet den Keim mit
(`TuckShield/ShieldMascotIcon.swift`, PNG neu gerendert) und bleibt stufenlos — was eine Stufe
verrät, sind die Blätter, und die zeichnet er nicht. Sein Sprössling-Offset ist −62 statt −70:
eine auf −70 zentrierte Spalte ragt zur Hälfte über die Oberkante, was ein SwiftUI-`.frame` nicht
beschneidet, `ImageRenderer` aber schon — der erste Render committete einen abgeschnittenen Stummel.

**Ein Hausatem statt drei unverbundener Literale.** §6.5 hatte 11,0 s für die ganze App
entschieden und die Entscheidung dann als drei Literale stehen lassen: zweimal als Summe von vier
Phasendauern (`MascotView.BreathPhase`, `OverrideFlowView.OverrideBreathPhase`) und einmal roh in
`MorningSky`s `sin(t * 2 * .pi / 11.0)`. `Tuck/Motion.swift` hält sie jetzt einmal, alle drei lesen
von dort, und `breathCycle` ist aus den vier Phasen **abgeleitet** statt danebengeschrieben — eine
Summe neben ihren eigenen Summanden ist dieselbe Drift, nur eine Datei kleiner. Hygiene, kein Fix:
alle drei Stellen waren vor der Änderung nachweislich identisch, es gab nichts zu reparieren. Was es
gab, ist der Mechanismus, den §6.5s eigener Schlussabsatz beschreibt — eine Phase an einer Stelle
nachziehen und die anderen zwei lautlos desynchronisieren.

**Drei Doku-Korrekturen und eine bewusst notierte Absage.** §9.3s zweite K4-Zeile las
noch „offen — Zahnrad-Overlay, Phase 2.5"; das Zahnrad steht seit dem 09.09. Mitgeschrieben,
weil es kein Dokument trug: das gebaute Zahnrad sitzt auf einer schwebenden Platte, die die
Handoff-Spec nicht vorsah — mit Grund, denn der alte Textbutton saß **unten** im Himmel, wo Charcoal
nie unter 3,40:1 fällt, das Overlay sitzt oben, im einen Band, wo es das tut (~~2,48:1~~ 2,44:1 auf Dawn Shadow, Zahl korrigiert 2026-09-14, s. den Eintrag vom 2026-09-13 und §2.4
bei Fortschritt 0). Zweitens ist der `tuckInk`-Rollout als abgeschlossen bestätigt, mit beiden
Ausnahmen in §2.1.3 statt nur im Audit-Log — sie sind aus **verschiedenen** Gründen draußen, und
genau diese Unterscheidung ist der Teil, der aufgeschrieben gehört. Drittens hält §2.6 als „Bewusst
notiert" fest, dass das Maskottchen-Körper-Token `#C8D6C2` vorgeschlagen und **abgelehnt** wurde, mit
den Zahlen: drei von vier Meilenstein-Inks fallen dagegen unter 3:1 (Charcoal 2,99:1, DustyBlue
2,91:1, WarmSand 2,73:1, nur SoftLavender hält mit 3,15:1), einschließlich der Default-Ink, die jeder
Nutzer ab Tag eins sieht. Das ist die einzige dauerhafte Spur dieser Entscheidung — ein externes
Handoff-Dokument außerhalb dieses Repos führt die Farbe weiter an mehreren Stellen.

**Was der Prüfdurchgang zurückgab: fünf LOW, zwei davon echte Testlücken.** Beide in
`TuckTests/SproutStageTests.swift`, beide von derselben Art — eine Prüfung, die etwas Wahres
behauptet und dabei die Frage nicht stellt, auf die es ankommt:

1. **Der Keim und der Knospen-Zeichencode wurden nie zusammengebracht.** Geprüft wurde, dass
   *irgendwo* in `sprout(sway:)` ein `case .seed:` steht, und dass *irgendwo* in `MascotView.swift`
   eine `bud`-Zeichnung existiert. Ein `.seed`-Zweig, der ein `leaf` zeichnet, erfüllt beides — der
   Keim, der ganze Punkt von 1.4, wäre ein kleines erstes Blatt gewesen, und nichts wäre rot geworden.
2. **Drei Stiellängen wurden als Zeichenketten entdoppelt, nicht als Zahlen.** `Set(["Self.stemLength
   * 0.6", "Self.stemLength * 0.8", "Self.stemLength"])` beweist, dass die drei Ausdrücke
   verschieden **geschrieben** sind. `Self.stemLength` neben `Self.stemLength * 1.0` sind zwei
   Zeichenketten und eine Länge.

**Kontrollgruppe — beide Lücken real gefahren, nicht behauptet.** Eigene Arbeitskopie,
zwei Mutationen gleichzeitig an `Tuck/MascotView.swift`: der `.seed`-Zweig zeichnet `leaf` statt
`bud`, und `.oneLeaf` bekommt `Self.stemLength * 1.0` (dieselbe Länge wie `.twoLeaves`, andere
Schreibweise). Gegen die **alten** Tests:

```
✔ Test run with 592 tests in 78 suites passed after 2.553 seconds.
** TEST SUCCEEDED **
```

Ein Sprössling, bei dem jede Stufe ein Blatt zeigt und zwei Stufen denselben Stiel haben, ging
vollständig durch. Dieselben zwei Mutationen gegen die **gehärteten** Tests:

```
✘ Test theThreeStagesDrawThreeDifferentStemLengths() recorded an issue at SproutStageTests.swift:135:9:
  Expectation failed: (Set(multipliers).count → 2) == (multipliers.count → 3)
  ↳ Tuck/MascotView.swift: two sprout stages compute the same stem length:
    [("seed", Optional(0.6)), ("oneLeaf", Optional(1.0)), ("twoLeaves", Optional(1.0))]
✘ Test onlyTheSeedBranchDrawsTheBud() recorded an issue at SproutStageTests.swift:156:17:
  Expectation failed: (crown → "sproutColumn(stemLength: Self.stemLength * 0.6) { leaf }").contains("bud")
  ↳ Tuck/MascotView.swift: the .seed branch draws no bud, it draws:
    sproutColumn(stemLength: Self.stemLength * 0.6) { leaf }
✘ Suite SproutSourceTests failed after 0.010 seconds with 2 issues.
✘ Test run with 593 tests in 78 suites failed after 2.292 seconds with 2 issues.
** TEST FAILED **
```

**Die Härtung.** Ein `sproutBranchBodies()`-Helfer zerlegt den Funktionsrumpf in die drei
`case`-Zweige und lässt die `case`-Zeile selbst weg — ohne das ist jede Frage nach „was zeichnet der
Keim" in Wahrheit eine Frage danach, was die Funktion irgendwo zeichnet, und die Antwort ist für alle
drei ja. Darauf: `onlyTheSeedBranchDrawsTheBud` verlangt `bud` im Zweig des Keims und verbietet ihn
in den beiden anderen (nur die eine Richtung zu prüfen ließe „jede Stufe zeichnet eine Knospe"
durch) und verlangt dort je ein `leaf`. `theThreeStagesDrawThreeDifferentStemLengths` parst den
Faktor aus jedem Zweig — ohne `* <Zahl>` ist er 1,0 — und vergleicht **Zahlen**: drei Stück,
paarweise verschieden, und aufsteigend, weil es eine Wachstumstabelle ist. Beides bleibt ein
Quelltext-Scan (`#filePath`, dieselbe Form wie `BodyInkSweepTests` und `HitTargetTests`) und wird
bewusst **kein** Laufzeittest über das Enum: `MascotStage.start.sproutStage == .seed` kompiliert vor
der Änderung nicht, und ein Compile-Fehler ist keine rote Kontrollgruppe.

**Die drei übrigen LOW** waren Beobachtungs-, keine Code-Lücken und sind mit diesem Eintrag erledigt:
die fehlende Audit-Log-Buchung dieser Arbeit, und die zwei Sachen, die grün aussehen und es nicht sind
(unten).

**Verifiziert.** `593/593` in 78 Suiten, `** TEST SUCCEEDED **` (592 vorher, plus
`onlyTheSeedBranchDrawsTheBud`) — **gemessen auf dem Stand vor dem Rebase**.
Nach dem Rebase sind es an derselben Arbeit **596/596 in 78 Suiten**
(`** TEST SUCCEEDED **`, nachgemessen am 14.09.): die drei zusätzlichen kommen
aus dem Eintrag vom 2026-09-11 (Explain-Schritt, Schrittwechsel), nicht aus dieser Runde. `platform=iOS Simulator,OS=26.5,name=iPhone 17` über
`scripts/test.sh`, Simulator `<simulator-udid>` (das einzige `iPhone 17` unter
iOS 26.5, auf das diese Zielangabe fallen kann). Die drei Läufe dieser Runde — Kontrollgruppe gegen
die alten Tests, Kontrollgruppe gegen die gehärteten, Endlauf — liefen **nacheinander** auf diesem
Gerät, nie gleichzeitig. Warnungs-Baseline
unverändert: sauberer Build (eigenes DerivedData, damit der inkrementelle Lauf nicht null Warnungen
vortäuscht) genau **3** `warning:`-Zeilen, alle `Metadata extraction skipped. No AppIntents.framework
dependency found.`, eine je Extension, keine neue. `xcodegen generate` ließ
`Tuck.xcodeproj/project.pbxproj` unverändert — diese Runde legt keine Datei an.
Kontrollgruppe in einer eigenen Arbeitskopie, danach entfernt.

**Am Gerät unverifiziert — zwei Stellen, an denen grün nicht „es funktioniert" heißt.**

1. *Das Shield-PNG ist nie in einer echten `ShieldConfiguration` gesehen worden.* Geprüft ist, dass
   die gerenderte Datei eine vollständige Knospe zeigt (zurückgelesen, nicht nur geschrieben) — nicht,
   dass iOS sie im Sperrbildschirm anzeigt. Der Simulator startet die Shield-Extension strukturell
   nie. Der abgeschnittene Stummel des ersten Renders ist genau die Fehlerform, die hier ohne echtes
   Gerät unsichtbar bleibt.
2. *Der Übergang `seed → .oneLeaf` ist nie beobachtet worden.* Er braucht **sieben echte Morgen**.
   Gepinnt sind die Stufenzuordnung (`MascotMilestoneTests`) und die Form der Zeichnung
   (`SproutStageTests`); dass die Animation an Morgen 7 auf einem echten Gerät auch läuft, sagt
   davon keiner. Der Keim selbst ist am Simulator gesehen (Screenshot bei `.start`, iPhone 17 /
   iOS 26.5), der Wechsel nicht.

**Eine dokumentierte Abweichung von der Reihenfolge, ohne Schaden — inzwischen aufgelöst.** Die
Onboarding-Änderung vom 2026-09-11 (Explain-Schritt, Schrittwechsel) sollte laut ursprünglicher
Reihenfolge vor dieser Serie landen. Als dieser Eintrag zuerst geschrieben wurde, war sie noch nicht
gelandet, und diese Serie saß direkt auf dem damaligen Hauptstand. Der Prüfdurchgang hatte die
Zusammenführung mit einem echten Drei-Wege-Merge nachgestellt: **konfliktfrei**. Der Schritt, der
diesen Satz aufgeschrieben hat, hängte selbst neue Zeilen ans Ende derselben Datei
(`docs/audit-log.md`, dieser Eintrag hier), und die Onboarding-Änderung hängte ihren eigenen Eintrag
ab derselben Basis ans Ende derselben Datei — womit ein erneuter Merge-Test einen **Konflikt in
`docs/audit-log.md`** meldete: ein reiner Text-, kein Logik-Konflikt, null Code-Überschneidung, die
zweite gemeinsame Datei (`docs/design/design-system.md`) mergte weiter sauber.

**Was daraus geworden ist.** Die Onboarding-Änderung ist gemergt, diese Serie ist auf den neuen
Hauptstand rebased — der Rebase ist der Vorgang, der die Vorhersage oben eingelöst hat. Der
Text-Konflikt in `docs/audit-log.md` trat genau wie beschrieben auf und wurde genau wie angekündigt
aufgelöst: **beide datierten Einträge behalten**, der 2026-09-11er vor dem 2026-09-13er (dieser hier)
— nachzählbar an den `### `-Überschriften in dieser Datei. Kein Code-Konflikt, `design-system.md`
mergte sauber, die Zusammenführung wurde als konfliktfrei gemeldet. Also eine Reihenfolge-Abweichung
mit Beleg, kein offenes Risiko; der Preis war ein Rebase und die Zahlen-Korrektur, die dieser
Nachtrag nachträgt.

**Lehre.** Zwei Prüfungen, die einzeln wahr sind, prüfen zusammen nicht das, was zwischen ihnen
liegt. „Es gibt einen `.seed`-Zweig" und „es gibt eine Knospen-Zeichnung" waren beide wahr,
während der Keim ein Blatt hätte sein können. Und eine Entdopplung ist nur so gut wie das, worauf
sie angewendet wird: über Zeichenketten misst sie Schreibweisen, über Zahlen misst sie Längen.

---

## Nachtrag 2026-09-16 — Runden ohne Eintrag, nachgezogen

Dieser Log endete am 2026-09-13. Die Lücke fiel beim Neuschreiben von
`docs/SSOT.md` auf und wurde als wichtigster Doku-Rückstand benannt — der Log hat nach dem Code die
höchste Präzedenz unter den Statusquellen, und eine Quelle, die vier Tage fehlt, ist für diese vier
Tage keine.

**Was diese Einträge sind und was sie nicht sind.** Sie sind aus den Beschreibungen und den
Commit-Nachrichten der jeweiligen Runde **rekonstruiert**, nicht aus einem eigenen Mess- oder
Prüflauf. Jede Zahl unten ist die des Bau- bzw. Prüfdurchgangs jener Runde, zu deren Datum sie
gehört; keine ist am 2026-09-16 nachgemessen worden. Wo eine Zahl zählt, gilt der Code-Stand der
jeweiligen Runde, nicht dieser Absatz.

### 2026-09-14 (Design-Handoff, Phase 2) — Die Marke bekommt zwei Farben und einen Zaun, das Icon einen echten Himmel

**Eine Änderungsserie**, drei Schritte. Der Plan ging durch
**zwei Review-Runden**: Runde 1 kein BLOCKER, sechs echte HIGH; Runde 2 nach
Einarbeitung ein weiterer HIGH — die Kontrast-Korrektur, die der Plan an sich selbst vorgenommen
hatte, war durch Abschneiden statt Runden entstanden. Die Serie folgt durchgehend den
nachgerechneten Zahlen, nicht denen des Handoffs.

**`Color.BrandPalette` und ein Zaun darum.** `dawnRed = #E0674C`,
`dawnRedDeep = #A84028`, direkt hinter `LightPalette` und **außerhalb** des
`#if canImport(UIKit)`-Gates. Die Platzierung ist mechanisch, nicht kosmetisch:
`tools/render-app-icon.sh` kompiliert `Color+Palette.swift` in eine reine macOS-Binärdatei ohne
UIKit und liest beide Werte dort als Tokens. Drei Kontrastverhältnisse sind als **exakte
Gleichheiten** gepinnt (Hausrundung, kein `accuracy:`-Band — ein Toleranzband hätte das Schloss
aufgehoben): `#17201B` auf `#E0674C` **4,94** (Handoff: 5,0), `#A84028` auf `#F5EFE6` **5,36**
(5,2), `#F5EFE6` auf `#E0674C` **2,96** (2,9). Die dritte ist die, auf die es ankommt — sie ist die
Paarung, die der Handoff selbst verbietet, und der Testname sagt das.
`BrandPaletteContainmentTests` scannt **alle fünf kompilierten Verzeichnisse** und erlaubt
`BrandPalette` an genau einer Stelle, ihrer eigenen Definition, **ohne Ausnahme** — zwei Carve-outs
aus früheren Planentwürfen hat die Review-Runde beide als grundlos verworfen.

**Kontrollgruppe, gefahren statt behauptet.** Grün auf einem sauberen Baum beweist über ein
Grep-Schloss nichts. Gepflanzter Verstoß: `let _ = Color.BrandPalette.dawnRed` ans Ende von
`Tuck/WakeAlarmScheduler.swift` — die AlarmKit-Tönung, eine Nicht-View-Datei, die eine „scanne die
Views"-Fassung des Tests durchgewunken hätte. Der Scan geht auf dem `Tuck`-Argument rot, der
Definitionsstellen-Test bleibt grün. Danach zurückgenommen.

**Der Boden hört auf, einen Himmel zu spielen.** Nur die Hintergrundebene: raus flaches
Charcoal plus Radiallift plus geblurrter Dusty-Rose-Schein, rein ein linearer Vier-Stop-Verlauf
`#17201B` 0 % → `#3E4A41` 42 % → `dawnRedDeep` 78 % → `dawnRed` 100 %. Körperfarbe, die
0,55-Kontur-Überzeichnung und das Rig bleiben unangetastet. Die zwei warmen Stops sind
`BrandPalette`-Tokens; die zwei kühlen sind Literale mit je einem Kommentar an Ort und Stelle —
`#17201B` ist **identisch mit `nightInk`** und nur deshalb ein Literal, weil `DarkPalette` hinter
dem UIKit-Gate sitzt und diese Datei kein UIKit hat; `#3E4A41` entspricht keinem Token.

**Die Kontrastzahl als benannter Fehlbetrag, nicht als erreichtes Ziel.** Gegen einen Verlauf gibt
es kein einzelnes Verhältnis — Sage läuft 12,50:1 gegen den obersten Stop und 2,53:1 gegen den
untersten. Gemessen wird das Minimum entlang der sichtbaren Körperkante, also die Unterkante der
Körper-Ellipse bei y ≈ 195,25 von 256. Am gerenderten PNG abgelesen: **4,70:1**; gegen den reinen
`#A84028`-Stop 4,59:1, sechs Punkte tiefer 4,50:1. **Der Handoff verlangt ≥ 4,8:1, das erreicht es
nicht** — 0,10 bis 0,30 zu wenig, je nach Messpunkt. In `design-system.md` §5.10.2 als bewusster
Fehlbetrag protokolliert, dieselbe Behandlung wie B1 in Phase 1, nicht in einen Erfolg gerundet.
Trotzdem genommen, und die Verbesserung ist größer als sie aussieht: die früher dokumentierten
3,40:1 waren das **flache Feld**, nicht der Render — am selben Punkt misst das alte Icon **2,88:1**,
also unter 3:1. Die Bewegung ist 2,88 → 4,70. Geprüft wie schon die vorige §5.10.2-Änderung:
gerendert und **bei 60 px nebeneinander** verglichen, nicht „das PNG angeschaut".
`TuckTests/AppIconAssetTests.swift` läuft **unverändert** grün — es prüft den geflachten Alphakanal,
den diese Änderung nicht berührt.

**2.4, und warum daraus ein Doku-Vermerk wurde.** **Es wurde kein zweiter Sprössling
gezeichnet.** Phase 1.4 hatte längst einen auf den Kopf von `TuckShield/ShieldMascotIcon.swift`
gesetzt (Knospe 8,4 pt, Stiel bei 0,6, eigener −62-Offset) — nachgelesen, bevor irgendetwas
geschrieben wurde, weil der ganze 2.4-Abschnitt des Plans auf dieser Prämisse steht. Die
Handoff-Aufgabe wörtlich zu bauen hätte einen doppelten Sprössling auf die meistgesehene Fläche der
App gesetzt. Zwei Punkte derselben Aufgabe bleiben offen, je mit Grund in §5.12: der „Simplified"-
Körpertausch braucht eine Schwanz-Geometrie, die es im Repo nirgends gibt (Suche über alle fünf
kompilierten Verzeichnisse plus `tools/` und `TuckTests/` nach tail/paw/Schwanz/Pfote: null
Zeichen-Treffer), und das separate „Signet" ist doppelt blockiert — Morgenrot darf keine
Produktfläche betreten, und der Shield ist eine (seit dem ersten Schritt dieser Serie mechanisch erzwungen). Ein
monochromer Ersatz hätte die erste Sperre umgangen statt sie zu lösen.

**Bewusst nicht in dieser Serie:** Aufgabe 2.3 (Instrument Serif bündeln) hängt am
ausdrücklichen Go des Projektinhabers zum Download einer Schriftdatei, und das lag nicht vor. Quelle geprüft (SIL OFL),
die versteckten Schritte notiert; 2.1/2.2/2.4 hängen nicht daran.

**Verifiziert.** `scripts/test.sh` nach dem letzten Commit: **602 Tests in 80 Suiten,
`** TEST SUCCEEDED **`** (vorher 596/78). Warnungs-Baseline auf sauberem Build (`xcodebuild clean`
vorweg) unverändert bei genau **3** `appintentsmetadataprocessor`-Notices, keine weitere
Warnungszeile. XcodeGen-Drift **nach jedem Commit** geprüft: beim ersten Schritt ist der pbxproj-Diff exakt
die zwei neuen Testdatei-Referenzen und sonst nichts (8 Insertions, 0 Deletions) — `TuckTests` ist
eine Verzeichnis-Referenz in `project.yml`, das wurde nachgesehen statt angenommen; Schritt 2 und 3
driftfrei.

**Was das nicht beweist.** Simulator-Grün heißt, die Logik hält, nicht dass das Icon auf Hardware
richtig aussieht — der 60-px-Vergleich ist ein gerenderter Downscale, kein Homescreen. Die
Kontrastzahlen sind gerechnete WCAG-2.1-sRGB-Verhältnisse gegen das gerenderte PNG: die stärkste
hier verfügbare Messung, und immer noch kein Gerät.

### 2026-09-14 (Design-Handoff, Phase 3, descoped) — Eine Geometrie-Quelle, ein Wort für jedes Gesicht, drei Flächen, die das Tier endlich tragen

**Eine Änderungsserie**, neun Schritte. Volle Suite grün nach **jedem** davon. Zwei
Review-Runden: Runde 1 ein echter BLOCKER (durch das Descoping aufgelöst) plus fünf echte
HIGH, Runde 2 den Blocker sauber bestätigt und vier weitere HIGH an den Rändern der Fixes.

**Zwei Produktentscheidungen des Projektinhabers sind eingebaut.** Spezies und Schwanz vertagt — und der
„geschlossene Sprössling im Dunkeln" **abgelehnt**, weil er sich bei der Prüfung als echter
Regressionsbug herausstellte: ein Nutzer auf „Eingespielt" hätte seinen Sprössling zur Knospe
zurückfalten sehen, gekoppelt ans Erscheinungsbild statt an die Uhr, die das Quellmaterial meinte.

**Eine Quelle für die Maße des Rigs statt vier.** Die rund 20 Zeichenkonstanten lagen in
`MascotView.swift`, in den **Default-Parametern** von `MascotSurfaces.swift`, in
`tools/AppIconComposition.swift` und in `TuckShield/ShieldMascotIcon.swift`. §8 A13 trug das mit
„erwähnen, nicht eigenmächtig zusammenlegen"; der Handoff beauftragt die Zusammenlegung ausdrücklich
— also mergen die **Konstanten** und die **Zeichnungen** nicht. `Tuck/MascotGeometry.swift` ist
Foundation-only, und genau das lässt es in die Shield-Extension und in beide macOS-Render-Binaries
kompilieren. Jede bewusste Abweichung von Icon und Shield gegenüber dem Bildschirm-Rig ist dort ein
benannter Eintrag statt einer stillen Scan-Ausnahme.

**Byte-Identitäts-Beweis, und warum er so gefahren wurde.** Beide PNGs zuerst **frisch aus dem
Eltern-Commit** auf dieser Maschine gerendert — nicht aus den eingecheckten Bytes genommen, die
Toolchain-Drift seit dem letzten Render zu einer falschen Baseline gemacht haben könnte — danach
erneut nach dem Refactor. `AppIcon.png` und `ShieldMascot@3x.png` beide identisch. Das ist ein
**einmaliger** Beweis über einen Commit und **kein** laufender SHA-256-Abgleich; einen solchen hat
dieses Repo nie gehabt und diese Runde legt keinen an. §4.4 sagt seitdem genau das statt dessen, was
sie vorher behauptete. Was läuft, ist `MascotGeometryContainmentTests`: vorher rot in jeder
gescannten Region (20 Issues), nachher grün.

**Vier Augen, fünf Münder und ein Wort für jedes.** `MascotEyeState`,
`MascotMouthShape`, `MascotGaze`, `MascotEarPose`, `MascotExpression` und `MascotPose` — letzteres
**ist** `bodyStack(sway:)`, extrahiert, keine neu geschriebene vierte Komposition des Rigs. Es ist
zustandslos; Atem, Entrance, Taps und Idle-Schleife bleiben in `MascotView`. Der Mund bleibt **ein**
`Smile`-Pfad in vier Rahmengrößen, damit das Gähnen weiter morpht statt zu kreuzblenden; `.smallO`
ist ein Kreis und deshalb ein eigener Zweig, als einzige Ausnahme benannt, und keine Fläche animiert
über ihn hinweg. Sieben der zehn Expression-Sheet-Zustände sind gebaut, die anderen drei stehen in
`MascotExpression.Unbuilt` statt angenähert zu werden.

**Die Mechanik-Grenze hat gehalten, und zwar bewiesen statt behauptet.** `MascotStage.eyesOpen`
bleibt exakt `stage != .start`. Die erste Fassung des Wächters war
`MascotStage.start.eyesOpen == false` — die prüft einen Bool, der existiert, und sagt nichts über
einen, der nicht existieren soll. Kontrollgruppe gefahren: mit einem in `MascotStage` verdrahteten
`var eyeState: MascotEyeState` (`.warmGeworden → .half`) blieben die drei exakten
`eyesOpen`-Gleichheiten **grün**, beide Scan-Hälften wurden **rot**. Manipulation zurückgenommen.

**Das Tier sitzt im Atemkreis.** `.breathing`, Augen zu, ein kleiner offener Mund
Ø4 → Ø8 → Ø4 auf dem Phasen-Animator des Kreises selbst. Unter Reduce Motion bewegt sich der Mund
weiter, während der Kreis stillsteht: eine Rahmengröße ist eine Formänderung, keine Transformation —
A17s eigene Einordnung, dieselbe, die Blinzeln, Blinzeln-Kneifen und Wangen erhält. Dieser Screen
las vorher **keinen** Fortschrittszustand. Eine fest verdrahtete Stufe wäre das dokumentierte
Anti-Pattern gewesen („eine falsche Stufe wäre schlimmer als keine"), also liest er dieselben zwei
Stores wie `GutenMorgenView` und `SettingsView`. Skalierung 0,7 und Offset +12 sind **hergeleitet**,
und `MascotRigFitTests` ist die Herleitung statt einer Behauptung darüber: Sprossen-Spalte 19 pt,
Oberkante −79,5 bzw. −80 mit Kontur, Kreisradius 55 — 55/80 = 0,6875 würde ganz ohne Offset passen.
Die enge Bedingung ist nicht der Boden des Körpers bei 50,5, sondern seine untere **Flanke** bei
52,70. **Am Render nachgemessen:** entferntestes Kontur-Pixel 52,61 pt vom Kreismittelpunkt gegen
einen gemessenen Radius von 55,33, an der unteren linken Flanke, genau da, wo die geschlossene Form
es hinlegt.

**„Dein Weg" hat endlich eine Spur davon, wessen Weg.** `.waiting`, auf der echten
Stufe, in dem Abschnitt, der **immer** sichtbar ist und `MascotStage.progressDescription` schon
trug — nicht in „Dein Tuck", das erst nach 45 Morgen auftaucht und einen Farbwähler mitbringt. Eine
eigene Zeile, `accessibilityHidden`, weil die Zeile darunter denselben Fakt in Worten sagt.

**Die Farbe von C3 und C4, und die ehrliche Hälfte davon.** Sage-Körper auf Sage-Grund ist
**1,0644:1** (Atemkreis) und **1,1259:1** (Settings-Zeilen) — unter den 1,1673:1, die dieses Projekt
für die deaktivierte Platte bereits akzeptiert. **Alle drei** Sage-Elemente bekommen eine
Kontur-Überschreibung, weil genau so die Ohren (Default-Ink 0) verschwinden, während der Körper
seine Kante behält; der Stiel hatte vorher gar keine Kontur-Option. Das hebt die sichtbare Kante auf
**1,9565:1** und **2,0697:1** — weiter **unter** dem 3:1-Boden für Nicht-Text, als solches
protokolliert statt weggerundet, dieselbe Behandlung wie der 4,70er-Boden des Icons und A29s
Himmelsverlauf. Nur eine volle Ink-Kontur würde ihn räumen (3,6149 / 3,8240) und würde das Tier auf
diesen zwei Flächen in eine Strichzeichnung verwandeln. Geprüft durch Hinsehen, nicht nur durch
Rechnen: Simulator-Screenshots bei Ø110 und Ø180 und die Settings-Zeile an beiden Enden des Bereichs
(Stufe „Eingespielt" und Stufe „Start" bei Sättigung 0,35, dem blassesten Bild, das die App je
zeigt).

**Anwesenheit über der Reconsider-Zeile.** `.attentive` hätte hier die Ohren nach vorn
gelegt und geradeaus geschaut, was über der Entscheidung eines Menschen leichter als *beobachtet
werden* liest denn als *begleitet werden*. `.waiting` ist der bewusste Hebel — ehrlich qualifiziert:
bei 0,45 trägt die **Ohrenhaltung** den Unterschied, der Seitenblick steuert etwa einen Punkt bei
(gemessen: Pupillen 3,05 px rechts der Mundachse). Das ist eine **benannte Ausnahme** in §5.14, kein
stiller Widerruf davon: `.accessibilityHidden(true)`, kein Trait, kein Label. **Die Zeile verschiebt
sich, und die Doku sagt es:** vorhergesagt (63 + 28)/2 = 45,5 pt nach unten, vorher/nachher am
selben Screen gemessen 362,7 pt → 408,0 pt = **45,33 pt**. `ReconsiderCopy` bleibt buchstabengleich.

**Ein eigener Körperton fürs Dunkle.** Das Tier war in Midnight Sage gezeichnet,
demselben Wert, mit dem die Settings-Zeilen und Sekundärplatten gefüllt sind, und stand mit
1,3558:1 auf der Seite. `tuckMascotBody`: hell byte-genau `LightPalette.sage`, dunkel `#3A4A40` —
dasselbe dunkle Sage, angehoben, kein neuer Farbton — und damit **1,7742:1**. Alle **sechs**
Füllungen schalten um (zwei Ohren, Körper, Stiel, Knospe, Blätter), ein Quelltext-Scan pinnt die
sechs. Die vier Monds-Inks darauf liegen zwischen 5,9764:1 und 6,1883:1 (vorher 7,8204 bis 8,0977
auf Midnight Sage). Ein drittes unabhängiges Nachrechnen vor dem Aufschreiben hat einen Wert bewegt:
Moon Dusty Blue ist 6,18827…, auf vier Stellen **6,1883**, getragen worden war 6,1882.

**Der Test, der lautlos falsch geworden wäre.**
`DarkMascotColorVariantContrastTests.everyVariantClearsTheNonTextThresholdOnTheMascotsOwnBody` löste
`.tuckSage` auf. Kontrollgruppe gefahren statt durchdacht: mit der alten Zeile und dem neuen Token
läuft die ganze Suite weiter grün — **grün, während sie eine Farbe prüft, die das Tier nicht mehr
trägt**, exakt die Fehlerklasse, vor der dieses Projekt ausdrücklich warnt. Der Test ist
**umgebogen**, nicht ergänzt worden.

**Die B-=-128-Herleitung, ausgeschrieben und bewusst nicht gebaut.** Das Ausschreiben
hat den Befund zweimal geändert: die Schwanz-Freiraum-Zeile ist **dieselbe Ungleichung** wie die
Leinwand-Zeile, nur von der anderen Seite gelesen (also drei unabhängige Beobachtungen, nicht vier),
und die „0,64 pt Reserve" eines früheren Entwurfs ist **nicht herleitbar** — die Tabelle sagt
nirgends, wo das Ring-Zentrum des Schwanzes relativ zum Körper sitzt. Drei Beobachtungen schließen
B = 140 aus und landen zwischen 126,6 und 130,2; 128 ist der einzige exakte Wert darin. Die
Gegenevidenz steht daneben: der heutige 140 × 110-Körper erfüllt das 0,79-Höhenverhältnis der
Tabelle bei B = 140 auf 0,6 pt genau. Mitkorrigiert: §5.10.2 sagte dreimal in einem Absatz, das Icon
müsse „nach Phase 3" neu gerendert werden — Phase 3 mergt **ohne** Schwanz, alle drei (plus eine
vierte Erwähnung in §8) zeigen jetzt auf die Anatomie-Runde, sonst schickt dieser Merge einen Leser
auf die Suche nach einem schmaleren Icon, das ihm niemand schuldet.

**Verifiziert.** Volle Suite über `scripts/test.sh` nach **jedem** Commit, nicht nur am Ende; final
**633 Tests in 85 Suiten, `** TEST SUCCEEDED **`**. Sauberer Build: Warnungs-Baseline genau **3**
`appintentsmetadataprocessor`-Notices, nichts Neues. `xcodegen generate` plus
`git diff --exit-code Tuck.xcodeproj/project.pbxproj` nach jedem Commit; Drift war immer nur der
eigene Eintrag der neuen Dateien und ist am HEAD null. Beide gerenderten PNGs am Ende der Serie erneut
byte-identisch zum Ausgangsstand. Eigene Arbeitskopie.

**Nicht in dieser Runde, jeweils mit Grund:** Aufgabe 3.2, die Anatomie-Neuzeichnung (Schwanz,
Pfoten, Ohren-Asymmetrie, Schnauzenschatten, größere Augen, schmalerer Mund, 8°-Stielneigung,
zweites kleineres Blatt) — der Schwanz des Handoffs macht Tuck zum Siebenschläfer, während
dem Illustrationsbrief (nicht Teil dieses Exports), ein lebendes Dokument, das zusammen mit einem Screenshot des
heutigen Rigs an eine Illustration gehen soll, bewusst „ein Kuscheltier **ohne festgelegte
Spezies**" beschreibt; ein Schwanz vor dieser Beauftragung hätte Brief und eigenen Screenshot in
Widerspruch gesetzt. Ebenfalls draußen: der Übergang B 140 → 128 (folgt aus dem Schwanz und aus
nichts sonst), 3.5(c) der Simplified-Shield-Körper (braucht dieselbe Geometrie) und 3.5(a) der helle
Körper `#C8D6C2`, der auf B1s Zahlen aus Phase 1 abgelehnt bleibt.

### 2026-09-14/15 (Design-Handoff, Phase 4) — Token-Sanierung, Accessibility, und ein DoD-Punkt, der beim Abnehmen übersprungen worden war

**Eine Änderungsserie**, zehn Schritte. Letzte der vier Handoff-Phasen — vier
Aufgaben plus ein abschließender Definition-of-Done-Check über den **gesamten** Handoff, weil es
keine Phase 5 gibt, die etwas Übersehenes noch auffängt.

**Layout-Token-Schicht (`Tuck/Layout.swift`, 15 Konstanten).** Löst eine bereits dokumentierte, aber
nie durchgesetzte Skala ein (`spacing:`/`cornerRadius:`), einschließlich der zwei Radius-12-Stellen,
die den A10-Entscheid nicht kannten, und `hitMin` mit einem echten Rot-vor-Grün-Beweis. Der
ursprünglich geplante Beweis hätte **nichts** gefangen — Review-Fund, per Kontrollgruppe bestätigt,
und der korrigierte fängt es.

**Motion-Token-Schicht (`Tuck/Motion.swift` erweitert).** Rund 45 von 78 echten Zeitliteralen
benannt — nur die in der Doku bereits entschiedenen Rollen, nicht jedes Literal. Die
Reduce-Motion-Fallenstellen sind gegen alle drei bekannten Scan-Lücken gehärtet (Mehrzeiler,
Funktionsstart-Guards, legitime Bestandspins).

**Statustext bei A11y-Größen.** Schwebende Platte hinter dem Status-Block ab
`dynamicTypeSize >= .accessibility1`, mit unabhängig nachgerechneten — nicht aus dem Handoff
übernommenen — Kontrastwerten. Dazu ein **zweites Signal** auf der Hinweiskarte (2-pt-Kontur), damit
die Karte sich nicht mehr allein über Farbe meldet.

**Messmethoden-Deklaration (§2.4).** Hex- und Float-Komposition weichen bei mehreren Kontrastwerten
in der zweiten Nachkommastelle voneinander ab (2,44/2,45/2,48; 3,41/3,42; 3,66/3,67). Jetzt einmal
verbindlich festgeschrieben, welche Methode gilt, statt dass jede künftige Nachrechnung dieselbe
Verwirrung reproduziert.

**Prozess.** Plan → Review-Runde 1 (8 reale HIGH, kein Blocker) → Konsolidierung →
Review-Runde 2 (2 weitere reale HIGH, darunter der Befund, dass 4.4 die Methoden-Lektion aus
4.1 nicht auf sich selbst angewendet hatte) → Fix → Bau → **Prüfrunde**. Die Prüfrunde fuhr die volle
Suite erneut, rechnete alle in dieser Phase gepinnten
Zahlen eigenständig nach und ging alle **elf** DoD-Punkte des Handoffs einzeln gegen den
ausgelieferten Code durch — elf, nicht zehn: Punkt 11 fehlte in jeder bisherigen Zählung.

**Der Fund der Prüfrunde, hier schon behoben.** §8.1, der in dieser Phase neu
angelegte DoD-Abnahme-Record, ging die Punkte 6, 9 und 11 durch — aber nicht Punkt 7 (App-Icon-
Kontrast ≥ 4,8:1). Ausgerechnet den einen von elf, der faktisch **nicht** erfüllt ist: Kontrast-Boden
4,70:1, ein bereits akzeptierter, benannter Phase-2.2-Entscheid, keine Regression dieser Phase. Ein
Abnahme-Record, der genau den unerfüllten Punkt auslässt, ist die Doku-Variante des lautlosen
Ausfalls. Reine Doku-Ergänzung, kein Code.

**Verifiziert.** **659 Tests / 91 Suiten, `** TEST SUCCEEDED **`, zweimal gelaufen** (in
der Bau- und in der Prüf-Arbeitskopie). Warnungs-Baseline unverändert bei den drei bekannten
`appintentsmetadataprocessor`-Notices. `xcodegen generate` plus pbxproj-Drift-Check in **beiden**
Arbeitskopien ohne Drift.

**Bewusst nicht Teil dieser Phase** (benannt in §8/§5.10.3): Schwanz-/Pfoten-/Anatomie-Neuzeichnung
(wartet auf die Spezies-Entscheidung), Instrument-Serif-Download (wartet auf das Go des Projektinhabers),
App-Icon-Neurendering nach der Anatomie-Runde.

### 2026-09-15/16 — Die Spezies steht fest: Igel

**Reine Doku.** Kein App-Code betroffen. Die Maskottchen-Illustration selbst und das zugehörige
Briefing-Material sind nicht Teil dieses Exports.

Das Briefing trug bis hierher bewusst „ohne festgelegte Spezies" (die
Formulierung, an der Phase 3 den Schwanz hat scheitern lassen). Die Recherche (DACH-Kultur,
globaler Markt, Bindungspsychologie, Wettbewerb) endet auf **Igel**.

**Der Einwand ist dokumentiert, nicht darum herum geschrieben.** Der Igel ist nachtaktiv und hält
Winterschlaf, also im falschen Takt für eine App, die um 6:30 weckt. Gelöst nicht durch Verschweigen
und nicht durch eine biologische Behauptung, sondern als erzählerische Geste: das Tier wacht nicht
routinemäßig auf, es wacht **für den Nutzer** auf, im selben Moment wie der Wecker.

**Die Wachstumsstufen werden dadurch konkret statt offen:** Jungigel kommen stachellos zur Welt, die
Stacheln entwickeln sich sichtbar — das passt 1:1 auf die drei bestehenden Stufen, ohne eine neue
Mechanik zu verlangen.

**Was das nicht ist: gebaut.** Die Igel-Anatomie steht im Briefing, nicht im Code — eine Suche nach
`spike|hedgehog|igel` über alle fünf kompilierten Verzeichnisse liefert null Treffer. Ob echte Igel-Anatomie ins Rig geht oder das Rig generisch bleibt, bis die Illustration da
ist, ist seitdem eine offene **Produktentscheidung**, kein Bau-Rückstand.

### 2026-09-15/16 — Ein unverdienter Kanal: Jahreszeiten, ein Fundstück, und vier Zellen, in denen eine Berührung nichts tat

**Eine Änderungsserie**, **22 Schritte**
(die letzten drei sind die Nachbesserungen aus der Prüfrunde). P5 (Responsivität) und P6
(Reziprozität) aus der Maskottchen-Recherche: „Niedlichkeit erzeugt den ersten Kontakt.
Responsivität und Reziprozität erzeugen den hundertsten."

**Drei Review-Runden auf den Plan, bevor Code entstand — jede mit echten Funden, keine
Formsache.**

1. **Runde 1: ein BLOCKER** plus 11 HIGH und 12 LOW. Der Blocker: der Idle-Timer-Fix war
   spezifiziert, ohne dass irgendein Test zwischen „korrekt", „No-Op" und „der Idle-Loop stirbt nach
   der ersten Reaktion" hätte unterscheiden können.
2. **Runde 2** (nach Fix): 5 HIGH, 5 LOW — darunter eine Kontrast-Abbruchbedingung, die für die
   *falsche* Sommer-Variante geschrieben war, und ein Monotonie-Test, der auf dem heutigen Code
   selbst nicht monoton war.
3. **Runde 3** (nach Fix): 1 HIGH, 6 LOW — eine echte Timing-Kollision zwischen dem neuen
   Entrance-Halt und der Wangen-Haltezeit von `beam()`, plus eine fehlende Summierungsregel zwischen
   zwei additiven Wangen-Schreibern.

**Was gebaut wurde.** Teil A: ein dezenter saisonaler Partikel-Layer (Frühling/Sommer/Herbst/Winter)
im Hintergrund des Guten-Morgen-Screens, mit vier Monatsgrenzen einmal als Funktion statt als
Gefühl. Teil B, Responsivität: der Idle-Takt redet nicht mehr in jede Reaktion hinein; die
Still-Face-Lücke — **vier von sechzehn Zellen ohne Antwort** — ist geschlossen; ein abgeschlossener
Morgen bekommt einen Mund, den kein Tap hat; das Tier sieht jeden Morgen kurz auf statt nur nach
einer langen Pause. Nachtrag: ein **Fundstück**, alle vierzehn Tage ein anderes, bedeutungslos, ohne
Zähler, ohne Bewertung — ein Geschenk, das der Nutzer nicht selbst hineingelegt hat.

**Kontrollgruppen tatsächlich ausgeführt, mit Vorher/Nachher-Zahlen.** Sechs
Stück; die lehrreichste ist die dritte: bei der Extraktion von `MorningSky.stops` geht die vom Test
**tatsächlich gelesene** Zahl rot, während die alte, falsche Kopie grün bleibt — genau der Fund, der
die Extraktion überhaupt nötig machte. Dazu die vier benannten Still-Face-Zellen
(`Tap 1/2/3 × Reduce Motion × eyes open`), vor dem Fix real rot, danach grün. **Acht Abweichungen
vom Plan**, jede begründet — u. a. eine eigenständige `ImageRenderer`-Messmethode für
die Sommer-Kontrastbedingung, weil die bestehenden §2.4-Helfer einen geblurrten Radialverlauf
strukturell nicht ausdrücken können.

**Prüfrunde**, zweite frische Arbeitskopie: eigener Testlauf, eigene Nachvollziehung
von fünf der sechs Kontrollgruppen (alle bestätigt), eigene `ImageRenderer`-Nachmessung der
Sommer-Kontrastzahlen (max. 0,01 Abweichung zur Bau-Runde), Simulator-Screenshots für die zwei vom
Plan offen gelassenen Fragen.

**Offene Frage 1, beantwortet: kein Kontur-Rückfall für Herbstblatt und Frühlingsblüte in Hell.**
Gemessenes Kanaldelta gegen denselben Himmel ohne Partikel: Herbst 11–17/255, Frühling 14–25/255.
Sichtbar, aber **chromatisch statt luminanzbasiert** — der Luminanzkontrast von 1,15–1,48:1 aus der
Bau-Runde unterschätzt die tatsächliche Sichtbarkeit systematisch. Ein Rückfall auf eine Kontur
(wie bei der Winterflocke) würde den Akzent in dieselbe Konstruktion zwingen wie den Winter und ihm
seine einzige Rolle nehmen. **Auflage:** beim mehrtägigen Gerätelauf (Phase 0) auf einem echten
Display bei niedriger Helligkeit mitprüfen — das kann kein Simulator zeigen.

**Offene Frage 2 — und der HIGH, der aus ihr wurde: der Wangen-Kanal trägt die Antwort bei
`.eingespielt` nicht.** Peak-Kanaldelta gegen ruhende Wangen, `MascotPose` gerendert:

| Stufe | Hell: tap 0/1/2/3 | Dunkel: tap 0/1/2/3 |
|---|---|---|
| `.start` | 15/6/5/4 | 52/18/13/8 |
| `.eingespielt` | **5/5/4/4** | 17/15/11/8 |

Bei `.eingespielt` in Hell liegt der gesamte Wangenkanal bei 4–5 von 255 — im Rauschen, nicht als
drei Schritte unterscheidbar. Der eigentliche Fund ist schärfer: **die Zelle „Tap 1 · Reduce Motion ·
eyes open true"** — eine der vier, die diese Runde schließen sollte — hat bei `.eingespielt` unter
Reduce Motion **nur diesen einen, nicht wirksamen Kanal**. Mechanisch beantwortet („keine Berührung
bleibt unbeantwortet"), perzeptuell nicht. Das ist die Fehlerklasse dieses Projekts in einer
Animation: ein Erfolgspfad, der meldet, dass er gelaufen ist, und nichts bewirkt. **Beide im Plan
vorbereiteten Fallbacks lösen es laut Messung nicht** — Fallback A verteilt denselben 0,13-Kopfraum
nur anders, Fallback B hebt die Decke nicht, weil Dusty Rose über dem hellen Körper insgesamt nur
etwa 25/255 Spanne hat; das ist eine neue Erkenntnis der Prüfrunde, keine im Plan schon gelöste
Frage. **Empfehlung, nicht in dieser Runde gebaut:** für `eyesOpen == true` zusätzlich `.blink` auf
Tap-Index 1 legen — dieselbe Achse, die Index 2/3 schon nutzen. **Der HIGH ist beim Merge
unentschieden geblieben** und steht als offener Punkt in `docs/SSOT.md` §7.

**Sechs LOW, dokumentiert, keiner blockierend** — darunter ein unbegründeter Default `.autumn` in
`MorningAmbience.season`, ein dritter Treffer derselben kommentar-blinden Positions-Sentinel-Falle
in `BlockDiagnosticsTests`/`CompletedMorningLedgerTests` (das richtige Muster, `strippedLines`,
existiert bereits in `MascotTapReactionTests` und ist nur nicht überall angewandt), und eine dünne
Marge am dunklen Fensterende der Sommer-Kontrastbedingung (3,24–3,33 gegen 3:1), die **kein Test
laufend bewacht**.

**Nicht geprüft, gehört in den mehrtägigen Gerätelauf (Phase 0):** die Idle-Beat-Zählung über 60 s
(kein UI-Test-Target, keine Zählinstrumentierung im Produktivcode — strukturell belegt über reine
Funktion, Kontrollgruppe und Verdrahtungs-Scan, aber der gezählte Nachweis braucht das numerische
Gate aus Phase 0), Dynamic Type auf größter Stufe für den neuen Paywall-Satz und die
End-Knoten-Zeile, und Herbstblatt/Frühlingsblüte auf einem echten OLED bei niedriger Helligkeit.

**Verifiziert.** **712 Tests / 97 Suiten grün**, jeder der Commits einzeln getestet,
`xcodegen generate` driftfrei, Warnungs-Baseline auf frischem DerivedData unverändert bei genau
3× `appintentsmetadataprocessor`. Reduce Motion: keine neue Stelle schaltet eine Reaktion stumm
(G5 sauber, `motionGatedSites` deckt die neuen Flächen ab). Copy laut gelesen: keine zweite Person,
kein Urteil, kein Trost, kein Kontrast-Framing gegen den Nutzer.

### 2026-09-16 — Die Wachstumsstufe folgt keinem zurückfallenden Zähler mehr (G4-Regression)

**Eine Änderungsserie**, vier Schritte. Eigene, kleine Runde, unabhängig von der
Stachel-/Spezies-Arbeit.

**Der Befund.** Ein G4-Regressionsbug, gefunden als **Nebenbefund eines Review-Durchgangs** auf die
Mascot-Evolve-Planungsrunde und unabhängig davon bereits auf `master` vorhanden: `MascotStage`, die
Wachstumsstufe des Maskottchens, wurde direkt aus der Live-Morgen-Zahl berechnet, **ungeratscht**.
Fällt der Zähler zurück — verlorener App-Group-Schreibvorgang, ein Bug im Zählpfad, ein fremder
Schreiber auf dem geteilten Container — blendet die Sättigung sichtbar herunter, das Tier schrumpft
und verliert ein Blatt. Und das, während `MilestoneStore` für das Meilenstein-System längst eine
High-Water-Mark-Ratsche hat: die Mechanik war da, drei Screens haben sie nur nicht gelesen.

**Der Fix, und wo er bewusst nicht sitzt.** Nicht in `MascotStage` selbst — das bleibt pur, kein
neuer Enum-Member, sonst wäre `MascotStageExpressionBoundaryTests.expectedMembers` rot geworden.
Stattdessen lesen `GutenMorgenView.swift`, `OverrideFlowView.swift` und `SettingsView.swift` jetzt
`MilestoneStore.reachedMornings()` statt der rohen Live-Zahl — **acht** Store-Lesungen betroffen,
nicht sechs wie zuerst angenommen. `progressTowardNext`/`progressDescription` rechnen auf derselben
geratschten Zahl; sonst hätte die App nach einem Rückfall eine in sich widersprüchliche Aussage
gezeigt („5 von 30 Morgen, Stufe Eingespielt"). Bewusst nicht angefasst: `ContentView.swift:24` (das
Debug-Readout der Rohzahl — genau sein Zweck) und `MorningCelebration.swift` (bekommt Zahlen
übergeben, liest den Store nie selbst; `acknowledge()` ist bereits eine eigene Ratsche).

**Der methodische Punkt, und der eigentliche Wert dieser Runde.** Der naheliegende Beweis wäre ein
Verhaltenstest gewesen: Zähler 30 → 6 simulieren, Stufe bleibt `.eingespielt`. **Der ist auch am
Vor-Fix-Stand grün**, weil `MilestoneStore.reachedMornings` schon vorher existierte — kaputt waren
nur die drei Screens, die sie nicht lasen. Wer ihn als Beleg vorgezeigt hätte, hätte einen Silent
Pass als Beweis verkauft. Der echte Beweis ist der Quelltext-Scan:
`noScreenDerivesTheStageFromTheLiveCounter` und `everyScreenReadsTheRatchetInstead` — am
Vor-Fix-Stand **3 Issues** (die drei Screens), nach dem Fix grün, zahlengenau in der Prüfrunde nachvollzogen.

**Zwei Nachbesserungen nach der Prüfrunde.**

1. **Der Scan sieht ab jetzt auch den vierten Screen.** Er kannte ursprünglich drei
   feste Dateinamen; ein vierter Screen mit derselben ungeratschten Lesart wäre lautlos
   durchgefallen. Umgestellt auf das robustere Verzeichnis-Scan-Muster, das
   `LayoutContainmentTests.swift` bereits etabliert hat (alle `Tuck/*.swift`, explizite begründete
   Ausnahmeliste). Eigene Kontrollgruppe: eine testweise eingefügte vierte Datei mit der
   ungeratschten Lesart wird jetzt tatsächlich gefangen, vorher wäre sie es nicht gewesen.
2. **Die Ratsche verteidigt keinen vollständigen Restore.** Drei Kommentare
   (`GutenMorgenView.swift`, `MilestoneStore.swift`, `MascotStageRatchetTests.swift`) und eine
   vierte Fundstelle (`MilestoneStoreTests.swift`) versprachen Schutz gegen einen vollständigen
   App-Group-Restore. Das stimmt nicht: bei einem echten Restore reisen Zähler **und** Ratsche
   gemeinsam auf den alten Stand, die Ratsche greift dort nicht. Real verteidigt ist der **partielle**
   Verlust. Alle vier Stellen korrigiert.

**Offener Punkt, bewusst nicht angefasst.** `MorningCelebration.swift:36` trägt eine ähnliche
„restored backup"-Formulierung für seinen eigenen, unabhängigen `acknowledgedMornings`-Ratchet — bei
näherer Betrachtung dort vermutlich **nicht** falsch, weil sich Zähler und Ratsche bei einem
vollständigen Restore gemeinsam bewegen und die Guard-Bedingung (`completed > stored`) korrekt
bliebe. Als Prüfpunkt für eine spätere Runde notiert, nicht als bestätigter Fehler — eine Korrektur
ohne dieselbe Sorgfalt wie oben hätte selbst eine neue Ungenauigkeit eingeführt.

**Verifiziert.** **722 Tests / 101 Suiten grün**, `xcodegen generate` driftfrei, Warnungs-Baseline
auf frischem DerivedData unverändert bei 3× `appintentsmetadataprocessor`.

### 2026-09-16 — `docs/SSOT.md` beschrieb eine App, die es so nicht mehr gab

**Reine Doku.** Das Dokument trug „Stand: 2026-09-09", obwohl seither viele Änderungen
hinzugekommen waren. Die Struktur (acht Abschnitte) bleibt unverändert; der Inhalt ist gegen Code und
Tests **neu belegt**, nicht aus dem Dokument selbst abgeschrieben.

**Sechs Falschangaben, korrigiert.** „406 Tests, 56 Suites — Stand 2026-09-09" → **722 Tests / 101
Suiten**, frisch über `scripts/test.sh` gemessen (`platform=iOS Simulator,OS=26.5,name=iPhone 17`),
`** TEST SUCCEEDED **`. „`DEVELOPMENT_TEAM` fehlt noch in `project.yml` für alle vier Targets" →
gesetzt, `YOUR_TEAM_ID`, `project.yml:92/153/190/213`. „Meilenstein-System … noch nicht
gebaut" → der Fahrplan 45–365 Morgen ist vollständig gebaut (`Shared/MascotMilestone.swift`,
`Shared/MilestoneStore.swift`), seit 2026-09-05. „Datenschutz-URL als gehostete Seite fehlt"
(pauschal) → präzisiert: der In-App-Link nach 5.1.1(i) **existiert** (`PaywallView.swift:360-406`),
Platzhalter ist allein `PaywallLegal.privacyPolicy` (`https://example.com/tuck/datenschutz`,
RFC 2606, mit `privacyPolicyIsPlaceholder`-Guard). „Kein Lösch-Weg für Nutzerdaten" → geschlossen,
es gibt keine Accounts, Guideline 5.1.1(v) greift nicht. „Die Maskottchen-Stufen 7/30 enden deutlich
vor dem 66-Tage-Median" → gilt nicht mehr, der Fahrplan reicht bis 365 Morgen.

**Zwei kritische offene Punkte, neu in §7, beide am Code belegt — und beide exakt die Fehlerklasse
dieses Projekts.**

1. **Kein App-seitiger Fallback für ein ausbleibendes `intervalDidStart`.** Der Produktionsreife-Plan
   (nicht Teil dieses Exports) fordert ihn in Phase 0 ausdrücklich. Gebaut ist nur die **Messung**:
   `BlockDiagnostics.auditMorningCallback` (`Shared/BlockDiagnostics.swift:74-91`) zählt nach 120 s
   Karenz einen `callbacksMissing` hoch — und keine Stelle baut daraufhin einen Shield auf, weder
   `StopWakeAlarmIntent.swift` noch `GutenMorgenView.swift` noch `ShieldActionRouting.swift`. Auch
   das geforderte Fail-open in der Shield-Action fehlt. Die App weiß, dass nichts passiert ist, und
   tut nichts.
2. **Die Diagnose-Zähler kennen kein Abendfenster.** `recordMorningIntervalStart`,
   `lastMorningIntervalStart` und `auditMorningCallback` sind morgen-only
   (`Shared/BlockDiagnostics.swift:37-38, 54-91`, verdrahtet an `if activity == .morningBlock`).
   `intervalsStarted`/`shieldsApplied` zählen beide Fenster in denselben Topf. Ein stiller Ausfall
   des Bettzeit-Fensters — daran hängt die Monetarisierung — ist im Gerätelauf nicht von einem
   Morgenausfall zu trennen.

**Die Drift-Befunde, die diesen Nachtrag ausgelöst haben.** Dass dieser Log am 2026-09-13 endet und
mehrere Änderungsrunden ohne Eintrag sind (der wichtigste Rückstand, weil dem Log nach dem Code die
höchste Präzedenz zukommt); dass die Apple-Developer-Checkliste (nicht Teil dieses Exports) weiterhin „heute steht es dort
nirgends" über `DEVELOPMENT_TEAM` sagte; dass `README.md` unter „Status" den Stand vom 2026-09-05
beschrieb. Alle drei sind mit diesem Eintrag geschlossen. Dazu:
Maskottchen-Anatomie ist jetzt eine **Produktentscheidung**, kein Bau-Rückstand — `grep -rli
"spike|hedgehog|igel"` über alle fünf kompilierten Verzeichnisse liefert null Treffer. Und der
HIGH aus der Reziprozitäts-Runde (Wangen-Kanal bei `.eingespielt`) bleibt unentschieden.

**§8: der Produktionsreife-Plan (nicht Teil dieses Exports) trägt denselben Datums-Rückstand.** Er ist vom 2026-09-09 und
abschnittsweise überholt — Phase 1 und 3 sind abgearbeitet, Phase 2 (UX) kennt die v2-Handoff-Phasen
nicht, die seine eigene Kritik beantwortet haben. **Phase 0 bleibt der Engpass und ist der einzige.**
§8 nennt die Reihenfolge, die daraus folgt, ohne den Plan selbst neu zu schreiben.

**Verifiziert.** Testlauf frisch in einer eigenen Arbeitskopie gefahren, die Zahl aus dem
`** TEST SUCCEEDED **`-Output entnommen statt geschätzt; nach dem Lauf (der
`xcodegen generate` ausführt) kein pbxproj-Drift; jede Zeilenangabe im Dokument gegen die
Datei geprüft, nicht aus einer früheren Beschreibung übernommen. Reine Doku-Änderung, kein App-Code betroffen.

**Lehre aus dieser ganzen Nachtragsrunde.** Der Log ist die Quelle mit der höchsten Präzedenz und
zugleich die einzige, die niemand kompiliert — nichts wird rot, wenn er vier Tage fehlt. Mehrere
der Runden oben waren selbst Doku-Korrekturen an Dokumenten, die nur deshalb falsch
waren, weil sie einmal richtig gewesen sind. Die einzige Verteidigung, die hier bisher funktioniert
hat, ist ein Eintrag pro abgeschlossener Änderung, geschrieben solange die Zahlen noch belegbar sind — nicht ein
Nachtrag wie dieser, der die Zahlen aus früheren Beschreibungen rekonstruieren muss.

### 2026-09-16 — Der Audit-Log holt Runden nach, Checkliste und README hören auf zu widersprechen

**Anlass:** der Drift-Befund, mit dem die SSOT-Neufassung selbst endete — dieser Log stand am
2026-09-13 still, während mehrere Änderungsrunden längst abgeschlossen waren. Dem Log kommt nach dem
Code die höchste Präzedenz unter den Statusquellen zu; vier Tage lang war die präzedenzstärkste
Quelle keine.

**Nachträge im etablierten Stil.** Ausgangsbefund, Gebautes und
Kontrollgruppen-/Prüf-Beleg je Eintrag — und ausdrücklich die Funde, die den Wert
eines Audit-Logs ausmachen, nicht nur die Titel: der G4-Regressionsbug (Wachstumsstufe) samt dem
methodischen Punkt, dass der naheliegende Verhaltenstest auch am Vor-Fix-Stand grün war, weil
`MilestoneStore.reachedMornings` schon existierte (ein Silent Pass wäre als Beweis durchgegangen);
der damals noch offene HIGH der Reziprozitäts-Runde (Wangen-Kanal trägt die Tap-Antwort bei `.eingespielt` nicht,
4–5/255 Peak-Delta, im Rauschen); der `DarkMascotColorVariantContrastTests`-Test aus Phase 3, der grün
blieb, während er eine Farbe prüfte, die das Tier nicht mehr trägt; der in Phase 4 übersprungene
DoD-Punkt 7 — ausgerechnet der einzige der elf, der faktisch nicht erfüllt war. Ausdrücklich als
Nachtrag gekennzeichnet: die Zahlen sind aus den damaligen Beschreibungen und Commit-Nachrichten
rekonstruiert, nicht am 2026-09-16 neu gemessen.

**Die Checkliste.** Die Apple-Developer-Checkliste (nicht Teil dieses Exports) sagte weiterhin „heute steht
es dort nirgends" über `DEVELOPMENT_TEAM` — falsch, seit der Wert gesetzt wurde. Nicht nur gestrichen, belegt:
`YOUR_TEAM_ID` an vier Stellen (`project.yml:92/153/190/213`). Dazu benannt, was damit nicht erledigt
ist: `CODE_SIGN_STYLE` steht in `project.yml` nirgends, Signing hängt an Xcodes Default statt an
einer festgeschriebenen Entscheidung, die Kette ist deklariert, nicht bewiesen — der Beleg wäre ein
durchlaufender `xcodebuild -destination 'generic/platform=iOS' -allowProvisioningUpdates`, den
niemand gefahren hat.

**Das README.** Der Status-Abschnitt trug eine eigene Feature-Liste vom 2026-09-05 und
verwies auf die Liste der nächsten Schritte (nicht Teil dieses Exports) — beides von vielen Änderungen überholt. Die Liste ist
ersatzlos entfallen statt aktualisiert (ein README, das den Feature-Stand nachführt, ist die zweite
Wahrheit, die beim nächsten Mal wieder driftet); jetzt Verweise auf `docs/SSOT.md`, den
Produktionsreife-Plan und diesen Log mit ihrer jeweiligen Rolle, eine Zahl mit ihrem Stand, und der
ausdrückliche Satz, dass hier ein Verweis steht und keine Quelle.

**Verifikation:** reine Doku, kein App-Code, kein `xcodegen generate` nötig, keine Tests betroffen.

### 2026-09-16 — Der Wangen-Kanal-HIGH stand noch als offen, während der Fix schon im Baum lag

**Befund:** `docs/SSOT.md` §7 führte den HIGH der Reziprozitäts-Runde weiterhin als „nicht gebaut,
Entscheidung steht aus". Gebaut war er am Morgen des 2026-09-16 — sieben Stunden vor der
SSOT-Neufassung, die §7 neu schrieb und die veraltete Zeile unverändert mitschleppte, weil der
Audit-Log zu diesem Fix zu diesem Zeitpunkt keinen Eintrag trug und die tiefere Quelle den Widerspruch nicht
auflösen konnte. `MascotTapReaction.swift:74` liefert auf Index 1 bereits `eyesOpen ? .blink :
.squint`, `MascotView.swift` liest dieselbe Antwort über `answer.contains(.blink)` statt der alten
gespiegelten Bedingung `index >= 2` — genau der von der ursprünglichen Prüfrunde empfohlene Fix.

**Kein Code geändert, nur nachgemessen statt nur zitiert:** derselbe `ImageRenderer`-Mess-Harness
(Scale 4, Peak-Kanaldelta) wie in der Prüfrunde der Reziprozitäts-Runde, neu gegen den heutigen Baum gefahren:

| Kanal | Peak | Pixel ≥ 10 |
|---|---|---|
| Wange, `.eingespielt`, hell, vor dem Fix | 5/255 | 0 |
| Auge offen→geschlossen, nach dem Fix | 148/255 | 1348 |

Bestätigt die 4–5/255 aus dem ursprünglichen SSOT-Eintrag; Faktor 30 im Peak nach dem Fix, erstmals
Pixel über der Schwelle von 10. Kein neues `reduceMotion ?`-Gate nötig — `.blink` ist Formänderung,
keine Bewegung (§8 A17), überlebt Reduce Motion strukturell.

**Fix:** zwei Zeilen in `docs/SSOT.md` (§7, §8 Punkt 6) — der HIGH ist nicht mehr offen.
`scripts/test.sh`: 722 Tests in 101 Suiten, `** TEST SUCCEEDED **`, iPhone 17 / iOS 26.5,
`xcodegen generate` driftfrei.

**Offener Punkt:** der Mess-Harness liegt nicht im Repo — bei Bedarf für
eine künftige Messung neu zu bauen.

### 2026-09-16 — Vorab-Namensprüfung

**Anlass:** Punkt 0.8 des Produktionsreife-Plans (nicht Teil dieses Exports), risikolose Recherche vor der App-Store-Namensreservierung.

**Befund:** Eine Namensprüfung wurde durchgeführt (keine Rechtsberatung); die Ergebnisse sind nicht
Teil dieses Exports.

**Dateien:** die volle Recherche mit Quellen lag in einem eigenen Dokument, das nicht Teil dieses
Exports ist; `docs/SSOT.md` §7 (kompakter Verweis).

### 2026-09-16/17 — Abend-Diagnose + Geräte-Check-Vorbereitung (Phase A), und ein HIGH: der Abend-Audit war auf jeder Update-Installation blind

**Anlass:** Phase A von zwei aus dem Fallback-Plan (nicht Teil dieses Exports) — adressiert `docs/SSOT.md` §7 „Kritisch —
Mechanismus": kein App-seitiger Fallback für ein ausbleibendes `intervalDidStart`, und die
Diagnose-Zähler kannten kein Abendfenster. Diese Phase baut ausdrücklich **nicht** die eigentliche
Fallback-Logik (Fail-open, Unlock-Anker, Sperr-Aufbau aus dem App-Prozess) — die hängt an
Geräte-Gate K1, nur am echten Gerät durchführbar, nicht im Simulator.

**Zähler trennen Morgen und Abend:** fünf Diagnose-Zähler wurden acht, je Fenster eigene
Schlüssel; Settings zeigen beide getrennt mit `accessibilityLabel`-Legende statt einem gemeinsamen
Footer. Wiring-Nachweis (keine Verhaltens-Kontrollgruppe möglich, §3.1 des Plans): drei Scans am
Vor-Fix-Stand gefahren, alle drei rot (5 Issues), danach grün. 725 Tests in 101 Suiten
(vorher 722).

**Der Abend bekommt seinen eigenen Ausfall-Nachweis:**
`recordBedtimeIntervalStart`/`auditBedtimeCallback`/`bedtimeCallbacksMissing` als
Abend-Entsprechung der Morgen-Diagnose. `BedtimeStore.recordBlockRegistration` schreibt bei Erfolg
neu einen Zeitstempel (`bedtimeBlockRegisteredAt`), der dem Abend — ohne eigenes `fireDate` — erst
eine Untergrenze gibt, ab wann eine Occurrence überhaupt als fehlend gemeldet werden darf.
Wiring-Nachweis am selben Vor-Fix-Commit: drei Scans rot (7 Issues), danach grün. 739 Tests in 101
Suiten.

**Der Shield-Abbau bekommt eine eigene Datei:** `Shared/ShieldRelease.swift`, reiner
Struktur-Commit, alle sieben Aufrufstellen umgezogen, kein Forwarder. Vorbereitung für den
Fail-open-Commit der (noch nicht gebauten) Phase B. 742 Tests in 102 Suiten.

**Der Shield-Schreibvorgang aus der App wird am Gerät prüfbar:** vier
DEBUG-only-Affordanzen (Shield schreiben/räumen, nur-Morgen-Store räumen, Schalter „Weckerstopp
schreibt den Shield") für das K1-Protokoll (Plan §6.3) — das gesamte Fallback-Vorhaben ruht auf der
im Repo bis dahin unbelegten Annahme, dass ein `ManagedSettings`-Schreibvorgang aus dem App- bzw.
einem vom System im Hintergrund gestarteten Prozess überhaupt sperrt; im Simulator strukturell
unprüfbar. Release-Build grün, `strings`-Scan bestätigt: kein DEBUG-Marker im Release-Binary. 744
Tests in 102 Suiten.

**HIGH-Fund einer Prüfrunde auf Phase A, ein eigenständiger, wertvoller
Fund, nicht Teil des ursprünglich geplanten Commit-5-Umfangs:** `bedtimeBlockRegisteredAt` wird nur
in den arm/disarm-Zweigen des Reconcilers geschrieben. Ein Gerät, auf dem
`bedtimeBlockRegistrationSucceeded` schon vor diesem Build `true` war — **jede
Update-Installation, nicht nur eine Neuinstallation** — bleibt in `bedtimeWindowAction` auf `.leave`
und betritt diese Zweige nie wieder. `countableOccurrence` blieb dadurch strukturell `nil`,
`auditBedtimeCallback` meldete sofort `false`, `bedtimeCallbacksMissing` stand permanent auf 0 —
exakt die Lesung eines funktionierenden Abends, in genau dem Commit, der sie beseitigen sollte. Der
Abend-Audit war damit für den mit Abstand häufigsten realen Installationsfall (Update statt
Neuinstallation) strukturell blind, nicht nur in einer Ecke ungenau. Fix: Schema-Migration Version
1→2 holt den Stempel einmalig nach, mit `.now` statt `.distantPast` (die Migration wirkt wie ein
frischer Arm-Vorgang, urteilt nicht rückwirkend über unbeobachtete Nächte), idempotent, mit
Rücklesung statt Behauptung (`SchemaMigrationOutcome.stepFailed`, dieselbe Fail-Loud-Kette wie
`.failed` in `TuckApp.swift`). 748 Tests in 102 Suiten.

**Zweite Prüfrunde, zwei LOW-Kommentarkorrekturen:** der neue Migrations-Kommentar
nannte die Reconciler-Zweige „its only writer" von `bedtimeBlockRegisteredAt`, obwohl
`BedtimeScheduler.setBedtime` denselben Schreiber ebenfalls aufruft (am Fix ändert das nichts, der
Pfad läuft auf einer reinen Update-Installation ohnehin nicht); der Dateikopf von
`SchemaMigrationTests.swift` behauptete weiterhin „die Migrationen sind leer" — seit dem Migrationsschritt dieser Phase nicht
mehr wahr. Keine Verhaltensänderung, 748 Tests weiterhin grün.

**Gesamtverifikation:** 748 Tests in 102 Suiten am Ende (Ausgangsstand 722/101),
`** TEST SUCCEEDED **`, iPhone 17 / iOS 26.5. `xcodegen generate` driftfrei, Warnungs-Baseline
unverändert (3× `appintentsmetadataprocessor`). Zwei vollständige Prüfrunden
in eigener Arbeitskopie — eine für Phase A als Ganzes, eine fokussiert auf den
HIGH-Fund, inklusive zweier gezielter Mutationstests, die bestätigen, dass die neuen Tests das
behauptete Verhalten wirklich prüfen und nicht zufällig grün sind.

**Was jetzt offen ist:** K1 (Plan §6.3) — ein Geräte-Check-Protokoll, sechs kurze
Wecker-Läufe (~1 Stunde), das beweist, ob ein `ManagedSettings`-Schreibvorgang aus dem App-Prozess
wirklich sperrt (warm/kalt × drei Auslöse-Gesten: Stop-Button/Power-Button/Swipe). Das Ergebnis
entscheidet den Umfang von Phase B; ohne K1 bleibt sie geparkt. Über die Sperre selbst — ob sie
wirklich greift — sagt keiner der neuen Zähler etwas; sie belegen nur, dass ein Ausfall jetzt
sichtbar wäre.
