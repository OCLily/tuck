import Testing
import Foundation
@testable import Tuck

struct MorningBlockWindowTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    private func date(hour: Int, minute: Int, second: Int = 0) -> Date {
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 9,
            day: 1,
            hour: hour,
            minute: minute,
            second: second
        )
        return calendar.date(from: components)!
    }

    @Test func nominalThirtyMinuteWindow() {
        let alarmTime = date(hour: 7, minute: 0)
        let window = MorningBlockWindow(alarmTime: alarmTime, duration: .seconds(30 * 60), calendar: calendar)

        #expect(window.start.hour == 7)
        #expect(window.start.minute == 0)
        #expect(window.end.hour == 7)
        #expect(window.end.minute == 30)
    }

    @Test func clampsDurationToThirtyMinuteProductMinimum() {
        let alarmTime = date(hour: 7, minute: 0)
        let window = MorningBlockWindow(alarmTime: alarmTime, duration: .seconds(5 * 60), calendar: calendar)

        #expect(window.start.hour == 7)
        #expect(window.start.minute == 0)
        #expect(window.end.hour == 7)
        #expect(window.end.minute == 30)
    }

    @Test func midnightWraparound() {
        let alarmTime = date(hour: 23, minute: 50)
        let window = MorningBlockWindow(alarmTime: alarmTime, duration: .seconds(30 * 60), calendar: calendar)

        #expect(window.start.hour == 23)
        #expect(window.start.minute == 50)
        #expect(window.end.hour == 0)
        #expect(window.end.minute == 20)
    }

    @Test func fallBackDaylightSavingTransitionDoesNotMakeEndAppearBeforeStart() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 10,
            day: 25,
            hour: 2,
            minute: 50
        )
        let alarmTime = calendar.date(from: components)!
        let window = MorningBlockWindow(alarmTime: alarmTime, duration: .seconds(30 * 60), calendar: calendar)

        #expect(window.start.hour == 2)
        #expect(window.start.minute == 50)
        #expect(window.end.hour == 3)
        #expect(window.end.minute == 20)
    }

    // On 2027-03-28, 02:00-03:00 local time does not exist (clocks jump forward) — this
    // wall-clock result (02:20) is a date-less time-of-day, so it is never resolved against
    // that specific calendar day here. How DeviceActivityCenter would resolve it once this
    // type is wired to a real schedule is unverified — deferred to that integration.
    @Test func springForwardDaylightSavingTransitionAddsThirtyWallClockMinutes() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2027,
            month: 3,
            day: 28,
            hour: 1,
            minute: 50
        )
        let alarmTime = calendar.date(from: components)!
        let window = MorningBlockWindow(alarmTime: alarmTime, duration: .seconds(30 * 60), calendar: calendar)

        #expect(window.start.hour == 1)
        #expect(window.start.minute == 50)
        #expect(window.end.hour == 2)
        #expect(window.end.minute == 20)
    }

    @Test func theAnchorIsTodaysWindowStartOnceItHasPassed() {
        let start = DateComponents(hour: 7, minute: 0, second: 0)
        let anchor = MorningBlockWindow.mostRecentStart(of: start, atOrBefore: date(hour: 7, minute: 20), calendar: calendar)

        #expect(anchor == date(hour: 7, minute: 0))
    }

    @Test func theAnchorIsYesterdaysWindowStartBeforeTodaysHasArrived() {
        let start = DateComponents(hour: 7, minute: 0, second: 0)
        let anchor = MorningBlockWindow.mostRecentStart(of: start, atOrBefore: date(hour: 6, minute: 30), calendar: calendar)

        #expect(anchor == calendar.date(byAdding: .day, value: -1, to: date(hour: 7, minute: 0)))
    }

    // The idempotency guard in WakeAlarmStore compares anchors: equal means "same morning,
    // do not count it twice".
    @Test func twoDismissalsInOneMorningShareAnAnchorTheNextMorningDoesNot() {
        let start = DateComponents(hour: 7, minute: 0, second: 0)
        let first = MorningBlockWindow.mostRecentStart(of: start, atOrBefore: date(hour: 7, minute: 0), calendar: calendar)
        let retry = MorningBlockWindow.mostRecentStart(of: start, atOrBefore: date(hour: 7, minute: 0, second: 4), calendar: calendar)
        let nextDay = MorningBlockWindow.mostRecentStart(
            of: start,
            atOrBefore: calendar.date(byAdding: .day, value: 1, to: date(hour: 7, minute: 1))!,
            calendar: calendar
        )

        #expect(first == retry)
        #expect(first != nextDay)
    }

    // A window that wraps past midnight still has a single anchor per morning: a dismissal just
    // after midnight belongs to the window that started the previous evening.
    @Test func aWindowStartingBeforeMidnightAnchorsThePostMidnightDismissalToTheSameMorning() {
        let start = DateComponents(hour: 23, minute: 50, second: 0)
        let evening = MorningBlockWindow.mostRecentStart(of: start, atOrBefore: date(hour: 23, minute: 55), calendar: calendar)
        let afterMidnight = MorningBlockWindow.mostRecentStart(
            of: start,
            atOrBefore: calendar.date(byAdding: .day, value: 1, to: date(hour: 0, minute: 10))!,
            calendar: calendar
        )

        #expect(evening == afterMidnight)
    }

    // The bedtime window is centered on the bedtime, 30 minutes either side.
    @Test func centeredWindowStartsHalfADurationBeforeAndEndsHalfAfter() {
        let window = MorningBlockWindow.centeredOn(
            date(hour: 22, minute: 30),
            halfDuration: .seconds(30 * 60),
            calendar: calendar
        )

        #expect(window.start.hour == 22)
        #expect(window.start.minute == 0)
        #expect(window.end.hour == 23)
        #expect(window.end.minute == 0)
    }

    // Both directions wrap: the start is pulled back across midnight here, the end pushed past it.
    @Test func centeredWindowWrapsPastMidnightInBothDirections() {
        let late = MorningBlockWindow.centeredOn(
            date(hour: 23, minute: 50),
            halfDuration: .seconds(30 * 60),
            calendar: calendar
        )

        #expect(late.start.hour == 23)
        #expect(late.start.minute == 20)
        #expect(late.end.hour == 0)
        #expect(late.end.minute == 20)

        let earlyMorning = MorningBlockWindow.centeredOn(
            date(hour: 0, minute: 10),
            halfDuration: .seconds(30 * 60),
            calendar: calendar
        )

        #expect(earlyMorning.start.hour == 23)
        #expect(earlyMorning.start.minute == 40)
        #expect(earlyMorning.end.hour == 0)
        #expect(earlyMorning.end.minute == 40)
    }

    // Exactly midnight is the sharpest case for the negative-offset wraparound: a single modulo
    // would produce hour -1 here rather than 23.
    @Test func centeredWindowOnMidnightItselfStaysInTheDay() {
        let window = MorningBlockWindow.centeredOn(
            date(hour: 0, minute: 0),
            halfDuration: .seconds(30 * 60),
            calendar: calendar
        )

        #expect(window.start.hour == 23)
        #expect(window.start.minute == 30)
        #expect(window.end.hour == 0)
        #expect(window.end.minute == 30)
    }

    @Test func centeredWindowClampsToHalfTheThirtyMinuteProductMinimum() {
        let window = MorningBlockWindow.centeredOn(
            date(hour: 22, minute: 30),
            halfDuration: .seconds(2 * 60),
            calendar: calendar
        )

        #expect(window.start.hour == 22)
        #expect(window.start.minute == 15)
        #expect(window.end.hour == 22)
        #expect(window.end.minute == 45)
    }

    @Test func centeredWindowSetsOnlyHourMinuteSecond() {
        let window = MorningBlockWindow.centeredOn(
            date(hour: 22, minute: 30),
            halfDuration: .seconds(30 * 60),
            calendar: calendar
        )

        #expect(window.start.year == nil)
        #expect(window.start.day == nil)
        #expect(window.end.year == nil)
        #expect(window.end.day == nil)
    }

    // Regression guard for the shared wall-clock helper: adding the centered factory changed
    // addingWallClockSeconds to a sign-safe modulo, and the forward-only morning factory must be
    // bit-for-bit unaffected by it — including across both DST transitions.
    @Test func theForwardMorningFactoryIsUnaffectedByTheCenteredAddition() {
        let nominal = MorningBlockWindow(alarmTime: date(hour: 7, minute: 0), duration: .seconds(30 * 60), calendar: calendar)
        #expect(nominal.start.hour == 7)
        #expect(nominal.start.minute == 0)
        #expect(nominal.end.hour == 7)
        #expect(nominal.end.minute == 30)

        let wrapping = MorningBlockWindow(alarmTime: date(hour: 23, minute: 50), duration: .seconds(30 * 60), calendar: calendar)
        #expect(wrapping.end.hour == 0)
        #expect(wrapping.end.minute == 20)

        let clamped = MorningBlockWindow(alarmTime: date(hour: 7, minute: 0), duration: .seconds(60), calendar: calendar)
        #expect(clamped.end.hour == 7)
        #expect(clamped.end.minute == 30)

        var berlin = Calendar(identifier: .gregorian)
        berlin.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let fallBack = berlin.date(from: DateComponents(
            calendar: berlin, timeZone: berlin.timeZone, year: 2026, month: 10, day: 25, hour: 2, minute: 50
        ))!
        let fallBackWindow = MorningBlockWindow(alarmTime: fallBack, duration: .seconds(30 * 60), calendar: berlin)
        #expect(fallBackWindow.end.hour == 3)
        #expect(fallBackWindow.end.minute == 20)

        let springForward = berlin.date(from: DateComponents(
            calendar: berlin, timeZone: berlin.timeZone, year: 2027, month: 3, day: 28, hour: 1, minute: 50
        ))!
        let springForwardWindow = MorningBlockWindow(alarmTime: springForward, duration: .seconds(30 * 60), calendar: berlin)
        #expect(springForwardWindow.end.hour == 2)
        #expect(springForwardWindow.end.minute == 20)
    }

    // Same open spring-forward edge as the forward factory (MorningBlockWindow.swift:20-27): the
    // result is a date-less time of day, so it is never resolved against the day that lacks it.
    @Test func centeredWindowAcrossASpringForwardTransitionAddsWallClockMinutes() {
        var berlin = Calendar(identifier: .gregorian)
        berlin.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let bedtime = berlin.date(from: DateComponents(
            calendar: berlin, timeZone: berlin.timeZone, year: 2027, month: 3, day: 28, hour: 1, minute: 50
        ))!
        let window = MorningBlockWindow.centeredOn(bedtime, halfDuration: .seconds(30 * 60), calendar: berlin)

        #expect(window.start.hour == 1)
        #expect(window.start.minute == 20)
        #expect(window.end.hour == 2)
        #expect(window.end.minute == 20)
    }

    @Test func durationOfAForwardWindowIsItsLength() {
        let window = MorningBlockWindow(alarmTime: date(hour: 7, minute: 0), duration: .seconds(30 * 60), calendar: calendar)

        #expect(window.durationSeconds == 30 * 60)
    }

    // The threshold of the screen-time event is derived from this, so a window that wraps past
    // midnight must not come back as a negative or near-full day.
    @Test func durationOfAWindowAcrossMidnightWrapsForward() {
        let window = MorningBlockWindow.centeredOn(
            date(hour: 23, minute: 50), halfDuration: .seconds(30 * 60), calendar: calendar
        )

        #expect(window.durationSeconds == 60 * 60)
    }

    @Test func onlyHourMinuteSecondAreSet() {
        let alarmTime = date(hour: 7, minute: 0)
        let window = MorningBlockWindow(alarmTime: alarmTime, duration: .seconds(30 * 60), calendar: calendar)

        #expect(window.start.era == nil)
        #expect(window.start.year == nil)
        #expect(window.start.month == nil)
        #expect(window.start.day == nil)
        #expect(window.start.hour != nil)
        #expect(window.start.minute != nil)
        #expect(window.start.second != nil)

        #expect(window.end.era == nil)
        #expect(window.end.year == nil)
        #expect(window.end.month == nil)
        #expect(window.end.day == nil)
        #expect(window.end.hour != nil)
        #expect(window.end.minute != nil)
        #expect(window.end.second != nil)
    }
}
