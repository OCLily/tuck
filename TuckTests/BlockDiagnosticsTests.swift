import Foundation
import Testing
@testable import Tuck

// The five-day observation is gated on these
// four numbers rather than on the eye, because the failure they measure is invisible by
// construction: DeviceActivity is documented to go silent on a share of devices without throwing,
// logging or failing anything. A counter that miscounts is worse than none — it would pass a gate
// that should have stopped the observation.
struct BlockDiagnosticsTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    private func date(day: Int = 1, hour: Int, minute: Int) -> Date {
        calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 9,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }

    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suite = "BlockDiagnosticsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        body(defaults)
    }

    @Test func everyCounterStartsAtZeroAndCountsUpwards() {
        withDefaults { defaults in
            for counter in BlockDiagnostics.Counter.allCases {
                #expect(BlockDiagnostics.count(of: counter, in: defaults) == 0)
                BlockDiagnostics.record(counter, in: defaults)
                BlockDiagnostics.record(counter, in: defaults)
                #expect(BlockDiagnostics.count(of: counter, in: defaults) == 2)
            }
        }
    }

    // Five events written from two processes into one suite: two counters sharing a key would read
    // as a working morning on a device that never shielded anything.
    @Test func theCountersDoNotShareAKey() {
        #expect(Set(BlockDiagnostics.Counter.allCases.map(\.rawValue)).count == BlockDiagnostics.Counter.allCases.count)
    }

    // MARK: - The audit for the callback that never came

    @Test func anOccurrenceWhoseIntervalNeverOpenedIsCountedAsMissing() {
        withDefaults { defaults in
            let anchor = date(hour: 7, minute: 0)

            #expect(BlockDiagnostics.auditMorningCallback(occurrence: anchor, now: date(hour: 7, minute: 30), in: defaults) == true)
            #expect(BlockDiagnostics.count(of: .morningCallbacksMissing, in: defaults) == 1)
        }
    }

    @Test func anOccurrenceTheIntervalDidOpenForIsNotCountedAsMissing() {
        withDefaults { defaults in
            let anchor = date(hour: 7, minute: 0)
            BlockDiagnostics.recordMorningIntervalStart(at: date(hour: 7, minute: 0), in: defaults)

            #expect(BlockDiagnostics.auditMorningCallback(occurrence: anchor, now: date(hour: 7, minute: 30), in: defaults) == false)
            #expect(BlockDiagnostics.count(of: .morningCallbacksMissing, in: defaults) == 0)
        }
    }

    // Yesterday's interval says nothing about today's occurrence — without the comparison a device
    // that worked once would look healthy forever.
    @Test func anIntervalFromAnEarlierOccurrenceDoesNotVouchForThisOne() {
        withDefaults { defaults in
            BlockDiagnostics.recordMorningIntervalStart(at: date(day: 1, hour: 7, minute: 0), in: defaults)

            #expect(BlockDiagnostics.auditMorningCallback(
                occurrence: date(day: 2, hour: 7, minute: 0),
                now: date(day: 2, hour: 7, minute: 30),
                in: defaults
            ) == true)
        }
    }

    // Five foreground entries on one silent morning are one platform failure, not five.
    @Test func oneSilentMorningIsCountedOnce() {
        withDefaults { defaults in
            let anchor = date(hour: 7, minute: 0)
            for minute in [30, 40, 50] {
                BlockDiagnostics.auditMorningCallback(occurrence: anchor, now: date(hour: 7, minute: minute), in: defaults)
            }

            #expect(BlockDiagnostics.count(of: .morningCallbacksMissing, in: defaults) == 1)
        }
    }

    // Opening the app in the same second the window starts is not evidence of anything yet.
    @Test func anIntervalThatHasHadNoTimeToArriveIsNotYetMissing() {
        withDefaults { defaults in
            let anchor = date(hour: 7, minute: 0)

            #expect(BlockDiagnostics.auditMorningCallback(occurrence: anchor, now: anchor, in: defaults) == false)
            #expect(BlockDiagnostics.count(of: .morningCallbacksMissing, in: defaults) == 0)

            // ...and the occurrence is not marked as audited either, or the grace period would
            // swallow the finding for good.
            let past = anchor.addingTimeInterval(BlockDiagnostics.callbackGraceSeconds)
            #expect(BlockDiagnostics.auditMorningCallback(occurrence: anchor, now: past, in: defaults) == true)
        }
    }

    @Test func withoutAnOccurrenceThereIsNothingToAudit() {
        withDefaults { defaults in
            #expect(BlockDiagnostics.auditMorningCallback(occurrence: nil, now: date(hour: 9, minute: 0), in: defaults) == false)
            #expect(BlockDiagnostics.count(of: .morningCallbacksMissing, in: defaults) == 0)
        }
    }

    // MARK: - The same audit for the evening

    @Test func anEveningWhoseIntervalNeverOpenedIsCountedAsMissing() {
        withDefaults { defaults in
            let anchor = date(hour: 22, minute: 0)

            #expect(BlockDiagnostics.auditBedtimeCallback(occurrence: anchor, now: date(hour: 22, minute: 30), in: defaults) == true)
            #expect(BlockDiagnostics.count(of: .bedtimeCallbacksMissing, in: defaults) == 1)
        }
    }

    @Test func anEveningIntervalFromAnEarlierOccurrenceDoesNotVouchForThisOne() {
        withDefaults { defaults in
            BlockDiagnostics.recordBedtimeIntervalStart(at: date(day: 1, hour: 22, minute: 0), in: defaults)

            #expect(BlockDiagnostics.auditBedtimeCallback(
                occurrence: date(day: 2, hour: 22, minute: 0),
                now: date(day: 2, hour: 22, minute: 30),
                in: defaults
            ) == true)
        }
    }

    @Test func oneSilentEveningIsCountedOnce() {
        withDefaults { defaults in
            let anchor = date(hour: 22, minute: 0)
            for minute in [30, 40, 50] {
                BlockDiagnostics.auditBedtimeCallback(occurrence: anchor, now: date(hour: 22, minute: minute), in: defaults)
            }

            #expect(BlockDiagnostics.count(of: .bedtimeCallbacksMissing, in: defaults) == 1)
        }
    }

    @Test func anEveningIntervalThatHasHadNoTimeToArriveIsNotYetMissing() {
        withDefaults { defaults in
            let anchor = date(hour: 22, minute: 0)

            #expect(BlockDiagnostics.auditBedtimeCallback(occurrence: anchor, now: anchor, in: defaults) == false)
            #expect(BlockDiagnostics.count(of: .bedtimeCallbacksMissing, in: defaults) == 0)

            let past = anchor.addingTimeInterval(BlockDiagnostics.callbackGraceSeconds)
            #expect(BlockDiagnostics.auditBedtimeCallback(occurrence: anchor, now: past, in: defaults) == true)
        }
    }

    @Test func withoutAnEveningOccurrenceThereIsNothingToAudit() {
        withDefaults { defaults in
            #expect(BlockDiagnostics.auditBedtimeCallback(occurrence: nil, now: date(hour: 9, minute: 0), in: defaults) == false)
            #expect(BlockDiagnostics.count(of: .bedtimeCallbacksMissing, in: defaults) == 0)
        }
    }
    // The whole point of the per-window split: a silent morning and a silent evening are two different findings,

    // and with one shared counter the five-day observation could not tell which half failed.
    @Test func theTwoWindowsAuditIndependently() {
        withDefaults { defaults in
            BlockDiagnostics.auditMorningCallback(
                occurrence: date(hour: 7, minute: 0),
                now: date(hour: 7, minute: 30),
                in: defaults
            )

            #expect(BlockDiagnostics.count(of: .morningCallbacksMissing, in: defaults) == 1)
            #expect(BlockDiagnostics.count(of: .bedtimeCallbacksMissing, in: defaults) == 0)

            BlockDiagnostics.auditBedtimeCallback(
                occurrence: date(hour: 22, minute: 0),
                now: date(hour: 22, minute: 30),
                in: defaults
            )

            #expect(BlockDiagnostics.count(of: .morningCallbacksMissing, in: defaults) == 1)
            #expect(BlockDiagnostics.count(of: .bedtimeCallbacksMissing, in: defaults) == 1)
        }
    }

    // One shared occurrence mark and the two audits would cancel each other out: whichever ran
    // first would leave the other's occurrence looking already audited.
    @Test func theTwoAuditsDoNotShareTheirOccurrenceMark() {
        withDefaults { defaults in
            let anchor = date(hour: 22, minute: 0)
            BlockDiagnostics.auditMorningCallback(occurrence: anchor, now: date(hour: 22, minute: 30), in: defaults)

            #expect(BlockDiagnostics.auditBedtimeCallback(occurrence: anchor, now: date(hour: 22, minute: 30), in: defaults) == true)
            #expect(BlockDiagnostics.count(of: .bedtimeCallbacksMissing, in: defaults) == 1)
        }
    }

    // An evening interval may not vouch for a morning occurrence or the other way round: they are
    // two keys, and reading one for the other is the same mix-up as one shared counter.
    @Test func theTwoWindowsKeepSeparateIntervalStarts() {
        withDefaults { defaults in
            BlockDiagnostics.recordBedtimeIntervalStart(at: date(hour: 22, minute: 0), in: defaults)

            #expect(BlockDiagnostics.lastMorningIntervalStart(in: defaults) == nil)
            #expect(BlockDiagnostics.lastBedtimeIntervalStart(in: defaults) == date(hour: 22, minute: 0))
        }
    }

    // MARK: - The line on the settings screen

    // Replaces theSummaryCarriesAllFiveNumbersInTheOrderOfTheMorning, which read the one mixed
    // summary both windows used to share.
    @Test func theMorningSummaryCarriesItsFiveNumbersInTheOrderOfTheMorning() {
        withDefaults { defaults in
            BlockDiagnostics.record(.morningWindowsRegistered, in: defaults)
            for _ in 0..<2 { BlockDiagnostics.record(.morningIntervalsStarted, in: defaults) }
            for _ in 0..<3 { BlockDiagnostics.record(.morningShieldsApplied, in: defaults) }
            for _ in 0..<4 { BlockDiagnostics.record(.morningCallbacksMissing, in: defaults) }
            for _ in 0..<5 { BlockDiagnostics.record(.weekdaysSkipped, in: defaults) }
            // The evening's own counters may not reach the morning's line.
            for _ in 0..<7 { BlockDiagnostics.record(.bedtimeShieldsApplied, in: defaults) }

            #expect(BlockDiagnostics.morningSummary(in: defaults) == "1 · 2 · 3 · 4 · 5")
        }
    }

    @Test func theBedtimeSummaryCarriesItsOwnNumbers() {
        withDefaults { defaults in
            BlockDiagnostics.record(.bedtimeWindowsRegistered, in: defaults)
            for _ in 0..<2 { BlockDiagnostics.record(.bedtimeIntervalsStarted, in: defaults) }
            for _ in 0..<3 { BlockDiagnostics.record(.bedtimeShieldsApplied, in: defaults) }
            for _ in 0..<4 { BlockDiagnostics.record(.bedtimeCallbacksMissing, in: defaults) }
            for _ in 0..<9 { BlockDiagnostics.record(.morningIntervalsStarted, in: defaults) }

            #expect(BlockDiagnostics.bedtimeSummary(in: defaults) == "1 · 2 · 3 · 4")
        }
    }

    // Replaces afreshInstallSummaryIsAllZeroesRatherThanEmpty, for both lines.
    @Test func aFreshInstallReadsAllZeroesOnBothLines() {
        withDefaults { defaults in
            #expect(BlockDiagnostics.morningSummary(in: defaults) == "0 · 0 · 0 · 0 · 0")
            #expect(BlockDiagnostics.bedtimeSummary(in: defaults) == "0 · 0 · 0 · 0")
        }
    }

    // MARK: - Wiring

    // The registration count has to sit after the throw: DeviceActivityCenter throws .unauthorized
    // on every Simulator run and until Family Controls is granted on device, and counting attempts
    // would report a fleet of armed windows that were all refused.
    @Test func onlyAcceptedRegistrationsAreCounted() throws {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Tuck/BlockWindowMonitor.swift")
        let lines = try String(contentsOf: source, encoding: .utf8).components(separatedBy: "\n")

        let start = try #require(lines.firstIndex { $0.contains("try DeviceActivityCenter().startMonitoring(") })
        let morning = try #require(lines.firstIndex { $0.contains("BlockDiagnostics.record(.morningWindowsRegistered)") })
        let bedtime = try #require(lines.firstIndex { $0.contains("BlockDiagnostics.record(.bedtimeWindowsRegistered)") })

        #expect(morning > start)
        #expect(bedtime > start)
    }

    // The one finding the split exists for: a bedtime that was never registered, whose interval
    // never opened or whose shield was never written, must not be able to hide behind the morning's
    // number. Every record in the two files that write them names the window it belongs to, and
    // neither branch of the extension's switch writes the other window's counter.
    @Test func noCounterIsWrittenForBothWindows() throws {
        for path in ["TuckMonitor/DeviceActivityMonitorExtension.swift", "Tuck/BlockWindowMonitor.swift"] {
            let source = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent(path)
            let lines = try String(contentsOf: source, encoding: .utf8).components(separatedBy: "\n")

            let records = lines.filter { $0.contains("BlockDiagnostics.record(") && !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            #expect(!records.isEmpty)
            for record in records {
                #expect(record.contains(".morning") || record.contains(".bedtime") || record.contains(".weekdaysSkipped"),
                        "\(record) does not say which window it belongs to")
            }
            // Branch by branch, not line by line: in the extension the case label and the records
            // under it are separate lines, and a morning counter written in the bedtime branch is
            // exactly the mix-up this test is for.
            for (label, forbidden) in [("case .morningBlock:", ".bedtime"), ("case .bedtimeBlock:", ".morning")] {
                for start in lines.indices where lines[start].contains(label) {
                    let end = lines[(start + 1)...].firstIndex { $0.contains("case .") || $0.contains("default:") }
                        ?? lines.endIndex
                    for line in lines[start..<end] where line.contains("BlockDiagnostics.record(") {
                        #expect(!line.contains(forbidden), "\(line) writes the other window's counter")
                    }
                }
            }
        }
    }

    // The interval count belongs before the guards, the shield count after the write: swapping
    // either turns the pair into one number that answers neither question.
    // Replaces theExtensionCountsTheCallbackItselfAndTheShieldSeparately, which asked the same two
    // questions of the one bucket both windows shared.
    @Test func theExtensionCountsEachWindowInItsOwnBucket() throws {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("TuckMonitor/DeviceActivityMonitorExtension.swift")
        let lines = try String(contentsOf: source, encoding: .utf8).components(separatedBy: "\n")

        let guardLine = try #require(lines.firstIndex { $0.contains("guard let storeName = Self.storeName(for: activity)") })
        let apply = try #require(lines.firstIndex { $0.contains("ShieldApplication.apply(selection, to: storeName)") })

        for counter in [".morningIntervalsStarted", ".bedtimeIntervalsStarted"] {
            let started = try #require(lines.firstIndex { $0.contains("BlockDiagnostics.record(\(counter))") })
            #expect(started < guardLine)
        }
        for counter in [".morningShieldsApplied", ".bedtimeShieldsApplied"] {
            let shielded = try #require(lines.firstIndex { $0.contains("BlockDiagnostics.record(\(counter))") })
            #expect(shielded > apply)
        }
        #expect(lines.contains { $0.contains("BlockDiagnostics.recordMorningIntervalStart(at: .now)") })
    }

    // The skipped-weekday count belongs inside the weekday guard's else and nowhere else: counted
    // one line higher it would count every interval, one line lower it would never run. Without it
    // a deliberately skipped Saturday and a device deviceactivityd has gone silent on produce the
    // same reading — an interval with no shield behind it.
    @Test func aDeliberatelySkippedWeekdayIsCountedApartFromAPlatformFailure() throws {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("TuckMonitor/DeviceActivityMonitorExtension.swift")
        let lines = try String(contentsOf: source, encoding: .utf8).components(separatedBy: "\n")

        let guardLine = try #require(lines.firstIndex { $0.contains("WakeAlarmWeekdayStore.morningBlockApplies(on: .now)") })
        let skipped = try #require(lines.firstIndex { $0.contains("BlockDiagnostics.record(.weekdaysSkipped)") })
        let apply = try #require(lines.firstIndex { $0.contains("ShieldApplication.apply(selection, to: storeName)") })

        #expect(skipped > guardLine)
        #expect(skipped < apply)
        #expect(lines.filter { $0.contains(".weekdaysSkipped") }.count == 1)
    }

    // Two lines of different lengths under one footer is an instrument with the wrong legend: the
    // numbers are only readable — in a support mail or by VoiceOver — if each line says what each
    // of its numbers means. The visible row stays the compact sequence; the legend rides on the
    // accessibilityLabel, and it is copy, so it has to be in the catalog with an English value.
    @Test func everyDiagnosticRowCarriesItsLegendAsAnAccessibilityLabel() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let lines = try String(contentsOf: root.appendingPathComponent("Tuck/SettingsView.swift"), encoding: .utf8)
            .components(separatedBy: "\n")

        for row in ["Diagnose Morgen", "Diagnose Abend"] {
            let index = try #require(lines.firstIndex { $0.contains("row(title: \"\(row)\"") })
            #expect(lines[index + 1].contains(".accessibilityLabel("))
        }

        let catalog = try String(contentsOf: root.appendingPathComponent("Tuck/Localizable.xcstrings"), encoding: .utf8)
        for key in [
            "Diagnose Morgen: %lld Fenster eingetragen, %lld Intervalle gestartet, %lld Shields geschrieben, %lld ohne Rückmeldung, %lld Tage übersprungen",
            "Diagnose Abend: %lld Fenster eingetragen, %lld Intervalle gestartet, %lld Shields geschrieben, %lld ohne Rückmeldung"
        ] {
            #expect(catalog.contains(key), "\(key) is not in the catalog")
        }
    }

    // The evening's interval start is recorded in the bedtime branch and above every guard, for the
    // same reason the morning's is: it records that iOS spoke, not that a shield went up.
    @Test func theExtensionRecordsTheEveningIntervalToo() throws {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("TuckMonitor/DeviceActivityMonitorExtension.swift")
        let lines = try String(contentsOf: source, encoding: .utf8).components(separatedBy: "\n")

        let branch = try #require(lines.firstIndex { $0.contains("case .bedtimeBlock:") })
        let record = try #require(lines.firstIndex { $0.contains("BlockDiagnostics.recordBedtimeIntervalStart(at: .now)") })
        let guardLine = try #require(lines.firstIndex { $0.contains("guard let storeName = Self.storeName(for: activity)") })

        #expect(record > branch)
        #expect(record < guardLine)
    }

    // The audit runs on the same two entry points the morning count does — there is no other
    // process that could ever notice a callback that did not happen.
    @Test func theMorningScreenAuditsOnBothOfItsEntryPoints() throws {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Tuck/GutenMorgenView.swift")
        let lines = try String(contentsOf: source, encoding: .utf8).components(separatedBy: "\n")

        let callSites = lines.indices.filter { lines[$0].contains("auditThisMorningsCallback()") }
        #expect(callSites.count == 3)

        let coldLaunch = try #require(lines.firstIndex { $0.contains(".task {") })
        let foregrounding = try #require(lines.firstIndex { $0.contains(".onChange(of: scenePhase)") })
        #expect(callSites.contains { $0 > coldLaunch && $0 < foregrounding })
        #expect(callSites.contains { $0 > foregrounding })
    }

    // Both windows on both entry points, or the evening's number stays at zero on a device whose
    // bedtime window never opened — which reads exactly like a bedtime that worked.
    @Test func theMorningScreenAuditsBothWindowsOnBothEntryPoints() throws {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Tuck/GutenMorgenView.swift")
        let lines = try String(contentsOf: source, encoding: .utf8).components(separatedBy: "\n")

        let coldLaunch = try #require(lines.firstIndex { $0.contains(".task {") })
        let foregrounding = try #require(lines.firstIndex { $0.contains(".onChange(of: scenePhase)") })

        for audit in ["auditThisMorningsCallback()", "auditThisEveningsCallback()"] {
            // Three, not two: the declaration line counts along.
            let callSites = lines.indices.filter { lines[$0].contains(audit) }
            #expect(callSites.count == 3, "\(audit) is not on both entry points")
            #expect(callSites.contains { $0 > coldLaunch && $0 < foregrounding })
            #expect(callSites.contains { $0 > foregrounding })
        }
    }
}
