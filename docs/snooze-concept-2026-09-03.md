# Snooze als USP — Konzept-Review (2026-09-03)

Vier Snooze-Konzepte im Vergleich, gegeneinander bewertet. Ergänzt Abschnitt 2 der offenen Fragen (nicht Teil dieses Exports). Ausgangspunkt war die Überlegung vom 2026-09-02, sich durch eine besondere Snooze-Funktion von anderen Apps abzusetzen und einen USP zu schaffen.

## Vorweg: zwei Annahmen, die vor allem anderen geprüft gehören

1. **Ein Snooze-USP wirkt nur, wenn ihn jemand sieht.** Die einzige Fläche, auf der ein besonderer Schlummer sichtbar wird, ist die Live Activity auf Sperrbildschirm/Dynamic Island. Wenn die App privat bleibt, ist der USP-Rahmen hinfällig — dann ist es nur noch "was ist schöner", eine kleinere Entscheidung.
2. **Alles hier steht auf einer ungetesteten Kette.** `StopWakeAlarmIntent.swift` hält selbst fest, dass noch nie ein Alarm end-to-end geklingelt hat. Snooze baut oben drauf, nichts davon ist im Simulator prüfbar. Reihenfolge: erst der Phase-2-stopIntent-Smoke-Test, dann Snooze.

## Die vier Konzepte, kurz eingeordnet

| # | Name | Kern | Differenzierung | Machbarkeit | Philosophie-Fit | Summe |
|---|---|---|---|---|---|---|
| 1 | **Mitschlummern** — das Tuck schläft mit | Live Activity zeigt die schlafende Kreatur + eine ehrliche Zeile ("noch 21 von 30 Minuten"), nichts wird abgezogen | 4 | **5** | **5** | **14** |
| 2 | Der sichtbare Drei-Minuten-Schlummer | Wie 1, plus 3-Minuten-Intervalle statt fixer Dauer, gegen Zurückfallen in den Schlafzyklus | 3 | 4 | 4 | 11 |
| 3 | Traumfaden — Snooze als Traum in Bildern | Jeder Schlummer zeigt ein neues Traumbild/-fragment | **5** | 2 | 2 | 9 |
| 4 | "Noch kurz" — adaptive Dauer + Wecker-später-Vorschlag | Personalisierte Schlummerdauer, schlägt vor den Wecker zu verschieben | 2 | 2 | 3 | 7 |

Konzept 3 bekommt die 5 bei Differenzierung (einzige Idee, die jemand nach einem Screenshot beschreiben könnte), aber die 2 bei Machbarkeit — der Bogen bricht, falls AlarmKit nur einen Schlummer pro Alarm erlaubt (ungeklärt). Konzept 4 scheitert nicht an AlarmKit, sondern daran, dass der nötige tägliche Re-Schedule-Pfad genau in den bekannten `WakeAlarmStore.isFirstDismissal`-Doppelzähl-Bug fällt und B2s Robustheit wieder aufgibt.

## Empfehlung: Konzept 1, plus eine Übernahme aus Konzept 2

Keine Drei-Wege-Synthese — Konzept 1 ist eigenständig am stärksten.

**Was gebaut wird:**

1. Sekundärbutton heißt nie "Schlummern", sondern trägt die Zahl: **"Noch 5 Minuten"**, `moon.zzz.fill`, Dusty Rose. Dauer ist eine Einstellung im Wecker-Setup, kein Automatismus.
2. Live Activity während des Countdowns zeigt die schlafende Kreatur (dieselbe Palette) plus **eine** ruhige Zeile: *"Dein Morgen: noch 21 von 30 Minuten."* Kein Balken, kein Farbwechsel, kein Ausrufezeichen — der stillste Screen des Produkts, bewusst.
3. **Nichts wird abgezogen.** Kein Streak-Bruch, keine Stufenregression, kein Zähler. Ein geschlummerter Morgen ist ein abgeschlossener Morgen (konsistent mit B4).
4. Eigenes kleines Sprechblasen-Set nach einem geschlummerten Morgen: *"Ich hab auch weitergeschlafen."* Das Maskottchen ist Komplize, nie Aufpasser — nie "du hast dreimal gedrückt".
5. **Aus Konzept 2 übernommen, aus Arithmetik, nicht Geschmack:** Schlummerdauer wählbar 3/5/8 Minuten, Default 5, **nichts über 8**. Das Sperrfenster hängt per B1 an der geplanten Weckzeit und läuft während des Schlummerns weiter — bei 9-Minuten-Intervallen essen vier Schlummer das ganze 30-Minuten-Fenster auf, die Sperre wäre beim Aufstehen lautlos schon vorbei.

**Warum das gewinnt:**

- **Man kann sich nicht in Instagram hineinschlummern** — das Sperrfenster hängt an der Weckzeit (B1), ist also schon aktiv während gedöst wird. Fällt kostenlos aus einer bereits getroffenen Architekturentscheidung heraus.
- **Dreht den Ton der Kategorie um.** Jede Anti-Snooze-App bestraft (Matheaufgaben, schrumpfende Dauer, Streak-Verlust). Hier schläft das Maskottchen mit — das "nie bestrafen"-Prinzip genau an der Stelle, an der es sonst überall fällt.
- **Ehrliche Rückmeldung statt Urteil.** "Noch 21 von 30" ist eine Tatsache über ein festes Fenster, keine Bewertung. Ohne erfundenes Punktesystem.
- **Robust gegen die größte offene Unbekannte** (Mehrfach-Schlummer pro Alarm ungeklärt) — funktioniert auch wenn nur ein Schlummer geht. Konzept 3 wäre dann tot.

**Bewusst nicht gebaut:**

- Kein Traum-Content auf dem Sperrbildschirm (Konzept 3) — Detox-Produkt, das Lesestoff auf den Lock Screen legt, ist ein Widerspruch. Falls die Idee reizt: als reine Textzeile im Guten-Morgen-Screen (3 Zeilen Code, kein Widget) statt als Live-Activity-Content. **Niemals sammelbar machen** ("12 von 40 Träumen entdeckt" erzieht zum Schlummern) — das gehört als bindende Entscheidung festgehalten.
- Keine adaptive Dauer, kein tägliches Neu-Scheduling (Konzept 4) — unsichtbarer Nutzen, nachweislich falscher Messwert, Preis ist ein täglicher Lauf durch einen bekannten Bug.
- Kein Pause-Button — ein pausierbarer Schlummer ist ein Schlummer, der nie endet, und spart eine dritte Live-Activity-Ansicht.
- Keine Obergrenze für die Anzahl der Schlummer — AlarmKit bietet keine, sie zu faken wäre Bestrafung durch die Hintertür.

**Was am ehesten schiefgeht:**

- Die "noch X von 30"-Zeile ist strukturell ein Countdown von etwas, das verloren geht — mit Rot/Balken/Dringlichkeit wird sie zum Schuld-Messgerät. Im Zweifel weniger prominent, nicht mehr.
- Eine niedliche schlafende Kreatur auf dem Sperrbildschirm ist ein Grund, draufzuschauen — genau der Griff zum Telefon, den die App verhindern soll. Die Live Activity muss *langweiliger* sein als der dunkle Screen, den sie ersetzt.
- Das Tier darf nie locken ("komm, noch fünf Minuten", Zwinkern) — es schläft nur.
- Ein einziger, immer gleicher Satz wird nach drei Tagen als Skript entlarvt. Kleines variiertes Set, und nur an echten Schlummer-Morgen.

## Produktentscheidung, die vor dem Bau fallen muss (kein Technik-Call)

**Was passiert, wenn jemand über das Fensterende hinaus schlummert?** Bei genug Schlummern ist das ruhige Morgenfenster schon vorbei, wenn der Nutzer aufsteht.

- **Empfehlung:** Fenster bleibt verankert (B1 intakt), die 8-Minuten-Obergrenze macht den Fall unwahrscheinlich, ein zusätzlicher Copy-Zustand nötig: *"Dein Morgenfenster war heute schon vorbei — bis morgen."*
- Alternative (nicht empfohlen): Fenster verschiebt sich mit dem letzten Schlummer — braucht eine erst beim Dismiss registrierte `DeviceActivitySchedule` und holt sich damit die stopIntent-Abhängigkeit zurück, die B1 bewusst vermieden hat.

## Technisch zu klären, in dieser Reihenfolge, auf echtem Gerät (Phase 2)

Im Simulator nichts davon prüfbar.

1. **stopIntent zuerst** — unverändert die existenzielle Frage der ganzen Kette. Snooze danach, sonst zwei ungeprüfte Schichten gleichzeitig.
2. Ist `Alarm.CountdownDuration.postAlert` wirklich die Schlummerdauer? Naheliegend aus Namensgebung, im SDK-Interface nirgends explizit gesagt.
3. Erscheint der Sekundärbutton nach Ablauf des Countdowns erneut (Mehrfach-Schlummer)? Für Konzept 1 nur Komfort, für Konzept 3 wäre es der Todesstoß.
4. Wird die eigene `ActivityConfiguration` bei AlarmKit-Alarmen tatsächlich gerendert, und auf welchen Flächen? Arbeitsannahme: die klingelnde Vollbildansicht gehört dem System, die Countdown-Ansicht uns. Falsch, verliert das Feature seine Bühne.
5. Wird `"Noch 5 Minuten"` im Alert und in der compact Dynamic Island ungekürzt dargestellt? Kurzfassung ("5 Min.") als Fallback vorsehen.
6. Kontrast der Palette (Sage auf Cream) auf dunklem Live-Activity-Grund — potenziell unlesbar, braucht eine dunkel-adaptierte Variante, echte Design-Arbeit.
7. `MascotView` ist so nicht wiederverwendbar — `@State breathe/blink/bounce` und die `Task`-Blinzelschleife laufen im Widget-Prozess nicht. Braucht eine animationsfreie Zeichenschicht in `Shared/`, App behält Animationen als Wrapper. Einzige nötige Änderung an bestehendem Code — chirurgisch extrahieren, nicht neu schreiben.
8. Konfigurationswechsel ist Pflicht: `WakeAlarmScheduler.swift:100` nutzt die Factory `AlarmConfiguration.alarm(...)` ohne `countdownDuration`-Parameter. Snooze braucht den vollen memberwise `init(countdownDuration:schedule:attributes:stopIntent:secondaryIntent:sound:)`. Neues Widget-Target in `project.yml`, dann `xcodegen generate` — Capabilities nie in Xcode klicken. App Group aufs Widget-Target: kein neuer Apple-Antrag, nur Provisioning.

## Aufwandseinschätzung

Ein neues Xcode-Target, vier Dynamic-Island-Layouts, ein ausgelagerter Mascot-Renderer, ein geänderter Alarm-Konfigurationspfad, eine dunkle Palettenvariante — für ein Feature, das bei gutem Verlauf selten benutzt wird. Kein Wochenendprojekt, aber auch kein Moonshot, und rein additiv: kein neues Entitlement, kein neuer Antrag, kein Anfassen der Family-Controls-Kette. Blockiert Phase 2 nicht und wird von Phase 2 nicht blockiert — außer bei den Gerätetests, die ohnehin alle denselben bezahlten Developer-Account voraussetzen.
