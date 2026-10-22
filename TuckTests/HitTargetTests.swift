import Foundation
import Testing
@testable import Tuck

// The 44 pt minimum hit area is the one composition rule that is
// mechanically greppable: a hit area is a `frame` at the call site, and a control without
// one does not have it — being legible is not the same as being tappable. The eleven controls
// below were bare `Button("…")` / `Link("…", destination:)` calls whose tappable region was the
// text's own line box, roughly 20 pt tall against Apple's 44 pt minimum.
//
// Where the modifiers have to sit is not a style question here: the PrimaryButtonPlate
// comment records that modifiers hung *outside* a Button grow the plate and not its
// hit area. So each site carries the frame on its label, inside the Button.
//
// The scan is therefore structural rather than a window of N lines after the label. Two regressions
// the window version would have waved through, both of them this project's own failure class — the
// screen still reads right and nothing is tappable:
//
//   1. the two modifiers moved *below* the closing brace of the label closure. Still a few lines
//      after the label, still greps fine, and back to exactly the defect the label form closed.
//   2. the `Button { … } label: {` wrapper deleted altogether, leaving a bare
//      `Text("Schließen").frame(minHeight: 44).contentShape(Rectangle())` — a 44 pt box that is not
//      a control at all.
//
// So the label line's *enclosing brace block* is resolved first. The modifiers are checked against
// that block; the wrapper against the whole chain of blocks around it, because a Button that holds
// an icon beside its label wraps the text one level further out than the closure it was written in.
//
// This is a source scan and not a view inspection for the same reason SettingsEntryPointTests and
// OnboardingCompositionTests are: there is no snapshot or view-inspection layer in this project.
// What is pinned is the shape at the call site.
struct HitTargetTests {
    struct Site: Sendable, CustomTestStringConvertible {
        let file: String
        let label: String
        let count: Int

        var testDescription: String { "\(file) — \(label)" }
    }

    // The `Button("Wecker ausschalten")` inside the confirmationDialog is deliberately not here:
    // iOS draws dialog buttons itself and sizes them itself. Only the in-screen control is ours.
    // The paywall's toolbar "Schließen" is out for the same reason — a navigation-bar item gets its
    // hit area from UIKit.
    static let sites: [Site] = [
        Site(file: "Tuck/BedtimeSetupView.swift", label: "Bettzeit entfernen", count: 2),
        Site(file: "Tuck/GutenMorgenView.swift", label: "Ich brauche kurz Zugriff", count: 1),
        Site(file: "Tuck/WakeAlarmSetupView.swift", label: "Wecker ausschalten", count: 1),
        Site(file: "Tuck/WakeAlarmSetupView.swift", label: "Bildschirmzeit-Zugriff prüfen", count: 1),
        Site(file: "Tuck/OverrideFlowView.swift", label: "Schließen", count: 2),
        Site(file: "Tuck/PaywallView.swift", label: "Käufe wiederherstellen", count: 1),
        Site(file: "Tuck/PaywallView.swift", label: "Abo verwalten", count: 1),
        Site(file: "Tuck/PaywallView.swift", label: "Nutzungsbedingungen", count: 1),
        Site(file: "Tuck/PaywallView.swift", label: "Datenschutzerklärung", count: 1)
    ]

    private struct Block {
        let openLine: Int
        let openPrefix: String
        let closeLine: Int
    }

    private struct Structure {
        let lines: [String]
        let blocks: [Block]
        let unclosed: Int
        let unopened: Int
    }

    private static func source(_ relativePath: String) throws -> [String] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n")
    }

    // A brace inside a string literal or behind `//` is not structure. None of the five scanned
    // files uses `"""` or `/* */`; if one ever does, the balance check in `structure(of:)` fails
    // loudly rather than letting a confused scan report a pass.
    private static func code(_ line: String) -> String {
        var result = ""
        var inString = false
        var escaped = false
        for character in line {
            if escaped {
                escaped = false
                continue
            }
            if inString {
                if character == "\\" { escaped = true }
                if character == "\"" { inString = false }
                continue
            }
            if character == "\"" {
                inString = true
                continue
            }
            if character == "/", result.hasSuffix("/") {
                result.removeLast()
                break
            }
            result.append(character)
        }
        return result
    }

    private static func structure(of relativePath: String) throws -> Structure {
        let lines = try source(relativePath)
        var open: [(line: Int, prefix: String)] = []
        var blocks: [Block] = []
        var unopened = 0
        for (index, line) in lines.enumerated() {
            var prefix = ""
            for character in code(line) {
                if character == "{" {
                    open.append((index, prefix))
                } else if character == "}" {
                    if let start = open.popLast() {
                        blocks.append(Block(openLine: start.line, openPrefix: start.prefix, closeLine: index))
                    } else {
                        unopened += 1
                    }
                }
                prefix.append(character)
            }
        }
        return Structure(lines: lines, blocks: blocks, unclosed: open.count, unopened: unopened)
    }

    private static func labelLines(in lines: [String], label: String) -> [Int] {
        lines.indices.filter { index in
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("Text(") && trimmed.contains("\"\(label)\"")
        }
    }

    // Every block that contains the label line, tightest first — the chain of closures the label was
    // written into, from its own outwards.
    private static func enclosingBlocks(of index: Int, in blocks: [Block]) -> [Block] {
        blocks
            .filter { $0.openLine < index && $0.closeLine >= index }
            .sorted { ($0.closeLine - $0.openLine) < ($1.closeLine - $1.openLine) }
    }

    // The tightest block that contains the label line — the closure the label was written into.
    private static func enclosingBlock(of index: Int, in blocks: [Block]) -> Block? {
        enclosingBlocks(of: index, in: blocks).first
    }

    // True for a Button's label closure and for a Link's content closure — the two shapes that make
    // the text inside them tappable.
    private static func opensAControl(_ block: Block, in structure: Structure) -> Bool {
        let opener = Self.code(structure.lines[block.openLine]).trimmingCharacters(in: .whitespaces)
        if opener.contains("Link(destination:") { return true }

        let prefix = block.openPrefix.trimmingCharacters(in: .whitespaces)
        guard prefix.hasSuffix("label:") else { return false }
        if prefix.contains("Button") { return true }
        // `} label: {`: the Button owns the action closure that ends on this very line.
        return structure.blocks.contains {
            $0.closeLine == block.openLine && $0.openPrefix.contains("Button")
        }
    }

    // nil means "one of the closures the label sits in really is a Button's label closure or a
    // Link's content closure". It does not have to be the tightest one: a Button that puts an icon
    // beside its label holds both in an HStack, and that HStack is not a defect — the Button one
    // level further out is still what makes the text tappable. Checking only the tightest block
    // failed that shape and, worse, named the HStack as the reason. A finding is therefore only a
    // finding when *no* block around the label is a control; the message then names the innermost
    // one, which is where someone reading it would start looking.
    private static func wrapperProblem(forLabelAt index: Int, in structure: Structure) -> String? {
        let blocks = Self.enclosingBlocks(of: index, in: structure.blocks)
        if blocks.contains(where: { Self.opensAControl($0, in: structure) }) { return nil }
        guard let innermost = blocks.first else { return "it sits in no closure at all" }

        let opener = Self.code(structure.lines[innermost.openLine]).trimmingCharacters(in: .whitespaces)
        if innermost.openPrefix.trimmingCharacters(in: .whitespaces).hasSuffix("label:") {
            return "a `label:` closure with no Button in front of it — it opens with `\(opener)`"
        }
        return "no closure around it is a Button label closure and none is a Link — the innermost opens with `\(opener)`"
    }

    // Spelled into the failure message because this is the exact shape the label form closed: the modifier
    // is still in the file, still right below the label, and no longer on the label.
    private static func noteIfBelowTheClosure(_ needle: String, _ block: Block, _ structure: Structure) -> String {
        let tail = structure.lines[block.closeLine...].prefix(6)
        guard tail.contains(where: { Self.code($0).contains(needle) }) else { return "" }
        return " — there is one below the label closure's closing brace at :\(block.closeLine + 1), "
            + "where it grows the layout box and not the hit area"
    }

    @Test(arguments: sites) func everyBareControlCarriesA44ptHitArea(site: Site) throws {
        let structure = try Self.structure(of: site.file)
        #expect(structure.unclosed == 0 && structure.unopened == 0,
                "\(site.file): brace scan unbalanced (\(structure.unclosed) unclosed, \(structure.unopened) unopened) — the structural checks cannot be trusted")

        let labels = Self.labelLines(in: structure.lines, label: site.label)
        #expect(labels.count == site.count,
                "\(site.file): expected \(site.count) label(s) \"\(site.label)\" inside a Button/Link label closure, found \(labels.count)")

        for index in labels {
            guard let block = Self.enclosingBlock(of: index, in: structure.blocks) else {
                Issue.record("\(site.file):\(index + 1) \"\(site.label)\" sits in no closure at all")
                continue
            }
            // Both modifiers have to be inside that closure, and in that order: a contentShape above
            // the frame describes the line box again.
            let interior = Array(structure.lines[index ..< max(index + 1, block.closeLine)]).map(Self.code)
            // The call sites name the token instead of writing 44 (Tuck/Layout.swift).
            // The name is what is checked here; the value is pinned once, at the definition site, by
            // LayoutContainmentTests.everyTokenHoldsTheValueTheScaleWasWrittenWith.
            let frame = interior.firstIndex { $0.contains(".frame(") && $0.contains("minHeight: Layout.hitMin") }
            let shape = interior.firstIndex { $0.contains(".contentShape(Rectangle())") }

            #expect(frame != nil,
                    "\(site.file):\(index + 1) \"\(site.label)\" has no minHeight: Layout.hitMin inside its label closure (:\(block.openLine + 1)–:\(block.closeLine + 1))\(Self.noteIfBelowTheClosure("minHeight: Layout.hitMin", block, structure))")
            #expect(shape != nil,
                    "\(site.file):\(index + 1) \"\(site.label)\" has no contentShape inside its label closure (:\(block.openLine + 1)–:\(block.closeLine + 1))\(Self.noteIfBelowTheClosure(".contentShape(Rectangle())", block, structure))")
            if let frame, let shape {
                #expect(frame < shape,
                        "\(site.file):\(index + 1) \"\(site.label)\" carries contentShape above the frame — that shapes the line box again")
            }
        }
    }

    // The other half a frame alone does not carry: a 44 pt box around a Text that no Button or Link
    // wraps is a hit area for nothing. Two of the eleven controls (the legal Links) are pinned a
    // second time by SubscriptionAccessTests.bothLegalLinksAreRenderedOnThePaywallItself; the nine
    // Button-based ones had nothing checking the wrapper until here.
    @Test(arguments: sites) func everyLabelSitsInsideARealButtonOrLinkWrapper(site: Site) throws {
        let structure = try Self.structure(of: site.file)
        let labels = Self.labelLines(in: structure.lines, label: site.label)
        #expect(labels.count == site.count,
                "\(site.file): expected \(site.count) label(s) \"\(site.label)\", found \(labels.count)")

        for index in labels {
            if let problem = Self.wrapperProblem(forLabelAt: index, in: structure) {
                Issue.record("\(site.file):\(index + 1) \"\(site.label)\" is not wrapped in a Button or Link: \(problem)")
            }
        }
    }

    // The half of the fix a frame alone does not carry: as long as the shorthand `Button("…")`
    // still stands at the site, the label closure the frame lives in is not there at all.
    @Test(arguments: sites) func noSiteFellBackToTheShorthandInitialiser(site: Site) throws {
        let lines = try Self.source(site.file)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
        let shorthand = lines.filter {
            $0.contains("Link(\"\(site.label)\"")
                || ($0.contains("Button(\"\(site.label)\"") && !$0.contains("confirmationDialog"))
        }
        // WakeAlarmSetupView keeps exactly one: the confirmation dialog's own button.
        let allowed = (site.file == "Tuck/WakeAlarmSetupView.swift" && site.label == "Wecker ausschalten") ? 1 : 0
        #expect(shorthand.count == allowed,
                "\(site.file): \(shorthand.count) shorthand \"\(site.label)\" control(s), expected \(allowed)")
    }
}
