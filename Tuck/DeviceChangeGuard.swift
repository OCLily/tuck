import Foundation

// A new iPhone restored from this one's backup
// arrives with the whole App Group — the alarm, the window, `morningBlockRegistrationSucceeded` at
// true and a FamilyActivitySelection whose ApplicationTokens belong to the old device. Nothing in
// that state is detectably wrong from the inside: the shield write succeeds, TokenRefresh hands the
// stale tokens back unchanged (Shared/TokenRefresh.swift — a refresh that would empty the set is
// treated as "no refresh happened", which is right for an expiry and cannot tell a foreign device
// apart), and the screen keeps saying "Sperrfenster bis 07:30" over apps that all open.
//
// That is the one thing this app must never do. So the selection is dropped and both windows lose
// their confirmation, which puts the screen on the branches it already has for it —
// StatusCopy.windowPending until the reconciler re-arms, then StatusCopy.windowWithoutApps until
// the user picks apps again. The stored alarm and bedtime stay: they are the user's intent, not a
// claim about a block, exactly the split reconcile() makes when authorization is revoked.
//
// App target only, not Shared: the picker that repairs the state lives in the app, the App Group
// is only ever written by a process that the app has launched at least once, and no extension can
// do anything with the answer.
enum DeviceChangeGuard {
    static let lastKnownDeviceIdentityKey = "lastKnownDeviceIdentity"

    enum Action: Equatable {
        case leave
        case adopt
        case invalidate
    }

    // Pure, so every branch is reachable without a second physical device.
    static func action(deviceIdentity: String?, lastKnown: String?, hasStoredSelection: Bool) -> Action {
        // No readable identity means the keychain itself failed, and a keychain failure says
        // nothing about which device this is. Wiping the selection on it would turn a transient
        // fault into a repeating loss of the user's setup — the one direction that is worse than
        // the state this guard exists to catch, because it is silent AND recurring.
        guard let deviceIdentity else { return .leave }
        guard let lastKnown else {
            // No recorded identity next to a selection that exists: either the defaults were
            // restored onto a device that never wrote one, or this build is the first to record it
            // at all. The two are indistinguishable from here, so the honest reading is the unsafe
            // one — it costs an existing user one trip through the picker, once.
            return hasStoredSelection ? .invalidate : .adopt
        }
        return lastKnown == deviceIdentity ? .leave : .invalidate
    }

    @discardableResult
    static func run(
        keychain: DeviceIdentityKeychain = SystemDeviceIdentityKeychain(),
        in defaults: UserDefaults = UserDefaults(suiteName: TuckIdentifiers.appGroupSuiteName) ?? .standard
    ) -> Action {
        let identity = DeviceIdentity.current(keychain: keychain)
        let decision = action(
            deviceIdentity: identity,
            lastKnown: defaults.string(forKey: lastKnownDeviceIdentityKey),
            hasStoredSelection: FamilyActivitySelectionStore.hasStoredSelection(in: defaults)
        )

        switch decision {
        case .leave:
            break
        case .adopt:
            defaults.set(identity, forKey: lastKnownDeviceIdentityKey)
        case .invalidate:
            FamilyActivitySelectionStore.clear(in: defaults)
            WakeAlarmStore.recordBlockRegistration(succeeded: false, in: defaults)
            BedtimeStore.recordBlockRegistration(succeeded: false, in: defaults)
            // Last, after the three writes above: if the process dies in between, the identity is
            // still unrecorded and the next launch redoes the same invalidation. Recording first
            // would leave a half-cleared state that looks settled.
            defaults.set(identity, forKey: lastKnownDeviceIdentityKey)
        }

        return decision
    }

    // Called wherever a selection is written, so the identity and the tokens it belongs to are
    // recorded together. A keychain that cannot answer records nothing rather than a wrong value:
    // the missing entry is read as "unknown, invalidate" later, which errs towards the honest side.
    static func recordCurrentDevice(
        keychain: DeviceIdentityKeychain = SystemDeviceIdentityKeychain(),
        in defaults: UserDefaults = UserDefaults(suiteName: TuckIdentifiers.appGroupSuiteName) ?? .standard
    ) {
        guard let identity = DeviceIdentity.current(keychain: keychain) else { return }
        defaults.set(identity, forKey: lastKnownDeviceIdentityKey)
    }
}
