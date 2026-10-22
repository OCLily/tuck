import Foundation

// The only thing about the block window DeviceActivity can actually report. A DeviceActivityEvent
// measures accumulated frontmost time and nothing else: its three target sets are whitelists with
// no complement (`includesAllActivity`, DeviceActivity.swiftinterface:90), so "everything except
// the blocked selection" is not expressible, and `eventDidReachThreshold` carries two names and
// nothing else — no app, no token, no duration. Detecting that someone worked around the block is
// therefore not hard here, it is unavailable.
//
// What is left is honest but blunt: a phone call, Maps on the way to the train and twenty minutes
// of scrolling raise the exact same flag, and the flag carries no frequency information either —
// one long stretch and many short check-ins trip the same threshold. Copy built on this must not
// name a quantity or a frequency, only that the phone was present; the moment it implies avoidance
// it is a guilt signal resting on a measurement that cannot carry it, and it lands hardest on the
// people with the fullest mornings.
enum ScreenTimeNotice {
    // Long enough for a morning that is not looked at until midday, short enough that "heute
    // Morgen" is still true and yesterday's flag can never surface on today's screen.
    private static let validity: TimeInterval = 6 * 60 * 60

    private static let recordedAtKey = "screenTimeNoticeRecordedAt"

    private nonisolated static var defaults: UserDefaults {
        UserDefaults(suiteName: TuckIdentifiers.appGroupSuiteName) ?? .standard
    }

    // Two thirds of the window, a product ratio with no SDK meaning: much lower and a single real
    // phone call trips it, much higher and only a morning spent entirely on the phone would.
    //
    // nil below the SDK's fifteen-minute monitoring floor (MonitoringError.intervalTooShort,
    // DeviceActivity.swiftdoc — the same floor MorningBlockWindow's product minimum sits at twice
    // of): a window reconstructed with start == end has a duration of zero, and a threshold clamped
    // up to one minute would put the line on almost every morning instead of never. Such a window
    // gets no event at all.
    nonisolated static func thresholdMinutes(forWindowSeconds seconds: Int) -> Int? {
        guard seconds >= 15 * 60 else { return nil }
        return seconds * 2 / 3 / 60
    }

    nonisolated static func record(now: Date = .now, in defaults: UserDefaults = Self.defaults) {
        defaults.set(now, forKey: recordedAtKey)
    }

    // Reads and clears in one step, same shape as ShieldOverrideRequest.take: the line is shown once
    // and is then gone. Nothing counts it and nothing keeps it — a tally or a repeat would be a
    // different, undecided feature, and the kind of engagement dashboard the app avoids.
    //
    // Only the shown case clears, for the same reason as there: as a `defer` this also fired on the
    // "nothing to say" path, so a flag the monitor extension had written but this process could not
    // see yet was deleted by the read that missed it, hours before its six were up.
    nonisolated static func take(now: Date = .now, in defaults: UserDefaults = Self.defaults) -> Bool {
        guard let recordedAt = defaults.object(forKey: recordedAtKey) as? Date,
              now.timeIntervalSince(recordedAt) >= 0,
              now.timeIntervalSince(recordedAt) <= validity
        else { return false }

        defaults.removeObject(forKey: recordedAtKey)
        return true
    }
}
