import Testing
import Foundation
import FamilyControls
import Security
@testable import Tuck

// The fake stands in for the one thing a restore changes and a UserDefaults suite does not: the
// keychain slot is empty on the new device while the App Group arrives complete.
private final class FakeKeychain: DeviceIdentityKeychain, @unchecked Sendable {
    var stored: String?
    var acceptsWrites = true
    // A read that fails over an item that is there — errSecInteractionNotAllowed and its siblings.
    // The fake originally could not express this, which is precisely why 18 green tests sat
    // on top of a defect: `identity() -> String?` had one nil for "empty" and "unreachable" both.
    var readsAreUnreadable = false
    private(set) var writes = 0

    init(stored: String? = nil) {
        self.stored = stored
    }

    func identity() -> DeviceIdentityLookup {
        if readsAreUnreadable { return .unreadable }
        guard let stored else { return .absent }
        return .found(stored)
    }

    func store(_ identity: String) -> Bool {
        writes += 1
        guard acceptsWrites else { return false }
        stored = identity
        return true
    }
}

struct DeviceChangeGuardTests {
    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suite = "DeviceChangeGuardTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        body(defaults)
    }

    private func armedDevice(_ defaults: UserDefaults) {
        FamilyActivitySelectionStore.save(FamilyActivitySelection(), in: defaults)
        WakeAlarmStore.recordBlockRegistration(succeeded: true, in: defaults)
        BedtimeStore.recordBlockRegistration(succeeded: true, in: defaults)
    }

    // MARK: - The decision, without any storage

    @Test func theSameIdentityOnBothSidesChangesNothing() {
        #expect(
            DeviceChangeGuard.action(deviceIdentity: "A", lastKnown: "A", hasStoredSelection: true) == .leave
        )
    }

    @Test func aDifferentIdentityInvalidates() {
        #expect(
            DeviceChangeGuard.action(deviceIdentity: "B", lastKnown: "A", hasStoredSelection: true) == .invalidate
        )
    }

    // The restore case has a second shape: the App Group can also arrive from a build that never
    // wrote an identity. A selection without one is unattributable, so it is not trusted.
    @Test func aSelectionWithoutARecordedIdentityIsNotTrusted() {
        #expect(
            DeviceChangeGuard.action(deviceIdentity: "B", lastKnown: nil, hasStoredSelection: true) == .invalidate
        )
    }

    @Test func aFreshInstallOnlyRecordsItself() {
        #expect(
            DeviceChangeGuard.action(deviceIdentity: "A", lastKnown: nil, hasStoredSelection: false) == .adopt
        )
    }

    // A keychain that cannot answer says nothing about which device this is. Wiping on it would
    // turn one transient fault into a repeating loss of the user's setup.
    @Test func anUnreadableKeychainNeverCostsTheSelection() {
        #expect(
            DeviceChangeGuard.action(deviceIdentity: nil, lastKnown: "A", hasStoredSelection: true) == .leave
        )
        #expect(
            DeviceChangeGuard.action(deviceIdentity: nil, lastKnown: nil, hasStoredSelection: true) == .leave
        )
    }

    // MARK: - The normal case: same device, nothing is touched

    @Test func aSecondLaunchOnTheSameDeviceKeepsEverything() {
        withDefaults { defaults in
            let keychain = FakeKeychain()
            armedDevice(defaults)
            DeviceChangeGuard.recordCurrentDevice(keychain: keychain, in: defaults)

            let decision = DeviceChangeGuard.run(keychain: keychain, in: defaults)

            #expect(decision == .leave)
            #expect(FamilyActivitySelectionStore.load(from: defaults) != nil)
            #expect(WakeAlarmStore.blockRegistrationSucceeded(in: defaults))
            #expect(BedtimeStore.blockRegistrationSucceeded(in: defaults))
        }
    }

    @Test func repeatedPassesOnTheSameDeviceStayAtLeave() {
        withDefaults { defaults in
            let keychain = FakeKeychain()
            armedDevice(defaults)
            DeviceChangeGuard.recordCurrentDevice(keychain: keychain, in: defaults)

            #expect(DeviceChangeGuard.run(keychain: keychain, in: defaults) == .leave)
            #expect(DeviceChangeGuard.run(keychain: keychain, in: defaults) == .leave)
            #expect(FamilyActivitySelectionStore.load(from: defaults) != nil)
        }
    }

    // The identity is minted once and then read, not re-minted per launch — a new UUID on every
    // pass would make every launch look like a device change.
    @Test func theIdentityIsMintedOnceAndKept() {
        let keychain = FakeKeychain()
        let first = DeviceIdentity.current(keychain: keychain)
        let second = DeviceIdentity.current(keychain: keychain)

        #expect(first != nil)
        #expect(first == second)
        #expect(keychain.writes == 1)
    }

    // MARK: - The device change

    // The restore, end to end: the App Group is copied over wholesale, the keychain slot is not.
    @Test func aRestoredAppGroupOnANewDeviceLosesItsTokensAndItsClaims() {
        withDefaults { oldDevice in
            let oldKeychain = FakeKeychain()
            armedDevice(oldDevice)
            DeviceChangeGuard.recordCurrentDevice(keychain: oldKeychain, in: oldDevice)
            let restored = oldDevice

            // ThisDeviceOnly: the new device starts with an empty slot and mints its own.
            let newKeychain = FakeKeychain()
            let decision = DeviceChangeGuard.run(keychain: newKeychain, in: restored)

            #expect(decision == .invalidate)
            #expect(FamilyActivitySelectionStore.load(from: restored) == nil)
            #expect(FamilyActivitySelectionStore.selectedActivityCount(in: restored) == 0)
            #expect(WakeAlarmStore.blockRegistrationSucceeded(in: restored) == false)
            #expect(BedtimeStore.blockRegistrationSucceeded(in: restored) == false)
            #expect(newKeychain.stored != oldKeychain.stored)
        }
    }

    // Once, not on every launch: the second pass on the new device must find the state settled,
    // or a user who picks apps again loses them at the next foreground.
    @Test func theInvalidationHappensOnceAndThenSettles() {
        withDefaults { defaults in
            armedDevice(defaults)
            DeviceChangeGuard.recordCurrentDevice(keychain: FakeKeychain(), in: defaults)

            let newKeychain = FakeKeychain()
            #expect(DeviceChangeGuard.run(keychain: newKeychain, in: defaults) == .invalidate)

            FamilyActivitySelectionStore.save(FamilyActivitySelection(), in: defaults)
            DeviceChangeGuard.recordCurrentDevice(keychain: newKeychain, in: defaults)

            #expect(DeviceChangeGuard.run(keychain: newKeychain, in: defaults) == .leave)
            #expect(FamilyActivitySelectionStore.load(from: defaults) != nil)
        }
    }

    // The alarm and the bedtime are the user's intent, not a claim about a block — same split the
    // reconciler makes when authorization is revoked. Only the confirmation goes.
    @Test func theStoredWindowsSurviveTheInvalidation() {
        withDefaults { defaults in
            let window = MorningBlockWindow(
                alarmTime: Date(timeIntervalSince1970: 1_757_400_000),
                duration: .seconds(1800),
                calendar: .current
            )
            WakeAlarmStore.store(id: UUID(), fireDate: .now, window: window, in: defaults)
            armedDevice(defaults)
            DeviceChangeGuard.recordCurrentDevice(keychain: FakeKeychain(), in: defaults)

            DeviceChangeGuard.run(keychain: FakeKeychain(), in: defaults)

            #expect(WakeAlarmStore.scheduledAlarm(in: defaults) != nil)
            #expect(WakeAlarmStore.blockRegistrationSucceeded(in: defaults) == false)
        }
    }

    // The eighth combination of action(), once untested: a device change on a phone
    // that never picked apps. There is no selection to clear, but the two confirmations still have
    // to fall — a `true` that travelled in with the App Group is a claim about a block that this
    // device's tokens cannot back, exactly as worthless as the tokens themselves.
    @Test func aDeviceChangeWithoutASelectionStillDropsTheClaims() {
        #expect(
            DeviceChangeGuard.action(deviceIdentity: "A", lastKnown: "B", hasStoredSelection: false) == .invalidate
        )

        withDefaults { defaults in
            WakeAlarmStore.recordBlockRegistration(succeeded: true, in: defaults)
            BedtimeStore.recordBlockRegistration(succeeded: true, in: defaults)
            defaults.set("the-phone-this-came-from", forKey: DeviceChangeGuard.lastKnownDeviceIdentityKey)

            let keychain = FakeKeychain()
            #expect(DeviceChangeGuard.run(keychain: keychain, in: defaults) == .invalidate)

            #expect(FamilyActivitySelectionStore.hasStoredSelection(in: defaults) == false)
            #expect(WakeAlarmStore.blockRegistrationSucceeded(in: defaults) == false)
            #expect(BedtimeStore.blockRegistrationSucceeded(in: defaults) == false)
            // And it settles: the identity is recorded, so the next launch reads .leave.
            #expect(defaults.string(forKey: DeviceChangeGuard.lastKnownDeviceIdentityKey) == keychain.stored)
            #expect(DeviceChangeGuard.run(keychain: keychain, in: defaults) == .leave)
        }
    }

    // A keychain write that fails leaves nothing recorded, so the next pass re-decides rather than
    // trusting a value that was never stored.
    @Test func aKeychainThatCannotWriteRecordsNothing() {
        withDefaults { defaults in
            let keychain = FakeKeychain()
            keychain.acceptsWrites = false

            DeviceChangeGuard.recordCurrentDevice(keychain: keychain, in: defaults)

            #expect(defaults.string(forKey: DeviceChangeGuard.lastKnownDeviceIdentityKey) == nil)
        }
    }

    @Test func aDeadKeychainLeavesAnArmedDeviceAlone() {
        withDefaults { defaults in
            armedDevice(defaults)
            DeviceChangeGuard.recordCurrentDevice(keychain: FakeKeychain(), in: defaults)

            let dead = FakeKeychain()
            dead.acceptsWrites = false

            #expect(DeviceChangeGuard.run(keychain: dead, in: defaults) == .leave)
            #expect(FamilyActivitySelectionStore.load(from: defaults) != nil)
        }
    }

    // A read that cannot answer must not be answered with a new identity: nothing is recorded, and
    // above all nothing is written over the identity that is still sitting in the slot.
    @Test func anUnreadableKeychainRecordsNothingAndOverwritesNothing() {
        withDefaults { defaults in
            let keychain = FakeKeychain(stored: "the-identity-this-phone-recorded")
            keychain.readsAreUnreadable = true

            DeviceChangeGuard.recordCurrentDevice(keychain: keychain, in: defaults)

            #expect(defaults.string(forKey: DeviceChangeGuard.lastKnownDeviceIdentityKey) == nil)
            #expect(keychain.stored == "the-identity-this-phone-recorded")
            #expect(keychain.writes == 0)
        }
    }

    // Corrupt selection data is still evidence that the user went through the picker, so it counts
    // as a selection here — otherwise a restore carrying unreadable data would be adopted silently.
    @Test func unreadableSelectionDataStillCountsAsASelection() {
        withDefaults { defaults in
            defaults.set(Data([0x00, 0x01]), forKey: TuckIdentifiers.familyActivitySelectionDefaultsKey)

            #expect(FamilyActivitySelectionStore.hasStoredSelection(in: defaults))
            #expect(FamilyActivitySelectionStore.load(from: defaults) == nil)
            #expect(DeviceChangeGuard.run(keychain: FakeKeychain(), in: defaults) == .invalidate)
        }
    }

    @Test func nothingStoredIsNotASelection() {
        withDefaults { defaults in
            #expect(FamilyActivitySelectionStore.hasStoredSelection(in: defaults) == false)
        }
    }

    // MARK: - Der Fund, gefixt und gedeckt (siehe docs/audit-log.md)
    //
    // The keychain this fake stands for is the worst one the app could be handed: a read that fails
    // over an item that is there, and a store() that throws the old value away before it finds out
    // whether the new one lands. The second half was SystemDeviceIdentityKeychain until the fix
    // (an unconditional SecItemDelete before SecItemAdd) and is not any more — the fake keeps it on
    // purpose, because the identity now survives a fault even against a destructive write: an
    // unreadable read no longer triggers a write at all.
    private final class DeleteThenAddKeychain: DeviceIdentityKeychain, @unchecked Sendable {
        var stored: String?
        var acceptsWrites = true
        var unreadableReads = 0

        init(stored: String? = nil) { self.stored = stored }

        func identity() -> DeviceIdentityLookup {
            if unreadableReads > 0 {
                unreadableReads -= 1
                return .unreadable
            }
            guard let stored else { return .absent }
            return .found(stored)
        }

        func store(_ identity: String) -> Bool {
            stored = nil
            guard acceptsWrites else { return false }
            stored = identity
            return true
        }
    }

    // The damage is deferred by one launch, which is why the suite above cannot see it. Launch 1 has
    // a keychain that can neither read nor write: the guard reads .leave, exactly as designed — but
    // store() has already deleted the identity it could not replace. Launch 2 has a perfectly
    // healthy keychain on the same physical phone, finds an empty slot, mints a new UUID, and the
    // guard compares that against the lastKnown the App Group still holds. Different -> .invalidate.
    // The user's block list is gone and nothing about the device ever changed.
    @Test func aTransientKeychainFaultCostsTheSelectionOnTheNextLaunch() {
        withDefaults { defaults in
            let keychain = DeleteThenAddKeychain()
            armedDevice(defaults)
            DeviceChangeGuard.recordCurrentDevice(keychain: keychain, in: defaults)
            let identityBeforeTheFault = keychain.stored
            #expect(identityBeforeTheFault != nil)

            keychain.unreadableReads = 1
            keychain.acceptsWrites = false
            #expect(DeviceChangeGuard.run(keychain: keychain, in: defaults) == .leave)

            // The contract DeviceChangeGuard.swift:32-35 states for itself: a keychain fault says
            // nothing about which device this is, so it may not cost the setup. It is the layer
            // below that breaks it — the identity is already gone here.
            #expect(keychain.stored == identityBeforeTheFault)

            keychain.acceptsWrites = true
            #expect(DeviceChangeGuard.run(keychain: keychain, in: defaults) == .leave)
            #expect(FamilyActivitySelectionStore.load(from: defaults) != nil)
            #expect(WakeAlarmStore.blockRegistrationSucceeded(in: defaults))
        }
    }
}

// The real keychain, on the one attribute the whole fix rests on: without ThisDeviceOnly the item
// travels with the iCloud backup and arrives on the new device together with the stale tokens,
// which is exactly the comparison this is supposed to break.
//
// .serialized: every test here drives the single real keychain item at
// SystemDeviceIdentityKeychain.service/.account, and Swift Testing runs tests in parallel by
// default — the three below already shared that item and passed only by timing.
@Suite(.serialized)
struct SystemDeviceIdentityKeychainTests {
    private func cleanSlate() {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: SystemDeviceIdentityKeychain.service,
            kSecAttrAccount as String: SystemDeviceIdentityKeychain.account,
        ] as CFDictionary)
    }

    @Test func theIdentityRoundTripsThroughTheRealKeychain() {
        cleanSlate()
        defer { cleanSlate() }
        let keychain = SystemDeviceIdentityKeychain()
        let written = UUID().uuidString

        #expect(keychain.store(written))
        #expect(keychain.identity() == .found(written))
    }

    // The other half of the distinction, and the one that keeps the guard alive at all: an empty
    // slot has to read as .absent, or current() never mints and every device looks unreadable
    // forever — a fix that only ever answered .unreadable would pass the four tests below.
    @Test func anEmptySlotIsAbsentAndIsMintedInto() throws {
        cleanSlate()
        defer { cleanSlate() }

        #expect(SystemDeviceIdentityKeychain().identity() == .absent)

        let minted = try #require(DeviceIdentity.current(keychain: SystemDeviceIdentityKeychain()))
        #expect(SystemDeviceIdentityKeychain().identity() == .found(minted))
    }

    @Test func theStoredItemIsMarkedThisDeviceOnly() {
        cleanSlate()
        defer { cleanSlate() }
        #expect(SystemDeviceIdentityKeychain().store(UUID().uuidString))

        var item: CFTypeRef?
        let status = SecItemCopyMatching([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: SystemDeviceIdentityKeychain.service,
            kSecAttrAccount as String: SystemDeviceIdentityKeychain.account,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ] as CFDictionary, &item)

        #expect(status == errSecSuccess)
        let accessible = (item as? [String: Any])?[kSecAttrAccessible as String] as? String
        #expect(accessible == (kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String))
    }

    // A second store overwrites rather than piling up duplicates that SecItemCopyMatching would
    // then resolve in an unspecified order.
    @Test func storingTwiceLeavesOneItem() {
        cleanSlate()
        defer { cleanSlate() }
        let keychain = SystemDeviceIdentityKeychain()
        #expect(keychain.store("first"))
        #expect(keychain.store("second"))

        var item: CFTypeRef?
        let status = SecItemCopyMatching([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: SystemDeviceIdentityKeychain.service,
            kSecAttrAccount as String: SystemDeviceIdentityKeychain.account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ] as CFDictionary, &item)

        #expect(status == errSecSuccess)
        #expect((item as? [Data])?.count == 1)
        #expect(keychain.identity() == .found("second"))
    }

    // MARK: - Der Fund, gefixt und gedeckt (siehe docs/audit-log.md)
    //
    // The same finding as the fake-based one above, on the real type and with no fake in the way:
    // an item that is present and reads back cleanly (SecItemCopyMatching == errSecSuccess) but
    // whose bytes are not a UTF-8 identity. It is the only unreadable state a simulator can be put
    // into on demand; errSecInteractionNotAllowed, errSecNotAvailable and errSecMissingEntitlement
    // are the realistic triggers and reach identity() at the same place.
    private func seedUnreadableItem() {
        cleanSlate()
        let status = SecItemAdd([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: SystemDeviceIdentityKeychain.service,
            kSecAttrAccount as String: SystemDeviceIdentityKeychain.account,
            kSecValueData as String: Data([0xFF, 0xFE]),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ] as CFDictionary, nil)
        #expect(status == errSecSuccess)
        #expect(SystemDeviceIdentityKeychain().identity() == .unreadable)
    }

    @Test func anItemThatCannotBeReadIsNotAnAbsentOne() {
        seedUnreadableItem()
        defer { cleanSlate() }

        // A keychain that cannot produce this device's identity has to say so, not hand out a new
        // one — the guard has a branch for the first and none for the second.
        #expect(DeviceIdentity.current(keychain: SystemDeviceIdentityKeychain()) == nil)
    }

    @Test func anUnreadableItemDoesNotSurviveTheReadThatFailedOnIt() {
        seedUnreadableItem()
        defer { cleanSlate() }

        _ = DeviceIdentity.current(keychain: SystemDeviceIdentityKeychain())

        var item: CFTypeRef?
        let status = SecItemCopyMatching([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: SystemDeviceIdentityKeychain.service,
            kSecAttrAccount as String: SystemDeviceIdentityKeychain.account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ] as CFDictionary, &item)

        #expect(status == errSecSuccess)
        #expect(item as? Data == Data([0xFF, 0xFE]))
    }

    // And the consequence the whole guard exists to prevent, on the user's own unchanged phone.
    @Test func anUnreadableItemCostsTheSelectionOnTheDeviceThatOwnsIt() {
        seedUnreadableItem()
        defer { cleanSlate() }

        let suite = "UnreadableDeviceIdentityItemTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        FamilyActivitySelectionStore.save(FamilyActivitySelection(), in: defaults)
        WakeAlarmStore.recordBlockRegistration(succeeded: true, in: defaults)
        defaults.set("the-identity-this-phone-recorded",
                     forKey: DeviceChangeGuard.lastKnownDeviceIdentityKey)

        let decision = DeviceChangeGuard.run(keychain: SystemDeviceIdentityKeychain(), in: defaults)

        #expect(decision == .leave)
        #expect(FamilyActivitySelectionStore.load(from: defaults) != nil)
        #expect(WakeAlarmStore.blockRegistrationSucceeded(in: defaults))
    }
}
