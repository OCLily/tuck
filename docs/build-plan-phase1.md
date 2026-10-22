# Tuck — Erster Schritt: Xcode-Projekt-Scaffold

Ins Repo übernommen aus einem früheren Plan, der die eigentliche Quelle für Phase 1 war (nicht Teil dieses Exports). Beschreibt den ursprünglich vorgesehenen Xcode-GUI-Weg — tatsächlich umgesetzt wurde er über XcodeGen (`project.yml`). Als historische Herleitung der Entscheidungen (Deployment-Target, Constraint C1/C2, die vier Entsperr-Optionen) weiterhin die maßgebliche Quelle.

**Stand-Marker (2026-09-06):** Dieses Dokument beschreibt den Zustand vom 2026-09-02. Die 26.2-Angaben unten (Deployment-Target, einzige Simulator-Runtime, Test-Ziel) sind seitdem überholt — das Target steht seit 2026-09-05 auf **26.5** (`docs/design/design-system.md` §8 A39), die 26.5-Runtime ist installiert, Tests laufen auf `OS=26.5`. Die Herleitung, *warum* 26.2 damals der Boden war, bleibt als Geschichte korrekt und wird hier nicht umgeschrieben.

## Context

Tuck: nach dem App-eigenen Wecker (AlarmKit, iOS 26) sperrt die App für mind. 30 Minuten digitale Ablenkung, statt Mascot-Guten-Morgen-Screen. Kein Xcode-Projekt existiert bisher — nur die ursprüngliche Produktspezifikation, `README.md` und `docs/` (concept/palette/mascot).

Die Architekturentscheidungen für diesen ersten Schritt (Zielgerüst, Entitlements, Testbarkeit) kamen aus mehreren Review-Runden. Alle technischen Aussagen unten sind gegen die tatsächliche Installation auf dieser Maschine verifiziert, nicht gegen Trainingsdaten: **Xcode 26.6 (17F113), iPhoneOS-SDK 26.5, einzige installierte Simulator-Runtime iOS 26.2.** Mehrere online kursierende Behauptungen zu AlarmKit-Entitlements und der Shield-Action-API waren nachweislich falsch; ebenso enthielt die Vorversion dieses Plans selbst drei sachliche Fehler (Entitlements, UI-Test-Target, unvollständige Shield-API). Alle drei sind hier korrigiert und die Korrekturen einzeln nachgeprüft.

Antworten zu den drei Gates aus dem Review:
- **Bezahlter Apple-Developer-Account:** wird für Phase 2 (Capabilities, Gerätetests) gebraucht, nicht für Phase 1 (Simulator-Scaffold).
- **Gerät/iOS-Version:** iOS 26.5+ auf dem Zielgerät vorausgesetzt. Bestätigt Deployment-Target 26.2 als sicheren Boden und macht sowohl den saubersten Shield→App-Pfad (`.openParentalControlsApp`, ab iOS 26.5) als auch das neue Shield-Submenü (ab iOS 26.4, siehe C1) später grundsätzlich nutzbar — beide Semantiken sind aber noch nicht auf dem Gerät verifiziert.
- **Bundle-ID-Commitment:** die Bundle-ID-Festlegung (Phase 0b) wird bewusst verschoben. `com.example.tuck` bleibt lokaler Platzhalter für Phase 1 — dafür ist keine Registrierung nötig.

## Recommended Approach

**Deployment Target: iOS 26.2.** Begründung: 26.1 ist in diesem SDK gar kein wählbares Deployment-Target (`ValidDeploymentTargets` in `iPhoneOS.sdk/SDKSettings.plist` springt 26.0 → 26.2 → 26.3 → 26.4 → 26.5); 26.2 liegt über der 26.1-Schwelle, ab der `AlarmPresentation.Alert` den sauberen Initializer anbietet; 26.2 ist die einzige installierte Simulator-Runtime.

Zur AlarmKit-Schwelle präzise (verifiziert im `AlarmKit.swiftinterface`): `AlarmPresentation.Alert` hat **zwei** Initializer — `init(title:secondaryButton:secondaryButtonBehavior:)` mit `@available(iOS 26.1, *)`, und den alten `init(title:stopButton:...)` mit `@available(iOS, deprecated: 26.1)`. Ein Boden von 26.2 heißt: der moderne, `stopButton`-freie Initializer ist ohne `#available`-Gate benutzbar, und der deprecated-Pfad wird gar nicht erst berührt.

Neuere APIs bekommen bei Bedarf ein `#available`-Gate statt einer Boden-Anhebung: `.openParentalControlsApp` → `#available(iOS 26.5, *)`, `secondaryButtonSubmenuItems` → `#available(iOS 26.4, *)`. Den Boden jetzt auf 26.4/26.5 zu heben würde die App im einzig installierten Simulator unlauffähig machen — für Features, die noch nicht existieren.

**Swift Language Mode 6**, einmal auf Projekt-Ebene gesetzt (gilt dann für alle Targets, sofern nicht einzeln überschrieben). Apples eigene Templates liefern standardmäßig `SWIFT_VERSION = 5.0` und am App-Target `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — ob die vier generierten Stubs unter Mode 6 mit MainActor-Default sauber kompilieren, ist nicht vorab bekannt (siehe Verification 1/3, deckt beide Risiken gemeinsam ab).

**Deployment-Target-Mechanik:** Projekt-Level 26.2 setzen UND auf jedem neu angelegten Target einzeln prüfen. Neue Targets bringen ein eigenes Target-Level-`IPHONEOS_DEPLOYMENT_TARGET` mit, das den Projekt-Default überstimmt — der Projekt-Wert allein genügt also nicht.

### Phase 1 — Scaffold + testbarer Kern (jetzt, kein Account/Gerät nötig)

Alles hier baut und testet auf dem iOS-26.2-Simulator **ohne Team und ohne Signing**. Nicht „ohne Entitlements": die Extension-Templates bringen von sich aus Entitlements-Dateien mit (siehe 1.4). Die sind im Simulator funktional wirkungslos, aber sie sind da und bleiben da.

**1.1 Projekt anlegen.** Xcode → File → New → Project → iOS → App.
- Product Name `Tuck`, Organization Identifier `com.example`, Interface SwiftUI, Language Swift, Storage None, Testing System **Swift Testing**, **"Create Git repository" deaktivieren** (Repo existiert bereits).
- Zur Testing-System-Option: der Dialog kennt exakt drei Werte — „None", „XCTest for Unit and UI Tests", „Swift Testing with XCTest UI Tests". **Eine Unit-Tests-only-Option gibt es nicht.** „Swift Testing" erzeugt IMMER zwei Test-Targets: `TuckTests` (Swift Testing) und `TuckUITests` (XCTest). Das ist erwartetes Verhalten, kein Fehlklick — Behandlung in 1.2.
- In `<repo>` speichern; Xcode verschachtelt alles unter `<Projektordner>/Tuck/`. **Xcode schließen**, den Inhalt dieses Ordners eine Ebene hochziehen, den leeren Ordner löschen, neu öffnen. Ziel-Layout: `<Projektordner>/Tuck.xcodeproj` + `<Projektordner>/Tuck/`. Alle pbxproj-Pfade (inkl. Xcode-Synchronized-Root-Gruppen) sind relativ zum `.xcodeproj`-Elternordner — sicher, aber nur bei geschlossenem Xcode. **Sofort nach dem Verschieben einen Clean Build verifizieren, vor dem Commit.**
- Deployment Target 26.2, Swift Language Mode 6.

**1.2 `TuckUITests`-Target löschen** (vor dem Scaffold-Commit). Target im Project-Editor auswählen → Minus/Delete; Xcode entfernt dabei nur das Target, **nicht** die Ordner-Referenz im Navigator und **nicht** den Ordner `TuckUITests/` auf der Platte. Den Ordner im Navigator per Rechtsklick → "Move to Trash" löschen (nicht nur im Finder) — das entfernt Datei UND pbxproj-Gruppenreferenz in einem Schritt; ein reiner Finder-Löschvorgang hinterlässt eine tote Referenz.

Bewusste Entscheidung, nicht Nachlässigkeit — die Begründung ist projektspezifisch:
- Das produktkritischste Stück UI (der Shield-Screen) wird von einem **fremden Systemprozess** gerendert (`com.apple.ManagedSettingsUI.shield-configuration-service`). XCUITest kann Out-of-Process-System-UI nicht ansteuern. Ausgerechnet das, wofür UI-Tests hier wertvoll wären, ist strukturell nicht UI-testbar.
- Family Controls funktioniert im Simulator nach bisheriger Erfahrung ohnehin nicht (hier nicht durch einen Build-Lauf verifiziert, nur Community-Konsens). In Phase 1 könnten UI-Tests also selbst im positiven Fall nur den trivialen `ContentView`-Button abdecken.
- Der Plan lehnt spekulative Tests explizit ab (siehe 1.7). Ein generierter `testExample` plus Launch-Performance-Test in einem **zweiten** Test-Framework (XCTest neben Swift Testing) wäre genau das — plus dauerhafte Build-Zeit bei jedem Cmd+U.
- Rückbaukosten ≈ null: File → New → Target → UI Testing Bundle, sobald es einen echten In-App-Flow zu testen gibt (z.B. den Guten-Morgen-Screen).

**1.3 `NSAlarmKitUsageDescription`.** Xcode-26-App-Targets haben kein Info.plist-File (`GENERATE_INFOPLIST_FILE=YES`); unter Target → Info → Custom iOS Target Properties hinzufügen. Deutscher String, z.B. *"Tuck stellt deinen Morgenwecker."*

**1.4 Drei Extension-Targets** (File → New → Target, jeweils in `Tuck` embedded; "Activate scheme"-Dialog jedes Mal abbrechen). Deployment Target 26.2 auf jedem einzeln setzen/prüfen.

| Template | Target | Bundle-ID |
|---|---|---|
| Device Activity Monitor Extension | `TuckMonitor` | `com.example.tuck.monitor` |
| Shield Configuration Extension | `TuckShield` | `com.example.tuck.shield` |
| Shield Action Extension | `TuckShieldAction` | `com.example.tuck.shieldaction` |

Zwei Dinge, die die Templates generieren und die **unangetastet bleiben müssen**:

1. **Die generierten `NSExtension`-Dicts nicht von Hand anfassen.** Die Asymmetrie in den beiden Shield-Identifiern ist echt und korrekt so — verifiziert: Shield Configuration = `com.apple.ManagedSettingsUI.shield-configuration-service`, Shield Action = `com.apple.ManagedSettings.shield-action-service` (einmal *mit*, einmal *ohne* `UI`). Sie sieht aus wie ein Tippfehler und ist ein bekannter App-Store-Ablehnungsgrund, wenn man sie „korrigiert".

2. **Die generierten `.entitlements`-Dateien nicht löschen und nicht leeren.** Jedes der drei Templates legt eine `<Target>.entitlements` mit `com.apple.developer.family-controls = true` an und verdrahtet sie über `CODE_SIGN_ENTITLEMENTS`. Das ist Apples eigener Template-Default, kein Fremdkörper und kein Überbleibsel eines früheren Setups. Ein Aufräum-Impuls („Phase 1 braucht doch noch keine Entitlements") zerstört hier Konfiguration, die in Phase 2 exakt so gebraucht wird.

Generierte Stubs sonst unangetastet lassen, bis auf das Löschen der Template-Erklärkommentare (die erklären WAS, nicht WHY — gegen die Konvention).

> **Eines von zwei unbewiesenen Build-Risiken in Phase 1** (das andere ist Swift Language Mode 6, siehe oben): dass ein Simulator-Build mit diesen family-controls-Entitlements **ohne Team** durchgeht. Dafür spricht stark, dass Apples eigener Template-Default genau diese Konfiguration erzeugt, und dass Simulator-Builds Entitlements nicht gegen ein Provisioning-Profil validieren. Ohne tatsächlichen Build-Lauf ist es aber Annahme, nicht Fakt — deshalb steht der Clean Build in Verification 1/3. Falls es doch scheitert: `CODE_SIGN_ENTITLEMENTS` am betroffenen Target **temporär** leeren — die Datei selbst aber behalten und den Eingriff in Phase 2 zurücknehmen. (Eine oft genannte Alternative, das Target auf "Sign to Run Locally" zu stellen, ist für iOS-Targets im Signing-Editor nach bisheriger Kenntnis nicht verfügbar — hier nicht verifizierbar, daher nicht als Fallback verlassen.)

**1.5 `Shared/TuckIdentifiers.swift`** im Repo-Root, als klassische Gruppe hinzugefügt, Target-Membership angehakt für **App + alle drei Extensions**. Inhalt: App-Group-Suite-Name `group.com.example.tuck`, `ManagedSettingsStore.Name` (`.morningBlock`), `DeviceActivityName` (`.morningBlock`), der Shared-Defaults-Key für die persistierte `FamilyActivitySelection`. Vier getrennte Prozesse müssen sich auf dieselben Literale byte-genau einigen; ein Tippfehler scheitert sonst lautlos über die Prozessgrenze. Das ist Dopplungs-Vermeidung, keine Abstraktion. `Shared/` liegt bewusst außerhalb jedes Synchronized-Root-Ordners, damit einfache Membership-Checkboxen funktionieren — keine Membership-Exceptions verwenden.

**1.6 `Shared/MorningBlockWindow.swift`** — das einzige wirklich testbare Stück. Target-Membership: **nur App-Target.** Nicht zusätzlich im Test-Target: das Projekt-Debug-Setting `ENABLE_TESTABILITY = YES` ist gesetzt (Xcode-Default), `TuckTests` hat `Tuck` als Host-App, und `@testable import Tuck` gibt damit vollen Zugriff auf `internal`-Symbole. Doppelte Membership wäre nicht bloß redundant, sondern schädlich: die Datei würde in **zwei** Module kompiliert, es entstünden zwei gleichnamige, aber verschiedene Typen (`Tuck.MorningBlockWindow` vs. `TuckTests.MorningBlockWindow`), der Test prüfte still die Test-Bundle-Kopie statt der ausgelieferten, und sobald ein Wert die Modulgrenze kreuzt, gibt es unverständliche Typfehler. Default-Sichtbarkeit `internal` genügt — keine `public`-Annotationen nötig.

Isoliert das in der ursprünglichen Produktspezifikation genannte "relatives Fenster ist Eigenbau"-Problem als reinen Wertetyp ohne Framework-Import:

```swift
struct MorningBlockWindow {
    let start: DateComponents   // nur hour/minute/second
    let end: DateComponents     // nur hour/minute/second
    init(dismissedAt: Date, duration: Duration, calendar: Calendar)
}
```

Zwei Constraints, deshalb ein Test statt Inline-Code am Call-Site:
- Dauer wird auf ein **30-Minuten-Minimum** geklemmt — das Produkt-Minimum aus dem Konzept. Es liegt komfortabel über der kolportierten Plattform-Untergrenze und macht die Frage damit gegenstandslos. **Zur Ehrlichkeit:** im SDK steht nur der Fehlerfall `DeviceActivityCenter.MonitoringError.intervalTooShort` — **keine Zahl**. Die „15 Minuten" sind Doku-/Community-Beobachtung, kein verifizierbarer SDK-Fakt (nachgeprüft: im `DeviceActivity.swiftinterface` kommt „15" ausschließlich als `iOS 15.0`-Availability vor). Testname und Kommentar müssen das so kennzeichnen — nicht als SDK-Konstante ausgeben.
- Nur `hour`/`minute`/`second` sind gesetzt; era/year/month/day bleiben nil (sonst `MonitoringError.invalidDateComponents`; gemischte Granularität unterdrückt dokumentiert lautlos `intervalDidStart`).

Mitternachts-Wraparound wird NICHT "repariert" — der Typ macht reine modulare Arithmetik (23:50 + 30min → Ende 00:20), die Interpretation überlässt er der Plattform. Ob DeviceActivity ein gewrapptes Intervall tatsächlich akzeptiert, ist unverifizierte Community-Folklore, kein SDK-Fakt — kommt auf die Phase-2-Geräteverifikation, nicht als Annahme in den Code.

Die `DeviceActivitySchedule` wird erst am Call-Site aus `start`/`end` gebaut — DeviceActivity bleibt außerhalb der getesteten Einheit.

**1.7 Tests zuerst.** Das Template legt `TuckTests` bereits an (Swift Testing, Host-App `Tuck`). Platzhalter-Test löschen, `TuckTests/MorningBlockWindowTests.swift` **vor** der Implementierung aus 1.6 schreiben — hier gibt es eine echte Spezifikation, gegen die ein Test fehlschlagen kann. `@testable import Tuck`. `Calendar`/`TimeZone` in jedem Case explizit pinnen (DST-Determinismus). Vier Fälle:
1. nominales 30-Minuten-Fenster
2. Unter-30-Minuten-Dauer klemmt auf 30 — Testname formuliert das als Produktregel, z.B. `clampsDurationToThirtyMinuteProductMinimum`, **nicht** als Plattform-Grenze
3. 23:50 + 30min ergibt 00:20
4. nur `hour`/`minute`/`second` sind non-nil

Keine Tests für Freischaltungs-Zähler oder Mascot-Wachstumsstufen — beide Features existieren noch nicht, Tests gegen imaginäre APIs wären spekulative Arbeit. Die bekommen Tests, wenn sie gebaut werden.

**1.8 Minimaler Authorization-Trigger.** Ein Button in `ContentView`, der `AuthorizationCenter.shared.requestAuthorization(for: .individual)` aufruft und `authorizationStatus` anzeigt. Die API ist `async throws` (iOS 16+) — also aus einem `Task` heraus aufrufen und den Fehler abfangen und anzeigen, nicht schlucken; im Simulator ist der Fehlerfall der erwartete Normalfall. `authorizationStatus` ist `@Published`, taugt also direkt für die Anzeige. Ohne diesen Schritt hat Phase 2 nichts zum Ausführen — und es ist die kleinstmögliche Probe, ob die Entitlement-Kette später überhaupt durchgeht.

**1.9 Drei Commits** (bewusste Abweichung von der Datei-für-Datei-Konvention — für einen Scaffold-Wurf unpraktikabel; Gruppierung nach logischer Änderung):
1. `chore: scaffold Xcode project with monitor and shield extension targets` (1.1–1.4 inkl. 1.2-Löschung — das UI-Test-Target existiert nie in einem committeten Zustand — sowie 1.5, die Shared-Identifiers-Datei)
2. `feat: add morning block window calculation` (Test + Implementierung, 1.6 + 1.7)
3. `feat: add family controls authorization trigger` (1.8)

Keine `.gitignore`-Änderung nötig — deckt `xcuserdata/`, `DerivedData/`, `.build/`, `*.xcuserstate` bereits ab (verifiziert).

### Zwei Design-Constraints, die jetzt schon feststehen

**C1 — Der Shield-Screen ist ein Apple-Template, keine eigene UI.** `ShieldConfiguration` exponiert exakt: `backgroundBlurStyle`, `backgroundColor`, ein `UIImage`-Icon, `title`-Label, `subtitle`-Label, `primaryButtonLabel`, `primaryButtonBackgroundColor`, `secondaryButtonLabel` — und seit iOS 26.4 zusätzlich `secondaryButtonSubmenuItems: [String]?`. Kein SwiftUI, kein Layout, keine Animation. Das Tuck-Mascot auf dem Block-Screen ist ein einzelnes statisches Bild. Der Yoga-ästhetische Guten-Morgen-Screen lebt **in der App**, nie im Shield. Konsequenz für die Asset-Produktion später: Shield braucht ein flaches PNG/PDF, der App-Screen kann alles sein.

**Neu und direkt produktrelevant (in der Vorversion dieses Plans übersehen):** Das Submenü am Secondary-Button trägt **bis zu drei unterscheidbare Einträge** — nicht weil das Array begrenzt wäre, sondern weil `ManagedSettings` genau drei zugehörige Action-Cases hat: `ShieldAction.firstSecondarySubmenuItemPressed`, `.secondSecondarySubmenuItemPressed`, `.thirdSecondarySubmenuItemPressed` (alle `@available(iOS 26.4, *)`). Das ist ein direkter Kandidat für die **"Begründung (kurze Auswahl warum)"**-Hälfte der Override-Mechanik aus der ursprünglichen Produktspezifikation (nicht Teil dieses Exports): die drei Gründe stehen als Submenü-Einträge im Shield selbst, die Auswahl kommt als unterscheidbarer Case in der Shield-Action-Extension an — ohne dass der Nutzer die App überhaupt öffnen muss.

Wichtig für die Produktlogik: das löst nur die **Begründungs**-Hälfte. Die **Verzögerungs**-Hälfte (Zwangs-Timer mit Atem-Animation) kann im Shield nicht stattfinden — dort gibt es keine Animation und keine Zeitanzeige. Die Friktion muss also entweder in der App liegen (Shield öffnet App) oder im Verhalten der Action-Extension (z.B. Freischaltung erst nach Ablauf eines Timers, den die Extension setzt). Vorbehalt: 26.4 liegt über unserem Boden 26.2 → `#available(iOS 26.4, *)`-Gate nötig.

**C2 — Der Shield kann die App öffnen, ab iOS 26.5.** `ShieldActionResponse.openParentalControlsApp` existiert in diesem SDK mit `@available(iOS 26.5, *)` — eine ältere, im Netz noch kursierende Annahme ("Shield kann die App nie öffnen") ist überholt. Zwei Vorbehalte vor Verlass darauf: (a) der Name sagt "parental controls app" — ob er unter `.individual`-Autorisierung tatsächlich die shieldende App selbst öffnet, ist unverifiziert und muss in Phase 2 am Gerät smoke-getestet werden; (b) erfordert das Gerät auf 26.5+.

### Explizit außerhalb dieses Schritts

- **Phase 0a** (bezahlter Account) — kein Ansatzpunkt hier.
- **Phase 0b** (Bundle-ID-Registrierung + Family-Controls-Distribution je Bundle-ID) — bewusst verschoben.
- **Phase 2** (Signing, Capabilities, Gerätetest) — setzt einen bezahlten Developer-Account voraus. Konkret: **Family Controls muss nur noch am App-Target ergänzt werden** — die drei Extensions haben das Entitlement seit 1.4 aus dem Template. **App Groups** dagegen an allen vier Targets neu hinzufügen. Phase 2 beginnt mit genau zwei Smoke-Tests, vor jeder weiteren Feature-Arbeit: (a) öffnet `.openParentalControlsApp` unter `.individual` wirklich die App? (b) akzeptiert DeviceActivity ein dynamisch erzeugtes Relativ-Fenster inkl. Mitternachts-Wraparound? Phase 1 de-riskt vom Kern-Loop selbst nichts — diese beiden Fragen sind die eigentlichen Killshot-Kandidaten.
- Widget-Extension (nur für Snooze/Countdown-Präsentation nötig), Device-Activity-Report-Extension, StoreKit, Onboarding, `FamilyActivityPicker`-UI, Mascot-Assets, Guten-Morgen-Screen-Inhalt, Farbwerte aus `docs/design/palette.md`.
- `stopIntent`-Fallback (ein gemeldeter, von Apple nicht reproduzierter Fall, dass `stopIntent` beim Wegwischen einer Live-Activity-Banner nicht feuert) — akzeptiertes Risiko für diesen Schritt, abgefedert dadurch, dass Arming von Anfang an idempotent und über `alarmUpdates` re-prüfbar bleibt.

### Offene Produkt-Fragen (blockieren Phase 1 nicht, vor Phase 2 / vor Asset-Produktion entscheiden)

Konsolidiert und aktuell gehalten in den offenen Fragen (nicht Teil dieses Exports).

## Critical Files

- `Tuck.xcodeproj/project.pbxproj`
- `Shared/TuckIdentifiers.swift`
- `Shared/MorningBlockWindow.swift`
- `TuckTests/MorningBlockWindowTests.swift`
- `TuckMonitor/DeviceActivityMonitorExtension.swift`

## Verification

1. Nach dem Ordner-Move (1.1): Clean Build (Cmd+Shift+K, dann Cmd+B) auf dem iOS-26.2-Simulator, bevor irgendetwas committet wird.
2. Nach 1.2: `TuckUITests` taucht weder im Project-Editor noch als Ordner auf der Platte auf; Schema-Test-Aktion enthält nur noch `TuckTests`.
3. App-Target UND alle drei Extension-Targets bauen fehlerfrei im Simulator — inklusive der drei Template-Entitlements-Dateien und ohne gesetztes Team. Funktional inert (Family Controls arbeitet im Simulator nicht, und ohne Profil ist das Entitlement wirkungslos), aber der Build selbst muss durchgehen. Das ist die Prüfung der einzigen unbewiesenen Annahme aus 1.4.
4. Die drei `.entitlements`-Dateien existieren noch und enthalten je `com.apple.developer.family-controls`; `CODE_SIGN_ENTITLEMENTS` zeigt bei jedem Extension-Target darauf.
5. Nach 1.6/1.7: `MorningBlockWindowTests` laufen lassen (Cmd+U oder `xcodebuild test -scheme Tuck -destination 'platform=iOS Simulator,OS=26.2,name=iPhone 17'`) — alle vier Fälle grün, insbesondere der Mitternachts-Wraparound-Fall.
6. `ContentView`-Button löst `requestAuthorization` aus und zeigt einen Status oder Fehler an (im Simulator nach bisheriger Erfahrung `.notDetermined`/Fehler, da Family Controls dort nicht funktioniert — hier nicht separat verifiziert. Zweck der Prüfung ist, dass der Code-Pfad existiert und kompiliert und irgendein Ergebnis anzeigt, unabhängig vom tatsächlichen Ausgang).
7. `git log --oneline` zeigt genau drei Commits in der Reihenfolge aus 1.9.

**Nachtrag (Ist-Stand):** Umgesetzt über XcodeGen statt Schritt 1.1–1.4 (Xcode-GUI) — siehe `project.yml` und `docs/audit-log.md` für den tatsächlichen Weg und die beiden Fix-Runden. Verification 1–7 wurden alle erfüllt, nur über andere Kommandos (`xcodebuild -target ... -sdk iphonesimulator`, `xcodebuild test`) als hier beschrieben.
