import FamilyControls
import Foundation

// The app owns the picker, the Monitor extension owns the shield write — two processes, so the
// selection has to live in the App-Group container rather than in a @State property.
// FamilyActivitySelection is Codable in the SDK (FamilyControls.swiftinterface: `public struct
// FamilyActivitySelection : Swift.Codable`), so it goes in as encoded Data; the tokens inside are
// opaque and deliberately not inspected here.
// One selection, shared by the morning and the bedtime window (docs/bedtime-window-2026-09-03.md):
// there is no second, bedtime-specific key.
enum FamilyActivitySelectionStore {
    private nonisolated static var defaults: UserDefaults {
        UserDefaults(suiteName: TuckIdentifiers.appGroupSuiteName) ?? .standard
    }

    nonisolated static func load(from defaults: UserDefaults = Self.defaults) -> FamilyActivitySelection? {
        guard let data = defaults.data(forKey: TuckIdentifiers.familyActivitySelectionDefaultsKey) else {
            return nil
        }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    nonisolated static func save(_ selection: FamilyActivitySelection, in defaults: UserDefaults = Self.defaults) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        defaults.set(data, forKey: TuckIdentifiers.familyActivitySelectionDefaultsKey)
    }

    // What "nothing selected" means, in one place. A selection shields something as soon as it
    // carries a token in any of its three sets: the settings row counted two of them and could
    // therefore report "noch keine" while a web-domain-only shield was active.
    nonisolated static func selectedActivityCount(in defaults: UserDefaults = Self.defaults) -> Int {
        guard let selection = load(from: defaults) else { return 0 }
        return count(of: selection)
    }

    // The same answer for a selection that is still in a picker's hands and has not been written
    // anywhere yet — the app-selection step asks it on every change.
    nonisolated static func count(of selection: FamilyActivitySelection) -> Int {
        selection.applicationTokens.count
            + selection.categoryTokens.count
            + selection.webDomainTokens.count
    }

    // Deliberately the raw presence of the key, not `load() != nil`: DeviceChangeGuard asks this to
    // find out whether the user ever went through the picker, and data that no longer decodes is
    // still evidence that they did.
    nonisolated static func hasStoredSelection(in defaults: UserDefaults = Self.defaults) -> Bool {
        defaults.data(forKey: TuckIdentifiers.familyActivitySelectionDefaultsKey) != nil
    }

    nonisolated static func clear(in defaults: UserDefaults = Self.defaults) {
        defaults.removeObject(forKey: TuckIdentifiers.familyActivitySelectionDefaultsKey)
    }
}
