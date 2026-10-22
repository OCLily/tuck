import Foundation

struct MorningBlockWindow {
    let start: DateComponents
    let end: DateComponents

    // alarmTime is the alarm's SCHEDULED ring time, not the moment the user dismisses it.
    // Anchoring here (not to dismiss) lets the block schedule be registered when the alarm is
    // set rather than depending on stopIntent firing reliably, and it degrades sanely under
    // snooze. See docs/product-decisions-2026-09-02.md for the full rationale.
    init(alarmTime: Date, duration: Duration, calendar: Calendar) {
        // 30 minutes is a product minimum (concept decision), not the platform floor: the SDK's own
        // documentation puts MonitoringError.intervalTooShort at fifteen minutes
        // (DeviceActivity.swiftdoc), so this sits at twice the floor.
        let clampedDuration = max(duration, .seconds(30 * 60))

        start = Self.timeComponents(from: alarmTime, calendar: calendar)
        // Adding the duration as absolute time (via Date.addingTimeInterval, or equivalently
        // Calendar.date(byAdding: .second/.minute, ...) — verified empirically to produce the
        // identical epoch-based result for sub-day units) and re-reading wall-clock components
        // afterwards breaks across a DST transition: the wall-clock hour/minute can jump
        // non-linearly relative to the real elapsed seconds. start/end here are pure
        // hour/minute/second-of-day components (no date), so the duration must be added in
        // that same wall-clock domain, matching the existing midnight-wraparound semantics.
        // Trade-off, not fully closed: once a year (spring-forward), the resulting wall-clock
        // time can fall inside the local hour that does not exist that day — undefined until
        // this type is wired to a real DeviceActivitySchedule call site (see build-plan-phase1.md).
        end = Self.addingWallClockSeconds(clampedDuration.components.seconds, to: start)
    }

    // Rebuilds a window from what a store persisted, for the reconciliation retry — the original
    // anchor is gone by then, only its two ends survive.
    init(start: DateComponents, end: DateComponents) {
        self.start = start
        self.end = end
    }

    // The bedtime window is centered on its anchor rather than running forward from it: 30 minutes
    // before bedtime through 30 minutes after (see docs/bedtime-window-2026-09-03.md). Same
    // wall-clock arithmetic as the forward case, so the midnight wraparound covers both directions
    // — a 23:50 bedtime yields 23:20-00:20, not a negative hour.
    static func centeredOn(_ anchor: Date, halfDuration: Duration, calendar: Calendar) -> MorningBlockWindow {
        // Half of the same 30-minute product floor the forward initializer clamps to, so a
        // centered window is never shorter than a forward one.
        let clampedHalf = max(halfDuration, .seconds(15 * 60)).components.seconds
        let center = Self.timeComponents(from: anchor, calendar: calendar)
        return MorningBlockWindow(
            start: Self.addingWallClockSeconds(-clampedHalf, to: center),
            end: Self.addingWallClockSeconds(clampedHalf, to: center)
        )
    }

    // Wall-clock seconds from start to end, wrapping past midnight the same way both ends were
    // built — a 23:50-00:20 bedtime is 30 minutes, not a negative day.
    var durationSeconds: Int {
        let secondsPerDay = 24 * 60 * 60
        let elapsed = Self.secondOfDay(end) - Self.secondOfDay(start)
        return ((elapsed % secondsPerDay) + secondsPerDay) % secondsPerDay
    }

    // Whether `now` falls in [start, end) — the one question both "which quota does this override
    // spend" (OverrideContext) and "is this window running right now" (BlockWindowReconciler) are.
    // Half-open and wrapping past midnight the same way durationSeconds measures, so a 23:50-00:20
    // window contains 00:10 and not its own end.
    func contains(_ now: Date, calendar: Calendar) -> Bool {
        let moment = Self.secondOfDay(calendar.dateComponents([.hour, .minute, .second], from: now))
        let start = Self.secondOfDay(start)
        let end = Self.secondOfDay(end)
        guard start != end else { return false }
        return start < end
            ? moment >= start && moment < end
            : moment >= start || moment < end
    }

    // Anchor for "which morning does this Date belong to": the most recent occurrence of the
    // window's start time at or before `date`. Two moments belong to the same morning exactly
    // when their anchors are equal — a real Date, so it stays correct for windows that wrap
    // past midnight, unlike comparing the bare time-of-day.
    static func mostRecentStart(of start: DateComponents, atOrBefore date: Date, calendar: Calendar) -> Date? {
        guard let sameDay = calendar.date(
            bySettingHour: start.hour ?? 0,
            minute: start.minute ?? 0,
            second: start.second ?? 0,
            of: date
        ) else { return nil }

        if sameDay <= date { return sameDay }
        return calendar.date(byAdding: .day, value: -1, to: sameDay)
    }

    private static func timeComponents(from date: Date, calendar: Calendar) -> DateComponents {
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        return DateComponents(hour: components.hour, minute: components.minute, second: components.second)
    }

    private static func secondOfDay(_ components: DateComponents) -> Int {
        (components.hour ?? 0) * 3600 + (components.minute ?? 0) * 60 + (components.second ?? 0)
    }

    private static func addingWallClockSeconds(_ seconds: Int64, to components: DateComponents) -> DateComponents {
        let secondsPerDay = 24 * 60 * 60
        let startSecondOfDay = secondOfDay(components)
        // Double modulo, not one: Swift's % keeps the sign of the dividend, so a negative offset
        // (centeredOn's start) would otherwise produce a negative hour instead of wrapping back
        // into the previous day. Identical to a single modulo for every non-negative offset.
        let endSecondOfDay = (((startSecondOfDay + Int(seconds)) % secondsPerDay) + secondsPerDay) % secondsPerDay
        return DateComponents(hour: endSecondOfDay / 3600, minute: (endSecondOfDay % 3600) / 60, second: endSecondOfDay % 60)
    }
}
