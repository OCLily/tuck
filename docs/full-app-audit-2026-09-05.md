# Voll-Audit der App — 2026-09-05

Sechs-Dimensionen-Audit über den gesamten Bestand (der Stand nach Dark Mode, Progressionssystem und Monetarisierungs-Umbau; die 298 Tests unten belegen es). Dimensionen: Design/Design-System, Code & Architektur, Accessibility, Usability, Security/Privacy, Stabilität. **Read-only** — es wurde nichts geändert, kein `xcodegen generate` ausgeführt. Builds und `xcodebuild test` liefen ausschließlich diagnostisch.

**Methode:** Rohfunde je Dimension erhoben, danach **jeder einzelne Fund gegen den echten Code neu verifiziert** — Datei gelesen statt Behauptung übernommen, eigene Neuberechnung statt Übernahme gemeldeter Zahlen, und in jedem Fall zusätzlich geprüft, ob der Fund bereits als bewusster Tradeoff in `docs/design/design-system.md` §8 oder in der Liste der nächsten Schritte (nicht Teil dieses Exports) steht. Funde, die diese Gegenprüfung nicht überlebten, stehen hier nicht.

---

## 1. Zusammenfassung

Der Bestand ist gesund. **0 BLOCKER.** Nichts stürzt ab, nichts verliert Daten, keine Farming-Lücke im Kontingent, keine Netz- oder Krypto-Angriffsfläche (die App hat keinen einzigen eigenen Netzwerk-Call), und die zentrale Ehrlichkeits-Regel G3 hält auf dem Hauptpfad. Die Test-Suite läuft grün: **298 Tests in 42 Suites, 0 Failures, 0 Skips** (`xcodebuild test`, iPhone 17 / iOS 26.2, `** TEST SUCCEEDED **`), und alle 34 Test-Dateien auf Platte sind auch wirklich im Target.

Verifiziert übrig geblieben sind **42 eigenständige Funde: 0 BLOCKER, 9 HIGH, 33 LOW.** (44 Rohfunde, davon zwei Doppelmeldungen desselben Defekts aus zwei Dimensionen zusammengeführt.) Die Gegenprüfung hat dabei kräftig korrigiert: **11 Funde wurden von HIGH auf LOW heruntergestuft** (meist Doku-Drift, die als Defekt gemeldet war), **einer von LOW auf HIGH hochgestuft** — die Sage-Platten schrumpfen nicht nur die Trefferfläche, sondern messbar den Accessibility-Frame auf 19,33 pt.

Der Schwerpunkt der HIGHs liegt nicht im Code-Kern, sondern an den Rändern, die noch nie auf einem echten Gerät liefen: die Berechtigungs-Fehlerpfade (Family Controls abgelehnt, Wecker-Registrierung fehlgeschlagen), das Onboarding bei Accessibility-Textgrößen, und drei Accessibility-Lücken, die die Doku als "geschlossen" führt. Zwei HIGHs sind Zustands-Ehrlichkeit: die App bestätigt ein Sperrfenster, das nichts sperrt (leere App-Auswahl), und schweigt komplett, wenn gar kein Wecker gesetzt ist.

**Launch-blockierend: nichts im engeren Sinn** — es gibt noch keinen Build im Feld, und jeder HIGH ist ohne Architektur-Umbau reparierbar. Aber vier HIGHs (H1–H4) betreffen genau die Pfade, die ein App-Review-Tester in den ersten fünf Minuten trifft, und **H5 (Kontrast des Morgenhimmels) falsifiziert eine Zahl, die als Begründung in einem Code-Kommentar und in einem Test-Kommentar steht** — die sollte vor der ersten Einreichung entschieden sein, nicht danach.

**Verifikationsgrenzen dieser Runde, offen benannt:** Family Controls autorisiert im Simulator nicht, der `.denied`-Zustand ist damit weiterhin nicht am Bildschirm geprüft (das steht so schon in §6.4). `simctl launch` trägt keine StoreKit-Konfiguration, die Paywall-Perioden-Zeilen (die einzige `.isSelected`-Stelle der App) wurden nur im Code geprüft. VoiceOver wurde nicht live gefahren — es gibt kein UI-Test-Target. Zwei Simulator-Läufe kamen nicht zustande; die betroffenen Funde sind unten als "berechnet, nicht fotografiert" markiert.

---

## 2. Funde

### 2.1 BLOCKER

Keine.

---

### 2.2 HIGH (9)

Reihenfolge: erst was ein Nutzer trifft, dann Accessibility, dann Code.

---

**H1 — Family Controls abgelehnt: der Fehler-Zweig verdeckt den einzigen Hinweis, wie man zurückkommt**
Dimension: Usability (Sackgasse) · `Tuck/AccessAndAppSelectionView.swift:24-72`

*Szenario:* Der Nutzer lehnt die Screen-Time-Berechtigung ab, sieht den einen erklärenden Satz ("Du kannst ihn in den Systemeinstellungen wieder geben …"), tippt auf den einzigen Button auf dem Bildschirm — und der Satz verschwindet, ersetzt durch einen rohen SDK-`localizedDescription`.

*Verifiziert:* Die Zweig-Reihenfolge ist `if let authorizationError` (`:24`) → `else if approved` (`:34`) → `else if denied` (`:39`). `authorizationError` wird nur im `catch` (`:62`) gesetzt und nur bei Erfolg (`:60`) gelöscht — `.onAppear` (`:74`) räumt es nicht ab. Der Fehler-Zweig steht also *über* dem `.denied`-Zweig und unterdrückt dessen Text für die Lebensdauer der View-Instanz. Der Retry-Button (`:55-72`) wird für jeden Status außer `.approved` gezeigt, unverändert beschriftet "Zugriff erlauben". Repo-weiter Grep über alle fünf Targets nach `openSettingsURLString|UIApplication|openURL|settingsURL`: **null Treffer** — es gibt nirgends einen Deep-Link in die Systemeinstellungen. Family Controls ist die Voraussetzung für das gesamte Produkt, und dies ist der einzige Screen, der ihr Scheitern behandelt.
*Korrektur zur Rohmeldung:* "kein Weg nach vorne" ist zu scharf — der Satz nennt das Ziel, und Sheet schließen/neu öffnen setzt den `@State` zurück. Der Defekt sind die zwei Dinge: kein Deep-Link, und die einzige Handlung auf dem Screen löscht die einzige Anleitung.
*Die richtige Form existiert schon im Repo:* `WakeAlarmSetupView.swift:88-108` modelliert Fehler als `switch`-Peer statt als Overlay — dort kann `.denied` nie überschrieben werden.
*Nicht dokumentiert:* §8 A14 regelt nur die *Satzform* dieser Copy, nicht die Zweig-Reihenfolge. `docs/design/design-system.md:704` hält fest, dass genau dieser Zustand im Simulator nie prüfbar war — so ist es durchgerutscht.

---

**H2 — Der Wecker-Sheet schließt sich 1,2 s nach "Erfolg" auch dann, wenn die Sperrfenster-Registrierung geworfen hat**
Dimension: Usability (Produkt-Flow) · `Tuck/WakeAlarmScheduler.swift:73-81`, `Tuck/WakeAlarmSetupView.swift:71-84`

*Szenario:* `BlockWindowMonitor.register` wirft, der Grund wird für etwa eine Sekunde angezeigt und ist danach für immer weg — der Nutzer bleibt dauerhaft in einem nicht scharf gestellten Zustand, ohne je zu erfahren warum oder wohin.

*Verifiziert:* Der innere `do/catch` schreibt `recordBlockRegistration(succeeded: false)` und `blockRegistrationError`, danach setzt Zeile 81 `status = .scheduled(fireDate)` **außerhalb** dieses `catch`. Die Auto-Dismiss-Reaktion (`:79`) hängt an genau `case .scheduled` → 1,2 s schlafen → `dismiss()`. Beide Mutationen laufen in einem synchronen `@MainActor`-Block, der Fehlersatz wird also wirklich gerendert — zusammen mit der Pending-Zeile, zwei umbrechende Sätze in Subheadline-Gewicht für 1,2 Sekunden.
*Der Fund war zu milde:* Verworfen wird mehr als gemeldet. `DeviceActivity.swiftinterface:166` deklariert `MonitoringError: LocalizedError` mit `errorDescription` **und `recoverySuggestion`** — Apple liefert eine Erklärung *und* einen Lösungsvorschlag, und die App liest den zweiten an keiner Stelle.
*"Nie wieder gezeigt" hält:* `SettingsView.swift:298-301` zeigt nur die Zeit ohne Pending-Markierung, `GutenMorgenView.swift:120-125` nur die Tatsache ohne Ursache, und der `.idle`-Zweig beim erneuten Öffnen (`:91-92`) ebenfalls. Nichts verlinkt von dort auf `AccessAndAppSelectionView`, wo das Mittel liegt.
*Milderungen, die die Rohmeldung ausließ:* Der Onboarding-Pfad ist immun (`OnboardingFlowView.swift:126` bettet die View ein, `dismiss()` ist dort ein No-Op), und die häufigste Ursache `.unauthorized` heilt sich über `BlockWindowReconciler.reconcile()` beim nächsten Foregrounding. Der Defekt sitzt auf dem Settings-Sheet-Pfad.
*G3 bleibt intakt* — es wird nie fälschlich "scharf" behauptet. HIGH, weil ein Nutzer, der Family Controls im Onboarding abgelehnt und später aus den Einstellungen den Wecker gestellt hat, dauerhaft und unerklärt ohne die Kernmechanik dasteht.
*Doku-Randnotiz:* §5.11 und §8 A15 zitieren beide `WakeAlarmSetupView.swift:69-81` — zwei Zeilen veraltet gegen die echten 71-84.

---

**H3 — "Sperrfenster bis 07:30" bei leerer App-Auswahl, wo nichts gesperrt wird**
Dimension: Usability (Zustands-Ehrlichkeit) · `Tuck/GutenMorgenView.swift:118-125`, `Tuck/WakeAlarmSetupView.swift:122-127`, `Tuck/BedtimeSetupView.swift:186-191`

*Szenario:* Wer das Onboarding mit erteilter Berechtigung, aber ohne ausgewählte Apps durchtippt, bekommt jeden Morgen eine ruhige, selbstbewusste Bestätigung eines Sperrfensters, das buchstäblich nichts sperrt.

*Verifiziert:* Die einzige Bedingung ist `blockRegistrationConfirmed` = `WakeAlarmStore.blockRegistrationSucceeded()`, ein blankes `defaults.bool(forKey:)`, geschrieben ausschließlich aus `try BlockWindowMonitor.register(...)` (`BlockWindowReconciler.swift:31,111`). `BlockWindowMonitor.register` liest den `FamilyActivitySelectionStore` überhaupt nicht — Registrierung und Auswahl sind vollständig entkoppelt. Grep über alle Targets: die drei einzigen `FamilyActivitySelectionStore.load()`-Aufrufer sind der Picker, die Settings-Zählung und die Monitor-Extension; **kein `isEmpty`/Token-Count gated irgendeine Copy.** Erreichbar in einem Tap: `OnboardingFlowView.swift:112-121` — "Weiter" ist im App-Auswahl-Schritt bedingungslos.
*Die Rohmeldung untertreibt den Umfang:* Es ist nicht eine Stelle, sondern drei — dieselbe Überbehauptung läuft über dasselbe Flag auch in `WakeAlarmSetupView.windowSentence` und, über `BedtimeStore.blockRegistrationSucceeded()`, in `BedtimeSetupView`. Ein Fix nur in `GutenMorgenView` lässt zwei Screens weiterlügen.
*Mechanik-Korrektur:* Bei *gar keiner* gespeicherten Auswahl kehrt die Monitor-Extension am `guard let` (`DeviceActivityMonitorExtension.swift:15`) zurück, bevor irgendetwas geschrieben wird; die "leerer Shield als No-Op"-Route ist der Fall *gespeichert-aber-leer* (`ShieldApplication.swift:21-26` schreibt vier `nil`). Gleiches Ergebnis für den Nutzer, anderer Weg.
*"Später erlauben" ist nicht der Schuldige:* Ohne Autorisierung wirft `startMonitoring` `.unauthorized`, das Flag bleibt false, `windowPending` greift — dieser Pfad ist ehrlich. Der unehrliche verlangt **erteilte Berechtigung + leere Auswahl**. `BlockWindowReconciler` entschärft bereits bei entzogener Autorisierung (`:15-27`); die Autorisierungs-Achse ist gedeckt, die Auswahl-Achse ist das Loch.
*Präzedenz im eigenen Log:* Der strukturell identische Bug ("Screen behauptet ein scharfes Sperrfenster ohne Bestätigung") steht im Audit-Log (Eintrag vom 2026-09-03) als HIGH und wurde gefixt. §5.4 Zeile 402: "**Nie** einen Platzhalter für einen unbestätigten Zustand verwenden."
*Nebenbefund derselben Familie:* `SettingsView.activityCount()` (`:343-346`) zählt `applicationTokens + categoryTokens`, aber nicht `webDomainTokens` — der eine Screen, der Leere anzeigt, kann "noch keine" sagen, während ein reiner Web-Domain-Shield aktiv ist. Umgekehrte Unehrlichkeit, gleiche Familie.

---

**H4 — Das Onboarding endet ohne Wecker, und der Morgen-Screen sagt dazu nichts**
Dimension: Usability (Sackgasse) · `Tuck/OnboardingFlowView.swift:123-131`, `Tuck/GutenMorgenView.swift:191-207`

*Szenario:* Der Wecker-Schritt geht auf "Weiter" weiter, egal ob "Wecker stellen" je gedrückt wurde. Ohne gespeicherten Wecker verschwindet die Fensterzeile komplett, und der Nutzer sieht jeden Morgen "Guten Morgen" plus eine zufällige Subline — kein Wecker, kein Fenster, kein Shield, und keine Zeile, die das fehlende Stück benennt.

*Verifiziert:* `wakeTimePicker` ist exakt `Spacer() / WakeAlarmSetupView() / Spacer() / nextButton("Weiter") { step = .bedtime }` — kein Lesen von `WakeAlarmStore.scheduledAlarm()`, kein `.disabled`, kein Gate. Der Wecker wird nur in `WakeAlarmScheduler.scheduleWakeAlarm` gespeichert, und auch dort nur bei `.authorized` (`:41-45` — bei Ablehnung wird gar nichts geschrieben). Auf dem Morgen-Screen ist die Fensterzeile in `if let scheduledAlarm` gewickelt; nichts sonst auf dem Screen liest Wecker-, Berechtigungs- oder Auswahl-Zustand. `BlockWindowReconciler.swift:28-33` registriert ohne Wecker nie etwas — "kein Wecker, kein Fenster, kein Shield" ist wörtlich wahr, nicht rhetorisch.
*Korrektur:* "Dieselbe Stille deckt auch die fehlende Berechtigung" stimmt **nicht**. Mit gespeichertem Wecker und fehlender Autorisierung rendert `StatusCopy.windowPending` ehrlich. Still sind nur der Kein-Wecker-Fall und, separat, die leere App-Auswahl (H3).
*Reichweite größer als gemeldet:* Auch wer "Wecker stellen" **drückt** und den einmaligen iOS-Wecker-Dialog ablehnt oder vertippt, landet im identischen stillen Zustand — Status `.denied`, nichts gespeichert, und die Onboarding-Copy sagt selbst "weiter geht es trotzdem" (`WakeAlarmSetupView.swift:103`). Das ist ein Nutzer, der es versucht hat und glaubt, die App sei scharf.
*Gegen die eigene Regel:* §7 verlangt "Ruhige Degradation statt Leerstellen" mit `StatusCopy.unsetValue`/`.emptyCount` (§8 A20, am 2026-09-05 gefixt), und `SettingsView.wakeValue` wendet sie bereits an ("nicht gesetzt"). Der Morgen-Screen ist die einzige Fläche, die die eigene kodifizierte Regel überspringt.
*Nicht BLOCKER:* einen Tap entfernt heilbar (Einstellungen → "Weckzeit · nicht gesetzt"), nichts stürzt ab.

---

**H5 — §2.4s Kontrastzeile für den hellen Himmelsgradienten ist in beide Richtungen falsch; Fließtext erreicht ~2,76:1, unter der eigenen 3:1-Schwelle**
Dimension: Accessibility (Kontrast) · `docs/design/design-system.md:106` · Code: `Tuck/MorningSky.swift:25-45`, `Tuck/GutenMorgenView.swift:135-137,189-207,212,238`

*Szenario:* Bei Accessibility-Textgrößen scrollt die Textspalte über den fest stehenden Himmel; Begrüßung, Subline und Fensterzeile wandern dabei in ein Band von ~2,74–2,89:1 — unter die 3:1-Marke, die §3.1 als immer erfüllt ausweist.

*Verifiziert, und die Pipeline vorher gegen die eigenen Tests validiert:* Oklab-Mischung + WCAG-2.1-Luminanz nachimplementiert; alle drei abgeleiteten Töne reproduzieren **byte-exakt** in beiden Erscheinungsbildern (`DarkModePaletteTests.swift:39-45`), und das Dunkel-Minimum des Himmels über 101 Progress-Werte kommt auf **3,3636 → 3,36**, exakt der Wert, den `DarkModePaletteTests.swift:102-113` in CI behauptet. Damit ist die Rechenmethode gegen einen laufenden Test geeicht, nicht selbstbezeugt.
*Ergebnis für Hell:* Minimum **2,44:1** (p=0, y=0, Dawn Shadow `#B6C2B3` am oberen Bildrand), Maximum **4,16:1** (p=1, Day Sky). Die Doku sagt "~3,5:1 (Maximum)" — falsch nach oben *und* nach unten. Bei p=0 liegt der 3:1-Übergang bei y=0,358: die obersten ~36 % des Bildschirms liegen unter der Marke.
*Der Mechanismus ist im Code belegt:* Der Gradient hängt als ZStack-Geschwister mit `.ignoresSafeArea()` (`GutenMorgenView.swift:135-137`) außerhalb der ScrollView, `.scrollableWhenTallerThanScreen()` (`:238`) umschließt nur die Spalte. Unscrolled sitzt der Textblock bei y≈0,49 (~3,2:1, über der Marke); dass die Spalte bei AX-Größen wirklich überläuft, ist keine Spekulation — §6.4 protokolliert den eigenen Simulator-Durchgang vom 2026-09-05, in dem die Begrüßung zu "Schön, dass d…" abgeschnitten war, und genau deshalb kam der Scroll-Wrapper. Rekonstruiert liegt der Block dann bei y≈0,20–0,32 → **~2,74–2,89:1**. `MorningAmbience`s Lichtquelle rettet das nicht: bei maximaler Alpha (0,184) hebt sie y=0,20 von 2,745 auf 2,821.
*Verschärfung gegenüber der Rohmeldung:* Der schlechteste Fall ist **nicht** tageszeitgebunden. `@State private var skyProgress: Double = 0` (`:87`), und der einzige Schreiber animiert über `withAnimation(.easeInOut(duration: 8))` — p=0 wird bei **jedem** Erscheinen des Screens für mehrere Sekunden gerendert.
*Die falsche Zahl hat sich fortgepflanzt:* `design-system.md:122`, `:130`, `:484`, der Test-Kommentar `DarkModePaletteTests.swift:99` — und `GutenMorgenView.swift:212`, wo "~3.5:1" als **Begründung einer gelieferten Design-Entscheidung** steht (beide Buttons in der Großtext-Kategorie).
*Kein akzeptierter Tradeoff:* Die Liste der nächsten Schritte (§2, nicht Teil dieses Exports) akzeptiert ausschließlich die *pt-Kategorie*-Frage (zählt 14 pt @ 700 als WCAG-Großtext), nicht einen Hintergrund unter 3:1. §8 führt den Himmel nirgends. Die Testabdeckung ist exakt entlang dieser Lücke asymmetrisch: Dunkel gepinnt, Hell gar nicht (`MorningSkyTests.swift` testet nur die `progress()`-Arithmetik).
*Nicht BLOCKER:* bei Standard-Textgröße liegt nichts unter 3:1 (Begrüßung ~3,2:1, beide Buttons bei y>0,8 auf 3,4–3,8:1), und der betroffene Text ist Status, kein Bedienelement. Halb berechnet, halb belegt: p=0 ist im Code bewiesen, die gescrollte Position rekonstruiert.

---

**H6 — Die drei älteren Sage-Platten schrumpfen den Accessibility-Frame auf 19,33 pt (LOW → HIGH hochgestuft)**
Dimension: Accessibility · `Tuck/WakeAlarmSetupView.swift:46-47`, `Tuck/BedtimeSetupView.swift:125-126`, `Tuck/AccessAndAppSelectionView.swift:70-71`

*Szenario:* Drei Primäraktionen — darunter der Family-Controls-Berechtigungsbutton und der Wecker-Button — zeichnen eine ~51 pt hohe Platte, exponieren aber ein ~19,3 pt hohes Accessibility-Element. VoiceOver-Fokusring, Voice-Control-Overlay und Switch-Control-Highlight landen auf dem Text, und Tippen auf die sichtbaren ~32 pt Plattenrand trifft nichts.

*Gemessen, nicht argumentiert:* Die echten Accessibility-Frames wurden am laufenden Simulator ausgelesen (iPhone 17 / iOS 26.2, Deutsch, **Standard**-Dynamic-Type):
| Element | Frame |
|---|---|
| "Zugriff erlauben" | 123,7 × **19,33** pt |
| "Wecker stellen" | 112,7 × **19,33** pt |
| "Bettzeit setzen" | 115,0 × **19,33** pt |
| Kontrolle: Override-Grund "Arbeit" (Modifier *im* `label:`) | 370,0 × 51,33 pt |
| Kontrolle: `primaryButtonPlate()` "Los geht's" | 370,0 × 39,33 pt |
51,33 − 19,33 = 32 = 2 × 16, exakt das Default-`.padding()`. Der Mechanismus ist damit auf den Punkt bestätigt.
*Warum hochgestuft:* Die Begründung der Rohmeldung für LOW — "die Ziele bleiben deutlich über 44 pt" — ist **messbar falsch**. 19,33 pt ist weniger als die Hälfte des Apple-HIG-Minimums von 44 × 44 pt. Kein WCAG-2.5.8-AA-Verstoß wird behauptet (die Abstände zwischen den Zielen greifen plausibel als Ausnahme); der Verstoß ist gegen die HIG und gegen schlichte Bedienbarkeit.
*Warum es nicht als "schon akzeptiert" durchgeht:* §5.2/§8 A8 akzeptieren und verschieben ausdrücklich die *Trefferflächen*-Facette ("das ist notiert, nicht in dieser Runde umgebaut"). Die Accessibility-Frame-Facette steht nirgends, und der Verschiebungs-Vermerk sagt nirgends, dass das Verschobene das Ziel auf 19 pt drückt. Die Akzeptanz wurde gegen eine untertriebene Beschreibung erteilt.
*Zählkorrektur:* Es sind **drei** Platten, nicht vier. Die drei Override-Gründe (`OverrideFlowView.swift:150-166`) hängen ihre Modifier bereits im `label:` und sind korrekt — ebenso "Plus ansehen" (`BedtimeSetupView.swift:71-76`) und `PrimaryButtonPlate.swift`. `design-system.md:325` zählt selbst falsch (siehe L4).
*Fix ist eine Zeile pro Stelle:* `.padding()`/`.background()` in den `label:`-Closure ziehen, genau wie `OverrideFlowView` und `PrimaryButtonPlate` es schon machen.

---

**H7 — Die Sprechblase des Maskottchens wird VoiceOver nie angesagt, inklusive der Meilenstein-Feier**
Dimension: Accessibility (VoiceOver) · `Tuck/GutenMorgenView.swift:179-186` (Schreibstellen `:352`, `:370`, `:412`)

*Szenario:* Ein VoiceOver-Nutzer aktiviert das Maskottchen, dem der Hinweis "Tippen für ein paar Worte" versprochen wurde — eine Sprechblase erscheint, verschwindet nach 2,8 s, und es wird nie etwas gesprochen. Dasselbe gilt für die Meilenstein-Feier, die einzige Stelle, an der ein freigeschalteter Idle-Beat überhaupt angekündigt wird.

*Verifiziert:* Die Blase rendert als blanker `SpeechBubble(text:)` im ZStack, ohne `.accessibilityElement`, ohne Fokus-Steuerung, ohne Announcement. `SpeechBubble` (`:3-24`) ist ein `Text` mit `.transition(.opacity)` — SwiftUI spricht neu eingefügten Text nicht von selbst an. Repo-weiter Grep über alle fünf Targets nach `AccessibilityNotification`, `UIAccessibility`, `accessibilityAction`, `announce`: **null Treffer** (nur drei Prosa-Kommentare). `bubbleText` wird an genau drei Stellen geschrieben und in `scheduleBubbleDismiss()` (`:382`) nach 2,8 s gelöscht.
*Schärfster Fall ist nicht der gemeldete:* Der Maskottchen-Tap ist der harte Defekt — `:172` verspricht per Hint eine Handlung auf einem Element mit `.isButton`, und die Handlung liefert Stille. Alltäglich, wiederholbar, und ein glatter WCAG-4.1.3-AA-Fehler (Status Messages). Die Meilenstein-Feier greift erst ab 45+ Morgen.
*Präzisierung:* "Der Nutzer erfährt nie von der Belohnung" ist halb richtig. Die Feier wird tatsächlich genau einmal verbraucht (`celebrateNewMilestone()` `:366-373` markiert *alle* offenen Meilensteine als gefeiert und zeigt nur den neuesten), aber Farbvarianten und Badges bleiben als dauerhafte Zeilen in den Einstellungen auffindbar. Verloren geht die *Nachricht*, nicht die Belohnung.
*Die Doku behauptet das Gegenteil:* §8 sagt "§6.3 führt keinen offenen Punkt mehr" und die VoiceOver-Achse sei geschlossen. Das ist falsch, solange diese Lücke besteht. Kein §8-Eintrag, kein Eintrag in der Liste der nächsten Schritte.
*Fix:* `AccessibilityNotification.Announcement(text)` an den drei Schreibstellen — der 2,8-s-Auto-Dismiss stört nicht, eine Ansage lebt unabhängig vom Element.

---

**H8 — Das Onboarding behält den Scroll-Offset des vorigen Schritts, der neue Schritt kommt mit abgeschnittenem Titel an**
Dimension: Accessibility (Dynamic Type) · `Tuck/OnboardingFlowView.swift:36-46`

*Szenario:* Bei `AccessibilityXXXL` ist jeder Onboarding-Schritt höher als der Bildschirm. Nach dem Weiterschalten steht der neue Schritt mitten im Scroll: Screen-Head-Glyph und Titel — also die Frage, die der Screen stellt — liegen oberhalb des Viewports, und die erste sichtbare Zeile ist von der Statusleiste beschnitten.

*Live reproduziert* (nicht nur gelesen): aktueller Stand gebaut (BUILD SUCCEEDED), frisch installiert auf iPhone 17 / iOS 26.2, gestartet mit `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL`.
- Schritt 1 → 2: oberste sichtbare Zeile ist "Bildschirm-", von der Statusleiste beschnitten; `hand.raised.fill` und die erste Titelhälfte liegen darüber.
- Schritt 5 → 6: `moon.stars.fill`, "Wann gehst du ins Bett?" und der Kopf des Rad-Pickers liegen alle über dem Viewport; das erste Sichtbare ist eine angeschnittene Picker-Zeile.
- `appSelection` verhält sich wie beschrieben — der Wechsel in den anderen Zweig setzt den Offset als Nebeneffekt zurück.
*Mechanismus:* `steps` ist ein Zwei-Zweig-`@ViewBuilder`; sechs von sieben Schritten rendern in **dieselbe** `.scrollableWhenTallerThanScreen()`-ScrollView, deren Identität den `step`-Wechsel überlebt — und damit ihr Content-Offset. Kein `ScrollViewReader`, kein `.id(step)`, kein `onChange(of: step)` in der Datei.
*Korrektur:* Nicht jeder Nicht-`appSelection`-Übergang ist betroffen — `explain → permission` kam im Lauf oben an, weil der Inhalt genug schrumpft und der Offset auf 0 klemmt. Der Defekt ist übergangsabhängig; die beiden konkret gemeldeten Instanzen reproduzieren.
*Kein akzeptierter Tradeoff:* §6.4 dokumentiert den Wrapper als Fix der Abschneide-Familie und protokolliert den Durchgang bei genau dieser Textgröße; die "wächst bewusst nur"-Passage akzeptiert nur Settings/Paywall und die "Weiter"-Platzierung im App-Auswahl-Schritt. Zu behaltenem Scroll-Offset steht nirgends etwas.
*Nicht BLOCKER:* alles ist durch Hochscrollen erreichbar. HIGH, weil es der Erstlauf ist, der verlorene Inhalt die Frage des Screens selbst ist und die natürliche Bewegungsrichtung im Flow nach unten geht — der Titel wird plausibel nie gesehen.
*Für den Fixer:* `.id(step)` verwirft auch die ScrollView-Identität pro Schritt und wechselwirkt mit der `.easeInOut(duration: 0.6)`-Schritt-Animation (`:32`, A16) — Übergang danach nachprüfen.

---

**H9 — Kommentar behauptet, keine der beiden Shield-Extensions deklariere die App Group; beide tun es, und taten es schon, als der Kommentar geschrieben wurde**
Dimension: Code & Architektur (zusätzlich aus Security/Privacy gemeldet — hier zusammengeführt) · `Shared/SubscriptionTier.swift:10-11`

*Szenario:* Der einzige Ort im Quellcode, der das Entitlement-Scoping der beiden Extensions beschreibt, beschreibt es rückwärts — und ist zugleich die alleinige Begründung für ein Invariant, das heute über zehn Dateien durchgesetzt wird (kein StoreKit-Import in den Extensions).

*Verifiziert:* Beide `.entitlements`-Dateien enthalten `com.apple.security.application-groups` = `group.com.example.tuck` und sind über `CODE_SIGN_ENTITLEMENTS` (`project.yml:142`, `:163`) real verdrahtet. Die Entitlements waren schon gesetzt, als der Satz zuletzt geschrieben wurde — er war beim letzten Schreiben bereits falsch.
*Aktive, nicht passive Drift:* Die Vorgängerfassung lautete "neither shield extension declares the App Group **or compiles these two files**". Eine spätere Änderung hat genau diesen Absatz neu geschrieben und nur die zweite Hälfte der falschen Klausel gestrichen. Die Engagement-Recherche (nicht Teil dieses Exports) hatte beide Hälften schon als falsch protokolliert ("Code wurde in dieser Runde nicht angefasst"). Der Satz hat also einen Doku-Durchgang **und** eine gezielte Umschreibung seines eigenen Absatzes überlebt.
*Zweite Falschaussage im selben Kommentar, von der Rohmeldung übersehen:* Zeilen 8-10 sagen, der Store bleibe App-Group-auflösbar, "so the shield-action extension can decrement the quota (B5)". `TuckShieldAction` kompiliert weder `UnlockQuotaStore.swift` noch `SubscriptionTier.swift` (`project.yml:151-157`) und dekrementiert nichts — es zeichnet nur eine Override-Anfrage auf und routet in die App. Die Extension, die das Kontingent tatsächlich liest, ist `TuckShield` (Konfiguration, nur lesend, über `OverrideContext.current()`). Falsches Entitlement-Bild, falsche Extension, falsche Operation.
*Das begründete Invariant ist real und gilt:* Alle zehn geteilten Dateien im Shield-Target importieren nur `Foundation`/`ManagedSettings`, das Target linkt nur ManagedSettings/ManagedSettingsUI. Genau das ist das Risiko — wer die Begründung prüft, feststellt, dass die App Group sehr wohl deklariert ist, und daraus schließt, die Regel sei spekulativ, entfernt eine lebende Beschränkung.
*Warum HIGH und nicht LOW:* Nachweislich falsch auf zwei unabhängigen Achsen, alleinige Begründung eines aktiven Invariants — und LOW hieße in diesem Projekt "dokumentieren", was hier bereits einmal geschah und die Sache nachweislich nicht erledigt hat. Kein BLOCKER: zur Laufzeit verhält sich nichts falsch, der Fix sind zwei Sätze.
*Nachbarkommentare, die auf derselben Prämisse ruhen:* `Tuck/WakeAlarmStore.swift:18-22` ist als Portal-Provisionierung gelesen vertretbar; `Shared/UnlockQuotaStore.swift:27-31` ist halb vertretbar — "once the entitlement lands" geht, aber es nennt ebenfalls die Shield-Action-Extension als Leser/Dekrementierer.

---

### 2.3 LOW (33)

#### Design & Design-System (10)

**L1 — Gestapeltes Paywall-Sheet: aus §5.11s "sieben Präsentationsstellen, keine Ausnahme" sind acht geworden**
`Tuck/BedtimeSetupView.swift:36`
`grep -c ".sheet(isPresented"` über `Tuck/` = **8** (SettingsView 5, GutenMorgenView 2, BedtimeSetupView 1); §5.11 (`:555`) und §8 A15 (`:785`) zählen beide sieben und listen genau die anderen sieben auf. Die achte kam mit dem Plus-Gate (2026-09-05) *nach* Schließung von A15. Von den Einstellungen aus ist der Weg drei Sheets tief.
*Aber:* funktional nichts kaputt. §5.11s "SwiftUI stapelt keine zweiten Sheets" bezieht sich auf eine Shield-Anfrage, die beim selben Präsentator ankommt (der Bug der Shield-Runde vom 2026-09-04, siehe Audit-Log) — ein Sheet aus bereits präsentiertem Inhalt zu öffnen ist reguläres SwiftUI, die Paywall geht auf. BUILD SUCCEEDED. `ShieldOverridePresentation.mayConsumeRequest` hängt an `showSettings`, das über den ganzen Stapel true bleibt — kein Nebeneffekt. Das "zwei Kopien einer Sache wie A8/A15"-Argument trägt nicht: jede View hält ihren eigenen `access`-State und aktualisiert nur sich selbst. Die Route selbst ist in den offenen Fragen (nicht Teil dieses Exports) entschieden; nie nachgezogen wurde die Präsentations-Buchführung. Erreichbar erst nach Ablauf der 14-Tage-Trial. **Fix ist eine Doku-Änderung.** (Visuelle Bestätigung im Simulator nicht möglich — Berechtigung verweigert.)

**L2 — Die Inline-Notiz behält `.padding(10)`**
`Tuck/AccessAndAppSelectionView.swift:162`
§4.2 (`:243`) und §5.5 Do's (`:424`) legen das blanke `.padding()` fest. Herkunft: `:162` stammt vom 2026-09-03, `:164` vom 2026-09-05 (A10-Radius-Pass, der den Radius 12 → 16 zog und das Padding daneben stehen ließ). §8 A10 nennt `:164` ausdrücklich und schweigt zum Padding.
*Formulierungskorrektur:* nicht "die einzige Karte/Platte ohne blankes `.padding()`" — `PrimaryButtonPlate.swift:19` und `SpeechBubble` haben ebenfalls nicht-blanke Innenabstände, sind aber dokumentierte Komponenten-Token. Präzise: die einzige, die **weder** blank **noch** dokumentiertes Token ist. Folge: 6 pt engerer Einzug an einer Box, Kontrast unverändert (3,82:1), kein Überlauf.

**L3 — Fünfte Flächen-Alpha: der Atem-Kreis füllt Sage bei 0.6**
`Tuck/OverrideFlowView.swift:213`
§2.3 nennt vier Stufen (0.5/0.25/0.45/0.9) und bezeichnet sie als die faktische Elevation der App. Eigener Alpha-Sweep über `Tuck/`, `Shared/`, `TuckShield/` bestätigt: für Volltonflächen nur diese vier — plus diese eine 0.6. Die anderen `0.6`-Treffer sind Text (`ContentView.swift:9`, in §8 A2 dokumentiert), ein `scaleEffect` (Mascot-Sprosse) und Animationsdauern.
*Provenienz-Korrektur:* die Zeile stammt aus dem Bau des Override-Flows (2026-09-02). Substanz unverändert.
*Für den, der es auflöst:* Ein mechanischer Sweep auf die nächste dokumentierte Stufe wäre falsch. §2.3s eigene Regel ("die Stufe folgt der Handlung, nicht der Optik") würde eine nicht antippbare Dekoration auf 0.25 legen und damit das Fokus-Element einer geführten Atemübung fast auslöschen. §4.4 spezifiziert die Größen des Kreises bereits — das Design-System kennt das Element und nennt seine Füllung nie.

**L4 — §5.2 nennt die falsche Menge und die falsche Zahl für den A8-Nebenbefund**
`docs/design/design-system.md` §5.2, zweiter Absatz (~`:325`)
Der Satz behauptet, "Plus ansehen" am Bettzeit-Gate sei "die einzige Sage-Plate des Bestands, deren Modifier am Label hängen", und "die vier älteren" trügen den Nebenbefund weiter. Beide Hälften sind falsch: zwei der fünf gelisteten Einträge hängen am Label (Bettzeit-Gate **und** die drei Override-Gründe), und den Defekt tragen **drei** Platten (siehe H6). Der Absatz beschrieb schon bei seiner Entstehung einen Zustand, den es nie gab — keine Drift, sondern von Anfang an falsch. Kosten: Fehlleitung in beide Richtungen — wer eine vierte kaputte Platte sucht, findet keine; wer §5.2 wörtlich folgt, baut die bereits korrekten Override-Buttons um. Dieser Satz **ist** die Nachverfolgung des Themas, und er ist das Falsche daran.

**L5 — §5.1s Working-Zustand schreibt `.tint(tuckCream)` vor; der Kaufbutton nutzt `tuckPrimaryPlateLabel`**
`docs/design/design-system.md:308` und `:782` (§8 A12) vs. `Tuck/PaywallView.swift:240`
Der Code ist nach A7 der richtige: `tuckCream` löst dunkel auf Night Ink auf, ergäbe auf Moon Plate rund 2,1:1 — ein praktisch unsichtbarer Spinner in dem einen Working-Zustand der App, den man wirklich sieht (`product.purchase()` wartet auf den App Store). **Zwei stale Stellen, nicht eine** — und A12 ist ausgerechnet der Changelog-Eintrag zu dem Commit, der die Zeile geschrieben hat. Entschärfend: die Token-Tabelle 20 Zeilen darüber (`:288`) ist korrekt, der falsche Weg ist also nicht der einzige angebotene. Risiko: wer §5.1s Working-Zeile wörtlich folgt, führt genau die A7-Rollenkollision wieder ein, gegen die die Rollen-Token existieren.

**L6 — Eine zweite Formulierung für denselben "StoreKit hat noch nicht geantwortet"-Moment**
`Tuck/PaywallView.swift:248`
Bei leerem Produktkatalog ersetzt `Text("Preis wird geladen …")` die gesamte Primäraktion, während `statusTitle` (`:94`) und `SettingsView.swift:326` für den unbeantworteten Zustand "Wird geprüft …" sagen — die Zeile, auf die A20 beide Screens unter G6 vereinheitlicht hat. Beide Strings sind separat übersetzt. Beide Zweige hängen an derselben `.task` (`:55-62`), beim ersten langsamen Öffnen zeigt der eine Screen also drei Formulierungen desselben Wartens (Statuskarte, "—" in den Plan-Zeilen, Button). §5.13 listet drei Zustände, dieser vierte steht nirgends.
*Schärfer als gemeldet:* `loadProducts()` fängt den Fehler in `notice = .failed(...)` und lässt `products` leer, ohne Retry im offenen Screen. Dann sagt der Button dauerhaft "Preis wird geladen …", während die Karte darunter "Hat gerade nicht geklappt" sagt — eine Zeile, die eine Handlung behauptet, die nicht mehr läuft. Das ist der G3-taugliche Grund für die Änderung, nicht die Dublette.
*Doku-Randbefund:* §5.4 `:400`, §7 `:741` und A20 `:790` referenzieren `SettingsView.tierValue` — ein Symbol, das es nicht mehr gibt (0 Grep-Treffer); A20s Zeilenangaben sind ebenfalls veraltet.

**L7 — Das Onboarding nutzt eine undokumentierte zweite Seitenhintergrund-Behandlung**
`Tuck/OnboardingFlowView.swift:22-28`
`LinearGradient(colors: [Cream, Sage.opacity(0.35)])` als Grund des allerersten Screens jedes neuen Nutzers. Repo-weiter Gradient-Grep: nur drei Familien — `MorningSky` (dokumentiert), das Shield-Mascot-Icon, und diese. Jeder andere Vollbildgrund ist ein flaches Token. Die Fläche steht in keiner der Kontrast-Inventuren (§2.3/§2.4/§2.4.1) und in keinem §8-Eintrag.
*Zwei Korrekturen:* es wäre eine **fünfte** Alpha, nicht die sechste; und §2.2 sagt nirgends "nur" — §2.3 erlaubt Alpha ausdrücklich auch auf Gradienten. Es ist also eine Inventur-Lücke, kein Regelbruch. Selbst gerechnet: Charcoal Green auf dem kompositierten Hell-Grund = **~3,75:1**, innerhalb des bestehenden Bandes der App. Nebenbei kohärent: `MorningSky.swift:39` endet die Himmel-Sequenz ebenfalls auf einer Cream→Sage-Bewegung. Die Zeile ist seither unverändert, hat jeden Sweep vom 2026-09-05 überlebt, inklusive der Dark-Mode-Runde, deren Bericht das Onboarding namentlich als geprüft nennt.

**L8 — §8 A11s Schlusssatz ist veraltet: der 8-pt-Außeneinzug, den er als bewusst stehengelassen führt, ist weg**
`docs/design/design-system.md:781`
§4.2 (`:246`), §8 A8 (`:778`) und §5.1 sagen alle, der Einzug sei seit 2026-09-05 entfernt; der Code auch (`PrimaryButtonPlate.swift:14-23` hat nur `.padding(.vertical, 10)`, repo-weit **null** Treffer für `padding(.horizontal, 8)`). A11s Satz ist nicht durchgestrichen und steht in der Auflösungs-Prosa — liest sich als offene Aufgabe.
*Zusätzlich:* A11s beide Zeilenanker sind selbst stale (`OnboardingFlowView.swift:168` ist heute `#Preview`, `AccessAndAppSelectionView.swift:206` eine schließende Klammer). A8s eigene Anker stimmen noch. Das Design-SSOT widerspricht sich damit selbst.

**L9 — In-Code-Kontrastnotiz sagt 5.64:1, Spec und gepinnter Test sagen 5,65:1**
`Tuck/GutenMorgenView.swift:10`
Eigene Neuberechnung (Moon Plate @0.9 über Night Ink, Ink Moon Sage): **5,64523** → nach der Projekt-Rundung 5,65. 5.64 ist Abschneiden statt Runden. `xcodebuild test -only-testing:TuckTests/DarkContrastTests` → TEST SUCCEEDED, die Methode ist also gegen die echte UIColor-Auflösung geeicht. Die Notiz im Code kam mit demselben Commit, der 5,65 als Test-Pin und Doku-Zeile schrieb — die handgetippte Zahl driftete gegen die eigenen Quellen im selben Commit.
*Korroborierter Nebenbefund, ungepinnt:* Die **helle** Zahl im selben Kommentarblock (`:7`, "4.46:1") trägt dieselbe Hundertstel-Drift. Zwei Neuberechnungen in dieser Runde ergaben 4,47265 → **4,47**. Sie steht an sechs Stellen (`GutenMorgenView.swift:7`, `design-system.md:99, 119, 476, 484, 771`) und wird von **keinem** Test gedeckt. Nicht durch einen laufenden Test bewiesen (das hieße eine Testdatei anzulegen, in einem Read-only-Audit ausgeschlossen) — aber die Rechenmethode ist auf der Dunkel-Seite testverifiziert.

**L10 — Settings-Zeile übergibt einen leeren Wert, was §5.4 ausschließt ("Nie leer")**
`Tuck/SettingsView.swift:103`
`row(title: "Entwickler-Status", value: "")` ist die einzige `value: ""`-Aufrufstelle der App. Die Helfer-Kette (`:197` → `:261`) rendert `Text(value)` ohne Leer-Prüfung, und `value:` hat keinen Default — eine wertlose Zeile ist keine vorgesehene §5.4-Variante.
*Korrektur:* Es rendert **nicht** kaputt. `Text("")` kollabiert auf null Breite, die Zeile sieht wie eine gewöhnliche Navigationszeile aus, VoiceOver liest "Entwickler-Status". Kein Rendering-Defekt, eine undokumentierte Abweichung von der Regel einer Produktionskomponente. Präzedenz: §8 A2 ist exakt dieselbe Klasse (DEBUG-gated, erreicht keinen Nutzer) und wurde trotzdem behoben, "weil die Ausnahme nirgends in der Datei steht". Die bestehenden DEBUG-Ausnahmen (§2.5, §3.4, A2) nennen alle `ContentView.swift`, also den *Inhalt* des Sheets — nicht diese Aufrufstelle in der Produktions-`SettingsView`.

#### Code & Architektur (7)

**L11 — `secondOfDay`/`timeComponents` in vier bzw. drei Kopien ohne gemeinsame Quelle**
`Shared/MorningBlockWindow.swift:96`, `Shared/BedtimeStore.swift:67`, `Tuck/WakeAlarmStore.swift:121`, `Tuck/MorningSky.swift:47` (+ inline `MorningSky.swift:19`)
Vier byte-identische `private static`-Körper, plus eine fünfte ausgeschriebene Kopie. Die Umkehrung existiert dreimal funktional (`WakeAlarmStore.swift:125`, `BedtimeStore.swift:71`, und ausgeschrieben in `MorningBlockWindow.swift:107`) — die Rohmeldung sagte zweimal. Kein Ziel-Mitgliedschafts-Hindernis: `MorningBlockWindow` ist bereits in App und Shield.
*Warum nur LOW und nicht HIGH:* Die duplizierte Einheit ist eine nebenwirkungsfreie Ein-Ausdruck-Arithmetik, deren korrekte Form an jeder Stelle selbstevident ist. Das ist qualitativ anders als A13 (~20 voneinander abhängige Zeichenkonstanten, wo Drift unsichtbar ist) oder A21 (Copy, wo Drift nutzersichtbar ist). Heute null Drift, verifiziert.
*Interessantere Nachbardublette, die die Meldung übersah:* `MorningSky.swift:13` rechnet die Fensterlänge als `(end - start + 86_400) % 86_400` und dupliziert damit die **Semantik** von `MorningBlockWindow.durationSeconds` mit einer abweichenden Implementierung — einfaches Add-dann-Modulo gegen das doppelte Modulo, das `MorningBlockWindow` mit Begründung (`:103-105`) für negative Offsets braucht. Zwei Wächter für eine Regel, weil die Helfer `private` sind. Das ist das echte Drift-Risiko, nicht die Arithmetik.

**L12 — `take()` löscht den Schlüssel bedingungslos, auch wenn nichts gelesen wurde**
`Shared/ShieldOverrideRequest.swift:45`, `Shared/ScreenTimeNotice.swift:49`
Beide Cross-Process-Übergaben haben `defer { clear/removeObject }` **vor** dem Guard, der entscheidet, ob überhaupt etwas konsumiert wurde. Swift führt `defer` auf jedem Ausgangspfad aus, auch `return nil` — der Mechanismus ist eine Sprachgarantie, kein Timing-Argument. Die App ruft beide `take()` bei **jedem** Foregrounding (`GutenMorgenView.swift:245`, `:247`, `:279`, `:281`, `:296` — zwei mehr als gemeldet), der "nichts gefunden"-Pfad ist also mit Abstand der häufige.
*Reichweite größer als gemeldet:* Unter *unvollkommener* Sichtbarkeit ist das Fenster nicht Nanosekunden, sondern die volle cfprefsd-Propagationslatenz. Auf dem B8-Pfad: Shield schreibt, App kaltstartet, `.task` liest bei `:245` nil, das `defer` löscht danach den bereits committeten Schlüssel. Das widerspricht direkt dem eigenen dokumentierten Design in `GutenMorgenView.swift:52-56`, das darauf baut, dass eine ungelesene Anfrage ihre Fünf-Minuten-Gültigkeit überlebt.
*Aber schmaler als gemeldet:* Unter *perfekter* Sichtbarkeit ist ein echtes Rennen auf dem Shield-Pfad strukturell unerreichbar (iOS' Ein-Vordergrund-Modell; eine suspendierte App führt kein `take()` aus). Für `ScreenTimeNotice` ist es erreichbar, weil `eventDidReachThreshold` auch Tucks eigene Vordergrundzeit zählt (bewusst offen, Audit-Log-Eintrag vom 2026-09-04).
*Interne Spannung, die dabei sichtbar wird:* `UnlockQuotaStore.swift:153-159` behauptet Cross-Process-Lesefrische unter Berufung auf `NSUserDefaults.h`, während die offenen Gerätefragen 13/18 genau diese Sichtbarkeit als ungeprüft führen. Beides kann nicht gleichzeitig tragen.
*Eskalationskriterium:* Beantwortet der Gerätetest Q13/Q18 mit "nicht sofort sichtbar", ist das HIGH — dann degradiert die B8-Grund-Vorauswahl bei jeder Nutzung still auf die ausdrücklich verworfene "Option 4".
*Fix ist gratis und nicht rennanfällig:* Löschen in den Erfolgspfad ziehen oder den gelesenen Zeitstempel vor dem Löschen vergleichen.

**L13 — `TrialState.isActive` ist tot**
`Shared/SubscriptionAccess.swift:37-42`
Repo-weiter Grep über alle Dateitypen: genau ein Treffer, die Deklaration selbst (der zweite ist `ManagedSettingsStore.isActive` in einer Doku-Datei, unverwandt). Kein Produktions-Aufrufer, kein Test. Der einzige Konsument (`:28`) matcht `guard case .active(let daysRemaining)` und braucht den assoziierten Wert — `isActive` könnte dort nie einspringen. Seit der Einführung nie referenziert; kein Rest einer gelöschten Aufrufstelle.
*Verstärkend:* Die unmittelbar vorhergehende Änderung an dieser Datei entfernte `SubscriptionAccess.displayName` als tot und unübersetzt — ein Geschwister-Toteintrag wurde aus genau diesem Grund bereits gelöscht. Das hier ist ein Übersehen jenes Durchgangs.
*Nebenkorrektur zur Rohmeldung:* `TuckIdentifiers.sharedCopyTable` wird von Tests referenziert (`EnglishLocalizationTests.swift:107,133,142`), der begründende Kommentar steht in `Shared/ShieldCopy.swift:12`.

**L14 — `FamilyActivitySelectionStore.clear` hat keinen Produktions-Aufrufer**
`Shared/FamilyActivitySelectionStore.swift:28`
Einziger Aufrufer ist `TuckTests/FamilyActivitySelectionStoreTests.swift:48`. Der Picker schreibt eine leere `FamilyActivitySelection`, statt den Schlüssel zu entfernen, und nichts in der App bietet "Auswahl vergessen".
*Stärker als gemeldet:* Es ist der einzige Store-`clear()` des Projekts ohne Produktions-Aufrufer — `WakeAlarmStore.clear()` (`WakeAlarmScheduler.swift:55`), `BedtimeStore.clear()` (`BedtimeScheduler.swift:46`) und `SubscriptionTierStore.clear()` (`SubscriptionController.swift:91`) haben alle einen.
*Keine Verhaltensfolge:* beide `load()`-Konsumenten behandeln eine leere (nicht-nil) Auswahl korrekt. Es ist ungenutzte API, kein latenter Defekt. Bewusst als **Entscheidung** geführt, nicht als automatische Löschung — für Symmetrie zu behalten ist vertretbar, und Löschen zöge den Test mit.

**L15 — Der Registriert-vs-Pending-Zweig steht dreimal von Hand da**
`Tuck/GutenMorgenView.swift:120-125`, `Tuck/WakeAlarmSetupView.swift:124-128`, `Tuck/BedtimeSetupView.swift:187-191`
A21 hat die *Pending*-Hälfte in `StatusCopy.windowPending` konsolidiert; der Zweig selbst und seine bestätigte Hälfte stehen weiter dreimal ausgeschrieben. Die drei bestätigten Sätze sind absichtlich verschieden — der duplizierte Teil ist der **Wächter**: jeder Screen erinnert sich selbständig daran, sein Registrierungs-Flag zu konsultieren, bevor er ein Fenster als scharf ausgibt, und das ist auf dieser Fläche das gesamte G3.
Grep bestätigt: genau diese drei Flächen rendern ein Fenster. Beide Methoden sind `private static` und **untestet**; die Suite prüft nur `StatusCopy.windowPending`/`blockWindowNoun` direkt. Ein vierter Screen, der ein Fenster rendert und den Zweig vergisst, kompiliert, besteht die Suite und verletzt G3 still.
*Detail für einen Fix:* Die drei Stellen lesen drei **verschiedene** Bestätigungsquellen (GutenMorgenView den `@State`-Schnappschuss, die beiden Setup-Views ihre Store-Statics zur Renderzeit). Ein Helfer muss `confirmed: Bool` als Parameter nehmen; einer, der das Flag selbst liest, passt nicht. Der Gewinn ist dünner als er klingt — der Aufrufer liefert weiter seinen eigenen bestätigten Satz. Was er kauft: aus "dran denken zu verzweigen" wird eine Signatur.

**L16 — Zeitformatierung: zwei Implementierungen an drei Stellen, die geteilte ohne Test**
`Tuck/WakeAlarmSetupView.swift:131-141` (`MorningBlockWindowFormatter`, `String(format: "%02d:%02d")`), `Tuck/WakeAlarmSetupView.swift:111-115` und `Tuck/SettingsView.swift:348-352` (zwei byte-identische private `DateFormatter`-Statics)
`MorningBlockWindowFormatter` ist ein projektweiter Helfer (drei Aufrufer in drei Dateien), lebt in einer View-Datei und hat **null** Tests.
*Das Lokalisierungs-Argument der Rohmeldung ist empirisch falsch* — mit echtem Swift gegen Foundation geprüft: de_DE/en_US/en_GB/en_AU, auch mit explizitem `hours=h12`-Override, lösen `HH:mm` auf und liefern `07:05`, identisch mit dem hartkodierten Pfad. Divergenz gibt es nur in nicht ausgelieferten Locales (ja_JP, ar_EG). Es gibt heute in keiner der beiden Sprachen eine sichtbare Inkonsistenz.
*Was bleibt, ist schärfer als gemeldet:* Der Wecker-Satz (`WakeAlarmSetupView.swift:92`/`:101`) interpoliert Locale-Formatter **und** `MorningBlockWindowFormatter`-Ausgabe in **denselben** Satz. Am Tag, an dem jemand das Template ändert (z. B. auf `j:mm` für einen 12-Stunden-Markt — die richtige Bewegung, wenn ein solcher dazukommt), divergieren die zwei Hälften eines Satzes still, und kein Test fängt das.
*Der Test-Ausreißer ist systematischer als gemeldet:* Jeder andere reine, nicht-View-Typ, der in einer View-Datei wohnt, hat einen eigenen Test — `ShieldOverridePresentation`, `FlowPhase`, `MascotStage`/`IdleBeat`, dazu StatusCopy, MorningCopy, BlocklistSuggestions, MorningRecognition, ScreenTimeNotice. Dieser Formatter ist die einzige Ausnahme.

**L17 — `MascotStage.progressDescription` ist untestet, obwohl es VoiceOver-Wert und Settings-Zeile ist**
`Tuck/MascotView.swift:77-83`
Konsumiert an zwei nutzersichtbaren Stellen: `SettingsView.swift:76` (Zeile "Fortschritt") und `GutenMorgenView.swift:114-115` → `.accessibilityValue` des Fortschrittsrings (`:154`). Repo-weiter Grep: fünf Treffer, alle unter `Tuck/`, keiner in `TuckTests/`. Zwei Format-Varianten mit je drei geordneten Interpolationen; beide englischen Übersetzungen existieren (`Localizable.xcstrings:154`, `:180`) und werden von nichts behauptet — obwohl `EnglishLocalizationTests` zwei andere Format-Strings genau so durch den englischen Katalog zieht.
*Zwei Detailkorrekturen:* Der "kein nächster Stufe"-Zweig ist nicht nur bei 30+ echten Morgen erreichbar — `displayedMornings` fällt auf `previewStage?.completedMornings` zurück, der Entwickler-Preview-Picker erreicht ihn direkt. Und es versteckt sich kein Laufzeitdefekt dahinter: die positionalen Specifier stimmen in beiden Sprachen, der englische Singular ("1 mornings") ist unerreichbar. Reine Abdeckungslücke gegen den eigenen, sonst konsequenten Standard.

#### Accessibility (2)

**L18 — Das Maskottchen trägt Button-Trait und Handlungs-Hinweis, aber keine Accessibility-Action**
`Tuck/GutenMorgenView.swift:169-172`
`.accessibilityElement(children: .ignore)` → Label → `.isButton` → Hinweis "Tippen für ein paar Worte", während die Tap-Behandlung ein blankes `.onTapGesture` in `MascotView.swift:351` ist. Repo-weit **null** `accessibilityAction`, kein UI-Test-Target, das es abdecken könnte.
*Überzogen an der Rohmeldung:* Die Behauptung, `children: .ignore` mache die Aktivierung unmöglich, ist zu mechanisch formuliert. `.ignore` verwirft Kind-Elemente, entfernt aber den Gesture-Recognizer nicht; VoiceOvers Doppeltipp synthetisiert mangels expliziter Aktion einen Touch am Aktivierungspunkt, der eine SwiftUI-`.onTapGesture` häufig erreicht. Die Aktivierung funktioniert also womöglich — auf undokumentiertem Fallback-Verhalten, auf das sich die App still verlässt. Der eindeutige Defekt ist: `.isButton` plus Handlungs-Hinweis ohne `.accessibilityAction`, gegen Apples Leitlinie für Custom-Gesten, und es ist das einzige solche Versprechen der App.
*Die verstärkende Hälfte ist voll bestätigt:* Selbst bei geglückter Aktivierung liefert die Sprechblase nichts Hörbares (siehe H7) — der Hinweis beschreibt eine Erfahrung, die VoiceOver nie bekommt. Zusätzlich begrenzt `guard index < 3` in `tapMascot` die Phrasen auf die ersten drei Taps pro Erkennung. §6.3 behauptet derweil, diese Achse sei geschlossen.
*Doku-Randbefund:* §5.10s Accessibility-Absatz zitiert `GutenMorgenView.swift:135-137`/`:145-148`; real sind es `:152-154` und `:169-172`.

**L19 — §6.4 führt `FamilyControlsAccessSection` weiter als einzige Fläche ohne eigene Scroll-Ebene im Sheet; der Code hat eine**
`docs/design/design-system.md:704` (und `:700`) vs. `Tuck/AccessAndAppSelectionView.swift:188-197`
Der nicht-genehmigte Zweig ist in `.scrollableWhenTallerThanScreen()` gewickelt, der "Schließen"-Primärbutton bleibt außerhalb (`:201-203`), passend zur §5.1/§6.4-Regel. Ursache: eine Änderung vom 2026-09-05 ("let the access sheet scroll instead of clipping its own buttons") betraf genau eine Datei — die Swift-Datei, keine Doku.
*Zusatz:* Auch `:700` ist betroffen — die "Angewandt auf"-Liste nennt dieses dritte Sheet nicht, und es ist die dokumentierenswerte Variante, weil der Wrapper hier *innerhalb* des Hosts auf einem Zweig sitzt statt an der Aufrufstelle. Abdeckungsprüfung: die einzigen zwei Nutzungsstellen sind dieser Host und `OnboardingFlowView.swift:103`, letztere über den Flow-Wrapper gedeckt — der Satz ist ausnahmslos falsch, nicht nur teilweise.
*Die zweite Hälfte des Vermerks bleibt gültig und muss stehen bleiben:* Der `.denied`-Zustand ist im Simulator unerreichbar, die längste Zeile des Screens (A14-Copy, `:44`) ist weiter nicht am Bildschirm geprüft. Risiko der Staleness: ein nächster Geräte-Durchgang wiederholt fertige Arbeit.

#### Usability & Copy (8)

**L20 — "Freigeschaltet" behauptet Erfolg für einen Schreibvorgang, den das SDK nie bestätigt**
`Tuck/OverrideFlowView.swift:259`
Der Bestätigungs-Screen sagt im Perfekt "Freigeschaltet" plus "Noch N für heute übrig", direkt nach `context.unlock()` — während der Kommentar desselben Pfads (`:5-11`) sagt: "this is the attempt, never evidence", und `Shared/ShieldApplication.swift:10-12` das auf SDK-Ebene stützt. G3 (`design-system.md:17`) kennt keine ManagedSettings-Ausnahme. Kein §8-Eintrag, kein Test pinnt die Copy — ein Fix bricht nichts.
*Korrektur 1:* "Jede vergleichbare Fläche verweigert diese Behauptung" ist falsch. `BedtimeSetupView.swift:168` sagt "Bettzeit entfernt. Abends bleibt jetzt alles offen." auf demselben stillen `ShieldApplication.clear` — acht Zeilen unter dem Kommentar, der erklärt, warum die Scharf-Hälfte nicht behauptet werden darf. **Zwei Instanzen, nicht eine**; ein Fix muss beide treffen, sonst verschiebt er die Inkonsistenz nur.
*Korrektur 2, severity-tragend:* Die Richtung zählt. G3s kanonischer Fall ist die Behauptung, eine Sperre sei *scharf* — latent falsch, erst am nächsten Morgen entdeckt. Hier wird behauptet, die Sperre sei *gefallen*. Im dominanten Pfad ist das wahr (ein Shield kann nur stehen, wenn Family Controls autorisiert ist, und genau diese Autorisierung lässt `clear()` wirken); wo es falsch ist, merkt der Nutzer es in Sekunden. Wirklich schädlich ist nur der eigene dokumentierte 30-Sekunden-Grenzfall (Audit-Log, Eintrag vom 2026-09-04): Kontingent verbraucht, Sperre bleibt, Screen meldet eine abgeschlossene Transaktion, die nicht stattfand.

**L21 — Der Override-Button steht den ganzen Tag; die eine tägliche Freischaltung ist um 15:00 für ein nicht laufendes Fenster ausgebbar**
`Tuck/GutenMorgenView.swift:223-233`
"Ich brauche kurz Zugriff" hängt ohne Fenster-Prüfung in der Wurzelspalte; `OverrideFlowView.swift:232-249` fährt die 30 Sekunden und ruft `context.unlock()` bedingungslos; `UnlockQuotaStore.morning.freeUnlockMaximum` ist 1. Der Reason-Picker sagt nirgends, dass gerade kein Shield steht.
*Vier Korrekturen, die die Meldung entschärfen:* (1) Das Aushängeschild-Beispiel 15:00 ist der harmlose Fall — der Morgen-Anker hängt am Kalendertag, ein Tap nach dem Fenster verbrennt ein Kontingent ohne verbleibende Verwendung; funktionaler Verlust: null. Der wirklich schädliche Fall wird nie genannt: ein Tap zwischen Mitternacht und Fensterbeginn. (2) `TrialStore.startIfNeeded()` gibt jedem Neuinstallierer 14 Tage Plus, und `consumeUnlock` schreibt bei `.unlimited` nichts — Neugier-Taps in genau dem Zeitraum, in dem sie am wahrscheinlichsten sind, kosten nichts. (3) Kein Ein-Tap-Verlust: 30 Sekunden absitzen; Wegwischen trifft die `Task.isCancelled`-Guards und gibt nichts aus. (4) **Der Außer-Fenster-Pfad ist bewusst und tragend**, nicht übersehen: `Shared/OverrideContext.swift:15-19` dokumentiert ihn ausdrücklich, und da die `intervalDidEnd`-Zuverlässigkeit noch offene Gerätefrage ist und `ShieldCopy` auf 26.2–26.4 den Sekundärbutton ganz ausblendet, ist dieser Button der einzige In-App-Ausweg aus einem Shield, das sein Fenster überlebt hat. Ihn außerhalb des Fensters zu verstecken würde genau diese Nutzer einsperren.
*Was echt bleibt:* Der Picker sagt nicht, dass keine Sperre läuft, und der Bestätigungs-Screen meldet "Freigeschaltet" für eine nie angewandte Sperre. Billig zu beheben (eine Copy-Zeile, wenn kein Fenster läuft; ggf. stale Shield räumen ohne zu belasten).

**L22 — Nach Ablauf der Testphase liest die gespeicherte Bettzeit als "wartet aufs Scharfstellen" und ist nicht entfernbar**
`Tuck/BedtimeSetupView.swift:128-136` (der einzige `clearBedtime()`-Aufrufer, im `setup`-Zweig) und `Tuck/SettingsView.swift:306-307`
*Die Rahmung der Rohmeldung überlebt das Lesen des ganzen Screens nicht.* Der Pending-Satz steht nicht allein: darüber stehen "Das Bettzeit-Fenster gehört zu Plus", "Mit Plus stellst du die Zeit hier ein." und ein "Plus ansehen"-Button zur Paywall (`:53-77`). Der Grund wird zweimal genannt, und das Scharfstellen passiert bei Kauf wirklich — `BedtimeGateTests.swift:90-95` pinnt genau das. "noch nicht scharf gestellt" ist wörtlich wahr. Die Komposition ist zudem in den offenen Fragen (nicht Teil dieses Exports) ausdrücklich so spezifiziert, inklusive der Entscheidung, die Bettzeit zu behalten ("sie ist die Absicht des Nutzers, nicht das Entitlement"). Und "nichts sagt dem Nutzer, dass die Testphase endete" ist falsch: `SettingsView.swift:332-333` kippt von "Testphase · noch N Tage" auf "Frei · 1 pro Morgen". Was fehlt, ist eine *proaktive* Benachrichtigung — eine Produktwahl, kein Defekt.
*Was real bleibt:* Ein abgelaufener Nutzer mit gespeicherter Bettzeit kann sie **weder sehen noch entfernen** — der einzige Entfernen-Button liegt im `setup`-Zweig, und die Settings-Zeile maskiert den Wert mit "Teil von Plus". Folgekosten klein (das Fenster ist entschärft, funktional geht nichts verloren), aber es bleibt ein Datensatz, den man nicht loswird, plus die Überraschung, dass eine vergessene Trial-Bettzeit bei späterem Abo still wieder scharf wird (dieses Wiederscharfstellen ist selbst als gewollt dokumentiert). Kein §8-Eintrag, kein Eintrag in der Liste der nächsten Schritte.

**L23 — Drei Periodenwörter für dieselbe eine freie Freischaltung, einen Tap auseinander**
`Tuck/SettingsView.swift:333` ("pro Morgen") vs. `Tuck/PaywallView.swift:106, 112, 116, 152` ("pro Tag") vs. `Tuck/OverrideFlowView.swift:138, 264` ("heute")
Alle aus derselben Konstante. Die Settings-Zeile öffnet per Tap genau die Paywall, die anders spricht. Alle Schlüssel separat übersetzt; `EnglishLocalizationTests.swift:279-282` und `:236` pinnen beide Dialekte — die Drift korrigiert sich nicht von selbst. `Shared/ShieldCopy.swift:73`/`:76` ist eine fünfte, ebenfalls "heute"-sprechende Fläche.
*Zwei Korrekturen:* Erstens ist die Behauptung, §5.4 zitiere die Settings-Zeile im "pro Morgen"-Dialekt, **falsch** — §5.4 enthält kein solches Zitat. Zweitens sind es nicht drei gleichrangige Dialekte, sondern **ein Ausreißer** gegen eine konsistente Tag/heute-Familie über fünf Flächen. Und "pro Morgen" ist die Formulierung, die die Mechanik falsch beschreibt: `UnlockQuotaStore.swift:39-44` setzt `dayRolloverHour: 0`, und der Kommentar (`:83-89`) ist ausdrücklich, dass der Reset allein aus `now` folgen muss — eine Kalendertagsgrenze, bewusst vom Morgenfenster entkoppelt. Der dokumentierte Restfall (ein Fenster, das die Rollover-Stunde überspannt, gewährt einen Extra-Slot) ist genau der, in dem "1 pro Morgen" falsch und "1 pro Tag" wahr wird. Richtungsentscheid für den Fix: Settings → "pro Tag" / "per day", nicht umgekehrt.
*Keine falsche Zahl:* die Konstante ist überall 1, null funktionale Wirkung.

**L24 — Der Erschöpft-Screen der App ist kontextblind und widerspricht dem Shield, mit dem er wortgleich sein soll**
`Tuck/OverrideFlowView.swift:192`
`exhausted` hardcodet "Morgen ist wieder ein neuer Morgen.", während `ShieldCopy.swift:70-78` nach Kontext verzweigt (`.bedtime` → "neuer Tag"). Die View **hält** `let context` (`:75`) und nutzt ihn bei `:138` und `:242` — sie ignoriert ihn nur in diesem Zweig. Erreichbar: `UnlockQuotaStore.bedtime.freeUnlockMaximum` ist 1, ein freier Nutzer landet nach einer Abend-Freischaltung dort.
*Zwei Verschärfungen:* Der App-String stammt nicht nur aus einem unverzweigten Ausdruck, sondern aus einem **anderen Katalog** (`Localizable.xcstrings:682` statt `Shared/SharedCopy.xcstrings:44,54`) — damit sind §5.8 ("beide Seiten aus derselben Quelle") **und** §7 `:753` ("Die G6-Anforderung ist damit erfüllt und kein offener Punkt mehr") beide unzutreffend. Und die Lücke ist bereits in einem Test einzementiert: `EnglishLocalizationTests.swift:104-125`, `theExhaustedCopyIsWordForWordIdenticalOnBothSides`, iteriert beide Kontexte, klammert die Volltext-Assertion aber mit `if context == .morning` — ohne erklärenden Kommentar. Der Test läuft grün und kann das strukturell nicht fangen.
*LOW, weil* der Satz im Abend-Kontext wahr und tonal tragbar bleibt; keine funktionale, Kontingent- oder Sperr-Folge. Wert liegt in den Kosten (Zweig und beide Übersetzungen existieren) und darin, dass drei Doku-Aussagen plus ein Testname die Parität derzeit überbehaupten.

**L25 — "in den Einstellungen" meint iOS-Einstellungen, heißt aber auch der eigene Screen**
`Tuck/WakeAlarmSetupView.swift:94` und `:103`
Beide meinen die iOS-Einstellungen-App (nirgends im Repo wird AlarmKit-Berechtigung in-app erteilt), während `AccessAndAppSelectionView.swift:44` dasselbe Ziel "Systemeinstellungen" nennt, `SettingsView.swift:112` `.navigationTitle("Einstellungen")` setzt und `GutenMorgenView.swift:218` ein `Button("Einstellungen")` ist. Verschärfend: `SettingsView.swift:140-146` präsentiert `WakeAlarmSetupView` als Sheet aus der Zeile "Weckzeit" — der Satz wird also in einem Sheet gelesen, dessen Elternscreen exakt "Einstellungen" heißt und keine Wecker-Berechtigung enthält. Repo-weit **null** `openSettingsURLString`/`UIApplication.openSettings`: das Substantiv ist der einzige Navigationshinweis, den der Nutzer hat.
Die Drift existiert auch im englischen Katalog, dort mit vierter Variante ("in Settings" vs. "in the Settings app") — und dort ist die Kollision exakt, weil der eigene Screen zu "Settings" lokalisiert. §8 A14 hält für genau diese beiden Zeilen die *Satzform* fest, nie das Ziel-Substantiv. Fix: ein Wort an zwei Stellen plus zwei englische Strings.

**L26 — Auf dem Mindest-OS (26.2–26.4) bietet das Shield ein einziges "Ich lass es" und erwähnt nie, dass es einen Weg gibt**
`Shared/ShieldCopy.swift:43-45`
`.openParentalControlsApp` verlangt iOS 26.5, das Deployment-Target ist 26.2 (`project.yml:6-7` und alle fünf Target-Einträge). `secondaryButton: exhausted || !canOpenApp ? nil : ...`, und `ShieldConfigurationExtension.swift:54` fällt auf 26.2–26.4 immer in die Konfiguration ohne zweiten Button. `ShieldCopyTests.swift:40-43` pinnt das — es ist gewollt.
*Zwei Korrekturen:* Die gemeldete Zeile 52 ist falsch (das ist der Titel-`case`); und "nirgends dokumentiert" stimmt nicht — `docs/product-decisions-2026-09-02.md:104` hält ausdrücklich fest, dass Option 3 für 26.2–26.4 bewusst **nicht** gebaut wurde und `ShieldCopy` den Button dort lieber ganz ausblendet, "statt einen Tap anzubieten, der nirgendwo hinführt". Die Button-Unterdrückung ist also ein akzeptierter, begründeter Tradeoff.
*Was übrig bleibt:* Die **Copy** wurde für die Versionsspanne nie angepasst. Der Erschöpft-Zustand macht es bei derselben button-losen Darstellung richtig ("Für heute aufgebraucht. Die Sperre bleibt bestehen.") — das Projekt weiß also, wie man einen fehlenden zweiten Button erklärt. Auf 26.2–26.4 fehlt die Erklärung, und das verbleibende Primär-Label "Ich lass es" rahmt eine Wahl, deren Alternative nie gezeigt wird. Das Onboarding erwähnt den Override in keiner Form (`OnboardingFlowView.swift:65-150`) — dieser Nutzer hat nie erfahren, dass es einen Weg gibt.
*Keine Sackgasse:* `GutenMorgenView.swift:223` trägt denselben Button in der App; das Feature ist erreichbar, nur unbeschildert. Bounded und schrumpfend: nie ausgeliefert, kein Build im Feld — das Deployment-Target vor Release auf 26.5 zu heben schließt es zu null Code-Kosten.

**L27 — Ausgelieferte Copy erzählt dem Nutzer vom "Simulator"**
`Tuck/AccessAndAppSelectionView.swift:114`
"Die Auswahl erscheint hier, sobald der Zugriff erlaubt ist — auf dem Simulator geht das nicht, auf deinem eigenen iPhone schon." Kein `#if DEBUG` in der Datei, `project.yml:34` kompiliert den ganzen Ordner unbedingt — der String ist per Konstruktion im Release. Der EN-Gegenpart existiert (`Localizable.xcstrings:652`). Von 18 Simulator-Erwähnungen im Repo ist dies die einzige, die einen Bildschirm erreicht.
*Reichweiten-Korrektur:* **Nicht** "immer wenn der Zugriff fehlt". Das Settings-Sheet zeigt bei fehlender Autorisierung `FamilyControlsAccessSection` statt dieser Sektion. Die einzige Route ist der Onboarding-Schritt `appSelection` nach "Später erlauben, weiter" (`OnboardingFlowView.swift:105`) — also genau der Pfad, den ein App-Review-Tester nimmt, der den Screen-Time-Dialog ablehnt oder aufschiebt.

#### Security & Privacy (5)

**L28 — `privacy-manifest-notes.md`: drei Meilenstein-Schlüssel fehlen in der Inventur, die Typ-Aussage stimmt nicht mehr, und §4 widerspricht §1**
`docs/privacy-manifest-notes.md:15, 18, 24, 82`
*Zwei Rohfunde zu diesem Dokument zusammengeführt und dabei gegeneinander bereinigt.* Bestätigt:
- **§1 Zeile 24** führt eine "Vollständige Liste der gespeicherten Schlüssel" mit 23 Einträgen und lässt die drei Meilenstein-Schlüssel aus: `milestoneReachedMornings`, `milestoneCelebratedMornings`, `mascotColorVariant` (`Shared/MilestoneStore.swift:7-9`, geschrieben in die App-Group-Suite über `:11-12`). Die Datei ist erst nach der letzten Doku-Änderung entstanden.
- **§1 Zeile 28** ("Der einzige nicht-skalare Eintrag ist `familyActivitySelectionData`") ist falsch: `MilestoneStore.swift:56` schreibt ein `[Int]`.
- **§4 Zeile 82** ("jeder der **zwölf** Zugriffe") widerspricht §1s eigener Zahl im selben Dokument; real sind es 16.
- **Die `140-154`-Zitate** für `withQuotaLock` sind stale (real `Shared/UnlockQuotaStore.swift:167-181`) und stehen **zweimal** (`:15` und `:18`).
*Ausdrücklich widerlegt:* Die Behauptung, §1s "an 16 Stellen" sei falsch und real seien es 17, hält nicht — einer der 17 Grep-Treffer steht in einem Kommentar (`TuckShield/ShieldConfigurationExtension.swift:29`). **16 stimmt, diese Zeile braucht keine Änderung.** Ebenso ist §7 keine Drift: "gehört in die Liste der nächsten Schritte, §5" ist präskriptiv formuliert, keine Behauptung, dass es dort schon steht.
*Substanz hält, unabhängig nachgeprüft:* Required-Reason-Grep (`systemUptime|mach_absolute|modificationDate|creationDate|volumeAvailable|statfs|activeInputModes|UITextInputMode|attributesOfItem`, dazu `resourceValues|NSFileCreationDate|getattrlist|fstat`) über alle fünf Targets: null Treffer. `FileManager` genau ein Treffer (`UnlockQuotaStore.swift:168`), nur `containerURL`/`open`/`flock`/`close`. `NSPrivacyAccessedAPICategoryUserDefaults` bleibt die einzige betroffene Kategorie, die App-Store-Antwort bleibt "Data Not Collected", das XML in §4 ist korrekt. Kein Manifest-Change nötig.
*Warum es trotzdem zählt:* Das Dokument verkauft sich in Zeile 3 als "gegen den Repo-Stand geprüft, nicht aus der Dokumentation abgeschrieben" — die Schlüsselliste ist die Beweisgrundlage für §3s leeres `NSPrivacyCollectedDataTypes`. Eine stale Inventur ist genau der Mechanismus, über den ein künftiger gespeicherter Datentyp ungeprüft durchrutscht.

**L29 — Die flock-Begründung nennt eine Extension, die das Lock nicht nehmen kann**
`Shared/UnlockQuotaStore.swift:126-130`, `docs/privacy-manifest-notes.md:18`, Apple-Developer-Checkliste §3 (nicht Teil dieses Exports)
Alle drei begründen `withQuotaLock` damit, App und Shield-**Action**-Extension seien zwei Prozesse über einer Suite. `TuckShieldAction` kompiliert `UnlockQuotaStore.swift` gar nicht — bestätigt nicht nur in `project.yml`, sondern auch in der generierten, eingecheckten `project.pbxproj` (zwei `PBXBuildFile`-Einträge, zwei Sources-Phasen: `TuckShield` und die App). Der einzige Nicht-App-Prozess, der das Kontingent liest, ist `TuckShield` (`ShieldConfigurationExtension.swift:37`), und der nimmt das Lock bewusst nicht. Der einzige `consumeUnlock`-Aufrufer im ganzen Repo außerhalb von Tests ist `Tuck/OverrideFlowView.swift:16`.
*Warum nur LOW:* Null Laufzeitwirkung. Das Lock ist heute durch einen **anderen, echten** Mechanismus gerechtfertigt, den dieselbe Datei zwei Absätze weiter korrekt benennt (`:161-163`: flock hängt an der Open-File-Description, serialisiert also auch zwei Threads in einem Prozess) — und `UnlockQuotaConcurrencyTests.swift` pinnt genau dieses Interleaving. Die Drift sitzt in der *Begründung*, nicht in der Entscheidung. Die Datei korrigiert sich zudem selbst in `:29-31` ("once the entitlement lands (Phase 2)", Futur), und die Apple-Developer-Checkliste §3 trägt zwei Punkte darüber die richtige offene Aufgabe.
*Zwei Nebenbefunde derselben Klasse:* Das Klammer-Zitat "(nicht nur `TuckIdentifiers`, wie aktuell in `project.yml`)" untertreibt — Shield-Action kompiliert bereits fünf geteilte Dateien.

**L30 — Die Apple-Developer-Checkliste führt zwei Capabilities als offen, die in allen vier `.entitlements` bereits deklariert sind**
Apple-Developer-Checkliste, Zeilen 20-21 (nicht Teil dieses Exports)
Alle vier Dateien sind in beiden relevanten Keys byte-identisch (`family-controls` = true, `application-groups` = `[group.com.example.tuck]`), und `project.yml` verdrahtet sie (`:66`, `:111`, `:142`, `:163`), die generierte `project.pbxproj` trägt alle acht Build-Config-Einträge.
*Korrektur:* Die Klammer ist nicht "invertiert", sondern überholt — `build-plan-phase1.md:119` belegt, dass sie zur Schreibzeit stimmte. Stale seit 2026-09-03 bzw. seit dem 2026-09-04.
*Bereits einmal gemeldet, nie aufgelöst:* Die Review-Notizen (nicht Teil dieses Exports) führen es als A4 ("GUI-Klicks, die `xcodegen generate` lautlos vernichtet"). Weder §8 noch die Liste der nächsten Schritte decken es. Das Gegenteil ist dokumentiert: `snooze-concept-2026-09-03.md:72` sagt "Capabilities nie in Xcode klicken" — die Checkliste widerspricht einer dokumentierten Regel.
*Verschärfend:* Die Datei wurde heute editiert (2026-09-05 13:53) — Zeile 24 wurde durchgestrichen und als erledigt markiert, Zeilen 20-21 blieben stehen. Es ist eine gepflegte Datei, keine vergessene.
*Nebenan echt offen:* Zeile 19 (Team/automatisches Signing) ist der eine §3-Punkt, der wirklich aussteht — `project.pbxproj` enthält kein `DEVELOPMENT_TEAM` — und trägt dieselbe Xcode-GUI-Rahmung, muss aber über `project.yml`.

**L31 — Der Entwurf der Datenschutzerklärung listet Meilenstein-Fortschritt und Maskottchen-Farbe nicht**
Datenschutz-Entwurf, Zeilen 19-28 (DE) und 78-87 (EN) (nicht Teil dieses Exports)
Die Liste ist ausdrücklich erschöpfend formuliert ("Alles, was Tuck über dich weiß, liegt auf deinem iPhone: …"), zehn Punkte, und nennt weder `milestoneReachedMornings` noch `milestoneCelebratedMornings` noch `mascotColorVariant`. "wie viele Morgen du abgeschlossen hast" deckt `completedMornings`, aber nicht die separate High-Water-Ratsche, die `MilestoneStore.reachedMornings` führt und nie senkt (`:20-27`) — ein Wert, der ein Restore aus einem älteren Backup bewusst überlebt und damit ein eigener aufbewahrter Datensatz ist. Der Code ist live, nicht tot (`StopWakeAlarmIntent.swift:40`, `SettingsView.swift:249`, `GutenMorgenView.swift:367-369`).
*Erweiterung:* Auch `trialStartedAt` (`Shared/SubscriptionAccess.swift:47-71`) fehlt — und das **nicht** geerbt aus L28, denn die Manifest-Notizen führen es. Nur die nutzersichtbare Liste lässt es fallen, und es ist von den vieren der substanziellste (ein datierter, an die Installation gebundener Datensatz).
*LOW, weil* nichts veröffentlicht ist: die Datei markiert sich selbst als "Entwurf, kein juristisch geprüfter Text", mit drei `(offen)`-Markern und ohne Live-URL. Es wird zum echten Genauigkeitsproblem, sobald dieser Text an der Datenschutz-URL steht.

**L32 — Kein `ITSAppUsesNonExemptEncryption` in der Info.plist, und nirgends nachverfolgt**
`Tuck/Info.plist`
Die Datei hat genau einen Key (`NSAlarmKitUsageDescription`), alles andere wird generiert. Empirisch geprüft: `plutil -p` auf der gebauten, fertig gemergten `Info.plist` zeigt keinen solchen Key — `GENERATE_INFOPLIST_FILE: YES` liefert ihn nicht. Grep über `*.md`/`*.plist`/`*.yml` nach `export|compliance|encryption|Verschlüss|Krypto|crypto`: null. §8, die Liste der nächsten Schritte, die Apple-Developer-Checkliste und beide Privacy-Dokumente kennen den Punkt nicht.
*Der richtige Wert ist `false`, und das ist belegt:* Grep nach `URLSession|URLRequest|NWConnection|CFNetwork|WKWebView|CloudKit|CryptoKit|CommonCrypto|SecKey|import Network` über alle fünf Targets: nichts. Der komplette Import-Satz des Repos ist AlarmKit, AppIntents, DeviceActivity, FamilyControls, Foundation, ManagedSettings, ManagedSettingsUI, Observation, StoreKit, SwiftUI, UIKit. Der einzige ausgehende Verkehr ist StoreKits eigenes HTTPS zu Apple — der Ausnahmefall.
*Präzisierung:* "nirgends nachverfolgt" ist auf Oberbegriffsebene leicht überzogen — die Engagement-Recherche (nicht Teil dieses Exports) führt bereits "Der TestFlight-Weg ist weiterhin nirgends beschrieben". Der konkrete Ein-Zeilen-Punkt hat aber kein Zuhause.
*Folge:* Jeder Upload bleibt in App Store Connect mit dem "Missing Compliance"-Banner stehen, bis der Fragebogen von Hand beantwortet ist — ein wiederholter, vermeidbarer Stall. Passt hier besser als `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption: NO` in `project.yml` als handeditierte Plist.

#### Stabilität (1)

**L33 — Die Liste der nächsten Schritte führt eine veraltete Test-Baseline als aktuellen Stand (162 statt 298)**
Liste der nächsten Schritte, Zeile 74 (nicht Teil dieses Exports)
"Aktueller Stand: sauberer Working Tree, alle Tests grün (162)" — präsentiert als Präsens-Zustand, nicht als datierter Schnappschuss. Echt: 299 `@Test`-Grep-Treffer minus einer in einem Kommentar (`ShieldActionRoutingTests.swift:51`) = 298 Deklarationen, und `xcodebuild test` führt exakt 298 aus. Untercount um 136 (~46 %).
*Die "das Dokument ist datiert"-Verteidigung trägt nicht:* zwei Änderungen **nach** dem Datum im Titel (beide 2026-09-05) haben neuen 2026-09-05-Inhalt in dieselbe Datei geschrieben. Gepflegtes Living Document mit einer zurückgebliebenen Zeile. 162 war beim Schreiben exakt richtig — Drift, kein Autorenfehler.
*Zweite, ungemeldete Staleness im selben Satz:* "`HEAD` folgt den Shield-Fixes vom 2026-09-04" stimmt ebenfalls nicht mehr. Ein Fix, der nur die Zahl korrigiert, lässt eine zweite falsche Präsens-Aussage stehen.
*Die Stabilitäts-Begründung geprüft, aber relativiert:* Die Zählung wäre tatsächlich der billigste Kanarienvogel dafür, dass eine Testdatei still aus dem Target fällt — `project.pbxproj` ist generiert und aus einem Verzeichnis-Glob gespeist, eine ohne Regenerierung hinzugefügte Datei verschwände lautlos. **Direkt geprüft: 34 Testdateien auf Platte, alle 34 in `project.pbxproj`, nichts ausgeschlossen.** Aber eine Prosa-Zahl ist kein Gate, das irgendwo läuft; der echte Kanarienvogel wäre ein Check, kein Satz.

---

## 3. Geprüft und als bewusster Tradeoff bestätigt — nicht erneut gemeldet

Diese Punkte tauchten im Scan auf, wurden gegen `design-system.md` §8, die Liste der nächsten Schritte und die offenen Fragen (beide nicht Teil dieses Exports), `product-decisions-2026-09-02.md` und `audit-log.md` geprüft und sind dort als entschieden dokumentiert. Sie stehen hier, damit klar ist: geprüft, nicht übersehen.

- **§8 A13 — Maskottchen-Zeichenkonstanten doppelt** (`MascotView.swift` ↔ `TuckShield/ShieldMascotIcon.swift`): ausdrücklich akzeptiert, "erwähnen, nicht eigenmächtig zusammenlegen".
- **§8 A8 — Trefferflächen-Facette der Sage-Platten**: als bekannt und verschoben dokumentiert ("notiert, nicht in dieser Runde umgebaut"). **Nur die Accessibility-Frame-Facette wird als H6 neu gemeldet**, weil sie nirgends steht und die Akzeptanz gegen eine untertriebene Beschreibung erteilt wurde.
- **Shield-Sekundärbutton auf 26.2–26.4 unterdrückt** (`product-decisions-2026-09-02.md:104`): begründete Entscheidung, Option 3 bewusst nicht gebaut. Nur die nie angepasste **Copy** wird als L26 gemeldet.
- **Die Bettzeit-Gate-Komposition im `locked`-Zweig** (offene Fragen §4): so spezifiziert, inklusive Beibehaltung der gespeicherten Bettzeit und der Reconcile-Zeitgrenze. Nur die fehlende Entfernen-Möglichkeit ist L22.
- **Der Außer-Fenster-Override-Pfad** (`Shared/OverrideContext.swift:15-19`): ausdrücklich gewollt, "including outside every window, which the shield's manual open can reach".
- **"14/15 pt @ 700 = WCAG-Großtext?"** (Liste der nächsten Schritte §2): als Frage akzeptiert und "nicht erneut aufgreifen" markiert. H5 hängt **nicht** daran — dort geht es um einen Hintergrund unter 3:1, nicht um die pt-Kategorie.
- **DEBUG-Ausnahmen für `ContentView`** (§2.5, §3.4, §8 A2): `.red` und Alpha-auf-Text im Entwickler-Sheet.
- **Tucks eigene Vordergrundzeit zählt auf denselben Bildschirmzeit-Schwellwert** (Audit-Log, Eintrag vom 2026-09-04, offene Produktfrage 17): bewusst nicht gefixt bis zum Geräte-Killkriterium.
- **Gerätefragen 13/18 — Sichtbarkeit von App-Group-Schreibvorgängen** (Liste der nächsten Schritte §4): offen, Gerät nötig. L12 ist davon unabhängig, aber die Eskalation von L12 hängt an ihrer Antwort.
- **`.denied` von Family Controls im Simulator nicht erreichbar** (`design-system.md:704`): als offene Geräte-Nachholung geführt — bleibt gültig und ist der Grund, warum H1 durchrutschen konnte.
- **`PrivacyInfo.xcprivacy` existiert noch nicht** (`privacy-manifest-notes.md §7`, Engagement-Recherche §2): bekannt und offen.
- **Apple-Developer-Checkliste, Zeile 19 (Team/Signing) und Zeilen 22-23**: legitim offen, keine Staleness.
- **`UnlockQuotaStore.swift:29-31` ("once the entitlement lands, Phase 2")**: korrekt im Futur formuliert, keine Falschaussage.
- **`TuckShield/ShieldConfigurationExtension.swift:27-32`**: bezieht sich auf Portal-Provisionierung, die laut Apple-Developer-Checkliste (Zeile 21) wirklich noch aussteht — nicht stale.
- **`§8 A23`** (Doku-Drift in `palette.md:14` und im Audit-Log): offen und bekannt; L1/L4/L5/L8 sind dieselbe Klasse, aber andere Stellen.
- **30-Sekunden-Grenzfall des Override-Taps** (Audit-Log, Eintrag vom 2026-09-04): bekannter LOW. L20s schädlichster Pfad ist genau dieser — kein neuer Fund, aber der Grund, warum die Copy-Frage überhaupt Gewicht hat.

---

## 4. Priorisierte Handlungsliste

Getrennt nach **klarem Bugfix** (Richtung ist aus dem Code oder den eigenen Regeln eindeutig ableitbar — direkt umsetzbar) und **Produktentscheidung** (echte Wahl mit Gewicht — Entscheidung des Projektinhabers, hier als Frage gestellt, nicht still gewählt).

### 4.1 Zuerst — klare Bugfixes, Reihenfolge nach Wirkung

1. **H1 — Zweig-Reihenfolge in `AccessAndAppSelectionView`.** Fehler als Peer-Zustand modellieren statt als Overlay, genau wie `WakeAlarmSetupView.swift:88-108` es schon macht; `authorizationError` in `.onAppear` räumen. Zuerst, weil es der Fehlerpfad der Voraussetzung des ganzen Produkts ist und die Korrekturform bereits im Repo liegt. *(Der fehlende Settings-Deep-Link ist eine separate kleine Entscheidung, siehe 4.2 Punkt 6.)*
2. **H2 — Auto-Dismiss an den Erfolg der Hälfte hängen, die scheitern kann.** `WakeAlarmScheduler` sollte einen Zustand liefern, der die Registrierung einschließt; zusätzlich Apples `recoverySuggestion` lesen, statt sie wegzuwerfen. Und einen dauerhaften Weg von der Pending-Zeile zur `AccessAndAppSelectionView` schaffen.
3. **H6 — `.padding()`/`.background()` an drei Stellen in den `label:`-Closure ziehen.** Eine Zeile pro Stelle, das Zielmuster existiert zweifach im Repo. Hebt drei 19,33-pt-Ziele auf 51,33 pt.
4. **H8 — Scroll-Offset beim Schrittwechsel zurücksetzen.** `ScrollViewReader` + `scrollTo` auf `.onChange(of: step)`; bei `.id(step)` die A16-Übergangsanimation nachprüfen.
5. **H7 — `AccessibilityNotification.Announcement` an den drei `bubbleText`-Schreibstellen.** Zusammen mit **L18** (`.accessibilityAction` am Maskottchen) — dieselbe Stelle, derselbe Durchgang, und danach stimmt §6.3s "geschlossen" wieder.
6. **H9 — Den Kommentar in `Shared/SubscriptionTier.swift:10-11` korrigieren**, beide Falschaussagen, und den Nachbarkommentar `UnlockQuotaStore.swift:27-31` mitziehen (Shield-Action liest das Kontingent nicht). Zwei Sätze, aber sie tragen ein Invariant über zehn Dateien.
7. **L12 — `defer` in den Erfolgspfad ziehen** (`ShieldOverrideRequest.swift:45`, `ScreenTimeNotice.swift:49`). Gratis, nicht rennanfällig, und stellt die im Code bereits beschriebene Fünf-Minuten-Retry-Sicherheit wieder her.
8. **L24 — `exhausted` nach `context` verzweigen** und den String aus `ShieldCopy` beziehen statt aus dem App-Katalog; danach die `if context == .morning`-Klammer in `EnglishLocalizationTests.swift:104-125` entfernen, damit der Test die Behauptung seines eigenen Namens wirklich prüft.
9. **L25 — "Einstellungen" → "Systemeinstellungen"** an `WakeAlarmSetupView.swift:94` und `:103` plus die zwei englischen Strings.
10. **L23 — Settings-Zeile auf "pro Tag" / "per day"** (`SettingsView.swift:333`), Richtung ist durch `dayRolloverHour: 0` eindeutig; Test-Pin `EnglishLocalizationTests.swift:279-282` mitziehen.
11. **Doku-Sanierungs-Batch in einem Durchgang:** L4 (§5.2 Satz), L5 (§5.1 `:308` + A12 `:782`), L8 (A11-Schlusssatz), L9 (5.64 → 5.65; die helle 4.46 → 4.47 erst nach eigener Nachrechnung, sechs Stellen), L19 (§6.4 `:700`/`:704`), L28 (drei Schlüssel, Typ-Aussage, "zwölf" → 16, zwei stale Zitate), L29 (flock-Begründung an drei Stellen), L30 (zwei Checklisten-Boxen), L31 (beide Sprachlisten + `trialStartedAt`), L33 (ganze Zeile, nicht nur die Zahl), dazu die stale `tierValue`-Referenzen aus L6 und die §5.10-Anker aus L18. Alle einzeln verifiziert, alle mechanisch.

### 4.2 Entscheidungen für den Projektinhaber — nicht eigenmächtig gewählt

Jede mit Vorschlags-Default, aber keine davon sollte ohne explizites Go umgesetzt werden.

1. **H5 — Der Morgenhimmel unterschreitet 3:1.** Drei echte Optionen mit unterschiedlichem Preis: (a) Ink abdunkeln — trifft die Signaturfarbe der App; (b) den Gradienten am oberen Ende heller deckeln — trifft das Kernbild "Dämmerung"; (c) sub-3:1 für Statustext bewusst akzeptieren und in §8 eintragen — kostet die Aussage "AA für großen Text wird erfüllt" in §3.1. *Vorschlag: erst die falsche Zahl korrigieren (das ist Bugfix, siehe 4.1 Punkt 11), dann entscheiden — die 2,44–4,16-Spanne ist eine andere Entscheidungsgrundlage als "~3,5 Maximum".* Zusatzfrage: soll ein Hell-Pendant zu `DarkModePaletteTests.swift:102` gepinnt werden, damit die Asymmetrie verschwindet?
2. **H3 — Was sagt der Morgen-Screen bei leerer App-Auswahl?** Dass eine leere Auswahl nicht als scharfes Fenster gelten darf, folgt aus G3 und §5.4 — die *Copy* und ob die drei Flächen dieselbe bekommen, ist eine Produktwahl. *Vorschlag: eine eigene Zeile in der `windowPending`-Familie ("Sperrfenster bis 07:30 · noch keine Apps ausgewählt"), an allen drei Stellen gleich.* Separat mitzuentscheiden: `activityCount()` zählt `webDomainTokens` nicht.
3. **H4 — Darf das Onboarding ohne Wecker enden?** (a) "Weiter" gaten, (b) durchlassen und den Morgen-Screen ehrlich degradieren lassen (`StatusCopy.unsetValue`-Familie, wie `SettingsView.wakeValue` es schon macht), (c) beides. *Vorschlag: (b) — es respektiert "nie bestrafen" und folgt §7s eigener Regel; (a) wäre die erste harte Sperre im Flow.* Der Fall "gedrückt und iOS-Dialog abgelehnt" muss mitentschieden werden, er sieht identisch aus.
4. **L26 — Deployment-Target auf 26.5 heben, oder Copy für 26.2–26.4 schreiben?** Nichts ist im Feld, das Target zu heben kostet null Code und schließt die Lücke ganz. *Vorschlag: heben — aber es ist eine Reichweiten-Entscheidung, keine technische.*
5. **L27 — Ersatzformulierung für den "Simulator"-Satz.** Dass er nicht ausgeliefert werden sollte, ist klar; womit er ersetzt wird, ist Copy. *Vorschlag: die Simulator-Erwähnung ersatzlos streichen — der Rest des Satzes trägt allein.*
6. **H1-Ergänzung / L25-Ergänzung — Deep-Link in die Systemeinstellungen einführen?** Die App hat bewusst oder unbewusst **keinen einzigen** `UIApplication.open`. Ihn einzuführen ist eine kleine Haltungsfrage (die App schickt den Nutzer aktiv woandershin) mit echtem Nutzen an drei Stellen. *Vorschlag: ja, an genau den drei Berechtigungs-Sackgassen — aber es ist eine erste ihrer Art.*
7. **L20 — Wortwahl "Freigeschaltet" / "Bettzeit entfernt".** Beides behauptet einen Schreibvorgang, den ManagedSettings nie bestätigt; die Fehlerrichtung ist selbstkorrigierend, aber der 30-Sekunden-Grenzfall meldet eine Transaktion, die nicht stattfand. *Vorschlag: beide Sätze in die Versuchs-Form ziehen, wie `StatusCopy` es auf der Scharf-Seite tut — oder ausdrücklich als G3-Ausnahme in §8 eintragen. Nicht schweigend so lassen: heute ist es keins von beidem.*
8. **L21 — Verhalten des Override-Buttons außerhalb jedes Fensters.** Verstecken ist die falsche Antwort (es sperrt Nutzer eines überlebenden Shields ein). Bleibt: Copy im Picker, oder nicht belasten, wenn keine Sperre stand, oder beides. *Vorschlag: nicht belasten, wenn kein Shield stand — das ist die G4-konforme Richtung; aber es ändert die Kontingent-Semantik und gehört deshalb entschieden, nicht gefixt.*
9. **L22 — Bekommt der `locked`-Zweig ein "Bettzeit entfernen"?** Heute kann ein abgelaufener Nutzer eine gespeicherte Bettzeit weder sehen noch löschen, und sie wird bei späterem Abo still wieder scharf. *Vorschlag: ja, plus die Zeit in der Settings-Zeile sichtbar lassen statt "Teil von Plus" — aber das berührt die in den offenen Fragen §4 festgehaltene Gate-Gestaltung.*
10. **L1 / L3 / L7 — Drei Design-System-Ausnahmen: dokumentieren oder angleichen?** Achtes Sheet (verschachtelt), fünfte Sage-Alpha 0.6, zweiter Seitenhintergrund im Onboarding. Alle drei sind heute harmlos und alle drei würden bei mechanischem Angleichen etwas verschlechtern (siehe L3). *Vorschlag: alle drei als §8-Einträge dokumentieren, §5.11s Don't auf "kein zweites Sheet beim selben Präsentator" verengen — das ist das, was die Shield-Runde tatsächlich bewiesen hat.*
11. **L14 — `FamilyActivitySelectionStore.clear` behalten oder löschen?** Symmetrie zu drei anderen Stores gegen tote API. *Vorschlag: behalten und in §8 als bewusst vermerken; Löschen zöge den Test mit und widerspricht dem Grundsatz, toten Code nicht stehen zu lassen.*
12. **L32 — `ITSAppUsesNonExemptEncryption: false` deklarieren.** Der Wert ist technisch bewiesen (null Netz-, null Krypto-APIs), aber es ist eine Export-Compliance-Erklärung im Namen des Entwicklers. *Vorschlag: als `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption: NO` in `project.yml` — aber die Erklärung gehört dem Projektinhaber.*

### 4.3 Hygiene, wenn ohnehin in der Nähe

L11 (`secondOfDay`/`timeComponents` konsolidieren — und dabei `MorningSky.swift:13` auf `durationSeconds` ziehen, das ist die interessantere Dublette), L15 (`StatusCopy.windowLine(confirmed:description:)`, macht aus einer Konvention eine Signatur), L16 (Formatter in eine eigene Datei plus Test, wie jeder andere View-lokale reine Typ ihn hat), L17 (zwei Tests für `progressDescription`, beide Varianten, beide Sprachen), L13 (`TrialState.isActive` löschen — Geschwister-Fall wurde bereits gelöscht), L2, L6, L10.

---

## 5. Was diese Runde nicht beweisen konnte

Ausdrücklich benannt, damit es nicht als geprüft durchgeht:

- **VoiceOver lief nie live** (kein UI-Test-Target). H7 und L18 stützen sich auf Code-Analyse plus die API-Abwesenheit; ob VoiceOvers synthetischer Tap die `.onTapGesture` in L18 erreicht, bleibt offen (ändert das Urteil nicht).
- **`.denied` von Family Controls** ist im Simulator unerreichbar — H1 ist am Code bewiesen, nicht am Bildschirm gesehen.
- **Die Paywall-Perioden-Zeilen** (`PaywallView.swift:224`, die einzige `.isSelected`-Stelle) wurden nur im Code geprüft; `simctl launch` trägt keine StoreKit-Konfiguration.
- **H5s gescrollte Position** ist rekonstruiert, nicht fotografiert. Bewiesen sind die Farbwerte, die Gradienten-Geometrie, dass p=0 bei jedem Erscheinen gerendert wird und dass die Spalte bei AX-Größen überläuft (§6.4s eigenes Protokoll).
- **Zwei Simulator-Läufe kamen nicht zustande** — die visuelle Bestätigung des gestapelten Sheets (L1) fehlt.
- **Gerätefragen 13/18** bleiben offen und sind das Eskalationskriterium für L12.
