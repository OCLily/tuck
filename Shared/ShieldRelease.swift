import ManagedSettings

// Taking a shield down, in its own file and without FamilyControls: the write that puts one up and
// the write that takes one down are not two halves of one operation. Only one of them is ever
// allowed in a process that must never block — and a file that cannot apply is a stronger statement
// of that than a comment saying so.
enum ShieldRelease {
    // Only the four shield settings, not clearAllSettings(): whether clearing one named store
    // leaves the other untouched is undocumented (see docs/bedtime-window-2026-09-03.md), and
    // the morning and bedtime stores are meant to be independent.
    static func clear(_ storeName: ManagedSettingsStore.Name) {
        let store = ManagedSettingsStore(named: storeName)
        store.shield.applications = nil
        store.shield.webDomains = nil
        store.shield.applicationCategories = nil
        store.shield.webDomainCategories = nil
    }

    // Both named stores, for the callers that cannot know which one is drawing: a shield hands out
    // an application token, never the name of the store behind it.
    static func clearAll() {
        clear(.morningBlock)
        clear(.bedtimeBlock)
    }
}
