import Foundation

// The one file that answers what the calendar gives today — and nothing else. Foundation only, no
// SwiftUI, the same rule Motion.swift, Layout.swift and MascotGeometry.swift follow, and
// app-target-local like MorningCelebration and MorningRecognition.
//
// METEOROLOGICAL, not astronomical: fixed month boundaries. Solstices and equinoxes would need
// either an ageing table or astronomy in the code, and four boundaries are four rules.
//
// NORTHERN HEMISPHERE. Month boundaries are northern by construction. Not fixable with the means of
// this app — a location would be a permission, and TimeZone as a latitude proxy is unreliable. A
// documented, accepted limitation rather than a silently wrong one.
//
// NO STORE, NO DICE, NO CLOCK TIME — AND NO COUNTER. The last one is the important one: this is the
// unearned channel. Nothing here may ever depend on how many mornings somebody has completed,
// because the moment it does, a date has quietly become something to earn or to lose.
// `SeasonalAccentTests.theUnearnedChannelTouchesNoCounterAndNoStore` makes that a mechanism instead
// of an intention.
// TWO CADENCES, ONE CHANNEL — and that is a governance statement, not a class. This file answers
// what the calendar gives today; everything that DRAWS lives next door in SeasonalAccent.swift. Both
// readers here meet the same four properties: purely over a date, deterministic, no store, no
// counter. The mechanical payoff is the reason for the shared file rather than the tidiness: the
// eight-symbol scan runs over TWO files. A third file would be a third scan target, and one of three
// drifts.
enum Season: CaseIterable {
    case spring, summer, autumn, winter

    /// The calendar comes in, it is not fetched — same separation as `IdleSchedule`, and the reason
    /// a test can pin this to Europe/Berlin the way `MorningCopyTests` does.
    static func current(on date: Date, calendar: Calendar = .current) -> Season {
        switch calendar.component(.month, from: date) {
        case 3, 4, 5: .spring
        case 6, 7, 8: .summer
        case 9, 10, 11: .autumn
        default: .winter
        }
    }
}

// The finer of the two cadences: something lies beside the animal, and every fourteen days it is
// something else. Guaranteed delivery, unknown content, and it means nothing — no expiry, no
// inventory, no shelf, no "x of y".
//
// WHAT IS BUILT HERE IS THE CADENCE, NOT THE RECOGNISABILITY. A found object is by definition a
// recognisable thing, and a triangle is not one. The illustration that would make it one is separate
// work that is not part of this repository. So the five cases
// are geometric placeholders with geometric names — no `acorn`, no `pebble`, no `mushroom`, because
// a symbol with a thing's name gets mistaken for the thing it names. Each one is the OUTLINE of the
// object that will take its place: the drawing inside the box changes, the cadence, the position,
// the size and the token do not.
//
// FIVE, not four and not six. 5 × 14 = 70 days to recurrence, long enough that the rotation does not
// read as a rotation and short enough that all five can be looked at once. And N may not divide 26
// (the number of fourteen-day periods in a year), or the same form would fall on nearly the same date
// every year and the object would become a second seasonal channel. 2 and 13 are out; 5 is coprime
// to 26.
enum FoundObject: CaseIterable {
    case disc, dome, wedge, lozenge, bar

    static let cadenceInDays = 14

    /// How many whole cadence periods lie between the epoch and `date`.
    ///
    /// Built this way and not another, four times over:
    ///
    ///   - The epoch is a CALENDAR DAY resolved through the same calendar `date` is read in. An
    ///     absolute timestamp divided by 86 400 would count UTC days against local ones — the exact
    ///     defect that makes `MorningCopy.morningIndex` unusable as a cadence anchor.
    ///   - The distance is counted between two `startOfDay` values, which makes it DST-proof: a 23-
    ///     or 25-hour day counts as one day.
    ///   - The division is a FLOOR division, not Swift's `/`. Swift truncates toward zero, so
    ///     `-1 / 14 == 0` and `-15 / 14 == -1` would make the period around the epoch 27 days long
    ///     instead of 14. Nobody lives before the epoch — until a device has a wrong clock, and a
    ///     silently double-length period is the kind of defect nobody ever finds.
    ///   - The epoch value is deliberately meaningless: not a release date, not an install date
    ///     (that would be a store read), not a milestone. Written down so a later reader does not
    ///     look for its significance.
    static func periodIndex(on date: Date, calendar: Calendar = .current) -> Int {
        guard let epoch = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)),
              let days = calendar.dateComponents([.day],
                                                 from: calendar.startOfDay(for: epoch),
                                                 to: calendar.startOfDay(for: date)).day
        else { return 0 }
        let quotient = days / cadenceInDays
        return days % cadenceInDays < 0 ? quotient - 1 : quotient
    }

    static func current(on date: Date, calendar: Calendar = .current) -> FoundObject {
        let index = periodIndex(on: date, calendar: calendar)
        let count = allCases.count
        // The same double modulo MorningCopy.subline uses, for the same reason and with the same
        // precedent test (`negativeIndicesStayInsideThePool`).
        return allCases[((index % count) + count) % count]
    }
}
