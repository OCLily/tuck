# Mascot — Tuck

Kombiniert zwei ursprünglich getrennte Konzepte: ein schlafendes Tier als Charakter + "Sprössling" (Wachstums-Mechanik). Der Charakter heißt "Tuck", wie die App.

## Prinzip
Wächst/verändert sich sichtbar mit Nutzungs-Konsequenz. Ein Aussetzer pausiert das Wachstum nur — NIE Rückschritt, NIE Bestrafung. Bewusst kein Duolingo-Guilt-Mechanismus (traurige Eule bei Pause). Vorbild: die Finch-App mit demselben "nie bestrafen"-Prinzip (Erfolgszahlen aus nicht enthaltenen Recherchenotizen, hier nicht belegt).

## Drei Wachstumsstufen

Stufen sind an **abgeschlossene Morgen** gebunden (ein Morgen zählt, sobald die Sperre einmal ausgelöst wurde — unabhängig davon ob eine Freischaltung genutzt wurde, siehe `docs/product-decisions-2026-09-02.md` B4), nicht an Kalenderzeit — Kalenderzeit lässt sich nicht "pausieren", das Prinzip oben aber schon. Ein Morgen ohne App-Wecker (siehe akzeptierte Lücke in der ursprünglichen Produktspezifikation, nicht Teil dieses Exports) zählt weder als Fortschritt noch als Aussetzer, er wird schlicht nicht gezählt. Zahlen sind ein Startpunkt, kein SDK- oder Recherche-Fakt — grobe Orientierung an "etwa eine Woche" / "etwa ein Monat" täglicher Nutzung, überschreibbar ohne Konzeptbruch.

1. **Start (0 abgeschlossene Morgen):** klein, Augen geschlossen, blasse/entsättigte Farbe.
2. **Warm geworden (ab 7 abgeschlossenen Morgen):** voller, Augen halb geöffnet, satter.
3. **Eingespielt (ab 30 abgeschlossenen Morgen):** voll wach, trägt kleine Sprossen-Krone (visuelle Verschmelzung mit dem Sprössling-Konzept).

Die Sprosse beginnt seit 2026-09-13 (Phase 1.4) schon auf Stufe 1 als **Keim** — Knospenkopf auf kurzem Stiel, kein Blatt —, setzt auf Stufe 2 als einblättrige Sprosse an und klappt auf Stufe 3 zur zweiblättrigen Krone auf. Das Wachstum ist damit über alle drei Stufen sichtbar statt erst ab Stufe 2. Bis dahin zeichnete Stufe 1 gar keine Sprosse: die Mechanik, die dieses Dokument beschreibt, war in der ersten Woche jedes neuen Nutzers unsichtbar. Geometrie und Begründung: `docs/design/design-system.md` §5.10.

## Nach Stufe 3: der Meilenstein-Fahrplan

Stufe 3 bei 30 Morgen war bis 2026-09-05 das Ende — danach änderte sich nie wieder etwas. Entscheidung vom 2026-09-05: es geht ab 45 Morgen weiter, in großen Abständen und ohne jede Mechanik dahinter. Datenschicht gebaut (`Shared/MascotMilestone.swift`, `Shared/MilestoneStore.swift`), seit 2026-09-05 vollständig: die Farbwahl steht in den Einstellungen unter „Dein Tuck" und listet nur Verdientes, die Abzeichen stehen als Blatt-Zeile („Blätter", seit 2026-09-07) unter „Fortschritt", und jede Freischaltung sagt sich selbst genau einmal in der Sprechblase an (`MascotMilestone.celebration`, Regeln und Auslösepfade in `docs/design/design-system.md` §5.4, §5.9, §5.10).

| Morgen | Belohnung |
|---|---|
| 45 | Farbvariante **Staubblau** (`#6C7A85`) |
| 60 | Idle-Beat **Strecken** |
| 90 | **Abzeichen 1** (`quarterYear`) |
| 120 | Farbvariante **Warmsand** (`#8A7A6B`) |
| 180 | Idle-Beat **Gähnen** |
| 270 | **Abzeichen 2** (`threeQuarterYear`) |
| 365 | Farbvariante **Soft-Lavendel** (`#7A6E85`) |

Dieselbe Bindung wie die drei Stufen: an **abgeschlossene Morgen**, nie an Kalenderzeit. Ein Aussetzer pausiert auch hier nur.

**Was die Belohnungen sind — und was sie nicht sind.** Die drei Farben ersetzen die Tinte des Rigs (Kontur, Augen, Mund, Kontaktschatten), nicht den Sage-Körper; sie sind entsättigt und liegen auf der Helligkeit des Originals, das Tier wiegt also in jeder Variante gleich (Kontrastwerte: `docs/design/design-system.md` §2.6). Die zwei Idle-Beats treten in dasselbe gewichtete Repertoire ein, aus dem `blink`, `doubleBlink`, `earTwitch`, `headTilt` und `lookAround` gezogen werden — ein nicht erreichter Beat ist nie im Topf. Und zwar in der laufenden Sitzung: der freigeschaltete Beat ist ab dem ersten Idle-Zug nach der Rückkehr in den Vordergrund ziehbar (3,5–7 s später), nicht erst nach einem Neustart — die Feier-Zeile „Wir strecken uns jetzt manchmal." behauptet also nichts, was noch nicht gilt (`docs/design/design-system.md` §6.2, im Simulator nachgemessen). Die zwei Abzeichen tun **gar nichts**: sie schalten nichts frei, sie stehen in keiner Bedingung, sie existieren nur, um gesehen zu werden.

**Kein Rückschritt, auch nicht technisch.** Erreichte Meilensteine sind eine reine Funktion des Morgen-Zählers, aber `MilestoneStore` liest ihn nicht direkt: er hält den höchsten je gesehenen Stand als Ratsche. Käme der Zähler je niedriger zurück, bliebe jede Belohnung stehen. Das Original (`tuckCharcoalGreen`) ist Default und bei jedem Stand wählbar — es ist keine Belohnung und kann deshalb auch nicht ausbleiben.

## Verdient und unverdient — zwei Kanäle, die sich nicht berühren (seit 2026-09-15)

Alles oben ist der **verdiente** Kanal: Stufen, Farben, Idle-Beats, Abzeichen. Er hat einen Sammelort, und zwar zu Recht — die Farbwahl unter „Dein Tuck", die Blatt-Zeile unter „Fortschritt", `MilestoneStore` als Ratsche dahinter. Wer nachsehen will, was er erreicht hat, findet es.

Daneben steht seit 2026-09-15 ein zweiter, **unverdienter** Kanal (`docs/design/design-system.md` §5.15): ein Jahreszeiten-Akzent und ein Fundstück, das alle vierzehn Tage ein anderes ist. Er ist an **keinen Zähler** gekoppelt — nicht an abgeschlossene Morgen, nicht an Meilensteine, nicht an die Stufe —, und das ist mechanisch geprüft, nicht nur beabsichtigt: ein Scan über beide Quelldateien auf acht verbotene Symbole, `MascotStage` und `MorningCelebration` eingeschlossen, weil beide Zähler-Verkleidungen sind.

**Das Fundstück ist der schärfste Fall dieser Trennung: ein Gegenstand, der NICHT in ein Regal wandert.** Kein Bestand, kein Archiv, kein Ablaufdatum, kein „x von y", kein „letzten Monat lag hier". Es gibt nichts zu sammeln und nichts zu verpassen. Genau das unterscheidet es vom Meilenstein-Fahrplan oben — und die Weglass-Entscheidung wird jetzt getroffen, weil sie jetzt nichts kostet und später ein Rückbau wäre.

**Und der Akzent dekoriert die Welt, nie das Tier.** Keine Jahreszeit ändert Wachheit, Haltung, Reaktionsbereitschaft, Idle-Frequenz oder Tap-Antwort. Tuck wacht in jeder Jahreszeit für den Nutzer auf; das ist die tragende Erzählung, kein saisonaler Zustand. Ein Winterschlaf-Motiv wäre zugleich ein Verstoß gegen die Still-Face-Invariante (§6.6).

Erste visuelle Skizzen (drei Paletten + drei Mascot-Richtungen zur Auswahl) wurden nicht als Datei gespeichert — bei Bedarf neu gestalten.
