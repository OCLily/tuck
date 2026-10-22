import Foundation
import Testing
@testable import Tuck

// Pattern from MorningCopyTests: an own gregorian calendar pinned to Europe/Berlin, dates built from
// DateComponents, function names as whole sentences. No control group is possible here — `Season`
// cannot be called before it exists, and a compile error is not a red test result (SproutSourceTests'
// header says so). What replaces it is coverage that is a table rather than a sample.
struct SeasonTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    private func date(year: Int = 2026, month: Int, day: Int, hour: Int = 12, minute: Int = 0,
                      in calendar: Calendar? = nil) -> Date {
        let calendar = calendar ?? self.calendar
        return calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year, month: month, day: day, hour: hour, minute: minute
        ))!
    }

    @Test func everyMonthOfTheYearHasExactlyOneSeason() {
        let expected: [Int: Season] = [
            1: .winter, 2: .winter, 3: .spring, 4: .spring, 5: .spring, 6: .summer,
            7: .summer, 8: .summer, 9: .autumn, 10: .autumn, 11: .autumn, 12: .winter
        ]
        for month in 1...12 {
            #expect(Season.current(on: date(month: month, day: 15), calendar: calendar) == expected[month],
                    "month \(month)")
        }
    }

    @Test func theFourBoundariesFallBetweenTheLastAndTheFirstOfAMonth() {
        let boundaries: [(before: (Int, Int), after: (Int, Int), from: Season, to: Season)] = [
            (before: (2, 28), after: (3, 1), from: .winter, to: .spring),
            (before: (5, 31), after: (6, 1), from: .spring, to: .summer),
            (before: (8, 31), after: (9, 1), from: .summer, to: .autumn),
            (before: (11, 30), after: (12, 1), from: .autumn, to: .winter)
        ]
        for boundary in boundaries {
            #expect(Season.current(on: date(month: boundary.before.0, day: boundary.before.1),
                                   calendar: calendar) == boundary.from)
            #expect(Season.current(on: date(month: boundary.after.0, day: boundary.after.1),
                                   calendar: calendar) == boundary.to)
        }
    }

    @Test func aLeapDayIsStillWinter() {
        #expect(Season.current(on: date(year: 2028, month: 2, day: 29), calendar: calendar) == .winter)
    }

    @Test func theSeasonDoesNotDependOnTheTimeOfDay() {
        #expect(Season.current(on: date(month: 3, day: 1, hour: 0, minute: 0), calendar: calendar) == .spring)
        #expect(Season.current(on: date(month: 3, day: 1, hour: 23, minute: 59), calendar: calendar) == .spring)
    }

    @Test func winterIsTheOneSeasonThatCrossesTheYearBoundary() {
        #expect(Season.current(on: date(year: 2026, month: 12, day: 31), calendar: calendar) == .winter)
        #expect(Season.current(on: date(year: 2027, month: 1, day: 1), calendar: calendar) == .winter)
        // And it is the only one whose months are not a contiguous run.
        let months = (1...12).filter {
            Season.current(on: date(month: $0, day: 15), calendar: calendar) == .winter
        }
        #expect(months == [1, 2, 12])
    }

    // The same instant, read by two calendars on opposite sides of the date line. The function is
    // allowed to disagree with itself by one calendar day; what it may not do is invent a season —
    // the two answers are either the same or the two that share the boundary that day sits on.
    @Test func travellingAcrossTheDateLineDoesNotInventASeason() {
        var auckland = Calendar(identifier: .gregorian)
        auckland.timeZone = TimeZone(identifier: "Pacific/Auckland")!

        // 2026-02-28 23:00 in Berlin is already 2026-03-01 11:00 in Auckland.
        let instant = date(year: 2026, month: 2, day: 28, hour: 23, minute: 0)

        #expect(Season.current(on: instant, calendar: calendar) == .winter)
        #expect(Season.current(on: instant, calendar: auckland) == .spring)

        // Away from a boundary the two agree, which is what makes the disagreement above a calendar
        // day and not a jump.
        let middleOfJuly = date(year: 2026, month: 7, day: 15, hour: 12, minute: 0)
        #expect(Season.current(on: middleOfJuly, calendar: calendar) == .summer)
        #expect(Season.current(on: middleOfJuly, calendar: auckland) == .summer)
    }
}

// The selection belongs to this file, the drawing to SeasonalAccentTests — the same split as the
// source files. Two suites in one file is house practice (`SproutSourceTests` lives in
// TuckTests/SproutStageTests.swift).
//
// No real control group is possible — `FoundObject` cannot be called before it exists. The
// substitute was two targeted detunings run in a separate working copy, each with a named expected red test.
struct FoundObjectCadenceTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    private var epoch: Date {
        calendar.date(from: DateComponents(calendar: calendar, timeZone: calendar.timeZone,
                                           year: 2026, month: 1, day: 1, hour: 12))!
    }

    private func day(_ offset: Int, hour: Int = 12, minute: Int = 0) -> Date {
        let start = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: epoch))!
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: start)!
    }

    // A table, not a sample: the index has to change at 14, 28 and 42 and NOWHERE else.
    @Test func theObjectChangesExactlyOnceEveryFourteenDays() {
        for offset in 0...42 {
            let expected = offset / 14
            #expect(FoundObject.periodIndex(on: day(offset), calendar: calendar) == expected,
                    "day \(offset)")
        }
    }

    // Mirror image of theSeasonDoesNotDependOnTheTimeOfDay: within a day, one period; across the
    // boundary, two.
    @Test func theLastMinuteOfDayThirteenAndTheFirstOfDayFourteenAreTwoPeriods() {
        #expect(FoundObject.periodIndex(on: day(13, hour: 0, minute: 0), calendar: calendar) == 0)
        #expect(FoundObject.periodIndex(on: day(13, hour: 23, minute: 59), calendar: calendar) == 0)
        #expect(FoundObject.periodIndex(on: day(14, hour: 0, minute: 0), calendar: calendar) == 1)
    }

    // The property `MorningCopy.morningIndex` loses the moment an alarm is entered or deleted, and
    // the reason the found object needs an anchor of its own.
    @Test func theIndexNeverRunsBackwardsWhileTimeRunsForwards() {
        var previous = Int.min
        var cursor = calendar.startOfDay(for: epoch)
        let end = calendar.date(byAdding: .year, value: 3, to: cursor)!
        while cursor < end {
            let index = FoundObject.periodIndex(on: cursor, calendar: calendar)
            #expect(index >= previous, "index fell at \(cursor)")
            previous = index
            cursor = calendar.date(byAdding: .hour, value: 6, to: cursor)!
        }
    }

    // Mechanically rather than as prose: without this scan, "its own anchor" is an intention
    // a later simplification cancels.
    @Test func noAlarmCanEverMoveTheObject() throws {
        let source = try SeasonalAccentTests.strippedSource("Tuck/Season.swift")
        for symbol in ["WakeAlarmStore", "morningIndex", "alarm"] {
            #expect(!source.contains(symbol), "Tuck/Season.swift reaches for `\(symbol)`")
        }
    }

    // The DST half of "a change of clock changes nothing": 2026-03-29 is the EU spring-forward day.
    @Test func aClockChangeWithinOneDayChangesNothing() {
        let switchDay = calendar.date(from: DateComponents(calendar: calendar,
                                                           timeZone: calendar.timeZone,
                                                           year: 2026, month: 3, day: 29))!
        let early = calendar.date(bySettingHour: 1, minute: 0, second: 0, of: switchDay)!
        let late = calendar.date(bySettingHour: 4, minute: 0, second: 0, of: switchDay)!

        #expect(FoundObject.periodIndex(on: early, calendar: calendar)
                == FoundObject.periodIndex(on: late, calendar: calendar))
    }

    @Test func travellingAcrossTheDateLineMovesTheObjectByAtMostOneDayNeverByAPeriod() {
        var auckland = Calendar(identifier: .gregorian)
        auckland.timeZone = TimeZone(identifier: "Pacific/Auckland")!

        var cursor = calendar.startOfDay(for: epoch)
        let end = calendar.date(byAdding: .day, value: 120, to: cursor)!
        while cursor < end {
            let here = FoundObject.periodIndex(on: cursor, calendar: calendar)
            let there = FoundObject.periodIndex(on: cursor, calendar: auckland)
            #expect(abs(there - here) <= 1, "a period was skipped at \(cursor)")
            cursor = calendar.date(byAdding: .hour, value: 6, to: cursor)!
        }
    }

    // Catches Swift's toward-zero division, which would make the period around the epoch 27 days
    // long instead of 14.
    @Test func theDayBeforeTheEpochBelongsToTheEarlierPeriod() {
        #expect(FoundObject.periodIndex(on: day(-1), calendar: calendar) == -1)
        #expect(FoundObject.periodIndex(on: day(-14), calendar: calendar) == -1)
        #expect(FoundObject.periodIndex(on: day(-15), calendar: calendar) == -2)
    }

    @Test func everyPeriodIndexLandsInsideTheList() {
        for offset in stride(from: -400, through: 400, by: 7) {
            let object = FoundObject.current(on: day(offset), calendar: calendar)
            #expect(FoundObject.allCases.contains(object), "day \(offset)")
        }
    }

    @Test func theSameDayAlwaysYieldsTheSameObject() throws {
        for offset in 0...30 {
            #expect(FoundObject.current(on: day(offset, hour: 6), calendar: calendar)
                    == FoundObject.current(on: day(offset, hour: 21), calendar: calendar))
        }
        // The time comes in, it is not fetched — the same separation IdleSchedule is held to.
        let source = try SeasonalAccentTests.strippedSource("Tuck/Season.swift")
        #expect(!source.contains("random"))
        #expect(!source.contains("Date()"))
        #expect(!source.contains(".now"))
    }

    @Test func theListHasTheCountItWasDecidedWith() {
        #expect(FoundObject.allCases.count == 5)
    }
}
