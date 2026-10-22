import Foundation
import Testing
@testable import Tuck

// The detection existed only inside
// UnlockQuotaStore's lock-file placement, where it silently picked a fallback directory. Here it is
// the diagnosis, and these pin the two things that make it one: it answers for the suite the whole
// app writes to, and the line it produces claims nothing.
struct AppGroupHealthTests {
    // The test bundle runs inside the host app, which carries the group entitlement — so a false
    // here is a real provisioning fault in this build, not a test artefact. It is also what the
    // Debug fatalError in TuckApp.init would fire on.
    @Test func theCheckAnswersForTheSuiteEveryStoreWritesTo() {
        #expect(TuckIdentifiers.appGroupSuiteName == "group.com.example.tuck")
        #expect(TuckIdentifiers.appGroupIsProvisioned)
    }

    // The honest state replaces the confirming copy rather than sitting beside it, so it may
    // not carry the vocabulary of a window that is entered or armed.
    @Test func theMissingStorageLineClaimsNoWindow() {
        let line = StatusCopy.sharedStorageMissing

        #expect(!line.contains("ist eingetragen"))
        #expect(!line.contains("scharf gestellt"))
        #expect(!line.contains("gesperrt"))
        #expect(!line.contains("aktiv"))
        #expect(!line.contains("!"))
    }
}
