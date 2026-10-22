# Palette — Salbei-Morgen

**Historisch, seit 2026-09-05 überholt:** dieses Dokument zeigt nur die vier ursprünglichen Hell-Werte und die Entscheidungsgeschichte dahinter — beides weiterhin korrekt. Der komplette aktuelle Tokensatz (elf Werte inkl. Dark-Mode-Gegenstücken, Mascot-Tinten, Rollen-Tokens) und der Auflösungsmechanismus stehen in `docs/design/design-system.md` §2, das jetzt die einzige verbindliche Quelle ist. Nicht nachgezogen, um die Entstehungsgeschichte unten nicht zu überschreiben.

| Rolle | Hex |
|---|---|
| Sage (Primär) | #D8E2D3 |
| Cream (Hintergrund) | #F5EFE6 |
| Dusty Rose (Akzent) | #E8C4B8 |
| Charcoal-Green (Text) | #6B7A6E |

Drei abgeleitete Dämmerungs-Töne werden in `Color+Palette.swift` aus diesen vier berechnet — keine eigenständigen Palette-Farben.

## Kontrast-Regel (viermal verletzt, deshalb explizit)

Nie Opacity < 1.0 für Fließ- oder Hinweistext, um Hierarchie zu erzeugen — Hierarchie läuft über Schriftgröße und -gewicht. Charcoal-Green erreicht auf Cream/Sage/Dusty-Rose selbst bei voller Deckkraft nur ~3,8–4,1:1: das reißt AA für kleinen Text (4,5:1), erfüllt aber AA für großen Text (3:1, ab 14 pt bei Gewicht 700 oder 18 pt regular). Jedes Prozent Alpha geht direkt vom Kontrast ab (0.7 → ~2,4:1, 0.55 → ~2,0:1). Bisher viermal aufgetreten: `GutenMorgenView` (zweimal), `OnboardingFlowView` und zuletzt acht Stellen in `OverrideFlowView`, `BedtimeSetupView`, `WakeAlarmSetupView` — dort auch auf der Fehlermeldung des Sperrfensters, der am schlechtesten lesbaren Zeile des Screens.

Gewählt aus drei Vorschlägen (Alternativen Lavendel-Dämmerung, Terrakotta-Ruhe verworfen). Ziel: ruhig, erdig, wenig Kontrast — "alles was das Auge am Morgen verkraften kann".
