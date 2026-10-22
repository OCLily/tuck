import Foundation

// What a user is allowed to do right now, resolved from two independent sources: a confirmed
// entitlement and a trial that runs on wall-clock time. Kept apart from SubscriptionTier because a
// trial grants the same capabilities without any tier ever having been bought — collapsing the two
// would mean writing a tier nobody paid for into the cache the quota reads.
enum SubscriptionAccess: Equatable, Sendable {
    case free
    case trial(daysRemaining: Int)
    case subscribed(SubscriptionTier)

    // The single question every gate asks. Bedtime access and the missing unlock ceiling both hang
    // off this and nothing else, so a trial cannot drift into being a partial Plus.
    var hasPlusAccess: Bool {
        switch self {
        case .free: false
        case .trial, .subscribed: true
        }
    }

    // The entitlement outranks the trial: someone who subscribes on day three keeps Plus when day
    // fourteen passes, and the trial timestamp is never touched by a purchase.
    nonisolated static func current(
        now: Date = .now,
        in defaults: UserDefaults = UserDefaults(suiteName: TuckIdentifiers.appGroupSuiteName) ?? .standard
    ) -> SubscriptionAccess {
        if let tier = SubscriptionTierStore.cachedTier(in: defaults) { return .subscribed(tier) }
        guard case .active(let daysRemaining) = TrialStore.state(now: now, in: defaults) else { return .free }
        return .trial(daysRemaining: daysRemaining)
    }
}

enum TrialState: Equatable, Sendable {
    case active(daysRemaining: Int)
    case expired

    var isActive: Bool {
        switch self {
        case .active: true
        case .expired: false
        }
    }
}

// Same App-Group suite and the same injectable-defaults shape as MorningBlockDurationStore and
// BedtimeStore. One `Date`, written once and never again.
enum TrialStore {
    static let lengthInDays = 14

    private static let startedAtKey = "trialStartedAt"

    private nonisolated static var defaults: UserDefaults {
        UserDefaults(suiteName: TuckIdentifiers.appGroupSuiteName) ?? .standard
    }

    nonisolated static func startedAt(in defaults: UserDefaults = Self.defaults) -> Date? {
        defaults.object(forKey: startedAtKey) as? Date
    }

    // Idempotent by construction, because every call site is a path that runs again and again: an
    // existing timestamp is returned untouched, so nothing but a fresh install can restart the
    // fourteen days. That property is also the whole migration story for the move of the
    // trigger — an install that already wrote this key under the launch rule keeps the timestamp it
    // has, whether the fourteen days are still running or long over.
    @discardableResult
    nonisolated static func startIfNeeded(
        now: Date = .now,
        in defaults: UserDefaults = Self.defaults
    ) -> Date {
        if let started = startedAt(in: defaults) { return started }
        defaults.set(now, forKey: startedAtKey)
        return now
    }

    // An unstarted trial reads as expired rather than as active, and this function never starts
    // one: it is called from the shield extensions too, and a trial that began because a system
    // process drew a block screen would be counting down before the user ever launched the app.
    nonisolated static func state(
        now: Date = .now,
        calendar: Calendar = .current,
        in defaults: UserDefaults = Self.defaults
    ) -> TrialState {
        guard let startedAt = startedAt(in: defaults),
              let endsAt = calendar.date(byAdding: .day, value: lengthInDays, to: startedAt),
              now < endsAt
        else { return .expired }

        // Rounded up, so the last partial day still reads as one day rather than as zero — a
        // countdown that reaches zero while access is still granted would be the same overclaim in
        // the other direction.
        let days = Int((endsAt.timeIntervalSince(now) / 86_400).rounded(.up))
        return .active(daysRemaining: max(1, days))
    }
}

// The one place that may start the clock. Before it existed the call site was the app's own
// launch task, which measured the fourteen days from an event the user has no stake in: somebody who
// opens the app, declines the Screen Time prompt and returns three weeks later had a trial run out
// without ever seeing what it grants. The clock now starts where the product first says no.
//
// Deliberately not "the paywall was opened": the paywall is reachable from a settings row, and
// tapping a row labelled "Abo" out of curiosity on day one is the same non-event as launching.
enum TrialTrigger {
    // Two boundaries exist and either can be the first one somebody meets — the evening window
    // (BedtimeSetupView) and the daily unlock ceiling (OverrideFlowView). Hanging the start on the
    // bedtime gate alone would leave the ceiling without a trigger, and a user who never opens the
    // bedtime screen would sit at one unlock a day forever while the paywall keeps describing a
    // trial they can no longer reach.
    //
    // Idempotent because startIfNeeded is, and that now carries more weight than it did: both call
    // sites run on every appearance of their screen, so the second contact and the two-hundredth
    // return the timestamp the first one wrote.
    @discardableResult
    nonisolated static func plusBoundaryReached(
        now: Date = .now,
        in defaults: UserDefaults = UserDefaults(suiteName: TuckIdentifiers.appGroupSuiteName) ?? .standard
    ) -> SubscriptionAccess {
        TrialStore.startIfNeeded(now: now, in: defaults)
        return SubscriptionAccess.current(now: now, in: defaults)
    }
}

// The three moments the fourteen days are worth a sentence about, and nothing else: they
// started, they are nearly over, they are over. Until now the trial began, ran and ended without the
// app ever saying so — the countdown existed on the paywall and in one settings row, i.e. exactly
// where somebody already knows what they are looking at.
//
// Decision only, no copy: the wording lives with the screen that draws it (Tuck/PaywallView.swift),
// because this file is compiled into the shield extensions too and they have neither a catalog for
// it nor a surface to show it on.
//
// What it is deliberately not: a countdown. Each notice is shown once, is a statement rather than a
// prompt, and none of them is repeated on the next visit — a number that reappears every morning is
// the pressure mechanism the app rules out, not information.
enum TrialNotice: String, CaseIterable, Sendable {
    case started
    case nearingEnd
    case ended

    // Day twelve of fourteen, expressed in the unit the app already counts in: TrialStore rounds the
    // remaining days up, so a trial started on day one first reads 3 on day twelve.
    static let nearingEndDaysRemaining = 3

    private static func acknowledgedKey(_ notice: TrialNotice) -> String {
        "trialNoticeAcknowledged.\(notice.rawValue)"
    }

    nonisolated static func hasBeenShown(
        _ notice: TrialNotice,
        in defaults: UserDefaults = UserDefaults(suiteName: TuckIdentifiers.appGroupSuiteName) ?? .standard
    ) -> Bool {
        defaults.bool(forKey: acknowledgedKey(notice))
    }

    // Pure: a screen may ask what is due without that answer being spent. `consume` below is the one
    // that marks it, and it is the only thing a view calls.
    nonisolated static func due(
        now: Date = .now,
        calendar: Calendar = .current,
        in defaults: UserDefaults = UserDefaults(suiteName: TuckIdentifiers.appGroupSuiteName) ?? .standard
    ) -> TrialNotice? {
        // Nothing to say about a trial that never started, and nothing at all to a subscriber: an
        // expiry notice to somebody who is paying would state the opposite of their access,
        // and it is also the one place where a notice would read as a sales pitch. Read from the
        // cached tier rather than from `SubscriptionAccess.current`, which cannot tell a subscriber
        // apart from someone whose trial is simply still running.
        guard TrialStore.startedAt(in: defaults) != nil,
              SubscriptionTierStore.cachedTier(in: defaults) == nil
        else { return nil }

        switch TrialStore.state(now: now, calendar: calendar, in: defaults) {
        case .active(let daysRemaining):
            // The later state wins over the earlier one, unshown or not: somebody who first opens a
            // gated screen on day twelve gets "nearly over", never a welcome to fourteen days that
            // are almost gone. A notice may not describe a state that has passed.
            let notice: TrialNotice = daysRemaining <= nearingEndDaysRemaining ? .nearingEnd : .started
            return hasBeenShown(notice, in: defaults) ? nil : notice
        case .expired:
            return hasBeenShown(.ended, in: defaults) ? nil : .ended
        }
    }

    // Read and mark in one call, because the two halves apart are how a notice ends up shown twice
    // or never — the same reason UnlockBooking exists.
    nonisolated static func consume(
        now: Date = .now,
        calendar: Calendar = .current,
        in defaults: UserDefaults = UserDefaults(suiteName: TuckIdentifiers.appGroupSuiteName) ?? .standard
    ) -> TrialNotice? {
        guard let notice = due(now: now, calendar: calendar, in: defaults) else { return nil }
        defaults.set(true, forKey: acknowledgedKey(notice))
        return notice
    }
}
