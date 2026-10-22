import Foundation
import Testing
@testable import Tuck

// The move out of ShieldApplication has no behaviour to check — the four writes are the same four
// writes, and whether they take a shield down is not observable in the Simulator at all. What is
// checkable is that there is still exactly one of them: two places nilling the same four properties
// is how one of them quietly stops being the one everybody calls.
struct ShieldReleaseTests {
    @Test func theFourShieldPropertiesAreNilledInExactlyOneFile() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let directories = ["Shared", "Tuck", "TuckMonitor", "TuckShield", "TuckShieldAction"]

        var files: [String] = []
        for directory in directories {
            let contents = try FileManager.default.contentsOfDirectory(
                atPath: root.appendingPathComponent(directory).path
            )
            for file in contents where file.hasSuffix(".swift") {
                let source = try String(
                    contentsOf: root.appendingPathComponent(directory).appendingPathComponent(file),
                    encoding: .utf8
                )
                if source.contains("store.shield.applications = nil") {
                    files.append("\(directory)/\(file)")
                }
            }
        }

        #expect(files == ["Shared/ShieldRelease.swift"])
    }

    // ShieldApplication keeps the write that puts a shield up and nothing else: no forwarder was
    // left behind, because two names for one operation are how somebody later calls the one that
    // does nothing.
    @Test func shieldApplicationNoLongerClearsAnything() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Shared/ShieldApplication.swift"),
            encoding: .utf8
        )

        #expect(source.contains("static func apply("))
        #expect(!source.contains("static func clear("))
    }

    // clearAll is for the caller that cannot know which store drew the shield it is looking at: a
    // shield action is handed a token, never a store name.
    @Test func clearingEverythingNamesBothWindows() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Shared/ShieldRelease.swift"),
            encoding: .utf8
        )

        #expect(source.contains("clear(.morningBlock)"))
        #expect(source.contains("clear(.bedtimeBlock)"))
    }
}
