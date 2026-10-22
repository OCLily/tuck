# Bettzeit-Fenster — Konzept & Entscheidung (2026-09-03)

Zweites Sperrfenster: **60 Minuten, zentriert auf die selbstgesetzte Bettzeit** (30 Minuten davor bis 30 Minuten danach) — dieselben Apps gesperrt wie morgens. Ergänzt Abschnitt 8 der offenen Fragen (nicht Teil dieses Exports). Ausgangspunkt war die Vorgabe, ab einem Zeitpunkt vor dem Zubettgehen keine Social-Media-Apps mehr zu öffnen; präzisiert am 2026-09-03 auf ein Fenster von 30 Minuten vor bis 30 Minuten nach der Bettzeit — kein rein vorlaufendes Fenster wie ursprünglich in diesem Dokument angenommen.

Entscheidungen sind nach demselben Schema markiert wie `docs/product-decisions-2026-09-02.md`: **[Technisch]**, **[Konsistenz]**, **[Empfehlung — überschreibbar]**.

---

## 0. Korrektur der Prämisse — vor allem anderen

**Es existiert im gesamten Repo keine einzige DeviceActivity-/ManagedSettings-Call-Site.** Volltext-Grep über alle `.swift`: `DeviceActivityCenter`, `startMonitoring`, `DeviceActivitySchedule` und `ManagedSettingsStore(...)` kommen ausschließlich in Kommentaren vor.

- `Tuck/WakeAlarmScheduler.swift:59-60` **berechnet** das `MorningBlockWindow` und persistiert es (`WakeAlarmStore.store`) — registriert es nirgends.
- `TuckMonitor/DeviceActivityMonitorExtension.swift:1-27` ist ein Stub: alle sechs Overrides rufen nur `super`.
- `TuckShield/ShieldConfigurationExtension.swift` gibt in allen vier Overloads das leere `ShieldConfiguration()` zurück (deckt sich mit C4 der Review-Notizen, nicht Teil dieses Exports).
- Von der Doku selbst bestätigt: `docs/product-decisions-2026-09-02.md:31` — "Noch kein Call-Site-Code für `DeviceActivitySchedule` vorhanden".

**Konsequenz:** Die Annahme "das Morgen-Shield läuft schon, Bettzeit braucht nur ein zweites Paar" ist konzeptionell richtig, faktisch aber nicht gebaut. Bettzeit v1 ist die **erste** echte DeviceActivity-/ManagedSettings-Verdrahtung des Projekts. Es ist damit nicht "einfacher als der Morgen-Flow" — es *ist* der Sperr-Mechanismus, den der Morgen ebenfalls noch braucht.

Daraus folgt ein Reihenfolge-Argument (kein Zwang): Bettzeit ist der sauberere Ort, dieses Plumbing zum ersten Mal zu bauen — identische Mechanik, aber ohne AlarmKit, ohne `stopIntent`, ohne Snooze-Interaktion. Was hier funktioniert, trägt den Morgen mit.

---

## 1. Entschieden (2026-09-03 — nicht neu aufrollen)

| # | Entscheidung | Charakter |
|---|---|---|
| E1 | **Bettzeit-Fenster wird als v1-Feature gebaut** und geht jetzt in die aktive Pipeline — kein "später vielleicht". | Produkt |
| E2 | **Eine einzige feste tägliche Bettzeit.** Keine Wochentags-/Wochenend-Differenzierung in v1. | Produkt |
| E3 | **Das Fenster ist auf die Bettzeit zentriert: 30 Minuten davor bis 30 Minuten danach, 60 Minuten gesamt** (2026-09-03 präzisiert — ursprünglich nur als Vorlauf dokumentiert, das war eine Fehlinterpretation dieses Dokuments, nicht die Aussage des Projektinhabers). | Produkt |
| E4 | **Gleiche Shield-/Override-Philosophie wie am Morgen** — dieselbe App-Auswahl, derselbe Entsperr-Pfad (B8), dieselbe Copy-Haltung: nie bestrafen, nie Guilt-Framing. | Konsistenz |
| E5 | **Bettzeit zählt v1 nicht zum Maskottchen-Wachstum** (Antwort auf O1) — stiller Shield, keine Kopplung an die unverifizierte `intervalDidEnd`-Callback. Aufrüstbar nach dem Geräte-Smoke-Test. | Produkt |
| E6 | **Eigenes, kleineres Freischaltungs-Kontingent abends** (Antwort auf O2) — hält das Verkaufsversprechen aus B7 ("2 pro Morgen") wörtlich; Startwert 1 Freischaltung/Abend, nicht gespiegelt vom Morgen-Kontingent. | Produkt |

Wochentags-Differenzierung kommt später als **gemeinsame** Erweiterung für Weckzeit *und* Bettzeit — bewusst nicht zwei getrennte Ausbaustufen (Begründung: Abschnitt 5).

---

## 2. v1-Scope-Grenze

**Drin in v1:**

- Eine feste Uhrzeit "Bettzeit", im Onboarding und in den Einstellungen setzbar, überspringbar (Muster: `Tuck/OnboardingFlowView.swift:225-233`).
- Fenster = Bettzeit − 30 Minuten bis Bettzeit + 30 Minuten, 60 Minuten gesamt, `repeats: true`, täglich.
- Eine zweite `DeviceActivityName` + ein zweiter benannter `ManagedSettingsStore` (Abschnitt 4).
- Dieselbe `FamilyActivitySelection` wie morgens — **keine** zweite App-Auswahl.
- Ruhige Degradation, wenn keine Bettzeit gesetzt oder Family Controls nicht autorisiert ist (Abschnitt 6).

**Explizit zurückgestellt:**

| Zurückgestellt | Warum |
|---|---|
| Wochentag/Wochenende | E2. Betrifft dann beide Zeiten gemeinsam. |
| Zweite, eigene App-Auswahl für abends | Ein zweiter `FamilyActivityPicker`-Durchlauf im Onboarding für einen Nutzen, den niemand angefragt hat. |
| Eigene Bettzeit-Erinnerung/Benachrichtigung | Ein Detox-Produkt, das abends von sich aus eine Push schickt, ist ein Widerspruch. Erst nach v1 diskutieren. |
| Kopplung Bettzeit ↔ Weckzeit (Schlafdauer-Rechner) | Feature-Kriecherei; die App ist ein Sperr-Produkt, kein Schlaf-Tracker. |
| Fenster, das bis zum Weckfenster durchläuft | Siehe offene Frage O3 — noch nicht entschieden, deshalb nicht im v1-Scope. |

---

## 3. Verifizierte technische Grundlage

SDK: `iPhoneOS26.5.sdk`, `DeviceActivity.swiftinterface` (453 Z.), `ManagedSettings.swiftinterface` (636 Z.).

**DeviceActivity ist von AlarmKit vollständig unabhängig.** `DeviceActivity.swiftinterface:5-12` importiert nur `Foundation`, `ManagedSettings`, `Swift`, `_Concurrency`, `_StringProcessing`, `_SwiftConcurrencyShims`, `os.log`, `os`. Kein AlarmKit, keine AppIntents. Der Sperr-Mechanismus hat auf Modul-Ebene keine Kopplung an Alarme oder Intents — ein Fenster ohne Wecker ist kein Sonderweg.

**Ein reines Zeitfenster ist im Public API ausdrückbar.** `DeviceActivitySchedule.init(intervalStart:intervalEnd:repeats:warningTime:)` (Z. 41-59) nimmt ausschließlich `DateComponents` — kein Event-, Alarm- oder Trigger-Parameter existiert im Typ. `startMonitoring(_:during:events:)` (Z. 185) hat `events` auf `[:]` defaulted. "22:00–22:30 täglich, ohne Bezug zu Alarm oder Intent" ist der Normalfall des API.

**Eine Monitor-Extension bedient beide Fenster.** `intervalDidStart(for activity:)` / `intervalDidEnd(for activity:)` (Z. 394-405) bekommen den `DeviceActivityName` als Argument. Kein zweites Extension-Target, keine neuen Target-Einträge in `project.yml`.

**~~Die "15-Minuten-Untergrenze" bleibt Folklore~~ — widerlegt am 2026-09-04.** Die ursprüngliche Beobachtung stimmt, die Schlussfolgerung nicht: `MonitoringError` (Z. 166-184) nennt im *Interface* keine Zahl, und "15" erscheint dort nur als `iOS 15.0`-Availability. Die Zahlen stehen aber in der `.swiftdoc` desselben Moduls (`arm64e-apple-ios.swiftdoc`, aus dem Binary extrahiert — bis dahin nie gelesen):

- `intervalTooShort`: „The minimum interval length for monitoring device activity is **fifteen minutes**."
- `intervalTooLong`: „The maximum interval length for monitoring device activity events is **one week**."
- `excessiveActivities`: „The maximum number of activities that can be monitored at one time by an app and its extensions is **twenty**."

30 Minuten liegen damit belegt, nicht nur vermutet, über der Untergrenze; die Produktentscheidung ändert sich nicht, nur ihre Begründung. Tuck registriert zwei Activities — von 20 weit entfernt. Weiterhin ohne Zahl bleibt der zweite, unabhängige Deckel, den das Binary als `.RateLimitCount` zeigt: `startMonitoring`s swiftdoc warnt vor „too many activities **or activities that are too tightly scheduled**" — eine Achse über Callback-Dichte, nicht über Registrierungs-Anzahl, und nur am Gerät messbar.

**ManagedSettings, relevant:**

- `ManagedSettingsStore.Name` hat `init(_ rawValue: String)` — beliebig viele benannte Stores, genau wie `Shared/TuckIdentifiers.swift:9-11` es schon nutzt.
- `public var shield: ShieldSettings` (Z. 427) ist **nicht werfend**. Ein Shield-Write ohne Autorisierung schlägt **still** fehl — kein Fehlerpfad, kein Rückgabewert. Genau die Fehlerklasse, die die Review-Notizen als charakteristisch für dieses Projekt benennt.
- Neu in 26.5 und relevant: `isActive` (Z. 405), `deleteStore()`, `deleteStores(_:)`, `stores`, `refresh(_:)` — letzteres die in den offenen Fragen notierte Token-Verfallspflicht. Betrifft Bettzeit genauso, da beide Fenster dieselbe persistierte `FamilyActivitySelection` nutzen.

---

## 4. Die eine echte Asymmetrie zum Morgen `[Konsistenz — gehört vor den Bau gesagt]`

C1 der Review-Notizen legt für den Morgen fest: **Shield synchron aus App/Intent setzen, DeviceActivity nur als Ende-Wecker.** Begründung: fail-open kostet einen Morgen, fail-closed sperrt dauerhaft.

**Diese Absicherung lässt sich auf Bettzeit nicht übertragen.** Um 21:30 gibt es keinen App-/Intent-Moment: kein Alarm klingelt, niemand dismissed etwas, der Nutzer öffnet die App nicht. Der einzige Auslöser, der das Shield um 21:30 setzen kann, ist `intervalDidStart` in der Monitor-Extension — also exakt der Pfad, dem C1 nicht traut und den die ursprüngliche Produktspezifikation selbst als "dokumentiert unzuverlässig" führt.

Der Reconciliation-Check bei `scenePhase == .active` (zweite Hälfte von C1) hilft nur asymmetrisch: er räumt ein hängengebliebenes Shield **auf**, kann ein nicht gesetztes Shield aber nicht **nachholen** — denn abends öffnet der Nutzer nicht Tuck, er öffnet Instagram, und genau die App wäre dann ungeshieldet.

**Konsequenz, festgehalten:** Bettzeit hängt strikt stärker an DeviceActivity-Zuverlässigkeit als der Morgen. Kein Blocker, aber Punkt 1 der Smoke-Test-Liste (Abschnitt 7) und der Grund, warum die Zähl-Frage (O1) nicht leichtfertig entschieden werden sollte.

---

## 5. Neue Identifier und Konstanten `[Technisch]`

Bestehende Konvention: `Shared/TuckIdentifiers.swift` hält **nur prozessübergreifende Literale** (App-Group-Suite, geteilter `FamilyActivitySelection`-Key). Store-interne Keys liegen als `private static let` im jeweiligen Store-Typ (`Tuck/WakeAlarmStore.swift:11-15`, `Shared/MorningProgressStore.swift:10-11`). C8 (Review-Notizen) friert `TuckIdentifiers` als reine Konstanten-Datei ein — das bleibt gewahrt.

**In `Shared/TuckIdentifiers.swift`** (rein additiv, nichts Bestehendes ändern):

```swift
extension ManagedSettingsStore.Name {
    static let bedtimeBlock = Self("bedtimeBlock")
}

extension DeviceActivityName {
    static let bedtimeBlock = Self("bedtimeBlock")
}
```

Naming folgt exakt `.morningBlock` (Z. 10, 14): lowerCamelCase, RawValue identisch zum Symbolnamen.

**Nicht dorthin:** der gespeicherte Bettzeit-Zeitpunkt. Der gehört als `private static let` in ein neues `Shared/BedtimeStore.swift`, gebaut nach dem Muster von `WakeAlarmStore` (Second-of-Day-Int-Persistenz, `Tuck/WakeAlarmStore.swift:91-101`), in derselben App-Group-Suite. Keys, die Konvention aus `WakeAlarmStore.swift:13-14` fortschreibend: `bedtimeSecondOfDay`, `bedtimeBlockWindowStartSecondOfDay`, `bedtimeBlockWindowEndSecondOfDay`.

**Plumbing-Punkte, die leicht übersehen werden:**

- `project.yml:22-26` listet `Shared/`-Dateien für den App-Target **einzeln**. Ein neues `Shared/BedtimeStore.swift` muss dort explizit eingetragen werden, sonst kompiliert es nicht mit. `TuckIdentifiers.swift` ist bereits in allen vier Targets (Z. 23, 64, 80, 97) — die beiden neuen Extension-Konstanten sind dadurch automatisch überall verfügbar.
- `MorningBlockWindow` ist bewusst nur im App-Target (`project.yml:24`). Das bleibt richtig: die Monitor-Extension braucht die Fenster-Mathematik nicht, sie bekommt den `DeviceActivityName` übergeben.
- **`MorningBlockWindow` ist nicht direkt wiederverwendbar.** `init(alarmTime:duration:calendar:)` rechnet **vorwärts** vom Anker (Start = Anker, Ende = Anker + Dauer). Bettzeit rechnet **zentriert** (Start = Anker − 30 Min, Ende = Anker + 30 Min, Anker = Bettzeit selbst) — ein dritter Fall, weder der bestehende Vorwärts- noch ein reiner Rückwärts-Fall. Zwei vertretbare Wege, Bau-Entscheidung: (a) zusätzliche statische Factory `MorningBlockWindow.centeredOn(_:halfDuration:calendar:)`, oder (b) Umbenennung zu `BlockWindow` mit mehreren Factories (`startingAt`, `centeredOn`). (b) ist ehrlicher, (a) ist chirurgischer. Die bestehende Mitternachts-Wraparound-Arithmetik (Modulo 86400) trägt für beide Richtungen gleichermaßen — kein Sonderfall für "vor Mitternacht rückwärts rechnen".
- **Mitternachts-Wraparound trägt bereits** (`Shared/MorningBlockWindow.swift:52-57` mod 86400, `mostRecentStart` Z. 35-45). Bettzeit 23:45 → Fenster-Ende 00:15 ist im Typ korrekt darstellbar. Ob `DeviceActivitySchedule` ein Intervall mit `intervalEnd < intervalStart` akzeptiert, steht **nirgends** im SDK → Smoke-Test 2.
- **Warum Wochentags-Differenzierung später beide Zeiten gemeinsam betrifft:** `Alarm.Schedule.Relative.Recurrence` kennt `.weekly([Locale.Weekday])` (`Tuck/WakeAlarmScheduler.swift:96-99`), `DeviceActivitySchedule` hat **keinen** Weekday-Parameter. Wochentagsdifferenzierung auf der Sperr-Seite hieße mehrere `DeviceActivityName`-Registrierungen — direkt in Richtung `excessiveActivities`, dessen Obergrenze undokumentiert ist. Das ist ein Problem für beide Fenster, deshalb E2.
- **DST:** der in `Shared/MorningBlockWindow.swift:20-27` dokumentierte offene Spring-Forward-Randfall gilt für Bettzeit unverändert — durch die Rückwärtsrechnung weder schlimmer noch besser.

---

## 6. Ruhige Degradation `[Konsistenz]`

**Family Controls nicht autorisiert:** `startMonitoring` ist `throws` und kennt `MonitoringError.unauthorized` (`DeviceActivity.swiftinterface:172, 185`) — der Registrierungsversuch scheitert **laut** und ist am Call-Site abfangbar, exakt wie `Tuck/WakeAlarmScheduler.swift:63-65` es für AlarmKit tut (`status = .unavailable(...)`, kein Absturz, kein Blocker).

**Aber:** `ManagedSettingsStore.shield` ist nicht werfend (`ManagedSettings.swiftinterface:427`). Ein Shield-Write ohne Autorisierung tut **still nichts**. **Bindend:** die App darf aus einem erfolgreichen Write niemals auf einen aktiven Shield schließen — sonst zeigt sie "Sperrfenster aktiv", während nichts gesperrt ist.

**Keine Bettzeit gesetzt:** nichts registriert, nichts gesperrt. Präzedenz ist etabliert und wird nur gespiegelt: `Tuck/OnboardingFlowView.swift:129` lässt die Berechtigung überspringen ("Später erlauben, weiter"), `OnboardingFlowView.swift:225-233` lässt den Wecker-Schritt überspringen, `Tuck/WakeAlarmSetupView.swift:97-100` zeigt bei leerem Zustand ruhig "—". Ein Bettzeit-Schritt übernimmt das 1:1.

**Simulator:** Family Controls funktioniert dort nachweislich nicht (`docs/product-decisions-2026-09-02.md:90`, Nutzer-Copy in `OnboardingFlowView.swift:164`). Bettzeit ist im Simulator genauso unprüfbar wie der Morgen-Block.

**Harte Vorbedingung, über C2 hinausgehend:** Der App-Target hat **überhaupt keine Entitlements-Datei** — `project.yml` setzt `CODE_SIGN_ENTITLEMENTS` nur für die drei Extensions (Z. 70, 86, 103). Dem App-Target fehlen damit sowohl `com.apple.security.application-groups` als auch `com.apple.developer.family-controls`. Da `DeviceActivityCenter.startMonitoring` und der `ManagedSettingsStore`-Write aus der **App** kommen müssen, blockiert das beide Fenster gleichermaßen. C2 (Review-Notizen) nennt nur das App-Group-Entitlement — das fehlende Family-Controls-Entitlement am App-Target kommt hinzu.

---

## 7. Produktfragen — **entschieden (2026-09-03)**

O1–O3 sind entschieden, siehe E5/E6 oben und die Auflösung direkt unter jeder Frage. O4 bleibt offen (technische Unbekannte, kein Entscheidungsbedarf vor dem Geräte-Test).

### O1 — Zählt ein eingehaltenes Bettzeit-Fenster auf dasselbe `MascotStage`-Wachstum? — **entschieden: nein (E5)**

Stiller Shield, kein Zählen in v1. Begründung: das einzige "Bettzeit geschafft"-Signal käme von der noch unverifizierten `intervalDidEnd`-Callback (Abschnitt 4) — ein falsch hochgezählter Streak ist im "nie bestrafen"-Konzept schwerer zu reparieren als fehlendes Feedback. Aufrüstbar auf Option A oder D (unten, als Referenz belassen) nach dem Geräte-Smoke-Test.

Vorprägender technischer Kontext: der Morgen wird beim **Dismiss** gezählt (`Tuck/StopWakeAlarmIntent.swift:30-38`) — eine echte Nutzerhandlung, im App-Prozess, idempotenzgeschützt (`WakeAlarmStore.swift:77-89`). Bettzeit hat kein Äquivalent. Das einzige "abgeschlossen"-Signal wäre `intervalDidEnd` in der Monitor-Extension — derselbe Fremdprozess, dem C1 nicht traut (Abschnitt 4). **Jede Option, die Bettzeit zählt, importiert diese Unzuverlässigkeit in die Streak-Mechanik.**

| Option | Was sie bedeutet | Kosten |
|---|---|---|
| **A — gemeinsamer Zähler, jedes Fenster zählt einzeln** | `MorningProgressStore.recordCompletedMorning` auch abends aufrufen | Einfachste Implementierung, aber Progression verdoppelt sich (Stufe 2 nach 3,5 statt 7 Tagen — nachjustierbar, `docs/design/mascot.md:10` nennt 7/30 ausdrücklich "Startpunkt"). Teurer ist die Semantik: der Zähler heißt `completedMornings`, die Copy ist durchgehend morgens gerahmt (`ContentView.swift:16`, `GutenMorgenView.swift:86-88` VoiceOver "X von Y Morgen"). Umbenennung zieht durch Copy, Accessibility-Strings und Tests. |
| **B — eigener Zähler, eigenes visuelles Feedback** | Zwei getrennte Fortschritts-Systeme | Ehrlich getrennt, Morgen-System unangetastet. Kostet ein zweites Fortschritts-System in einem Produkt, dessen Design ein einziger ruhiger Screen ist; `docs/design/mascot.md` beschreibt genau ein Wesen mit genau einer Wachstumslinie. Zwei Ringe/zwei Kreaturen widersprechen der Konzeptmitte deutlicher als eine verschobene Zahl. |
| **C — gar nicht gamifiziert, stiller Shield** | Bettzeit sperrt, zählt nichts | Billigste Option, null Konflikt mit dem Morgen-System, umgeht die `intervalDidEnd`-Unzuverlässigkeit vollständig (was nicht gezählt wird, kann nicht falsch gezählt werden). Passt zur Situation: abends soll niemand die App für eine Belohnung öffnen. Gegenargument: ohne jedes Feedback ist ein still funktionierendes Feature von einem still kaputten nicht unterscheidbar — bei einem Trigger mit bekannter Wackligkeit ein reales Problem. |
| **D — gemeinsamer Zähler, ein Tag zählt höchstens einmal** | Tages-Idempotenz statt Fenster-Idempotenz | Erhält die Bedeutung der 7/30-Schwellen ohne Umbenennung; Bettzeit allein (ohne Morgen) zählt den Tag ebenfalls, was die in der ursprünglichen Produktspezifikation akzeptierte Wecker-Lücke teilweise schließt. Kostet eine zusätzliche Tages-Idempotenz-Schicht — genau die Art Logik, die `WakeAlarmStore.isFirstDismissal` schon einmal aufwendig richtig bekommen musste, jetzt aber prozessübergreifend zwischen App und Monitor-Extension. |

**Sequenz-Argument, unabhängig von der Wahl:** Solange `intervalDidStart`/`intervalDidEnd` nicht am Gerät verifiziert sind (Smoke-Test 1), ist jede Zähl-Kopplung eine Wette auf einen ungetesteten Fremdprozess. Ein falsch hochgezählter Streak ist im "nie bestrafen"-Konzept schwerer zu reparieren als ein fehlendes Feedback. Die Entscheidung lässt sich also v1 aufschieben, ohne den Bau zu blockieren — solange sie *bewusst* aufgeschoben wird.

### O2 — Gilt `MorningProgressStore.dailyUnlockMaximum` auch abends? — **entschieden: nein, eigenes Kontingent (E6)**

Eigenes, kleineres Abend-Kontingent (Startwert 1, nicht am Morgen-Wert von 2 gespiegelt) — hält B7s Verkaufsversprechen ("2 pro Morgen") wörtlich, gibt aber ein Sicherheitsventil statt komplett override-loser Sperre (Option C wurde verworfen, da sie die in der ursprünglichen Produktspezifikation als nicht verhandelbar markierte Override-Kernmechanik verletzt hätte). Technisch: zweiter Key nach demselben Muster wie `MorningProgressStore`, kein neuer Mechanismus.

Kontext: `dailyUnlockMaximum = 2` (`Shared/MorningProgressStore.swift:8`). B5 (`docs/product-decisions-2026-09-02.md:51`) definiert die Reset-Grenze ausdrücklich als "pro Morgen = pro ausgelöstem Sperrfenster", technisch umgesetzt als Auffüllen in `recordCompletedMorning` (`MorningProgressStore.swift:28-31`), ausgelöst vom Alarm-Dismiss.

| Option | Was sie bedeutet | Kosten |
|---|---|---|
| **A — geteiltes Kontingent** | Eine Zahl für beide Fenster | Keine neue Mechanik. Aber: wer morgens beide Freischaltungen verbraucht, steht abends ohne da — und der Reset hängt heute am Alarm-Dismiss, abends gäbe es gar keinen Auffüll-Moment außer wieder über die Monitor-Extension. Ändert zudem still, was der Abonnent gekauft hat: B7 verkauft "2 Freischaltungen **pro Morgen**", nicht "2 pro Tag für zwei Sperren". |
| **B — eigenes Kontingent pro Fenster** | Zweiter Key, dieselbe `consumeUnlock`-Logik | Hält das Preisversprechen aus B7 wörtlich, macht jedes Fenster für sich überlebbar. Verdoppelt aber die Gesamt-Freischaltungen pro Tag ohne Preisänderung und schwächt die Friktion, die das Produkt verkauft (ursprüngliche Produktspezifikation: die Preisstufe kauft eine höhere Obergrenze — hier stiege sie faktisch, ohne dass jemand dafür zahlt). Variante: kleinere Abend-Obergrenze (z.B. 1 statt 2) statt Spiegelung — kein Mechanik-Zuwachs, trägt der Tatsache Rechnung, dass ein 30-Minuten-Abendfenster weniger legitime Notfälle enthält. |
| **C — Bettzeit ohne Override** | Abends gibt es keinen Entsperr-Pfad | Maximal konsistent mit "Friktion ist das Produkt"; das Fenster ist kurz, vorhersehbar und selbstgewählt. Kollidiert aber frontal mit der ursprünglichen Produktspezifikation, wo der Override (Verzögerung **plus** Begründung) als nicht verhandelbare Kernmechanik steht. Wäre die erste Ausnahme davon und müsste als solche entschieden werden, nicht implizit entstehen. |

Das ist eine Preis-/Produktentscheidung, keine technische.

### O3 — Wann endet das Bettzeit-Fenster? — **entschieden: 30 Minuten nach Bettzeit (E3)**

Weder die ursprünglich in diesem Dokument angenommene Lesart ("endet zur Bettzeit", reiner Vorlauf) noch "durchlaufen bis zum Weckfenster" — sondern eine dritte, vom Projektinhaber präzisierte Form: **zentriert auf die Bettzeit**, 30 Minuten davor bis 30 Minuten danach. Vermeidet das mehrstündige Intervall (und damit `intervalTooLong`-Risiko) der Durchlauf-Variante, deckt aber sowohl das Zubettgehen als auch die ersten Minuten danach ab — näher an der Ursprungsabsicht als eine reine Vorlauf-Sperre. Überschneidung mit dem Weckfenster (O4) bleibt bei einer normalen Nachtlänge praktisch ausgeschlossen.

### O4 — Zwei gleichzeitig aktive `ManagedSettingsStore`

Ob die Shields zweier benannter Stores additiv wirken und ob `clearAllSettings()` auf dem einen den anderen unberührt lässt, steht **nicht** im Interface. Nicht annehmen. Relevant, sobald O3 zugunsten des durchlaufenden Fensters entschieden wird — bei symmetrischen 30 Minuten mit hinreichendem Abstand nicht.

---

## 8. Was zwingend an ein echtes Gerät gehört

In dieser Reihenfolge, weil Punkt 1 alle anderen gegenstandslos macht. Reiht sich in die bestehende Smoke-Test-Liste ein (Review-Notizen und `docs/product-decisions-2026-09-02.md:90`) — alles hängt am bezahlten Developer-Account.

1. **Feuert `intervalDidStart` auf einer reinen Zeit-Schedule, wenn die App den ganzen Tag nicht geöffnet wurde und terminiert ist?** Existenziell — es gibt keinen Ersatz-Pfad (Abschnitt 4). Für Bettzeit das, was der stopIntent-Test (B9) für den Morgen ist.
2. **Akzeptiert `startMonitoring` ein Intervall mit `intervalEnd < intervalStart`** (Bettzeit 23:45 → 00:15)? Kandidaten-Fehler: `invalidDateComponents`, `intervalTooLong`. Im SDK nicht dokumentiert.
3. **Passiert ein 30-Minuten-Intervall die `intervalTooShort`-Schwelle?** Seit 2026-09-04 dokumentiert (15 Minuten, s. Abschnitt 3) — die Beobachtung am Gerät ist damit nur noch Bestätigung, kein offener Punkt.
4. ~~**Löst die zweite registrierte `DeviceActivityName` `excessiveActivities` aus?**~~ Erledigt ohne Gerät: die Obergrenze ist 20 (s. Abschnitt 3), Tuck registriert zwei. Offen bleibt nur die zahlenlose Rate-Limit-Achse.
5. **Zwei gleichzeitig aktive `ManagedSettingsStore`** — additiv? `clearAllSettings()` isoliert? (O4)
6. **`repeats: true` auf reiner Zeit-Schedule:** überlebt die Registrierung einen Neustart und re-armt täglich ohne App-Start? B2 setzt das bindend voraus (`docs/product-decisions-2026-09-02.md:29`) — für Bettzeit ohne jeden App-Kontakt als Rückfallebene.
7. **DST-Randfall** aus `Shared/MorningBlockWindow.swift:20-27` gilt unverändert.

---

## 9. Implementiert (2026-09-03) — Stand nach drei Build→Prüfrunden

Entitlements (App-Group + Family Controls am App-Target), geteilte `FamilyActivitySelection`-Persistenz zwischen App und Monitor-Extension, echte `DeviceActivityCenter`-Registrierung für Morgen und Bettzeit, echte Monitor-Extension-Logik, eigenes Bettzeit-Kontingent, Zugriffs-/App-Auswahl-Einstiegspunkt außerhalb des Onboardings — alles gebaut und gegengeprüft, **0 BLOCKER, 0 HIGH**. Details im Audit-Log (`docs/audit-log.md`, Eintrag 2026-09-03).

Drei dokumentierte, bewusst nicht weiterverfolgte LOW-Reste:

- **Zeitzonen-Wechsel könnte das Bettzeit-Kontingent theoretisch erneut auffüllen.** Der Kontingent-Anker (`Shared/UnlockQuotaStore.swift`) ist eine reine Funktion von Uhrzeit + `Calendar.current` — ändert sich die Zeitzone des Geräts, ändert sich auch der berechnete Kalendertag. Braucht Verlassen der App und eine iOS-Einstellungsänderung, kein Ein-Tap-Exploit mehr wie der behobene BLOCKER. Fix falls gewünscht: monotonen Anker speichern, der nie rückwärts läuft.
- **Ein Bettzeit-Fenster, das die 6-Uhr-Tagesgrenze selbst überspannt** (z.B. Bettzeit 05:30–06:30), gewährt einmalig eine zusätzliche Freischaltung. Bewiesen begrenzt auf genau +1, nicht wiederholbar.
- **Asymmetrie behoben:** der Wecker-Sheet hat jetzt denselben `BlockWindowReconciler.reconcile()`-Aufruf beim Schließen wie die anderen beiden Sheets (war als LOW gefunden, direkt nachgezogen, kein eigener Fix-Durchgang nötig).

## Referenzen

- `Shared/TuckIdentifiers.swift`, `Shared/MorningBlockWindow.swift`, `Shared/MorningProgressStore.swift`
- `Tuck/WakeAlarmScheduler.swift`, `Tuck/WakeAlarmStore.swift`, `Tuck/StopWakeAlarmIntent.swift`, `Tuck/OnboardingFlowView.swift`, `Tuck/OverrideFlowView.swift`
- `TuckMonitor/DeviceActivityMonitorExtension.swift`, `project.yml`
- iOS-26.5-SDK: `DeviceActivity.framework/.../arm64e-apple-ios.swiftinterface`, `ManagedSettings.framework/.../arm64e-apple-ios.swiftinterface`, `FamilyControls.framework/...`
- iOS-26.2-Simulator-Runtime, `DeviceActivity`-Binary (Strings: `allowShortIntervals`, `IntervalTooShortError`, `ExcessiveActivitiesError`)
