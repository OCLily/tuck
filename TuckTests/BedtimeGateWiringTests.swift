import Foundation
import Testing
@testable import Tuck

// BedtimeGateTests pins the decision; this pins that the monitor extension asks it, and asks it
// before it shields. The same split MorningCelebrationWiringTests exists for, and here it is not
// optional: DeviceActivityMonitorExtension is compiled into TuckMonitor, which the Simulator never
// launches, so there is no other way to see whether the gate is wired at all. A gate nobody calls
// looks exactly like a gate that works — the silent-failure shape of this project.
struct BedtimeGateWiringTests {
    private func intervalDidStartBody() throws -> [String] {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("TuckMonitor/DeviceActivityMonitorExtension.swift")
        let lines = try String(contentsOf: source, encoding: .utf8).components(separatedBy: "\n")
        let start = try #require(lines.firstIndex { $0.contains("override func intervalDidStart(") })
        let end = try #require(lines[start...].dropFirst().firstIndex { $0 == "    }" })
        return Array(lines[start...end])
    }

    @Test func theEntitlementIsCheckedBeforeAnyShieldIsWritten() throws {
        let body = try intervalDidStartBody()
        let gate = try #require(body.firstIndex { $0.contains("BlockWindowEntitlement.action(") })
        let apply = try #require(body.firstIndex { $0.contains("ShieldApplication.apply(") })

        #expect(gate < apply)
        // Read live, not from a cache the app process refreshes: the whole point is the install
        // whose app is never opened again.
        #expect(body[gate].contains("access: .current()"))
    }

    // The other half of the release: an occurrence whose intervalDidEnd never arrived leaves a
    // shield standing, and skipping the apply would not take it down.
    @Test func theBlockedBranchClearsTheStoreInsteadOfOnlyReturning() throws {
        let body = try intervalDidStartBody()
        let gate = try #require(body.firstIndex { $0.contains("BlockWindowEntitlement.action(") })
        let apply = try #require(body.firstIndex { $0.contains("ShieldApplication.apply(") })

        #expect(body[gate..<apply].contains { $0.contains("ShieldRelease.clear(") })
    }

    // The counter that answers "did iOS speak at all" stays above the gate: counting only the
    // callbacks that ended in a shield would turn the five-day observation's one honest number into
    // a count of successful shields wearing its name.
    @Test func theIntervalCountStillPrecedesTheGate() throws {
        let body = try intervalDidStartBody()
        let count = try #require(body.firstIndex { $0.contains("BlockDiagnostics.record(.morningIntervalsStarted)") })
        let gate = try #require(body.firstIndex { $0.contains("BlockWindowEntitlement.action(") })

        #expect(count < gate)
    }
}
