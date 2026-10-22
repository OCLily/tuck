import Foundation

// The rule that closes the quota-farming exploit, alone in a file so it cannot quietly stop being
// that rule. Every earlier version of both quotas keyed the reset off a stored window — the
// bedtime's start, the morning's occurrence — and both of those are values the user can edit at any
// moment: an edit that moves the window across `now` moves the anchor with it, and the quota that
// was already spent comes back, once per edit, without limit.
//
// The rule is therefore: nothing readable from BedtimeStore or WakeAlarmStore may enter this
// computation. Stated as a comment inside UnlockQuotaStore it was a promise anybody could break by
// reaching for a store that was already in scope. Here it is a shape: this file takes an instant, a
// rollover hour and a calendar, imports Foundation and nothing else, and there is no store in reach
// to read. Adding one means adding an import to a file whose only job is not to have it — visible in
// a diff, not silent. QuotaAnchorDayTests pins that shape.
//
// Residual, bounded and not reachable by editing: a window that itself contains the rollover hour
// crosses it once and grants one extra unlock there.
func unlockQuotaAnchorDay(now: Date, rolloverHour: Int, calendar: Calendar = .current) -> Int {
    var day = calendar.dateComponents([.year, .month, .day, .hour], from: now)
    if (day.hour ?? 0) < rolloverHour, let previous = calendar.date(byAdding: .day, value: -1, to: now) {
        day = calendar.dateComponents([.year, .month, .day], from: previous)
    }
    return (day.year ?? 0) * 10_000 + (day.month ?? 0) * 100 + (day.day ?? 0)
}
