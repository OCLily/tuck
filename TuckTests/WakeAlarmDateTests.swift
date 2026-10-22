import Testing
import Foundation
@testable import Tuck

struct WakeAlarmDateTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    private func date(
        year: Int = 2026,
        month: Int = 9,
        day: Int = 1,
        hour: Int,
        minute: Int,
        second: Int = 0
    ) -> Date {
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        )
        return calendar.date(from: components)!
    }

    @Test func wakeTimeStillAheadTodayResolvesToToday() {
        let fireDate = WakeAlarmDate.nextFireDate(
            forWakeTime: date(hour: 7, minute: 0),
            after: date(hour: 6, minute: 30),
            calendar: calendar
        )

        #expect(fireDate == date(hour: 7, minute: 0))
    }

    @Test func wakeTimeAlreadyPassedTodayResolvesToTomorrow() {
        let fireDate = WakeAlarmDate.nextFireDate(
            forWakeTime: date(hour: 7, minute: 0),
            after: date(hour: 8, minute: 0),
            calendar: calendar
        )

        #expect(fireDate == date(day: 2, hour: 7, minute: 0))
    }

    @Test func wakeTimeExactlyNowResolvesToTomorrow() {
        let fireDate = WakeAlarmDate.nextFireDate(
            forWakeTime: date(hour: 7, minute: 0),
            after: date(hour: 7, minute: 0),
            calendar: calendar
        )

        #expect(fireDate == date(day: 2, hour: 7, minute: 0))
    }

    @Test func onlyHourAndMinuteOfTheWakeTimeAreUsed() {
        let fireDate = WakeAlarmDate.nextFireDate(
            forWakeTime: date(year: 2011, month: 3, day: 14, hour: 7, minute: 0, second: 41),
            after: date(hour: 6, minute: 30),
            calendar: calendar
        )

        #expect(fireDate == date(hour: 7, minute: 0, second: 0))
    }

    // 2027-03-28 02:00-03:00 does not exist in Europe/Berlin (clocks jump forward). The
    // resolution below is Foundation's `.nextTime` policy, pinned here because an alarm must
    // still land on a real instant that day rather than silently returning nil.
    @Test func wakeTimeInsideSpringForwardGapResolvesToTheHourAfterTheGap() {
        let fireDate = WakeAlarmDate.nextFireDate(
            forWakeTime: date(hour: 2, minute: 30),
            after: date(year: 2027, month: 3, day: 27, hour: 20, minute: 0),
            calendar: calendar
        )

        #expect(fireDate == date(year: 2027, month: 3, day: 28, hour: 3, minute: 0))
    }

    @Test func timeOfDayReadsTheWallClockTimeInTheGivenCalendarsTimeZone() {
        let time = WakeAlarmDate.timeOfDay(forWakeTime: date(hour: 7, minute: 5, second: 41), calendar: calendar)

        #expect(time?.hour == 7)
        #expect(time?.minute == 5)
    }

    // The recurring AlarmKit schedule carries a bare hour/minute, so it must stay the wall-clock
    // time the user picked even on the day a DST transition moves that instant — unlike
    // nextFireDate, which resolves one concrete instant and shifts out of the spring-forward gap.
    @Test func timeOfDayIsUnaffectedByDaylightSavingTransitions() {
        let time = WakeAlarmDate.timeOfDay(
            forWakeTime: date(year: 2027, month: 3, day: 27, hour: 2, minute: 30),
            calendar: calendar
        )

        #expect(time?.hour == 2)
        #expect(time?.minute == 30)
    }

    @Test func timeOfDayFollowsTheCalendarTimeZoneRatherThanUTC() {
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!

        let time = WakeAlarmDate.timeOfDay(forWakeTime: date(hour: 7, minute: 0), calendar: tokyo)

        #expect(time?.hour == 14)
        #expect(time?.minute == 0)
    }

    // A missing weekday would silently turn "every morning" into "every morning except one".
    @Test func everyDayCoversAllSevenWeekdaysWithoutDuplicates() {
        let localeWeekdays = WakeAlarmWeekdayStore.everyDay.localeWeekdays
        #expect(localeWeekdays.count == 7)
        #expect(Set(localeWeekdays) == Set([
            Locale.Weekday.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday
        ]))
    }

    @Test func wakeTimeInsideFallBackRepeatedHourResolvesToItsFirstOccurrence() {
        let fireDate = WakeAlarmDate.nextFireDate(
            forWakeTime: date(hour: 2, minute: 30),
            after: date(year: 2026, month: 10, day: 24, hour: 20, minute: 0),
            calendar: calendar
        )

        #expect(fireDate == date(year: 2026, month: 10, day: 25, hour: 2, minute: 30))
    }
}
