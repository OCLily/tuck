import Testing
import Foundation
@testable import Tuck

struct MorningSkyTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    private func date(hour: Int, minute: Int, day: Int = 1) -> Date {
        calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026, month: 9, day: day, hour: hour, minute: minute
        ))!
    }

    private func alarm(startHour: Int, startMinute: Int, endHour: Int, endMinute: Int) -> WakeAlarmStore.ScheduledAlarm {
        WakeAlarmStore.ScheduledAlarm(
            id: UUID(),
            fireDate: date(hour: startHour, minute: startMinute),
            blockWindowStart: DateComponents(hour: startHour, minute: startMinute, second: 0),
            blockWindowEnd: DateComponents(hour: endHour, minute: endMinute, second: 0)
        )
    }

    @Test func progressIsZeroExactlyAtTheAnchor() {
        let progress = MorningSky.progress(
            now: date(hour: 7, minute: 0),
            alarm: alarm(startHour: 7, startMinute: 0, endHour: 7, endMinute: 30),
            calendar: calendar
        )

        #expect(progress == 0)
    }

    @Test func progressIsHalfwayFifteenMinutesIntoAThirtyMinuteWindow() {
        let progress = MorningSky.progress(
            now: date(hour: 7, minute: 15),
            alarm: alarm(startHour: 7, startMinute: 0, endHour: 7, endMinute: 30),
            calendar: calendar
        )

        #expect(abs(progress - 0.5) < 0.0001)
    }

    @Test func progressStaysClampedAtOneLongAfterTheWindowEnded() {
        let progress = MorningSky.progress(
            now: date(hour: 9, minute: 30),
            alarm: alarm(startHour: 7, startMinute: 0, endHour: 7, endMinute: 30),
            calendar: calendar
        )

        #expect(progress == 1)
    }

    @Test func aWindowWrappingPastMidnightIsHalfwayFiveMinutesAfterMidnight() {
        let progress = MorningSky.progress(
            now: date(hour: 0, minute: 5, day: 2),
            alarm: alarm(startHour: 23, startMinute: 50, endHour: 0, endMinute: 20),
            calendar: calendar
        )

        #expect(abs(progress - 0.5) < 0.0001)
    }

    @Test func withoutAnAlarmProgressFollowsWallClockBetweenFiveAndNine() {
        #expect(MorningSky.progress(now: date(hour: 5, minute: 0), alarm: nil, calendar: calendar) == 0)
        #expect(abs(MorningSky.progress(now: date(hour: 7, minute: 0), alarm: nil, calendar: calendar) - 0.5) < 0.0001)
        #expect(MorningSky.progress(now: date(hour: 9, minute: 0), alarm: nil, calendar: calendar) == 1)
        #expect(MorningSky.progress(now: date(hour: 3, minute: 0), alarm: nil, calendar: calendar) == 0)
        #expect(MorningSky.progress(now: date(hour: 12, minute: 0), alarm: nil, calendar: calendar) == 1)
    }

    @Test func gradientStopsStayMonotonicAcrossTheWholeWindow() {
        for progress in [0.0, 0.5, 1.0] {
            let locations = MorningSky.stopLocations(progress: progress)
            #expect(locations == locations.sorted())
            #expect(locations.first == 0)
            #expect(locations.last == 1)
        }
    }
}
