import Testing
import Foundation
@testable import Tuck

struct MorningRecognitionTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    private func date(hour: Int, minute: Int, day: Int = 10) -> Date {
        calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026, month: 9, day: day, hour: hour, minute: minute
        ))!
    }

    private var alarm: WakeAlarmStore.ScheduledAlarm {
        WakeAlarmStore.ScheduledAlarm(
            id: UUID(),
            fireDate: date(hour: 7, minute: 0),
            blockWindowStart: DateComponents(hour: 7, minute: 0, second: 0),
            blockWindowEnd: DateComponents(hour: 7, minute: 30, second: 0)
        )
    }

    private func freshDefaults() -> UserDefaults {
        let name = "MorningRecognitionTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func aFirstEverAppearanceIsANewMorning() {
        let defaults = freshDefaults()

        let kind = MorningRecognition.check(now: date(hour: 7, minute: 5), alarm: alarm, calendar: calendar, in: defaults)

        #expect(kind == .nextMorning)
    }

    @Test func asecondLookInTheSameWindowIsTheSameMorning() {
        let defaults = freshDefaults()
        MorningRecognition.check(now: date(hour: 7, minute: 5), alarm: alarm, calendar: calendar, in: defaults)

        let kind = MorningRecognition.check(now: date(hour: 7, minute: 22), alarm: alarm, calendar: calendar, in: defaults)

        #expect(kind == .sameMorning)
    }

    @Test func oneDayLaterIsTheNextMorningThreeOrMoreIsAGap() {
        for (dayOffset, expected) in [(1, MorningRecognition.Kind.nextMorning),
                                      (2, .nextMorning),
                                      (3, .afterGap),
                                      (10, .afterGap)] {
            let defaults = freshDefaults()
            MorningRecognition.check(now: date(hour: 7, minute: 5), alarm: alarm, calendar: calendar, in: defaults)

            let kind = MorningRecognition.check(
                now: date(hour: 7, minute: 5, day: 10 + dayOffset),
                alarm: alarm,
                calendar: calendar,
                in: defaults
            )

            #expect(kind == expected)
        }
    }

    @Test func checkNeverTouchesTheMorningCount() {
        let defaults = freshDefaults()
        let before = MorningProgressStore.completedMornings(in: defaults)

        MorningRecognition.check(now: date(hour: 7, minute: 5), alarm: alarm, calendar: calendar, in: defaults)
        MorningRecognition.check(now: date(hour: 7, minute: 5, day: 14), alarm: alarm, calendar: calendar, in: defaults)

        #expect(MorningProgressStore.completedMornings(in: defaults) == before)
    }
}
