import Foundation
import Testing
@testable import Tuck

// 3.3. The key was the last one still in UserDefaults.standard while every other store had moved to
// the App Group. Three separate @AppStorage declarations of one key is the drift risk: two of them
// pointing at one container and the third at another is a state that reads back correctly at each
// site and still shows onboarding to someone who finished it.
struct OnboardingCompletionStorageTests {
    private static let declaration =
        "@AppStorage(\"hasCompletedOnboarding\", store: TuckIdentifiers.appGroupDefaults)"

    private static let sites = ["Tuck/TuckApp.swift", "Tuck/ContentView.swift", "Tuck/OnboardingFlowView.swift"]

    private func lines(of relativePath: String) throws -> [String] {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
        return try String(contentsOf: source, encoding: .utf8).components(separatedBy: "\n")
    }

    @Test func allThreeViewsDeclareTheKeyAgainstTheAppGroupSuite() throws {
        for site in Self.sites {
            let lines = try lines(of: site)
            #expect(lines.contains { $0.contains(Self.declaration) }, "\(site) does not read the App Group")
        }
    }

    // The failure this is really watching for: one site reverting to the bare declaration, which
    // compiles, runs, and writes to a different container than the other two.
    @Test func noSiteIsLeftOnTheAppsOwnDefaults() throws {
        for site in Self.sites {
            let lines = try lines(of: site)
            #expect(!lines.contains { $0.contains("@AppStorage(\"hasCompletedOnboarding\")") },
                    "\(site) still declares the key without a store")
        }
    }

    // The constant the three sites point at, checked without writing to it: the test host carries
    // the group entitlement (AppGroupHealthTests), so the `?? .standard` fallback firing here would
    // be the silent per-app-container case — the same value at all three sites, in the wrong
    // container, invisible to any reset that only clears the group.
    @Test func theSharedStoreIsNotTheAppsOwnDefaults() {
        #expect(TuckIdentifiers.appGroupIsProvisioned)
        #expect(TuckIdentifiers.appGroupDefaults !== UserDefaults.standard)
    }

    // The constant resolves the suite rather than being pointed at some other name.
    @Test func theSharedStoreIsResolvedFromTheAppGroupSuiteName() throws {
        let lines = try lines(of: "Shared/TuckIdentifiers.swift")

        #expect(lines.contains { $0.contains("static var appGroupDefaults: UserDefaults") })
        #expect(lines.contains { $0.contains("UserDefaults(suiteName: appGroupSuiteName) ?? .standard") })
        #expect(TuckIdentifiers.appGroupSuiteName == "group.com.example.tuck")
    }
}
