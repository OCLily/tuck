# Privacy Manifest (`PrivacyInfo.xcprivacy`) — Entwurf & Belege

Stand 2026-09-05. Was hier steht, ist gegen den Repo-Stand geprüft, nicht aus der Dokumentation abgeschrieben — jede Aussage nennt ihre Belegstelle. Was **nicht** verifizierbar war, steht in §6 als offene Frage und nicht als Entwurf.

Kein Apple-Developer-Account nötig: die Datei ist eine Property-List im Repo, kein App-Store-Connect-Artefakt. Was ein Account braucht, ist erst die Einreichung.

---

## 1. Was die App tatsächlich tut (Grep-Befund, nicht Annahme)

| Behauptung | Wie geprüft | Ergebnis |
|---|---|---|
| **Kein eigener Netzwerkpfad** | `grep -rn "URLSession\|URLRequest\|NWConnection\|CFNetwork\|dataTask\|WKWebView\|CloudKit\|NSUbiquitous\|Firebase"` über alle vier Targets + `Shared/` | **Null Treffer.** Die einzigen `http`-Vorkommen im Repo sind die `DOCTYPE`-URLs in den `.plist`-Dateien *(Stand 2026-09-05; überholt: `Tuck/PaywallView.swift` enthält inzwischen zwei `https`-URL-Literale in `PaywallLegal`, die als SwiftUI-`Link` erst beim Tippen im Systembrowser geöffnet werden, kein App-eigener Netzwerkpfad)*. Die App ruft keine dieser APIs auf — sie nutzt aber `StoreKit` (`Product.products(for:)`, `Transaction.currentEntitlements`, `AppStore.sync()`, alle in `SubscriptionController.swift`), das intern mit Apples eigenen Servern spricht, um Käufe und Abo-Status zu prüfen. Kein Code dieser App öffnet selbst eine Verbindung. |
| Keine Analytics, kein Crash-SDK, kein Third-Party-SDK | dieselbe Suche + `project.yml` (keine `packages:`, keine `carthage`/`SPM`-Abhängigkeit) | Alle eingebundenen Frameworks sind Apples eigene: `AlarmKit`, `AppIntents`, `FamilyControls`, `DeviceActivity`, `ManagedSettings`, `ManagedSettingsUI`, `StoreKit`, `SwiftUI`, `UIKit`, `Foundation`, `Observation`. |
| Nutzdaten liegen in `UserDefaults` | `grep -rn "UserDefaults\|FileManager\|Keychain\|CoreData\|SwiftData"` | Fast alles in `UserDefaults(suiteName: "group.com.example.tuck")` — jeder Store-Zugriff, ohne Ausnahme, immer mit `?? .standard` als Fallback (die frühere Stellenzahl hier ist gestrichen: sie driftete zweimal, und das Manifest hängt am *Ob* des Pfads, nicht am Wie-oft); ein einzelner Schlüssel (`hasCompletedOnboarding`, s. u.) liegt außerhalb davon in `UserDefaults.standard`. Kein Keychain, keine Datenbank *(Stand 2026-09-05; überholt: `Tuck/DeviceIdentity.swift` legt inzwischen einen Keychain-Eintrag an, nur für dieses Gerät und ohne Nutzdaten)*. **Eine `FileManager`-Stelle gibt es** (`Shared/UnlockQuotaStore.swift:172-186`), sie speichert aber nichts — s. den Absatz darunter. |
| Keine Required-Reason-API außer `UserDefaults` | `grep -rn "systemUptime\|mach_absolute\|modificationDate\|creationDate\|volumeAvailable\|statfs\|activeInputModes\|UITextInputMode\|attributesOfItem"` | **Null Treffer.** Kein File-Timestamp, kein Boot-Time, kein Disk-Space, keine Active-Keyboards. |

**Die eine `FileManager`-Stelle, und warum sie die File-Timestamp-Kategorie nicht auslöst:** `UnlockQuotaStore.withQuotaLock` (`Shared/UnlockQuotaStore.swift:172-186`) holt sich über `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)` den App-Group-Container, legt darin per `open(2)` die leere Datei `unlockQuota.lock` an und nimmt darauf `flock(2)`. Die Datei trägt keinen Inhalt; sie existiert nur, damit es einen Dateideskriptor zum Sperren gibt.

**Wer das Lock heute wirklich braucht** (korrigiert 2026-09-05): bis dahin stand hier „der einzige Mutex, den die App und die Shield-Action-Extension als zwei Prozesse über einer Suite teilen können". `TuckShieldAction` kompiliert `UnlockQuotaStore.swift` gar nicht (`project.yml`, Sources dieses Targets: fünf geteilte Dateien, diese nicht darunter) und dekrementiert nichts; `consumeUnlock` hat repo-weit außerhalb der Tests genau einen Aufrufer, `Tuck/OverrideFlowView.swift:16`. Der einzige Nicht-App-Prozess, der das Kontingent überhaupt liest, ist `TuckShield` — nur lesend, und er nimmt das Lock bewusst nicht. Was das Lock **heute** trägt, steht zwei Absätze weiter in der Datei selbst (`:166-168`): `flock` hängt an der Open-File-Description, serialisiert also auch zwei Threads in einem Prozess, und genau dieses Interleaving pinnt `TuckTests/UnlockQuotaConcurrencyTests.swift`. Der Zwei-Prozess-Fall ist der künftige (§3 der Apple-Developer-Checkliste), nicht der bestehende — die Entscheidung war richtig, nur ihre Begründung war es nicht.

Apples Required-Reason-Kategorie „File Timestamp" ist an konkrete APIs gebunden — `stat`, `fstat`, `getattrlist`, `NSFileCreationDate`/`NSFileModificationDate` und ihre `URLResourceValues`-Entsprechungen. `containerURL`, `open` und `flock` stehen auf keiner der vier Required-Reason-Listen, und keine der genannten APIs wird hier gerufen: der Code fragt nie nach einem Zeitstempel, einer Größe oder einem Attribut der Datei. **Die Schlussfolgerung von §4 bleibt damit unverändert** — eine zusätzliche Deklaration ist nicht nötig, `NSPrivacyAccessedAPICategoryUserDefaults` bleibt die einzige betroffene Kategorie. Der Grep in der Zeile darüber deckt das mit ab: `attributesOfItem`, `creationDate` und `modificationDate` sind Teil seiner Suchbegriffe und haben null Treffer.

**Liste der gespeicherten Schlüssel** *(Stand 2026-09-05; seither erweitert, zum Beispiel um Wecker-Wochentage, Schema-Version, Geräteidentität und Diagnose-Zähler, daher nicht mehr vollständig)* (Skalare, Strings oder `Date` bis auf die zwei unten genannten Ausnahmen; alle im App-Group-Suite bis auf den letzten Absatz):

`wakeAlarmID` · `wakeAlarmFireDate` · `wakeAlarmDismissedAt` · `morningBlockWindowStartSecondOfDay` · `morningBlockWindowEndSecondOfDay` · `morningBlockRegistrationSucceeded` · `morningBlockDurationMinutes` · `bedtimeSecondOfDay` · `bedtimeBlockWindowStartSecondOfDay` · `bedtimeBlockWindowEndSecondOfDay` · `bedtimeBlockRegistrationSucceeded` · `remainingUnlocksToday` · `morningUnlockQuotaAnchorDay` · `bedtimeRemainingUnlocks` · `bedtimeUnlockQuotaAnchorDay` · `completedMornings` · `resolvedSubscriptionTier` · `trialStartedAt` · `lastSeenMorningAnchor` · `screenTimeNoticeRecordedAt` · `shieldOverrideRequestReason` · `shieldOverrideRequestedAt` · `familyActivitySelectionData` · `milestoneReachedMornings` · `milestoneCelebratedMornings` · `mascotColorVariant`

Die drei letzten kamen mit dem Meilenstein-Fahrplan (`Shared/MilestoneStore.swift:7-9`, geschrieben in die App-Group-Suite über `:11-13`) und fehlten hier bis 2026-09-05: die Datei entstand vor jenem Commit und wurde danach nicht nachgezogen. Diese Liste ist die Beweisgrundlage für §3s leeres `NSPrivacyCollectedDataTypes` — eine stale Inventur ist genau der Weg, auf dem ein künftiger gespeicherter Datentyp ungeprüft durchrutscht.

Dazu **`hasCompletedOnboarding`**, der als einziger Schlüssel **nicht** im App-Group-Suite liegt: er wird über `@AppStorage("hasCompletedOnboarding")` geschrieben (`Tuck/TuckApp.swift:6`, `OnboardingFlowView.swift:12`, `ContentView.swift:15`), und ohne `.defaultAppStorage(_:)` — das im gesamten Repo nirgends gesetzt ist — geht `@AppStorage` auf `UserDefaults.standard`. Ein `Bool`, nur in der App gelesen, von keiner Extension.

**Zwei nicht-skalare Einträge**, nicht einer (korrigiert 2026-09-05):

- `familyActivitySelectionData` — die JSON-kodierte `FamilyActivitySelection` (`Shared/FamilyActivitySelectionStore.swift:23-26`). Die Tokens darin sind vom System vergebene, opake Werte; die App liest sie nie aus und kann aus ihnen keinen App-Namen und keine Bundle-ID rekonstruieren.
- `milestoneCelebratedMornings` — ein `[Int]` (`Shared/MilestoneStore.swift:56`, geschrieben als `celebrated.sorted()`, gelesen `:59-60`). Kein Datentyp im Sinne des Manifests: es sind die Schwellenwerte, an denen eine Feier-Zeile schon einmal gezeigt wurde, also Ableitungen aus `completedMornings`, das ohnehin gelistet ist.

---

## 2. Tracking

```xml
<key>NSPrivacyTracking</key>
<false/>
<key>NSPrivacyTrackingDomains</key>
<array/>
```

Belegt durch §1: der einzige Netzwerkpfad ist StoreKits eigene Verbindung zu Apple für Käufe und Abo-Status — das ist kein Tracking im Sinne von Apples Definition (keine Zusammenführung mit Daten Dritter, keine geräteübergreifende Identifizierung durch diese App), und es existiert keine Tracking-Domain, die zu deklarieren wäre.

---

## 3. Erhobene Daten (`NSPrivacyCollectedDataTypes`)

```xml
<key>NSPrivacyCollectedDataTypes</key>
<array/>
```

**Begründung, weil das der am leichtesten falsch ausgefüllte Teil ist:** Apples Definition von „collect" ist *Übertragung vom Gerät weg*, nicht *Speicherung auf dem Gerät*. Daten, die die App ausschließlich lokal ablegt und nie sendet, sind nach dieser Definition nicht erhoben. Die Weckzeit, der Streak und das Kontingent liegen also zu Recht nicht in dieser Liste — obwohl sie zweifellos personenbezogen sind.

**Zwei Stellen, an denen das trotzdem gegengeprüft gehört:**

- **StoreKit.** Der Kauf läuft über Apple, nicht über die App. Die App bekommt eine `Transaction` und liest daraus ausschließlich `productID`, `revocationDate` und `expirationDate` (`Tuck/SubscriptionController.swift`, `refreshEntitlement`). Sie sendet nichts und speichert nichts über den Kauf hinaus außer dem aufgelösten Stufennamen (`resolvedSubscriptionTier`). Der Zahlungsvorgang selbst ist Apples Datenverarbeitung, nicht die des Entwicklers — er gehört in die Datenschutzerklärung (Entwurf, nicht Teil dieses Exports), nicht in das Manifest dieser App. **Das ist die Stelle, an der ich am wenigsten sicher bin** (siehe §6.2).
- **Das App-Privacy-Label in App Store Connect ist eine zweite, separate Angabe.** Manifest ≠ Nutrition Label. Beide müssen zueinander passen, aber das Label wird im Portal ausgefüllt, nicht in dieser Datei. Erwarteter Stand dort: **„Data Not Collected"**.

---

## 4. Required-Reason-APIs (`NSPrivacyAccessedAPITypes`)

Genau eine Kategorie ist betroffen: `NSPrivacyAccessedAPICategoryUserDefaults`.

```xml
<key>NSPrivacyAccessedAPITypes</key>
<array>
    <dict>
        <key>NSPrivacyAccessedAPIType</key>
        <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
        <key>NSPrivacyAccessedAPITypeReasons</key>
        <array>
            <string>1C8F.1</string>
            <string>CA92.1</string>
        </array>
    </dict>
</array>
```

**Warum zwei Gründe und nicht einer:**

- `1C8F.1` ist der Grund für Zugriff auf `UserDefaults` eines **App Groups**, dessen Mitglieder App und Extensions sind. Das ist der reguläre Pfad dieser App: **jeder** Store-Zugriff geht auf `UserDefaults(suiteName: TuckIdentifiers.appGroupSuiteName)`, in allen vier Bundles (§5 belegt pro Extension, welche Stores sie kompiliert). Die Zugriffszahl steht hier absichtlich nicht mehr — sie hatte sich zweimal geändert („zwölf", dann „16", real 17 am 2026-09-06), und eine Zahl in Prosa ist kein Anker; der Grund-Code braucht sie nicht.
- `CA92.1` ist der Grund für Zugriff auf `UserDefaults`, die **nur der App selbst** zugänglich sind. Dieser Pfad ist hier kein theoretischer: `hasCompletedOnboarding` liegt über `@AppStorage` dauerhaft in `UserDefaults.standard` (§1) — ein echter Schlüssel im privaten Suite, nicht nur ein Zweig, der im Fehlerfall greifen würde. Der Fallback kommt dazu: jede Store-Datei schreibt `UserDefaults(suiteName:) ?? .standard`, und schlägt das Öffnen des Suites fehl, landet der Schreibvorgang in den privaten Defaults des jeweiligen Prozesses — kommentiert in `Tuck/WakeAlarmStore.swift:20-24` und `TuckShield/ShieldConfigurationExtension.swift:29`. Der Grund trägt damit auf beiden Wegen.

Mehrere Gründe pro Kategorie sind zulässig — das Feld ist ein Array.

### Wo die Datei liegen muss

Vier Bundles greifen auf `UserDefaults` zu, nicht eins:

| Target | Greift zu über | Braucht eigenes Manifest? |
|---|---|---|
| `Tuck` (App) | alle Stores | **Ja**, unstrittig |
| `TuckMonitor` | `FamilyActivitySelectionStore`, `ScreenTimeNotice` | siehe §6.1 |
| `TuckShield` | `UnlockQuotaStore`, `SubscriptionTierStore`, `TrialStore`, `BedtimeStore` | siehe §6.1 |
| `TuckShieldAction` | `ShieldOverrideRequest` | siehe §6.1 |

Empfehlung: **in allen vier**. Ein überflüssiges Manifest kostet nichts, ein fehlendes ist ein Ablehnungsgrund. In `project.yml` gehört die Datei je Target unter `sources:` (bei `Tuck` deckt der Verzeichnis-Eintrag `- path: Tuck` sie automatisch ab, bei den drei Extensions ebenso über ihre Verzeichnis-Einträge). Danach `xcodegen generate`.

---

## 5. Was ausdrücklich **nicht** ins Manifest gehört

- **Family Controls / DeviceActivity / ManagedSettings.** Keine dieser drei APIs steht auf Apples Required-Reason-Liste. Sie sind entitlement-gegated, was ein anderer Mechanismus ist — der Antrag und die App-Review-Notes (Entwurf, nicht Teil dieses Exports) tragen diese Rechtfertigung, nicht das Manifest.
- **AlarmKit.** Ebenfalls keine Required-Reason-API. Die zugehörige Nutzerinformation ist der `NSAlarmKitUsageDescription`-String in `Tuck/Info.plist`, der bereits gesetzt und über `Tuck/InfoPlist.xcstrings` lokalisiert ist.
- **Die opaken Tokens.** Sie sind kein deklarierbarer Datentyp; die App kann sie nicht auflösen und überträgt sie nicht.

---

## 6. Offene Punkte — geraten wäre hier teurer als nachschlagen

1. **Brauchen First-Party-App-Extensions ein eigenes `PrivacyInfo.xcprivacy`?** Apples Beschreibung des Privacy-Reports adressiert ausdrücklich die App und *Third-Party-SDKs*; für mitgelieferte eigene Extensions habe ich keine eindeutige Aussage gefunden. §4 empfiehlt deshalb den sicheren Weg (alle vier), aber die Frage ist nicht beantwortet, sondern umgangen. **Nebenfolge, geprüft 2026-09-06 und bewusst in Kauf genommen:** in den drei Extensions ist `CA92.1` über-deklariert — `hasCompletedOnboarding` lebt nur im App-Target, und der Pfad zu `UserDefaults.standard` existiert dort allein als `?? .standard`-Fallback, der wegen `@autoclosure` im Normalbetrieb nie konstruiert wird. Ein zusätzlicher *gültiger* Grund ist die sichere Fehlrichtung (Apple prüft fehlende Gründe, nicht überzählige), und eine gemeinsame Datei für vier Bundles ist mehr wert als Präzision pro Target. Kein Befund, nur damit es später nicht für einen gehalten wird.
2. **StoreKit und die Kategorie „Purchases".** Ob ein reiner In-App-Kauf ohne eigenen Server im App-Privacy-Label als „Purchases / not linked" anzugeben ist oder gar nicht, ist eine Auslegungsfrage von Apples Label-Definition. Das Manifest ist davon nach meiner Lesart nicht betroffen (§3), das **Label** möglicherweise schon. Vor dem Ausfüllen des Labels prüfen.
3. ~~**Die exakten Reason-Codes.**~~ **Geprüft am 2026-09-06 gegen Apples live DocC-Dokument** (`developer.apple.com/tutorials/data/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype.json`), die `termList`-Paare strukturell geparst: `CA92.1` = „only accessible to the app itself", `1C8F.1` = „same App Group" — beide existieren, mit genau der Bedeutung, die §4 ihnen zuweist. **Falle für jede Wiederholung:** eine naive Textextraktion aus diesem JSON liefert die zwei Codes in *vertauschter* Reihenfolge und erzeugt einen falschen Alarm; strukturell parsen, nicht flach lesen. Vor einer späteren Einreichung mit derselben Methode erneut — billig, und ein veralteter Code wäre eine automatische Upload-Zurückweisung.
4. **Ab wann die Datei Pflicht ist.** Für Apps, die Required-Reason-APIs nutzen, verlangt Apple das Manifest seit dem Frühjahr 2024 beim Upload. Das Datum ist für dieses Projekt ohne Belang (es liegt in jedem Fall davor), die Pflicht selbst nicht.
5. ~~**Export-Compliance (`ITSAppUsesNonExemptEncryption`).**~~ **Erklärt am 2026-09-05** (Audit-Fund L32; Entscheidung). Der Wert ist **`false`**, und die Grundlage ist der Befund aus §1 dieses Dokuments: über alle fünf Targets **null Netz-APIs und null Krypto-APIs** (`URLSession`, `URLRequest`, `NWConnection`, `CFNetwork`, `WKWebView`, `CloudKit`, `CryptoKit`, `CommonCrypto`, `SecKey`, `import Network` — kein einziger Treffer). Der einzige ausgehende Verkehr ist StoreKits eigenes HTTPS zu Apple, also genau der Ausnahmefall, auf den die Frage zielt. Umgesetzt als `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption: NO` in `project.yml` am **App-Target allein**: die `INFOPLIST_KEY_*`-Familie wirkt laut Xcodes eigener Build-Setting-Spezifikation (`CoreBuildSystem.xcspec`) nur, „when `GENERATE_INFOPLIST_FILE` is enabled" — und das ist von den fünf Targets nur für die App und das Test-Bundle wahr; die drei Extensions liefern handgeschriebene `Info.plist`s, dort wäre der Schlüssel ein No-op. Am gebauten Produkt geprüft, nicht angenommen: `plutil -p Tuck.app/Info.plist` zeigt `"ITSAppUsesNonExemptEncryption" => false`, die drei `.appex` haben ihn erwartungsgemäß nicht. Damit entfällt das „Missing Compliance"-Banner, das sonst jeden Upload in App Store Connect anhält. **Was damit nicht beantwortet ist:** ob Apple die Erklärung je zurückweist, entscheidet Apple — dies ist die Erklärung, nicht ihre Bestätigung.

---

## 7. Umsetzung — die Datei existiert

**Angelegt am 2026-09-06 unter `Shared/PrivacyInfo.xcprivacy`.** Bis dahin stand hier „noch nicht angelegt"; das galt für den Entwurfsstand vom 2026-09-05 und gilt nicht mehr.

**Die Entscheidung „in allen vier Targets" ist eine Erklärung, nicht nur eine Empfehlung.** Getroffen am **2026-09-06**. §4 hatte alle vier nur *empfohlen*, und §6.1 hält bis heute fest, dass Apples Dokumentation für mitgelieferte eigene Extensions keine eindeutige Aussage macht — die Frage ist damit weiter offen, die Entscheidung darüber aber getroffen: der sichere Weg, weil ein überflüssiges Manifest nichts kostet und ein fehlendes ein Ablehnungsgrund ist. Was hier deklariert wird, deklariert der Projektinhaber; die Datei ist die Angabe des Projektinhabers gegenüber Apple.

**Eine Datei, vier Targets** — dieselbe Form, die `Shared/SharedCopy.xcstrings` schon trägt: in `project.yml` unter `sources:` jedes der vier Targets gelistet (`Tuck`, `TuckMonitor`, `TuckShield`, `TuckShieldAction`), das Test-Bundle bewusst nicht. Vier Kopien derselben Angabe wären genau die Drift, gegen die die Katalog-Regel schon einmal geschrieben wurde.

**Die Build-Phase ist nachgesehen, nicht angenommen.** XcodeGen 2.46 sortiert `.xcprivacy` von sich aus in die Resources-Phase; ein ausdrückliches `buildPhase: resources` war nicht nötig. Beleg in der generierten `Tuck.xcodeproj/project.pbxproj`: vier `PBXBuildFile`-Einträge auf **einer** `PBXFileReference`, jeder „`in Resources`", in den Resources-Phasen genau der vier Targets — und null Vorkommen in irgendeiner `PBXSourcesBuildPhase`. Eine Compile-Phase hätte die Datei nicht ins Bundle gelegt, sondern zu übersetzen versucht.

**Am gebauten Produkt bewiesen.** Clean-Build aller vier Targets (`-sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO`), danach jede gefundene Datei mit `plutil -p` gelesen: `Tuck.app/PrivacyInfo.xcprivacy` sowie `PrivacyInfo.xcprivacy` in der Wurzel jeder der drei `.appex` unter `PlugIns/` — vier Dateien, alle vier parsebar, alle vier mit den Werten aus §§2–4. Die Bundle-Wurzel ist unter iOS die Stelle, an der Apple liest; ein Manifest ein Verzeichnis tiefer wäre vorhanden und trotzdem unwirksam.

**Gepinnt.** `TuckTests/PrivacyManifestTests.swift` löst die Datei aus `Bundle.main` und aus den drei `.appex` unter `builtInPlugInsURL` auf — derselbe Weg, den `EnglishLocalizationTests` zum Shield nimmt, und der einzige, den es für zwei Extensions gibt, die der Simulator nie startet. Gelesen wird direkt von `bundleURL`, nicht über `url(forResource:)`: das durchsucht Unterverzeichnisse und würde ein falsch platziertes Manifest finden und für richtig halten. Geprüft wird pro Bundle, was §§2–4 festlegen; auf eine fehlende Datei läuft der Test rot, nicht stumm durch — gegengeprüft an einer Arbeitskopie mit aus einem Target entferntem Manifest.

**Was damit nicht erledigt ist:** §6.1 (die Frage selbst) und §6.2 bleiben offen, und das App-Privacy-Label in App Store Connect ist die zweite, separate Angabe (§3) — sie ist nicht gemacht.
