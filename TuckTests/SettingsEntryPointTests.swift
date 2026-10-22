import Foundation
import Testing
@testable import Tuck

// The entry point to settings was a bare
// `Button("Einstellungen")` carrying the same three modifiers as the status line above it, with a
// hit area under half the HIG minimum — a user reading the screen as "there are no settings" was
// reading it correctly. There is no view-inspection dependency here, so what is checked is the same
// thing MorningCelebrationWiringTests checks: the shape at the call site.
struct SettingsEntryPointTests {
    private func morningSource() throws -> [String] {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Tuck/GutenMorgenView.swift")
        return try String(contentsOf: source, encoding: .utf8).components(separatedBy: "\n")
    }

    @Test func theSettingsEntryIsAGearWithAFullHitArea() throws {
        let lines = try morningSource()
        let overlay = try #require(lines.firstIndex { $0.contains(".overlay(alignment: .topTrailing)") })
        let block = lines[overlay...].prefix(16)
        #expect(block.contains { $0.contains("showSettings = true") })
        #expect(block.contains { $0.contains("Image(systemName: \"gearshape\")") })
        // The gear names the token rather than writing 44 twice; the 44 itself is
        // pinned once at the definition site (LayoutContainmentTests).
        #expect(block.contains { $0.contains(".frame(width: Layout.hitMin, height: Layout.hitMin)") })
        #expect(block.contains { $0.contains(".contentShape(Rectangle())") })
        // The label the text button carried is what VoiceOver still has to hear.
        #expect(block.contains { $0.contains(".accessibilityLabel(\"Einstellungen\")") })
    }

    // The text button is gone rather than kept alongside: two entry points to the same sheet is the
    // drift the design system spends its effort avoiding.
    @Test func theTextButtonIsGone() throws {
        let code = try morningSource().filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
        #expect(!code.contains { $0.contains("Button(\"Einstellungen\")") })
    }

    private func source(_ relativePath: String) throws -> [String] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n")
    }

    // Every line that is inside an #if DEBUG and not inside its #else.
    private func debugOnlyLines(of lines: [String]) -> Set<Int> {
        var inside = 0
        var result: Set<Int> = []
        for (index, line) in lines.enumerated() {
            let code = line.trimmingCharacters(in: .whitespaces)
            if code == "#if DEBUG" {
                inside += 1
                continue
            }
            if code == "#endif", inside > 0 {
                inside -= 1
                continue
            }
            if inside > 0 { result.insert(index) }
        }
        return result
    }

    // The four affordances of the device gate ship in no release build — including the
    // one that is not on this screen at all. A ManagedSettings write inside the alarm's stop intent
    // is the single most expensive line in this app to leave behind: it would write a bedtime shield
    // on a real user's morning, and nothing in the build takes that one down.
    @Test func theIntentShieldProbeExistsOnlyInDebugBuilds() throws {
        let settings = try source("Tuck/SettingsView.swift")
        let debugSettings = debugOnlyLines(of: settings)
        for affordance in [
            "Shield jetzt schreiben",
            "Shield jetzt räumen",
            "Nur Morgen-Store räumen",
            "Weckerstopp schreibt den Shield",
            "private func writeShieldNow()"
        ] {
            let index = try #require(settings.firstIndex { $0.contains(affordance) })
            #expect(debugSettings.contains(index), "\(affordance) is not behind #if DEBUG")
        }

        let intent = try source("Tuck/StopWakeAlarmIntent.swift")
        let debugIntent = debugOnlyLines(of: intent)
        for line in [
            "BlockDiagnostics.intentShieldProbeIsArmed()",
            "ShieldApplication.apply(selection, to: .bedtimeBlock)",
            "BlockDiagnostics.recordIntentShieldWrite()",
            "import ManagedSettings"
        ] {
            let index = try #require(intent.firstIndex { $0.contains(line) })
            #expect(debugIntent.contains(index), "\(line) is not behind #if DEBUG")
        }
    }

    // One shot, and the flag is consumed in the same branch that reads it: a switch left on would
    // write a bedtime shield after every alarm stop, which before the fail-open exists nothing
    // clears. A debug affordance that builds a permanent block is the silent failure this project
    // keeps finding.
    @Test func theIntentShieldProbeConsumesItsFlag() throws {
        let intent = try source("Tuck/StopWakeAlarmIntent.swift")
        let debugLines = debugOnlyLines(of: intent)

        let read = try #require(intent.firstIndex { $0.contains("BlockDiagnostics.intentShieldProbeIsArmed()") })
        let consume = try #require(intent.firstIndex { $0.contains("BlockDiagnostics.disarmIntentShieldProbe()") })

        #expect(debugLines.contains(consume))
        #expect(consume > read)
        let write = try #require(intent.firstIndex { $0.contains("ShieldApplication.apply(selection, to: .bedtimeBlock)") })
        #expect(consume < write)
    }
}
