# Produktentscheidungen — Stufe 2

Löst die in den Review-Notizen (nicht Teil dieses Exports; Abschnitt "Stufe 2") aufgeführten Business-Logik-Lücken auf, vor der ersten Phase-2-Code-Zeile. Entscheidungen sind nach Charakter markiert:

- **[Technisch]** — reine Implementierungsfrage, keine Produktentscheidung, direkt umgesetzt.
- **[Konsistenz]** — löst einen Widerspruch innerhalb bereits fixierter Prinzipien auf, keine neue Richtung.
- **[Empfehlung — überschreibbar]** — echte Produkt-/Business-Entscheidung mit mehreren vertretbaren Antworten. Umgesetzt als Arbeitsstand, damit weitergebaut werden kann, aber explizit Sache des Projektinhabers zu ändern.

---

## B1 — Anker: Alarmzeit statt Dismiss-Zeitpunkt `[Technisch]`

**Entscheidung:** `MorningBlockWindow.init` nimmt jetzt `alarmTime` statt `dismissedAt` entgegen (umgesetzt, `Shared/MorningBlockWindow.swift`). Das Sperr-Fenster wird konzeptionell ab der **geplanten Weckzeit** gerechnet, nicht ab dem Moment, in dem der Nutzer den Wecker tatsächlich abstellt.

**Warum:** Mit AlarmKit kennt die App die Weckzeit bereits beim Stellen des Weckers (typischerweise am Vorabend) — die `DeviceActivitySchedule` kann dadurch vorab registriert werden, statt von einem zuverlässigen `stopIntent`-Feuern beim Abstellen abzuhängen. `stopIntent` ist laut Recherche der ungetestete Single Point of Failure der ganzen Kette (siehe Review-Notizen B9) — dieser Anker entschärft genau das. Nebeneffekt: verhält sich unter Snooze sinnvoll (Fenster hängt am ursprünglich gestellten Alarm, nicht an einem von mehreren Dismiss-Momenten).

**Kein Effekt auf sichtbares Nutzerverhalten** — der Block startet weiterhin "morgens, wenn der Wecker geklingelt hat", nur die technische Herleitung ändert sich.

---

## B2 — `DeviceActivitySchedule.repeats` `[Technisch]` — **revidiert 2026-09-02 nach der AlarmKit-Integration**

**Ursprüngliche Entscheidung (überholt):** `repeats: false`, Schedule bei jedem Alarm-Stellen frisch registriert. Begründung damals: `repeats: true` würde die Sperre täglich zur gestrigen Uhrzeit auslösen, sobald sich die Weckzeit von Tag zu Tag unterscheidet.

**Was tatsächlich gebaut wurde:** Der Wecker ist kein Ein-Schuss-Alarm mehr. `WakeAlarmScheduler` registriert ihn als `Alarm.Schedule.relative(.init(time: .init(hour:minute:), repeats: .weekly(alle sieben Wochentage)))` — AlarmKits einzige wiederkehrende Form (`Recurrence` kennt nur `.weekly([Locale.Weekday])` und `.never`, verifiziert im iOS-26.5-SDK-`swiftinterface`). Der Alarm klingelt damit von sich aus jeden Morgen zur selben Uhrzeit.

**Warum das besser ist als die ursprüngliche Annahme:** Die alte Fassung setzte voraus, dass die App jeden Abend einen frischen Alarm registriert. Dafür hätte es einen täglichen Re-Registrierungs-Pfad gebraucht — der nur läuft, wenn der Nutzer die App abends tatsächlich öffnet. Ein verpasstes Öffnen hieß: kein Wecker, kein Sperrfenster. Der native wiederkehrende Schedule braucht diesen Code gar nicht und hat den Fehlerfall nicht.

**Konsequenz für `repeats`:** `repeats: true`. Die Weckzeit ist jetzt konstruktionsbedingt an jedem Tag dieselbe, also sind auch Start/Ende des Sperrfensters konstant — der ursprüngliche Einwand greift nicht mehr. `repeats: false` wäre nach der Umstellung sogar falsch: "bei jedem Alarm-Stellen frisch registrieren" heißt jetzt "nur wenn der Nutzer die Weckzeit ändert", das Fenster würde also nur am ersten Morgen greifen. Ändert der Nutzer die Weckzeit, wird ohnehin beides neu registriert (der alte Alarm wird dabei per `AlarmManager.cancel(id:)` abgeräumt).

Noch kein Call-Site-Code für `DeviceActivitySchedule` vorhanden — bleibt bindende Vorgabe für den, der ihn schreibt.

---

## B3 — Mascot-Wachstumsregel `[Konsistenz]`

**Entscheidung:** umgesetzt in `docs/design/mascot.md`. Stufen sind an die Anzahl abgeschlossener Morgen gebunden, nicht an Kalenderzeit ("Tag 1"/"Woche 1"/"Monat 1+" waren nicht mit "ein Aussetzer pausiert nur" vereinbar — Kalenderzeit läuft immer weiter). Zahlen (7, 30) sind ein Startpunkt, keine feste Größe.

---

## B4 — Zählt eine genutzte Freischaltung als Aussetzer? `[Empfehlung — überschreibbar]`

**Entscheidung:** Nein. Ein Morgen mit genutzter Freischaltung zählt für die Mascot-Progression genauso als "abgeschlossener Morgen" wie einer ohne.

**Begründung:** Eine Freischaltung ist eine im System selbst vorgesehene, bezahlte und mit Friktion versehene Möglichkeit — kein Regelbruch. Sie zusätzlich am Mascot zu bestrafen würde den Nutzer zweimal zahlen lassen (Geld/Friktion UND Fortschritt) und widerspricht dem "nie bestrafen"-Prinzip direkt. Alternative (Freischaltung pausiert das Wachstum wie ein echter Aussetzer) würde das bezahlte Feature gegen die Retention-Mechanik ausspielen — genau das Risiko, das die Review-Notizen (B4) benannt haben.

---

## B5 — Freischaltungs-Zähler: Reset, Re-Arm, Speicherort `[Empfehlung — überschreibbar]`

- **Reset-Grenze `[revidiert 2026-09-03/04 beim Bau]`:** ein stabiler Kalendertag-Anker, berechnet allein aus `(now, calendar)` — **nicht** aus Start/Ende des Sperrfensters. Die Tagesgrenze unterscheidet sich pro Fenster: Morgen rollt um Mitternacht (ein Morgenfenster enthält weit öfter 06:00 als Mitternacht), Bettzeit um 06:00 (damit ein Fenster über Mitternacht, z.B. 23:50–00:20, ein Abend bleibt). Umgesetzt in `Shared/UnlockQuotaStore.swift`.
- **Warum nicht "pro Sperrfenster" (ursprüngliche Fassung, war der Bug):** Fenstergrenzen sind vom Nutzer jederzeit editierbar. Ein Edit, der das Fenster über `now` schiebt, verschiebt den Anker mit — bereits verbrauchtes Kontingent kam pro Edit unbegrenzt zurück (bewiesen: 10 Wiederholungen → 10 statt 1 Freischaltung). Details und Beweisführung: `docs/audit-log.md`, Einträge 2026-09-03 (Bettzeit, BLOCKER) und 2026-09-04 (dasselbe Loch auf der Morgen-Seite). **Nicht zurückbauen** — kein Wert aus `BedtimeStore`/`WakeAlarmStore` darf in diese Rechnung eingehen.
- **Re-Arm:** keins innerhalb eines Tages — verbrauchte Freischaltungen sind bis zum nächsten Anker-Wechsel weg, das ist der Kern der Friktion. Ein Upgrade hebt die Obergrenze erst für die nächste Auffüllung; ein Downgrade greift sofort, weil ein sinkender Deckel nichts re-armen kann.
- **Speicherort:** App-Group-`UserDefaults` (`group.com.example.tuck`, siehe `Shared/TuckIdentifiers.swift`) — muss von App **und** Shield-Action-Extension lesbar/schreibbar sein, da die Freischaltung im Shield selbst ausgelöst wird. Erfordert das App-Groups-Entitlement (Phase 2; Apple-Developer-Checkliste, nicht Teil dieses Exports).

**Warum diese Reihenfolge dokumentiert wird, bevor der Code existiert:** das Schema bestimmt, was im App-Group-Container liegt — nachträglich ändern heißt zwei Prozesse (App + Extension) synchron anfassen.

---

## B6 — Verhalten bei erschöpftem Kontingent `[Empfehlung — überschreibbar]`

**Entscheidung:** Der Shield bleibt für den Rest des Fensters aktiv — keine weitere Freischaltung möglich, aber auch keine Bestrafung. Konkret:
- Shield-Copy wechselt von der Freischaltungs-Option zu einer neutralen Aussage (z.B. "Freischaltungen für heute aufgebraucht — Sperre bleibt bis [Endzeit]"), kein Guilt-Framing.
- Mascot bleibt unberührt (konsistent mit B4 — erschöpftes Kontingent ist kein Aussetzer, der Nutzer hat das System genutzt, nicht ignoriert).
- Keine Möglichkeit, durch erneutes Antippen doch noch durchzukommen — sonst wäre die Obergrenze bedeutungslos.

**Warum das die einzige Stelle ist, an der sich "nie bestrafen" und Monetarisierung berühren könnten:** die Entscheidung hält die beiden bewusst getrennt — die Konsequenz ist "Sperre bleibt", nicht "du bist ein schlechter Nutzer".

---

## B7 — Preisstaffelung — **ersetzt 2026-09-05 (Entscheidung nach strategischer Prüfung)**

### Überholt (Stand 2026-09-02 bis 2026-09-04)

Zwei Stufen, gegated über die Anzahl Freischaltungen: Standard ~0,99 €/Monat für 2 pro Morgen, Plus ~2,99 €/Monat für 5 pro Morgen; ohne Abo galt im Code stillschweigend das Standard-Kontingent. **Verworfen.** Drei Gründe, knapp — die vollständige Herleitung steckt in der Strategie-Prüfung (nicht Teil dieses Exports):

1. **Preisinversion pro Einheit.** 0,99 € für 2 sind 0,50 € pro Freischaltung, 2,99 € für 5 sind 0,60 € — die teurere Stufe war pro Einheit die schlechtere. Wer rechnet, kauft die kleine.
2. **Falsche Gating-Achse.** Der Zähler koppelt Umsatz an Rückfallhäufigkeit: wer öfter durchbricht, zahlt mehr. Die Review-Notizen hatten die Spannung benannt, das Framing entschärfte sie aber nur in der Copy, nicht in der Mechanik.
3. **Kein Wettbewerber verkauft Feature-Stufen-Decoys.** Im untersuchten Feld (Opal, one sec, ScreenZen, Freedom, Roots) gibt es free vs. paid, keine zwei bezahlten Stufen — eine künstliche Zwischenstufe kostet Konversion, statt sie zu heben.

### Gültig ab 2026-09-05

- **FREE, dauerhaft, ohne Zeitlimit:** 1 Freischaltung/Tag. Mechanik identisch (30 s + Begründung), nur die Tageszahl ist eine andere. Dazu Morgenfenster in gewählter Länge, volle Maskottchen-Progression, Wecker. Nicht enthalten: Bettzeit-Fenster und alles Spätere.
- **PLUS, die einzige bezahlte Stufe** ("Standard" ist ersatzlos gestrichen, auch nicht als deprecated Case): Freischaltungen **ohne Tageslimit** — der Zähler entfällt, er wird nicht angehoben —, Bettzeit-Fenster, und Dachstufe für alles Spätere (Alarmton-Anpassung, Live Activity …).
- **Zwei Kaufoptionen in einer Abo-Gruppe:** 3,99 €/Monat (`com.example.tuck.plus.monthly`), 29,99 €/Jahr (`com.example.tuck.plus.yearly`, seit 2026-09-09 — davor 19,99 €). Eine Lifetime-Option ist eine bewusst spätere Ergänzung — der Code ist so gebaut, dass ein drittes Produkt nur ein weiterer `SubscriptionPlan`-Case ist (`Shared/SubscriptionTier.swift`), aber sie ist heute weder gebaut noch bepreist.
- **TRIAL:** 14 Tage mit vollem Plus-Zugang, danach automatisch FREE. Abgeleitet aus einem einzigen Zeitstempel (`trialStartedAt`, App-Group-Suite) gegen `.now` — kein Ablauf-Callback, der ausbleiben könnte. Ein Abo überstimmt und überlebt die Testphase. **Startpunkt seit 2026-09-09: die erste Plus-Grenze, nicht der erste App-Start** (siehe Absatz unten).

**Warum "kein Limit" statt "hohes Limit":** die Friktion, die das Produkt trägt, ist die Verzögerung plus die Begründung, nicht der Zähler. Ein Deckel von 999 wäre immer noch ein Deckel, den jemand trifft, und er zwänge eine Zahl auf einen Screen, der keine haben soll. Umgesetzt als eigener Typ (`UnlockAllowance.unlimited` vs. `.limited(Int)`), nicht als große Zahl.

**Trial-Start an der ersten Plus-Grenze (2026-09-09, Entscheidung nach erneuter Prüfung):** die 14 Tage liefen bisher ab dem ersten App-Start (`TuckApp`, `.task`). Das maß sie an einem Ereignis, an dem der Nutzer keinen Anteil hat: wer die App öffnet, die Screen-Time-Abfrage ablehnt und drei Wochen später wiederkommt, hatte eine abgelaufene Testphase, ohne je gesehen zu haben, was sie gewährt. Der Zeitstempel wird jetzt an der Stelle geschrieben, an der das Produkt zum ersten Mal nein sagt — `TrialTrigger.plusBoundaryReached` (`Shared/SubscriptionAccess.swift`).

**An welcher Grenze — und warum es zwei sind.** Vorgeschlagen war nur das Bettzeit-Setup (`BedtimeSetupView`). Das hätte den zweiten Weg zur Paywall ins Leere laufen lassen: Plus hat zwei Grenzen, das Abendfenster **und** das Tageslimit für Freischaltungen, und die Paywall wirbt in ihrer ersten Zeile mit dem Limit, nicht mit dem Abend. Wer den Bettzeit-Screen nie öffnet, hätte damit dauerhaft auf 1 Freischaltung/Tag gesessen, während jede Zeile über die Testphase etwas beschreibt, das er nicht mehr erreichen kann. Beide Grenzen lösen deshalb aus:

1. **Ankunft auf `BedtimeSetupView`** — nicht der Tap auf „Bettzeit setzen": der Picker liegt *hinter* dem Gate, ein Auslöser auf die Handlung selbst könnte nie feuern. Ankunft ist ohnehin die ehrlichere Lesart: dort zu stehen heißt, die Screen-Time-Abfrage beantwortet, Apps ausgewählt und eine Weckzeit gesetzt zu haben — oder die Einstellungszeile bewusst angetippt zu haben.
2. **Erschöpftes Tageskontingent beim Öffnen des Entsperr-Flows** (`OverrideContext.allowanceReachingTheCeiling`). Nur dort, wo die Antwort „nein" lautet — ein Override mit freiem Slot ist keine Absage und hat nichts zu argumentieren.

**Nicht ausgelöst wird durch:** das bloße Öffnen der Paywall (sie hängt an einer Einstellungszeile „Abo"; die aus Neugier am ersten Tag anzutippen ist dasselbe Nicht-Ereignis wie ein App-Start) und durch jeden Lesepfad der Extensions — die Shield-Configuration-Extension liest `quota.allowance()` für jeden Sperrbildschirm, den sie zeichnet, und ein Systemprozess darf niemandes 14 Tage starten. Deshalb ist die Kontingent-Frage eine eigene Funktion und keine Zeile in `allowance`.

**Bestandsinstalls:** keine Migration nötig und keine geschrieben. Beide Regeln schreiben denselben Schlüssel in derselben App-Group-Suite über dasselbe idempotente `startIfNeeded`. Eine laufende Testphase behält ihren Start, eine abgelaufene bleibt abgelaufen — niemand bekommt durch das Update eine zweite oder eine verlängerte. Die Richtung, die Geld kostet, ist als eigener Test gepinnt.

**Jahrespreis 29,99 € (2026-09-09, Entscheidung nach erneuter Prüfung):** der Jahrespreis steigt von 19,99 € auf 29,99 €, der Monatspreis bleibt bei 3,99 €. Der Rabatt gegenüber zwölf Monatszahlungen fällt damit von 58 % auf 37 % — 19,99 € machten das Jahresabo so viel billiger, dass es das Monatsabo als Option entwertete und den Ankerpreis der ganzen Stufe nach unten zog. Geändert wurde genau eine Zahl (`Tuck.storekit`); im Code steht kein Preis, `PaywallView` liest ausschließlich `product.displayPrice`, und die Store-Texte sind preisfrei geschrieben.

**Der nebenbei gefundene Bug (behoben 2026-09-05):** `SubscriptionTierStore.cachedTier` fiel bei leerem Cache auf `.standard` zurück, und `refreshEntitlement` schrieb bei jedem ergebnislosen Lookup den Boden zurück. Ein zahlender Nutzer mit langsamem Netz verlor damit kurzzeitig seine Stufe. Jetzt: der Cache ist die zuletzt **bestätigte** Berechtigung, und nur ein *bewiesener* Negativbefund (abgelaufene oder widerrufene Transaktion) löscht ihn.

---

## B8 — Entsperr-Pfad `[Empfehlung — überschreibbar, hängt am Phase-2-Smoke-Test]`

**Entscheidung als Arbeitsstand:** Option 1 (`.openParentalControlsApp`, volles Shield→App) als primärer Pfad, Option 3 (Benachrichtigungs-Umweg) als dokumentierter Fallback, falls der Phase-2-Smoke-Test zeigt, dass Option 1 unter `.individual`-Autorisierung nicht das tut, was der Name verspricht (siehe `docs/build-plan-phase1.md`, C2 — bislang unverifiziert). Option 2 (Shield-Submenü) bleibt Ergänzung für die Begründungs-Auswahl, nicht Ersatz — sie kann nicht die Verzögerungs-Hälfte tragen (kein Timer/keine Animation im Shield möglich, Constraint C1). Option 4 bewusst nicht gewählt: sie verlangt vom Nutzer, jeden Morgen von sich aus zur App zu wechseln, was die einzige Automatisierung des ganzen Produkts (App reagiert auf den eigenen Wecker) an dieser einen Stelle wieder aufgibt.

**Bindend erst nach dem Smoke-Test** — diese Doku hält die Reihenfolge/Priorität fest, nicht das Endergebnis.

### Umsetzungsstand 2026-09-04 — gebaut

Option 1 ist verdrahtet (`Shared/ShieldActionRouting.swift`, `TuckShieldAction/ShieldActionExtension.swift`, `Shared/ShieldOverrideRequest.swift`, `Tuck/GutenMorgenView.swift`). Jede Shield-Aktion außer dem Primärbutton gibt ab iOS 26.5 `.openParentalControlsApp` zurück; die gewählte Begründung wandert über einen einzelnen App-Group-`UserDefaults`-Eintrag in die App, die daraufhin den Override-Screen mit vorgewählter Begründung öffnet. Der Timer läuft trotzdem vollständig — das Submenü trägt nur die Begründungs-Hälfte, nie die Verzögerung.

`.openParentalControlsApp` ist im echten SDK verifiziert: `ManagedSettings.swiftinterface:199`, `@available(iOS 26.5, *)`. Deployment-Target bleibt 26.2, also `#available`-Gate statt Boden-Anhebung. Für 26.2–26.4 ist Option 3 (Benachrichtigungs-Umweg) **nicht** gebaut; stattdessen blendet `ShieldCopy` den Sekundärbutton dort ganz aus, statt einen Tap anzubieten, der nirgendwo hinführt.

### Neue Punkte für den Phase-2-Gerätetest (ergänzen die Liste in den Review-Notizen, §4, Stufe 3)

Alles davon ist im Simulator strukturell unprüfbar — Family Controls läuft dort nicht, und beide Shield-Extensions sind Systemprozesse, die der Simulator nie startet.

1. Liefert ein Shield mit gesetzten `secondaryButtonSubmenuItems` beim Druck auf den Sekundärbutton noch `.secondaryButtonPressed`, oder ausschließlich die drei Submenü-Cases? Nirgends dokumentiert. Beide Formen werden heute gleich behandelt, damit die Frage die Funktion nicht blockiert — die Antwort bestimmt nur, ob der reason-lose Pfad je vorkommt.
2. Kann die Shield-**Configuration**-Extension den App-Group-Container tatsächlich lesen, sobald die Capability provisioniert ist? Wenn nicht, erscheint die B6-Copy ("Für heute aufgebraucht") nie, und der Shield bietet dauerhaft die Freischaltung an, die die App danach ablehnt. Fehlerrichtung ist die sichere, aber es ist ein Fehler.
3. ~~Auf welchem Thread ruft `com.apple.ManagedSettingsUI.shield-configuration-service` die vier `configuration(shielding:)`-Overloads auf?~~ — gegenstandslos seit 2026-09-04: das Mascot wird nicht mehr zur Laufzeit gerendert. `ImageRenderer` ist vollständig MainActor-isoliert (`SwiftUICore.swiftinterface:16275–16305`), der nötige Hop auf einen fremden Thread ist ersatzlos entfallen; die Extension lädt ein vorgerendertes Asset (`tools/render-shield-mascot.sh`).
4. Zeigt der Shield das Mascot-Asset, und wie skaliert er es? `ShieldConfiguration` hat keine Größenangabe, nur `icon: UIImage?`.
5. Ist der App-Group-Write der Action-Extension sichtbar, bevor die App ihn liest? Prozessübergreifende `UserDefaults`-Sichtbarkeit ohne Synchronisationspunkt — falls nicht, öffnet der Shield die App ohne vorgewählte Begründung (wieder die sichere Richtung).

---

## Stufe 3 — Status

Nicht ausführbar zu diesem Stand: alle sechs Smoke-Tests (Review-Notizen, Abschnitt 4, Stufe 3) brauchen ein physisches Gerät mit gültigem Family-Controls-Entitlement — Family Controls funktioniert im Simulator nachweislich nicht (siehe `docs/audit-log.md`/Review-Notizen). Voraussetzung: bezahlter Apple-Developer-Account (Apple-Developer-Checkliste, G1, nicht Teil dieses Exports) + Signing auf dem Gerät (Phase 2). Reihenfolge bleibt wie in den Review-Notizen festgelegt: stopIntent zuerst (existenziell), dann die übrigen fünf.

## Stufe 4 — Status

Bleibt als Implementierungs-Notizen in den Review-Notizen (C1–C6) stehen — das sind Hinweise für den Moment, in dem der jeweilige Code tatsächlich geschrieben wird (Shield-Konfiguration, Onboarding, Zähler-Implementierung), keine isoliert vorziehbaren Schritte ohne den dazugehörigen Feature-Code.
