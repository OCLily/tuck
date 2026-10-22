import FamilyControls
import ManagedSettings

// The one write that puts a shield up, used by the Monitor extension at intervalDidStart. Taking
// one down lives in ShieldRelease, which needs no FamilyControls and is therefore compilable into a
// target that may never block. Property names come from the SDK, not from the concept doc: ShieldSettings has no
// `categories` — it has applicationCategories/webDomainCategories, both ActivityCategoryPolicy,
// while FamilyActivitySelection hands out one flat categoryTokens set for both.
//
// `shield` is a non-throwing property (ManagedSettings.swiftinterface:427): a write without
// Family-Controls authorization does nothing and reports nothing. Nothing here may be read as
// evidence that a shield is actually active.
enum ShieldApplication {
    static func apply(_ selection: FamilyActivitySelection, to storeName: ManagedSettingsStore.Name) {
        // The one place tokens are handed to the system, so the one place they have to be current.
        // The refreshed values are deliberately not written back into the App Group: the picker in
        // the app writes that same key on every change, and a second writer in the extension would
        // race it for no gain — refreshing at each write is idempotent and costs one call per window.
        let selection = TokenRefresh.refreshed(selection)
        let store = ManagedSettingsStore(named: storeName)
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens

        let categories = selection.categoryTokens
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        store.shield.webDomainCategories = categories.isEmpty ? nil : .specific(categories)
    }
}
