import Foundation
import Testing
@testable import Tuck

// Three claims, and only the first of them can
// be checked end to end here:
//
// (a) the selection reaches AlarmKit — pinned as the pure mapping plus the wiring that carries it
//     into the one `.weekly(...)` call site. AlarmManager never authorizes in the Simulator, so no
//     test in this project can observe a scheduled alarm at all.
// (b) an unselected weekday builds no shield — pinned as the pure decision plus the structural
//     claim that the guard sits ahead of ShieldApplication.apply in intervalDidStart. The monitor
//     extension is a system process the Simulator never launches and is not compiled into this
//     bundle; the guard's position in the source is the strongest available evidence.
// (c) a selected weekday behaves exactly as before — same two halves, other direction, plus the
//     absent-store default that keeps every existing install on all seven days.
struct WakeAlarmWeekdayTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    // Throwaway suite per test, so nothing here touches the App-Group container the app and the
    // monitor extension actually use.
    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suite = "WakeAlarmWeekdayTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        body(defaults)
    }

    // 2026-09-07 is a Monday, so day + n lands on Monday + n.
    private func monday(plusDays days: Int = 0, hour: Int = 7, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 9,
            day: 7 + days,
            hour: hour,
            minute: minute
        ))!
    }

    private func source(_ relativePath: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    // The whole point of the default: an install from before this setting existed has no key and
    // rang on all seven days. Anything else would take mornings away from people who were never
    // asked.
    @Test func anEmptyStoreIsEveryDay() {
        withDefaults { defaults in
            #expect(WakeAlarmWeekdayStore.selected(in: defaults) == WakeAlarmWeekdayStore.everyDay)
            #expect(WakeAlarmWeekdayStore.selected(in: defaults).count == 7)
        }
    }

    @Test func aStoredSubsetSurvives() {
        withDefaults { defaults in
            let workdays: Set<WakeAlarmWeekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
            WakeAlarmWeekdayStore.store(workdays, in: defaults)
            #expect(WakeAlarmWeekdayStore.selected(in: defaults) == workdays)
        }
    }

    // An empty selection would be an alarm that never rings and a window that never applies, under
    // a screen that still reports a scheduled alarm. It is refused at the store rather than only in
    // the view, because the view is not the only thing that could ever call this.
    @Test func anEmptySelectionIsRefusedRatherThanStored() {
        withDefaults { defaults in
            WakeAlarmWeekdayStore.store([.monday], in: defaults)
            WakeAlarmWeekdayStore.store([], in: defaults)

            #expect(WakeAlarmWeekdayStore.selected(in: defaults) == [.monday])
        }
    }

    // A value this build does not know is not evidence of any choice. An array of nothing but
    // unknown numbers falls back to all seven, the same as an absent key — never to a narrower week
    // than anyone picked.
    @Test func unreadableStoredNumbersFallBackToEveryDay() {
        withDefaults { defaults in
            defaults.set([0, 8, 99], forKey: "wakeAlarmWeekdays")
            #expect(WakeAlarmWeekdayStore.selected(in: defaults) == WakeAlarmWeekdayStore.everyDay)
        }
    }

    // (a) The mapping that goes into `.weekly(...)`: Calendar's numbering on this side,
    // Locale.Weekday's names on the other, and the order is the array's, not the set's.
    @Test func theSelectionMapsOntoAlarmKitsWeekdaysInAStableOrder() {
        let workdays: Set<WakeAlarmWeekday> = [.friday, .monday, .wednesday]
        #expect(workdays.localeWeekdays == [.monday, .wednesday, .friday])
        #expect(WakeAlarmWeekday.monday.rawValue == 2)
        #expect(WakeAlarmWeekday(rawValue: 1) == .sunday)
    }

    // (a), the wiring half: the mapping above is worth nothing if the scheduler still hands AlarmKit
    // a hard-coded week. The one `.weekly(` call site has to carry the value that came in, and the
    // old "every weekday" constant may not exist anywhere to fall back to.
    @Test func theOneWeeklyCallSiteCarriesTheSelectionRatherThanAConstant() throws {
        let scheduler = try source("Tuck/WakeAlarmScheduler.swift")

        #expect(scheduler.contains("repeats: .weekly(weekdays)"))
        #expect(!scheduler.contains("everyWeekday"))
        #expect(scheduler.contains("weekdays: days.localeWeekdays"))
        // The selection is written only after AlarmKit accepted the alarm: a store written on the
        // denied path would gate the shield on days the still-live previous alarm does not ring on.
        let scheduled = try #require(scheduler.range(of: "AlarmKitBridge.scheduleWakeAlarm("))
        let stored = try #require(scheduler.range(of: "WakeAlarmWeekdayStore.store(days)"))
        #expect(stored.lowerBound > scheduled.upperBound)
    }

    // The stored fire date is a fact about when the alarm rings next, and it anchors the block
    // window. On a Monday-only selection, "tomorrow" is a week away.
    @Test func theNextFireDateSkipsWeekdaysNobodyChose() throws {
        let fireDate = try #require(WakeAlarmDate.nextFireDate(
            forWakeTime: monday(hour: 7, minute: 0),
            after: monday(hour: 8, minute: 0),
            weekdays: [.monday],
            calendar: calendar
        ))

        #expect(fireDate == monday(plusDays: 7, hour: 7, minute: 0))
    }

    // (c) on the same path: with every day selected the answer is the one the daily search always
    // gave, tomorrow morning.
    @Test func theNextFireDateIsUnchangedWhenEveryDayIsChosen() throws {
        let fireDate = try #require(WakeAlarmDate.nextFireDate(
            forWakeTime: monday(hour: 7, minute: 0),
            after: monday(hour: 8, minute: 0),
            weekdays: WakeAlarmWeekdayStore.everyDay,
            calendar: calendar
        ))

        #expect(fireDate == monday(plusDays: 1, hour: 7, minute: 0))
    }

    // (b) The decision the monitor extension takes. DeviceActivitySchedule has no weekday
    // parameter, so intervalDidStart really does fire on a Saturday that nobody selected — this is
    // the only thing standing between that callback and a shield.
    @Test func anUnselectedWeekdayIsNotAMorningTheShieldBelongsTo() {
        withDefaults { defaults in
            WakeAlarmWeekdayStore.store([.monday, .tuesday, .wednesday, .thursday, .friday], in: defaults)

            #expect(!WakeAlarmWeekdayStore.morningBlockApplies(
                on: monday(plusDays: 5), calendar: calendar, in: defaults
            ))
            #expect(!WakeAlarmWeekdayStore.morningBlockApplies(
                on: monday(plusDays: 6), calendar: calendar, in: defaults
            ))
        }
    }

    // (c) Every selected day, and every day at all when nothing was ever stored, answers the way it
    // always did.
    @Test func everySelectedWeekdayStillCarriesItsMorning() {
        withDefaults { defaults in
            WakeAlarmWeekdayStore.store([.monday, .tuesday, .wednesday, .thursday, .friday], in: defaults)
            for day in 0..<5 {
                #expect(WakeAlarmWeekdayStore.morningBlockApplies(
                    on: monday(plusDays: day), calendar: calendar, in: defaults
                ))
            }
        }

        withDefaults { defaults in
            for day in 0..<7 {
                #expect(WakeAlarmWeekdayStore.morningBlockApplies(
                    on: monday(plusDays: day), calendar: calendar, in: defaults
                ))
            }
        }
    }

    // The gate reads the day the interval opens on, which for a window that wraps past midnight is
    // still the day the alarm rang — 23:50 on a Monday belongs to Monday, not to the Tuesday its
    // window ends on.
    @Test func aWindowWrappingPastMidnightIsJudgedByTheDayItStartsOn() {
        withDefaults { defaults in
            WakeAlarmWeekdayStore.store([.monday], in: defaults)

            #expect(WakeAlarmWeekdayStore.morningBlockApplies(
                on: monday(hour: 23, minute: 50), calendar: calendar, in: defaults
            ))
            #expect(!WakeAlarmWeekdayStore.morningBlockApplies(
                on: monday(plusDays: 1, hour: 0, minute: 20), calendar: calendar, in: defaults
            ))
        }
    }

    // (b), the wiring half, in the shape the bug would have: a weekday guard that sits after the
    // shield write gates nothing at all. The two diagnostic counters stay ahead of it on purpose —
    // they count that iOS spoke, which is what the five-day observation asks.
    @Test func theWeekdayGuardStandsAheadOfTheShieldWrite() throws {
        let extensionSource = try source("TuckMonitor/DeviceActivityMonitorExtension.swift")
        let lines = extensionSource.components(separatedBy: "\n")
        let start = try #require(lines.firstIndex { $0.contains("override func intervalDidStart(") })
        let end = try #require(lines[start...].dropFirst().firstIndex { $0 == "    }" })
        let body = Array(lines[start...end])

        let guardLine = try #require(body.firstIndex { $0.contains("WakeAlarmWeekdayStore.morningBlockApplies(") })
        let apply = try #require(body.firstIndex { $0.contains("ShieldApplication.apply(") })
        let intervalsStarted = try #require(body.firstIndex { $0.contains(".morningIntervalsStarted") })

        #expect(guardLine < apply)
        #expect(intervalsStarted < guardLine)
    }

    // The claim above is only half of it, and the half that misses the expensive failure: a guard
    // ahead of the shield write still has to say what happens to a shield that is already up. The
    // morning window's intervalDidEnd is documented to go missing, so a Friday shield can still be
    // standing when Saturday's intervalDidStart arrives — and a bare `return` there leaves it up for
    // the whole of Saturday's window. "A missed block costs one window, a stranded shield blocks
    // forever" (Tuck/BlockWindowMonitor.swift).
    //
    // Deliberately about the whole method rather than one named guard: every exit taken after the
    // store name is known is an exit that could be leaving a shield behind, whichever guard added
    // it and whenever it was added. The two exits before the store name is known are exempt — an
    // activity this build does not own has no store to clear.
    @Test func everyGuardExitAfterTheStoreIsKnownClearsTheShield() throws {
        let body = try intervalDidStartBody()
        let storeName = try #require(body.firstIndex { $0.contains("let storeName = Self.storeName(") })

        // Code only, and both shapes an exit comes in: `return` on its own line under a guard's
        // else, and the one-line `else { return }`. Reading the trimmed prefix alone would let the
        // second shape through unseen, which is precisely the shape the bug had.
        let exits = body.indices.filter { index in
            guard index > storeName else { return false }
            let code = body[index].components(separatedBy: "//")[0]
            return code.contains("return")
        }
        #expect(!exits.isEmpty)

        for exit in exits {
            let clearedHere = body[max(storeName, exit - 2)...exit]
                .contains { $0.contains("ShieldRelease.clear(storeName)") }
            #expect(clearedHere, "bare return at line \(exit - storeName) after the store name is known")
        }
    }

    // The ordering half in its own right: the weekday guard has to sit BELOW the store-name lookup, or it
    // cannot clear anything even if it wanted to.
    @Test func theWeekdayGuardKnowsTheStoreItHasToClear() throws {
        let body = try intervalDidStartBody()
        let storeName = try #require(body.firstIndex { $0.contains("let storeName = Self.storeName(") })
        let weekday = try #require(body.firstIndex { $0.contains("WakeAlarmWeekdayStore.morningBlockApplies(") })
        let apply = try #require(body.firstIndex { $0.contains("ShieldApplication.apply(") })

        #expect(storeName < weekday)
        #expect(weekday < apply)
    }

    // The morning screen is the one the user actually reads on the morning itself, and its line
    // was left claiming "Sperrfenster bis 07:30" on a day the monitor extension skips. The line has
    // to deny the window and say which days do carry one — "heute nicht" alone would read like
    // something broke.
    @MainActor
    @Test func theMorningScreenDeniesTheWindowOnADayItDoesNotBlock() {
        let line = GutenMorgenView.dayOffLine([.monday, .tuesday, .wednesday, .thursday, .friday])

        #expect(!line.contains("bis"))
        let symbols = Calendar.current.shortWeekdaySymbols
        #expect(line.contains(symbols[WakeAlarmWeekday.monday.rawValue - 1]))
        #expect(!line.contains(symbols[WakeAlarmWeekday.saturday.rawValue - 1]))
        #expect(line != StatusCopy.windowPending("bis 07:30"))
        #expect(line != StatusCopy.windowWithoutApps("bis 07:30"))
    }

    // ...and it has to be asked before the two claims it outranks. The schedule really is registered
    // on a skipped Saturday and the picker really is filled: both branches below would vouch for a
    // window that is not coming. Only the App-Group check stays ahead of it — without the shared
    // container the stored selection this reads is not the one the extension sees.
    @Test func theMorningScreensLineAsksTheWeekdayBeforeItClaimsAWindow() throws {
        let view = try source("Tuck/GutenMorgenView.swift")
        let lines = view.components(separatedBy: "\n")
        let start = try #require(lines.firstIndex { $0.contains("private func blockWindowLine(") })
        let end = try #require(lines[start...].dropFirst().firstIndex { $0 == "    }" })
        let body = Array(lines[start...end])

        let appGroup = try #require(body.firstIndex { $0.contains("TuckIdentifiers.appGroupIsProvisioned") })
        let weekday = try #require(body.firstIndex { $0.contains("WakeAlarmWeekdayStore.morningBlockApplies(") })
        let registration = try #require(body.firstIndex { $0.contains("blockRegistrationConfirmed") })
        let apps = try #require(body.firstIndex { $0.contains("selectedActivityCount") })

        #expect(appGroup < weekday)
        #expect(weekday < registration)
        #expect(weekday < apps)
    }

    private func intervalDidStartBody() throws -> [String] {
        let extensionSource = try source("TuckMonitor/DeviceActivityMonitorExtension.swift")
        let lines = extensionSource.components(separatedBy: "\n")
        let start = try #require(lines.firstIndex { $0.contains("override func intervalDidStart(") })
        let end = try #require(lines[start...].dropFirst().firstIndex { $0 == "    }" })
        return Array(lines[start...end])
    }

    // The screen-time notice speaks about the block window, so it may not be written for a morning
    // no shield stood on.
    @Test func theScreenTimeNoticeIsGatedByTheSameWeekdayCheck() throws {
        let extensionSource = try source("TuckMonitor/DeviceActivityMonitorExtension.swift")
        let lines = extensionSource.components(separatedBy: "\n")
        let start = try #require(lines.firstIndex { $0.contains("override func eventDidReachThreshold(") })
        let end = try #require(lines[start...].dropFirst().firstIndex { $0 == "    }" })
        let body = Array(lines[start...end])

        let guardLine = try #require(body.firstIndex { $0.contains("WakeAlarmWeekdayStore.morningBlockApplies(") })
        let record = try #require(body.firstIndex { $0.contains("ScreenTimeNotice.record()") })
        #expect(guardLine < record)
    }

    // The sentence may say "every morning" only when it is one. A subset named as "jeden Morgen"
    // claims six mornings the alarm will not ring on — the silent discrepancy in its purest form.
    @MainActor
    @Test func theStatusLineSaysEveryMorningOnlyWhenItIsTrue() {
        #expect(WakeAlarmSetupView.daysPhrase(WakeAlarmWeekdayStore.everyDay) == "jeden Morgen")

        let subset = WakeAlarmSetupView.daysPhrase([.monday, .wednesday])
        #expect(subset != "jeden Morgen")
        let symbols = Calendar.current.shortWeekdaySymbols
        #expect(subset.contains(symbols[WakeAlarmWeekday.monday.rawValue - 1]))
        #expect(subset.contains(symbols[WakeAlarmWeekday.wednesday.rawValue - 1]))
        #expect(!subset.contains(symbols[WakeAlarmWeekday.friday.rawValue - 1]))
    }
}
