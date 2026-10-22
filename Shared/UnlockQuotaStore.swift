import Foundation

// Either a counted quota or none at all. Plus removes the counter rather than raising it to a large
// number: a ceiling of 999 is still a ceiling somebody can hit, and it would put a number on a
// screen that is not supposed to have one.
enum UnlockAllowance: Equatable, Sendable {
    case unlimited
    case limited(Int)

    var isExhausted: Bool {
        switch self {
        case .unlimited: false
        case .limited(let remaining): remaining <= 0
        }
    }

    // nil where there is no number to show, so a caller that wants to print one has to decide what
    // to do about the case where none exists.
    var remainingCount: Int? {
        switch self {
        case .unlimited: nil
        case .limited(let remaining): remaining
        }
    }
}

// Morning and evening run the exact same quota mechanics (docs/product-decisions-2026-09-02.md,
// docs/bedtime-window-2026-09-03.md) and differ only in where their day turns over and which two
// keys they occupy. Both live in the App-Group suite, same
// container and same shape as WakeAlarmStore, so an extension can read them once the group is
// provisioned. The one extension that does is TuckShield, read-only, to pick the
// right shield copy; TuckShieldAction does not compile this file at all, and consumeUnlock
// has exactly one caller, in the app.
//
// Deliberately not a progress/streak counter: the bedtime window stays out of the mascot growth
// entirely, so the streak stays where it belongs, on MorningProgressStore alone.
struct UnlockQuotaStore {
    // Its day turns at midnight rather than at the evening's 06:00: a morning window contains 06:00
    // far more often than it contains midnight, and the hour the window crosses is the one that
    // hands out an extra refill mid-window.
    static let morning = UnlockQuotaStore(
        freeUnlockMaximum: 1,
        dayRolloverHour: 0,
        remainingUnlocksKey: "remainingUnlocksToday",
        quotaAnchorDayKey: "morningUnlockQuotaAnchorDay"
    )

    // Its day turns at 06:00 so a window that wraps past midnight (23:50-00:20) stays one evening.
    // The free number is carried anyway although the bedtime window is Plus-only: a quota that only
    // ever answers "unlimited" would silently stop being a quota, and the gating that keeps free
    // users out of the evening lives above this file, not in it.
    static let bedtime = UnlockQuotaStore(
        freeUnlockMaximum: 1,
        dayRolloverHour: 6,
        remainingUnlocksKey: "bedtimeRemainingUnlocks",
        quotaAnchorDayKey: "bedtimeUnlockQuotaAnchorDay"
    )

    // The permanent free baseline, not a fallback for an unresolved tier: one emergency unlock per
    // day, at the same 30 s plus reason everybody else pays.
    let freeUnlockMaximum: Int
    // Internal rather than private so the memberwise initialiser stays reachable from the tests:
    // UnlockQuotaConcurrencyTests needs a quota with more slots than the product grants, or the
    // interleaving it exists to provoke cannot happen at all.
    let dayRolloverHour: Int
    let remainingUnlocksKey: String
    let quotaAnchorDayKey: String

    private nonisolated static var defaults: UserDefaults {
        UserDefaults(suiteName: TuckIdentifiers.appGroupSuiteName) ?? .standard
    }

    // The only read a gate may use. `remainingUnlocks` below counts, and a count is meaningless for
    // somebody the counter does not apply to — everything that decides whether an unlock is
    // available goes through here.
    nonisolated func allowance(
        now: Date = .now,
        calendar: Calendar = .current,
        in defaults: UserDefaults = Self.defaults
    ) -> UnlockAllowance {
        guard !SubscriptionAccess.current(now: now, in: defaults).hasPlusAccess else { return .unlimited }
        return .limited(remainingUnlocks(now: now, calendar: calendar, in: defaults))
    }

    // Derived from `now` and this store's own rollover hour, and nothing else — the reason that
    // matters, and the reason the computation itself lives in Shared/QuotaAnchorDay.swift where no
    // store is in reach, is written there.
    nonisolated func quotaAnchorDay(now: Date, calendar: Calendar = .current) -> Int {
        unlockQuotaAnchorDay(now: now, rolloverHour: dayRolloverHour, calendar: calendar)
    }

    // The refill is lazy and computed on read rather than written by a callback: the evening has no
    // user action to hang it on — nobody dismisses a bedtime — and making it depend on
    // intervalDidEnd firing would import exactly the unverified-callback risk section 4 of the
    // bedtime doc warns about. A fresh install has never spent an unlock, so nothing has written
    // the quota yet — it still starts full rather than at zero.
    //
    // The counted balance, and only that: it says nothing about whether the count applies. Read it
    // through `allowance` for any decision — a Plus user has a stale number here from whatever they
    // spent while free, and acting on it would re-impose a ceiling they no longer have.
    //
    // Upgrading no longer re-arms anything either way (trivially true: the counter stops being
    // consulted rather than growing), and a lapse takes effect immediately — the clamp against
    // `freeUnlockMaximum` can only ever lower a stored count, never raise one.
    nonisolated func remainingUnlocks(
        now: Date = .now,
        calendar: Calendar = .current,
        in defaults: UserDefaults = Self.defaults
    ) -> Int {
        guard let storedDay = defaults.object(forKey: quotaAnchorDayKey) as? Int,
              storedDay == quotaAnchorDay(now: now, calendar: calendar),
              let remaining = defaults.object(forKey: remainingUnlocksKey) as? Int
        else { return freeUnlockMaximum }
        return min(remaining, freeUnlockMaximum)
    }

    // No re-arm inside a window, and an exhausted quota stays exhausted rather than going
    // negative and silently granting more once the next day resets it.
    //
    // The read and the write are one critical section: unguarded, two callers read the same count
    // and both write the same decrement, and one unlock is handed out without being paid for.
    // Measured, not theorised — five concurrent callers against one five-slot quota spent as few as
    // one slot (TuckTests/UnlockQuotaConcurrencyTests.swift). Those five are threads in one
    // process, which is what the lock earns its place with today: no extension decrements, and
    // consumeUnlock has exactly one caller, OverrideFlowView. The cross-process case is the one
    // a provisioned App Group adds, not the one this guards against now.
    nonisolated func consumeUnlock(
        now: Date = .now,
        calendar: Calendar = .current,
        in defaults: UserDefaults = Self.defaults
    ) {
        Self.withQuotaLock {
            // Unlimited access writes nothing at all rather than decrementing a number nobody
            // reads: a counter kept warm in the background is a counter that starts applying again
            // the moment somebody forgets to ask whether it should.
            guard case .limited(let remaining) = allowance(now: now, calendar: calendar, in: defaults),
                  remaining > 0
            else { return }
            // Count first, anchor second. Readers deliberately do not take the lock — the shield's
            // configuration extension reads this to draw every block screen — so they can land
            // between the two writes. In this order the worst they see is a spend not yet counted;
            // in the other order they see today's anchor beside yesterday's leftover count, which
            // reports a full quota as exhausted.
            defaults.set(remaining - 1, forKey: remainingUnlocksKey)
            defaults.set(quotaAnchorDay(now: now, calendar: calendar), forKey: quotaAnchorDayKey)
        }
    }

    // UserDefaults cannot do this on its own and no retry loop can rescue it: the entire API
    // surface is objectForKey and setObject (SDK NSUserDefaults.h) with nothing between them, so a
    // lost update is not detectable from inside, let alone re-doable. What UserDefaults does give
    // is cross-process freshness — the header's own advice for anyone who "synchronized before
    // reading in order to fetch updated values" is to delete the call — so a reader that already
    // holds the lock sees every write that finished before it. That is what makes a plain mutex
    // sufficient here and a compare-and-set impossible.
    //
    // flock on a file in the App-Group container is the one mutex two processes over one suite can
    // take, which is why it was chosen and why it still fits once the group is provisioned. It is
    // held per open file description, so two threads inside one process exclude each other the same
    // way, and the kernel releases it when the holder dies — an extension killed mid-unlock cannot
    // strand the quota. If the lock cannot be taken at all this falls through to the unguarded
    // write rather than dropping the unlock: the user already paid the delay for it, and a race is
    // the lesser of those two. Same fallback shape as `defaults` above, for the same reason.
    private nonisolated static func withQuotaLock<T>(_ body: () -> T) -> T {
        let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: TuckIdentifiers.appGroupSuiteName)
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let descriptor = open(container.appendingPathComponent("unlockQuota.lock").path, O_CREAT | O_RDWR, 0o644)
        guard descriptor >= 0 else { return body() }
        defer { close(descriptor) }

        while flock(descriptor, LOCK_EX) != 0 {
            guard errno == EINTR else { return body() }
        }
        defer { flock(descriptor, LOCK_UN) }

        return body()
    }
}
