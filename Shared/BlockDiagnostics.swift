import Foundation

// The only measuring instrument for the five-day
// device observation, and the only thing that will ever tell a real user's phone apart from a
// working one. The product hangs on a system callback that Apple's DeviceActivity API is documented
// to drop entirely on some devices — deviceactivityd stays silent, nothing throws, nothing logs —
// so "it looked fine" is not evidence and the gate for the observation is numeric off these four.
//
// Five counts, in the order the morning walks through them: a window was registered, iOS opened its
// interval, a shield was written, the fourth is the gap between the first two — an occurrence whose
// interval never opened at all — and the fifth is the interval that opened on a weekday nobody
// chose and was let go on purpose.
//
// The fifth exists because without it the observation cannot read its own numbers: an interval
// without a shield is the shape of a platform failure, of a lapsed access, and of a Saturday a Mo-Fr
// user deliberately kept — three different findings behind one difference. Counted where the
// decision is taken, so the five days say which of the three happened.
//
// Per window, not per event: the first three used to share one bucket for both windows, and a
// bedtime that silently never fired was then indistinguishable from a morning that did. The proof
// is needed per window: if the evening is the half that fails, the bedtime window as a paid
// feature is what the finding is about, and one mixed number cannot say so.
// The skipped weekday stays single: only the morning has a weekday selection at all.
//
// Local only. Nothing here leaves the device, and the privacy manifest stays what it is: these are
// UserDefaults integers in the App Group, in the same suite and the same shape as every other store.
// Written from two processes — the app registers, the monitor extension reports — which is why they
// are separate keys per event rather than one structure read and rewritten by both.
enum BlockDiagnostics {
    enum Counter: String, CaseIterable, Sendable {
        case morningWindowsRegistered = "diagnosticMorningWindowsRegistered"
        case bedtimeWindowsRegistered = "diagnosticBedtimeWindowsRegistered"
        case morningIntervalsStarted = "diagnosticMorningIntervalsStarted"
        case bedtimeIntervalsStarted = "diagnosticBedtimeIntervalsStarted"
        case morningShieldsApplied = "diagnosticMorningShieldsApplied"
        case bedtimeShieldsApplied = "diagnosticBedtimeShieldsApplied"
        case morningCallbacksMissing = "diagnosticMorningCallbacksMissing"
        case bedtimeCallbacksMissing = "diagnosticBedtimeCallbacksMissing"
        case weekdaysSkipped = "diagnosticWeekdaysSkipped"
    }

    // An interval that opens within this of the window's start has simply not been reported yet:
    // the app can come forward in the same second the window begins, and calling that a missed
    // callback would make the one number that has to be trustworthy the noisiest. One constant for
    // both windows: "can the callback have arrived at all yet" is the same question in either.
    static let callbackGraceSeconds: TimeInterval = 120

    private static let lastMorningIntervalStartKey = "diagnosticLastMorningIntervalStart"
    private static let lastAuditedMorningOccurrenceKey = "diagnosticLastAuditedMorningOccurrence"
    private static let lastBedtimeIntervalStartKey = "diagnosticLastBedtimeIntervalStart"
    private static let lastAuditedBedtimeOccurrenceKey = "diagnosticLastAuditedBedtimeOccurrence"

    private nonisolated static var defaults: UserDefaults {
        UserDefaults(suiteName: TuckIdentifiers.appGroupSuiteName) ?? .standard
    }

    nonisolated static func record(_ counter: Counter, in defaults: UserDefaults = Self.defaults) {
        defaults.set(count(of: counter, in: defaults) + 1, forKey: counter.rawValue)
    }

    nonisolated static func count(of counter: Counter, in defaults: UserDefaults = Self.defaults) -> Int {
        defaults.integer(forKey: counter.rawValue)
    }

    // The moment half of the interval count: the count alone says how often iOS answered, this says
    // whether it answered for the occurrence being asked about.
    nonisolated static func recordMorningIntervalStart(
        at date: Date,
        in defaults: UserDefaults = Self.defaults
    ) {
        defaults.set(date, forKey: lastMorningIntervalStartKey)
    }

    nonisolated static func lastMorningIntervalStart(in defaults: UserDefaults = Self.defaults) -> Date? {
        defaults.object(forKey: lastMorningIntervalStartKey) as? Date
    }

    nonisolated static func recordBedtimeIntervalStart(
        at date: Date,
        in defaults: UserDefaults = Self.defaults
    ) {
        defaults.set(date, forKey: lastBedtimeIntervalStartKey)
    }

    nonisolated static func lastBedtimeIntervalStart(in defaults: UserDefaults = Self.defaults) -> Date? {
        defaults.object(forKey: lastBedtimeIntervalStartKey) as? Date
    }

    // The fourth counter, and the only one nothing fires on its own: a callback that never arrives
    // arrives nowhere, so somebody has to come looking. The app does, at the moment it comes
    // forward, for the occurrence it finds — the same anchor the morning count is claimed on, handed
    // in rather than read here, because this file is compiled into the monitor extension too and
    // WakeAlarmStore is not.
    //
    // Once per occurrence, whatever the answer: without the audit mark, five foreground entries on
    // one silent morning would report five separate platform failures.
    @discardableResult
    nonisolated static func auditMorningCallback(
        occurrence anchor: Date?,
        now: Date = .now,
        in defaults: UserDefaults = Self.defaults
    ) -> Bool {
        audit(
            occurrence: anchor,
            now: now,
            in: defaults,
            lastIntervalStartKey: lastMorningIntervalStartKey,
            lastAuditedOccurrenceKey: lastAuditedMorningOccurrenceKey,
            counter: .morningCallbacksMissing
        )
    }

    // The evening's own, and the reason it exists: with one shared counter a bedtime window that
    // never opened read exactly like a morning that did. The audit does not have to run in the
    // evening — it has to run after the occurrence, and the usual moment is the next morning.
    //
    // Its own occurrence mark, deliberately not the morning's: one shared mark and the two audits
    // would cancel each other out, each finding the other's occurrence already audited.
    @discardableResult
    nonisolated static func auditBedtimeCallback(
        occurrence anchor: Date?,
        now: Date = .now,
        in defaults: UserDefaults = Self.defaults
    ) -> Bool {
        audit(
            occurrence: anchor,
            now: now,
            in: defaults,
            lastIntervalStartKey: lastBedtimeIntervalStartKey,
            lastAuditedOccurrenceKey: lastAuditedBedtimeOccurrenceKey,
            counter: .bedtimeCallbacksMissing
        )
    }

    // One implementation behind the two names: the question is identical per window, and two
    // hand-written copies are how the grace period or the check-and-set silently differs in one of
    // them. The keys and the counter are what differs, and they are arguments.
    private nonisolated static func audit(
        occurrence anchor: Date?,
        now: Date,
        in defaults: UserDefaults,
        lastIntervalStartKey: String,
        lastAuditedOccurrenceKey: String,
        counter: Counter
    ) -> Bool {
        guard let anchor,
              now.timeIntervalSince(anchor) >= callbackGraceSeconds,
              defaults.object(forKey: lastAuditedOccurrenceKey) as? Date != anchor
        else { return false }

        defaults.set(anchor, forKey: lastAuditedOccurrenceKey)

        guard let started = defaults.object(forKey: lastIntervalStartKey) as? Date, started >= anchor else {
            record(counter, in: defaults)
            return true
        }
        return false
    }

    // One line, five numbers, in the order of the morning. Deliberately not five rows and not five
    // sentences: this is an instrument, it belongs on the settings screen the way a serial number
    // does — findable when it is asked for, invisible when it is not.
    nonisolated static func morningSummary(in defaults: UserDefaults = Self.defaults) -> String {
        let registered = count(of: .morningWindowsRegistered, in: defaults)
        let started = count(of: .morningIntervalsStarted, in: defaults)
        let shielded = count(of: .morningShieldsApplied, in: defaults)
        let missing = count(of: .morningCallbacksMissing, in: defaults)
        let skipped = count(of: .weekdaysSkipped, in: defaults)
        return "\(registered) · \(started) · \(shielded) · \(missing) · \(skipped)"
    }

    // The device gate: whether a ManagedSettings write out of the app process the
    // system started in the background actually shields is an assumption nothing in this repo backs
    // and no Simulator can answer. The probe is what makes it measurable at all — the counter says
    // the background process reached the write, the observed block says the write had an effect, and
    // the two are different claims. Debug builds only: it measures the platform, not the product.
    #if DEBUG
    private static let intentShieldProbeArmedKey = "debugIntentShieldProbeArmed"
    private static let intentShieldWritesKey = "debugIntentShieldWrites"

    nonisolated static func armIntentShieldProbe(_ armed: Bool, in defaults: UserDefaults = Self.defaults) {
        defaults.set(armed, forKey: intentShieldProbeArmedKey)
    }

    nonisolated static func intentShieldProbeIsArmed(in defaults: UserDefaults = Self.defaults) -> Bool {
        defaults.bool(forKey: intentShieldProbeArmedKey)
    }

    nonisolated static func disarmIntentShieldProbe(in defaults: UserDefaults = Self.defaults) {
        defaults.removeObject(forKey: intentShieldProbeArmedKey)
    }

    nonisolated static func recordIntentShieldWrite(in defaults: UserDefaults = Self.defaults) {
        defaults.set(intentShieldWrites(in: defaults) + 1, forKey: intentShieldWritesKey)
    }

    nonisolated static func intentShieldWrites(in defaults: UserDefaults = Self.defaults) -> Int {
        defaults.integer(forKey: intentShieldWritesKey)
    }
    #endif

    // Four, not five: the evening has no weekday selection, so it has no day to skip on purpose.
    nonisolated static func bedtimeSummary(in defaults: UserDefaults = Self.defaults) -> String {
        let registered = count(of: .bedtimeWindowsRegistered, in: defaults)
        let started = count(of: .bedtimeIntervalsStarted, in: defaults)
        let shielded = count(of: .bedtimeShieldsApplied, in: defaults)
        let missing = count(of: .bedtimeCallbacksMissing, in: defaults)
        return "\(registered) · \(started) · \(shielded) · \(missing)"
    }
}
