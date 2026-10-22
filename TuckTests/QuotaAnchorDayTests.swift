import Testing
import Foundation
@testable import Tuck

struct QuotaAnchorDayTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    private func date(year: Int = 2026, month: Int = 9, day: Int, hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }

    @Test func midnightRolloverGivesEveryInstantOfADayTheSameAnchor() {
        let expected = 2026_09_01
        #expect(unlockQuotaAnchorDay(now: date(day: 1, hour: 0), rolloverHour: 0, calendar: calendar) == expected)
        #expect(unlockQuotaAnchorDay(now: date(day: 1, hour: 13), rolloverHour: 0, calendar: calendar) == expected)
        #expect(unlockQuotaAnchorDay(now: date(day: 1, hour: 23, minute: 59), rolloverHour: 0, calendar: calendar) == expected)
        #expect(unlockQuotaAnchorDay(now: date(day: 2, hour: 0), rolloverHour: 0, calendar: calendar) == 2026_09_02)
    }

    // The evening's night belongs to the evening it started in: everything before 06:00 still counts
    // to the previous calendar day, and the anchor changes exactly once, at the rollover hour.
    @Test func aSixOClockRolloverKeepsTheNightWithTheEveningItStartedIn() {
        #expect(unlockQuotaAnchorDay(now: date(day: 1, hour: 23, minute: 55), rolloverHour: 6, calendar: calendar) == 2026_09_01)
        #expect(unlockQuotaAnchorDay(now: date(day: 2, hour: 0, minute: 10), rolloverHour: 6, calendar: calendar) == 2026_09_01)
        #expect(unlockQuotaAnchorDay(now: date(day: 2, hour: 5, minute: 59), rolloverHour: 6, calendar: calendar) == 2026_09_01)
        #expect(unlockQuotaAnchorDay(now: date(day: 2, hour: 6), rolloverHour: 6, calendar: calendar) == 2026_09_02)
    }

    // Month and year borders have to survive the packed integer, in both rollover shapes.
    @Test func theAnchorCrossesMonthAndYearBordersBackwards() {
        #expect(unlockQuotaAnchorDay(now: date(month: 10, day: 1, hour: 2), rolloverHour: 6, calendar: calendar) == 2026_09_30)
        #expect(unlockQuotaAnchorDay(now: date(year: 2027, month: 1, day: 1, hour: 2), rolloverHour: 6, calendar: calendar) == 2026_12_31)
    }

    // Both DST transitions in Europe/Berlin: the day the clock loses an hour (2027-03-28) and the day
    // it gains one (2026-10-25). Subtracting a calendar day either side of the jump must still land
    // on the previous calendar day, not two days back and not on the same one.
    @Test func theAnchorSurvivesBothDaylightSavingTransitions() {
        #expect(unlockQuotaAnchorDay(now: date(month: 10, day: 25, hour: 2), rolloverHour: 6, calendar: calendar) == 2026_10_24)
        #expect(unlockQuotaAnchorDay(now: date(month: 10, day: 25, hour: 7), rolloverHour: 6, calendar: calendar) == 2026_10_25)
        #expect(unlockQuotaAnchorDay(now: date(year: 2027, month: 3, day: 28, hour: 4), rolloverHour: 6, calendar: calendar) == 2027_03_27)
        #expect(unlockQuotaAnchorDay(now: date(year: 2027, month: 3, day: 28, hour: 7), rolloverHour: 6, calendar: calendar) == 2027_03_28)
    }

    // The store is a caller of this function, not a second implementation of it: a re-inlined copy
    // inside UnlockQuotaStore would drift from the file that carries the rule.
    @Test func bothQuotasReadTheirAnchorFromThisFunction() {
        for hour in 0..<24 {
            let now = date(day: 3, hour: hour)
            #expect(UnlockQuotaStore.morning.quotaAnchorDay(now: now, calendar: calendar)
                == unlockQuotaAnchorDay(now: now, rolloverHour: UnlockQuotaStore.morning.dayRolloverHour, calendar: calendar))
            #expect(UnlockQuotaStore.bedtime.quotaAnchorDay(now: now, calendar: calendar)
                == unlockQuotaAnchorDay(now: now, rolloverHour: UnlockQuotaStore.bedtime.dayRolloverHour, calendar: calendar))
        }
    }

    // The point of the separate file, pinned: the farming exploit came back once already by way of
    // an anchor that read a user-editable window. Nothing that can be edited may be in reach here —
    // and "in reach" is a property of the file's imports and code, not of anybody's intention.
    @Test func theAnchorFileCannotSeeAnyStore() throws {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Shared/QuotaAnchorDay.swift")
        let lines = try String(contentsOf: source, encoding: .utf8).components(separatedBy: "\n")
        let code = lines.filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }

        #expect(code.filter { $0.hasPrefix("import ") } == ["import Foundation"])
        #expect(!code.contains { $0.contains("Store") })
        #expect(!code.contains { $0.contains("UserDefaults") })
    }
}
