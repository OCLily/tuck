import Testing
import Foundation
import FamilyControls
@testable import Tuck

// The tokens inside a FamilyActivitySelection can only be produced by the real picker under a
// granted Family-Controls authorization, which the Simulator does not have — so what is testable
// here is the round trip itself, not a selection with contents.
struct FamilyActivitySelectionStoreTests {
    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suite = "FamilyActivitySelectionStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        body(defaults)
    }

    @Test func nothingIsStoredOnAFreshInstall() {
        withDefaults { defaults in
            #expect(FamilyActivitySelectionStore.load(from: defaults) == nil)
        }
    }

    @Test func aSavedSelectionComesBackOut() {
        withDefaults { defaults in
            FamilyActivitySelectionStore.save(FamilyActivitySelection(), in: defaults)

            #expect(FamilyActivitySelectionStore.load(from: defaults) == FamilyActivitySelection())
        }
    }

    @Test func theSelectionSurvivesANewLookupOnTheSameSuite() {
        let suite = "FamilyActivitySelectionStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        FamilyActivitySelectionStore.save(FamilyActivitySelection(), in: defaults)
        let reopened = UserDefaults(suiteName: suite)!

        #expect(FamilyActivitySelectionStore.load(from: reopened) != nil)

        defaults.removePersistentDomain(forName: suite)
    }

    @Test func clearingRemovesTheSelection() {
        withDefaults { defaults in
            FamilyActivitySelectionStore.save(FamilyActivitySelection(), in: defaults)
            FamilyActivitySelectionStore.clear(in: defaults)

            #expect(FamilyActivitySelectionStore.load(from: defaults) == nil)
        }
    }

    @Test func nothingStoredAndAnEmptySelectionBothCountAsNone() {
        withDefaults { defaults in
            #expect(FamilyActivitySelectionStore.selectedActivityCount(in: defaults) == 0)

            FamilyActivitySelectionStore.save(FamilyActivitySelection(), in: defaults)

            #expect(FamilyActivitySelectionStore.selectedActivityCount(in: defaults) == 0)
        }
    }

    // The tokens themselves cannot be minted here, so what is checkable is the domain rather than a
    // sum: the count reads every token set a selection has. It read two of three, which let the
    // settings row say "noch keine" while a web-domain-only shield was active — and a fourth set in
    // a later SDK would reopen exactly that hole.
    @Test func theCountCoversEveryTokenSetASelectionCarries() {
        let sets = Mirror(reflecting: FamilyActivitySelection())
            .children
            .compactMap(\.label)
            .filter { $0.hasSuffix("Tokens") }

        #expect(Set(sets) == ["applicationTokens", "categoryTokens", "webDomainTokens"])
    }

    // Corrupt or foreign data must degrade to "nothing selected", not trap.
    @Test func unreadableDataDegradesToNoSelection() {
        withDefaults { defaults in
            defaults.set(Data([0x00, 0x01, 0x02]), forKey: TuckIdentifiers.familyActivitySelectionDefaultsKey)

            #expect(FamilyActivitySelectionStore.load(from: defaults) == nil)
        }
    }
}
