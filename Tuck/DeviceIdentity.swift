import Foundation
import Security

// The one value in this app that must NOT survive a restore onto a new iPhone.
//
// Everything else the app owns lives in the App-Group container, and that container is part of the
// iCloud/Finder backup — deliberately, it is how a streak survives a new phone. The stored
// FamilyActivitySelection travels with it too, but its ApplicationTokens are device-bound: on the
// new device they resolve to nothing. That is the failure the identity below exists to detect, so
// storing it next to the tokens it is supposed to distinguish itself from would be circular — the
// stale identity would arrive together with the stale tokens and vouch for them.
//
// kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly is the whole mechanism: `ThisDeviceOnly` keeps
// the item out of the iCloud Keychain and out of encrypted backups, so a restore lands with an
// empty keychain slot and a full App Group — exactly the asymmetry that makes the comparison in
// DeviceChangeGuard meaningful. `AfterFirstUnlock` rather than `WhenUnlocked`: every caller today
// runs from a foreground SwiftUI path, already past the first unlock (BlockWindowReconciler.reconcile()
// from GutenMorgenView/SettingsView/WakeAlarmSetupView) — but a background or pre-unlock caller is a
// natural next step for an alarm app, and `.unreadable` already degrades safely to `.leave` there
// (Tuck/DeviceChangeGuard.swift), so the looser accessibility buys headroom for that case rather
// than describing one that exists yet.
//
// The three answers are kept apart on purpose. "Nothing was ever stored here" and "something is
// stored and I cannot reach it right now" are the same `nil` to a String?-returning read, and
// DeviceChangeGuard's safety valve for a keychain fault hangs on telling them apart: folded
// together, one transient read fault replaced this device's identity for good and cost the user
// their app selection on the next launch (docs/audit-log.md).
enum DeviceIdentityLookup: Equatable {
    case found(String)
    case absent
    case unreadable
}

protocol DeviceIdentityKeychain {
    func identity() -> DeviceIdentityLookup
    func store(_ identity: String) -> Bool
}

struct SystemDeviceIdentityKeychain: DeviceIdentityKeychain {
    static let service = "com.example.tuck.device-identity"
    static let account = "installation"

    func identity() -> DeviceIdentityLookup {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        // errSecItemNotFound is the only status that means the slot is empty.
        // errSecInteractionNotAllowed, errSecNotAvailable and errSecMissingEntitlement all mean an
        // item can be sitting there unreachable — and bytes that did come back but are not a UTF-8
        // identity mean one certainly is.
        guard status != errSecItemNotFound else { return .absent }
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty
        else { return .unreadable }

        return .found(value)
    }

    // Add first, update on collision, never delete. The delete-then-add this replaces discarded the
    // delete's result before the add decided the return value, so a write that failed did not leave
    // the old identity alone — it removed it, and the next launch read the empty slot as a new
    // device.
    func store(_ identity: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
        ]

        var attributes = query
        attributes[kSecValueData as String] = Data(identity.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let added = SecItemAdd(attributes as CFDictionary, nil)
        if added == errSecSuccess { return true }
        guard added == errSecDuplicateItem else { return false }

        let update: [String: Any] = [
            kSecValueData as String: Data(identity.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        return SecItemUpdate(query as CFDictionary, update as CFDictionary) == errSecSuccess
    }
}

enum DeviceIdentity {
    // A UUID rather than identifierForVendor: the vendor identifier is reset when the last app of a
    // vendor is deleted, which would read as a device change on a plain reinstall, and it is
    // documented as temporarily nil before the first unlock — the one launch state this is read in.
    static func current(keychain: DeviceIdentityKeychain = SystemDeviceIdentityKeychain()) -> String? {
        switch keychain.identity() {
        case .found(let existing):
            return existing
        case .unreadable:
            // Minting here would write a new identity over one that exists and is only temporarily
            // out of reach. nil is what DeviceChangeGuard.action's .leave branch is for.
            return nil
        case .absent:
            let fresh = UUID().uuidString
            return keychain.store(fresh) ? fresh : nil
        }
    }
}
