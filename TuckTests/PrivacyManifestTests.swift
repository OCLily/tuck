import Foundation
import Testing
@testable import Tuck

// The manifest is a resource, and a resource is only in a bundle if a build phase put it there —
// which is exactly the part project.yml cannot promise on its own. All four bundles read
// UserDefaults, so all four have to declare it; a missing one is an upload rejection, and it would
// be invisible in the sources because the file would still sit in Shared/ looking correct.
//
// Resolved out of the built products the way EnglishLocalizationTests reaches the shield: the app
// from Bundle.main, the three extensions from builtInPlugInsURL — the Simulator never launches
// either extension, so their bundles are the only evidence there is.
struct PrivacyManifestTests {
    private static let appexNames = ["TuckMonitor", "TuckShield", "TuckShieldAction"]

    private func manifest(in bundle: Bundle, of name: String) throws -> [String: Any] {
        // Not bundle.url(forResource:): a manifest that landed in a subdirectory would still be
        // found by that and would still be wrong. Apple reads it at the bundle root only.
        let url = bundle.bundleURL.appendingPathComponent("PrivacyInfo.xcprivacy")
        #expect(FileManager.default.fileExists(atPath: url.path), "\(name) ships no PrivacyInfo.xcprivacy")
        let data = try #require(try? Data(contentsOf: url), "\(name): PrivacyInfo.xcprivacy is unreadable")
        let plist = try? PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(plist as? [String: Any], "\(name): PrivacyInfo.xcprivacy is no dictionary")
    }

    private func allManifests() throws -> [(String, [String: Any])] {
        var found = [("Tuck", try manifest(in: .main, of: "Tuck"))]
        let plugIns = try #require(Bundle.main.builtInPlugInsURL)
        for name in Self.appexNames {
            let url = plugIns.appendingPathComponent("\(name).appex")
            let appex = try #require(Bundle(url: url), "\(name).appex is not in PlugIns/")
            found.append((name, try manifest(in: appex, of: name)))
        }
        return found
    }

    @Test func allFourBundlesShipAManifest() throws {
        #expect(try allManifests().count == 4)
    }

    // The only outbound traffic is StoreKit's own connection to Apple, so there is nothing to
    // track with and no domain to name. Either key drifting to a non-empty value would be a claim
    // about this app that no code in it supports.
    @Test func nothingIsTrackedAndNoDomainIsDeclared() throws {
        for (name, manifest) in try allManifests() {
            #expect(manifest["NSPrivacyTracking"] as? Bool == false, "\(name) declares tracking")
            let domains = try #require(manifest["NSPrivacyTrackingDomains"] as? [Any], "\(name) has no tracking-domains key")
            #expect(domains.isEmpty, "\(name) declares \(domains.count) tracking domains")
        }
    }

    // "Collect" in Apple's sense is transmission off the device, and nothing here leaves it.
    // The list stays empty for as long as that holds — a store that starts sending is what this
    // pins, not the storing itself.
    @Test func noDataTypeIsCollected() throws {
        for (name, manifest) in try allManifests() {
            let types = try #require(manifest["NSPrivacyCollectedDataTypes"] as? [Any], "\(name) has no collected-types key")
            #expect(types.isEmpty, "\(name) declares \(types.count) collected data types")
        }
    }

    // Exactly one category, and both reasons. 1C8F.1 carries the App Group suite every store
    // reads — hasCompletedOnboarding among them — CA92.1 the app's own defaults, where
    // onboardingStep is what is left in UserDefaults.standard. Dropping either
    // would leave a real access path undeclared, and adding a category would declare an API the
    // app does not call.
    @Test func userDefaultsIsTheOnlyDeclaredCategoryAndCarriesBothReasons() throws {
        for (name, manifest) in try allManifests() {
            let types = try #require(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]], "\(name) has no accessed-API key")
            #expect(types.count == 1, "\(name) declares \(types.count) API categories")

            let entry = try #require(types.first, "\(name) declares no API category")
            #expect(entry["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults",
                    "\(name) declares a category other than UserDefaults")

            let reasons = try #require(entry["NSPrivacyAccessedAPITypeReasons"] as? [String], "\(name) declares no reasons")
            #expect(Set(reasons) == ["1C8F.1", "CA92.1"], "\(name) declares reasons \(reasons)")
        }
    }
}
