import Foundation

enum WakeAlarmDate {
    static func timeOfDay(forWakeTime wakeTime: Date, calendar: Calendar) -> (hour: Int, minute: Int)? {
        let time = calendar.dateComponents([.hour, .minute], from: wakeTime)
        guard let hour = time.hour, let minute = time.minute else { return nil }
        return (hour, minute)
    }

    // The weekdays are a filter over the same daily search, not a second search: matching on
    // weekday and time together would hand DST gaps and repeated hours to a matching policy that
    // has no way to answer for both at once, and the four tests below pin exactly that behaviour.
    // Seven candidates are enough — one of them is today's weekday again.
    static func nextFireDate(
        forWakeTime wakeTime: Date,
        after now: Date,
        weekdays: Set<WakeAlarmWeekday> = WakeAlarmWeekdayStore.everyDay,
        calendar: Calendar
    ) -> Date? {
        guard let time = timeOfDay(forWakeTime: wakeTime, calendar: calendar) else { return nil }
        let days = WakeAlarmWeekdayStore.normalized(weekdays)

        var candidate = now
        for _ in 0..<7 {
            guard let next = calendar.nextDate(
                after: candidate,
                matching: DateComponents(hour: time.hour, minute: time.minute, second: 0),
                matchingPolicy: .nextTime,
                direction: .forward
            ) else { return nil }

            if let weekday = WakeAlarmWeekday(rawValue: calendar.component(.weekday, from: next)),
               days.contains(weekday) {
                return next
            }
            candidate = next
        }
        return nil
    }
}
