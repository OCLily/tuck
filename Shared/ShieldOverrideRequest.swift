import Foundation

// The one thing that crosses from the shield-action extension into the app: the app
// is opened by iOS, not by a URL, so nothing about the tap arrives with it. A single App-Group
// UserDefaults write, read once and cleared, in the same container and the same shape as every
// other store here — no URL scheme, no Darwin notification, no shared file.
//
// It carries no permission. Spending an unlock stays entirely inside OverrideFlowView's own timer,
// which is what keeps the hard constraint intact: delay AND justification, never either alone.
enum ShieldOverrideRequest {
    struct Pending: Equatable {
        // nil when the secondary button itself was pressed rather than one of its submenu items.
        // Whether a shield with submenu items still delivers .secondaryButtonPressed is not
        // documented and not observable in the Simulator, so both shapes have to be representable.
        let reason: OverrideReason?
    }

    // Long enough for a cold launch on a slow device, short enough that a tap from yesterday
    // morning cannot open an override sheet the user did not ask for today.
    private static let validity: TimeInterval = 5 * 60

    private static let reasonKey = "shieldOverrideRequestReason"
    private static let requestedAtKey = "shieldOverrideRequestedAt"

    private nonisolated static var defaults: UserDefaults {
        UserDefaults(suiteName: TuckIdentifiers.appGroupSuiteName) ?? .standard
    }

    nonisolated static func record(
        reason: OverrideReason?,
        now: Date = .now,
        in defaults: UserDefaults = Self.defaults
    ) {
        defaults.set(reason?.rawValue, forKey: reasonKey)
        defaults.set(now, forKey: requestedAtKey)
    }

    // Reads and clears in one step: a request is answered by opening the sheet once. Leaving it in
    // place would re-open the override on the next foregrounding, which is exactly the kind of
    // unasked-for screen the shield path exists to avoid.
    //
    // The clear sits on the success path alone. As a `defer` it also ran on `return nil`, which
    // deleted a request this read had not consumed — and the app calls this on every foregrounding,
    // so "found nothing" is the common case. A write the app cannot see yet is exactly what the
    // five minutes above exist for: it has to survive to the next read, not be erased by the one
    // that missed it.
    nonisolated static func take(
        now: Date = .now,
        in defaults: UserDefaults = Self.defaults
    ) -> Pending? {
        guard let requestedAt = defaults.object(forKey: requestedAtKey) as? Date,
              now.timeIntervalSince(requestedAt) >= 0,
              now.timeIntervalSince(requestedAt) <= validity
        else { return nil }

        let pending = Pending(reason: defaults.string(forKey: reasonKey).flatMap(OverrideReason.init(rawValue:)))
        clear(in: defaults)
        return pending
    }

    nonisolated static func clear(in defaults: UserDefaults = Self.defaults) {
        defaults.removeObject(forKey: reasonKey)
        defaults.removeObject(forKey: requestedAtKey)
    }
}
