import Foundation
import Testing
@testable import Tuck

// The design system wrote the layout scale down and then asked prose to hold it: "die folgende Skala
// ist de facto entstanden und wird hiermit als Sollzustand festgeschrieben". It did not hold. Two
// `cornerRadius: 12` appeared in WakeAlarmSetupView after the design system had decided 12 away
// — and its own list of exceptions was already missing four values that have more than one
// call site each. Neither is a documentation failure; both are the absence of a mechanism.
//
// Same idiom and same reason as MascotGeometryContainmentTests and BrandPaletteContainmentTests:
// there is no snapshot or view-inspection layer in this project, so the shape of the source is the
// only thing an assertion can reach. The scan machinery below is this file's own copy rather than
// an import of the mascot one — the same choice BrandPaletteContainmentTests made, so that a
// change to one scan's definition of a violation cannot silently redefine the other's.
//
// SCOPE, chosen explicitly rather than by accident:
//
//   scanned:      `spacing:`, `cornerRadius:`, `.padding(.horizontal, N)`, `.padding(.vertical, N)`
//   NOT scanned:  `.frame(`, `minHeight:`, and the bare `.padding()`
//
// The two directed paddings are in because four of the tokens — `textInset`, `plateY` and
// the `plateInset` pair —
// are padding values, and with a spacing/radius-only scope they would have been named and then
// held by nothing at all, which is the exact state this file exists to end. `.frame(`/`minHeight:`
// are out so that the hit-target token can arrive on its own without this scan firing at
// the seam. The bare `.padding()` is out because the design system names it as the house default and
// it is deliberately left alone ("nicht anfassen").
//
// WHAT IS NOT IN HERE AND WHY: the mascot rig. Its four drawing files carry zero of the scanned
// literals (verified) because they have already moved to MascotGeometry, and the
// three that MascotGeometryContainmentTests scans as whole files are excluded below so the two
// scans cannot both claim the same territory.
struct LayoutContainmentTests {
    static let definitionSite = "Tuck/Layout.swift"

    // Excluded by name rather than by glob-with-holes so that a new file in Tuck/ is scanned by
    // default: a scan that has to be extended to see new code is a scan that will not see it.
    static let notScanned: Set<String> = [
        "Layout.swift",          // the definition site
        "MascotGeometry.swift",  // the other axis's definition site
        "MascotView.swift",      // held by MascotGeometryContainmentTests
        "MascotPose.swift",      // held by MascotGeometryContainmentTests
        "MascotSurfaces.swift"   // held by MascotGeometryContainmentTests
    ]

    // The design system's Einzelfall table, mechanical instead of prose. Each entry has exactly one call site
    // and a `// Grund:` comment beside it; a value that grows a second call site has become a role
    // and belongs in Layout.swift instead of here.
    static let allowed: [String: Set<String>] = [
        "spacing:": ["0", "2", "4"],
        "cornerRadius:": [],
        // 14 and 8 left this list: the status block was given the same floating-plate
        // inset the speech bubble carries, which made them two call sites and therefore a role.
        // They are Layout.plateInsetX / .plateInsetY now.
        ".padding(.horizontal,": [],
        ".padding(.vertical,": ["10"]
    ]

    static let labels = ["spacing:", "cornerRadius:"]
    static let calls = [".padding(.horizontal,", ".padding(.vertical,"]

    // MARK: - Reading

    private static var repository: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static func source(_ relativePath: String) throws -> String {
        try String(contentsOf: repository.appendingPathComponent(relativePath), encoding: .utf8)
    }

    static func scannedFiles() throws -> [String] {
        let directory = repository.appendingPathComponent("Tuck")
        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        return names
            .filter { $0.hasSuffix(".swift") && !notScanned.contains($0) }
            .sorted()
            .map { "Tuck/\($0)" }
    }

    // Line comments are stripped before anything is scanned: several of the files being migrated
    // explain in prose the very numbers this scan forbids, and a comment arguing why the bubble's
    // padding is 14 must not read as a violation of it.
    static func withoutComments(_ text: String) -> String {
        text.components(separatedBy: "\n")
            .map { line -> String in
                guard let marker = line.range(of: "//") else { return line }
                return String(line[..<marker.lowerBound])
            }
            .joined(separator: "\n")
    }

    // MARK: - Parsing

    private static func indices(of needle: String, in text: [Character]) -> [Int] {
        let pattern = Array(needle)
        guard !pattern.isEmpty, text.count >= pattern.count else { return [] }
        var found: [Int] = []
        for start in 0...(text.count - pattern.count) where Array(text[start ..< (start + pattern.count)]) == pattern {
            found.append(start)
        }
        return found
    }

    // The rest of one argument: up to the next top-level "," or the ")" that closes the call it
    // sits in, and never past the end of its own line.
    private static func argument(in text: [Character], from start: Int) -> String {
        var depth = 0
        var expression = ""
        var index = start
        while index < text.count {
            let character = text[index]
            if character == "\n" { break }
            if character == "(" || character == "[" { depth += 1 }
            if character == ")" || character == "]" {
                if depth == 0 { break }
                depth -= 1
            }
            if character == "," && depth == 0 { break }
            expression.append(character)
            index += 1
        }
        return expression.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // A whole label, not a suffix of one: without this, `spacing:` would also match a hypothetical
    // `lineSpacing:` and the walk would read an argument that belongs to another call.
    private static func isWholeToken(_ text: [Character], at start: Int) -> Bool {
        guard start > 0 else { return true }
        let preceding = text[start - 1]
        return !(preceding.isLetter || preceding.isNumber || preceding == "_")
    }

    // MARK: - The rule

    // An argument passes if it names a token, or if it is a number this file's allow-list carries
    // for that argument position. Everything else is a literal at a scanned position.
    static func isAcceptable(_ expression: String, at position: String) -> Bool {
        if expression.contains("Layout.") || expression.contains("MascotGeometry.") { return true }
        if Double(expression) != nil { return allowed[position, default: []].contains(expression) }
        // Not a plain number and not a token: a named parameter, a computed expression or a
        // ternary over two tokens. Those carry no constant, so there is nothing here to drift.
        return !expression.contains(where: \.isNumber)
    }

    struct Finding: CustomStringConvertible {
        let file: String
        let position: String
        let expression: String
        var description: String { "\(file): \(position) \(expression)" }
    }

    static func scan(_ file: String) throws -> (findings: [Finding], seen: [String: Int]) {
        let characters = Array(withoutComments(try source(file)))
        var findings: [Finding] = []
        var seen: [String: Int] = [:]

        for label in labels {
            for start in indices(of: label, in: characters) where isWholeToken(characters, at: start) {
                let expression = argument(in: characters, from: start + label.count)
                seen[label, default: 0] += 1
                if !isAcceptable(expression, at: label) {
                    findings.append(Finding(file: file, position: label, expression: expression))
                }
            }
        }

        for call in calls {
            for start in indices(of: call, in: characters) {
                let expression = argument(in: characters, from: start + call.count)
                seen[call, default: 0] += 1
                if !isAcceptable(expression, at: call) {
                    findings.append(Finding(file: file, position: call, expression: expression))
                }
            }
        }

        return (findings, seen)
    }

    // MARK: - Tests

    @Test func noScreenWritesASpacingRadiusOrDirectedPaddingAsARawNumber() throws {
        var findings: [Finding] = []
        for file in try Self.scannedFiles() {
            findings.append(contentsOf: try Self.scan(file).findings)
        }
        #expect(findings.isEmpty,
                "the layout scale is written out instead of read from Tuck/Layout.swift: \(findings.map(\.description))")
    }

    // The other direction, the one BrandPaletteContainmentTests learned the hard way: a scan that
    // passes because the thing it scans for no longer exists anywhere is not a passing scan.
    @Test func theScanHasSomethingToScan() throws {
        let files = try Self.scannedFiles()
        #expect(files.count > 20, "Tuck/ suddenly holds \(files.count) scannable files")

        var seen: [String: Int] = [:]
        for file in files {
            for (position, count) in try Self.scan(file).seen { seen[position, default: 0] += count }
        }
        for position in Self.labels + Self.calls {
            #expect(seen[position, default: 0] > 0,
                    "no `\(position)` anywhere in Tuck/ any more — this scan now checks nothing at that position")
        }
    }

    @Test func theDefinitionSiteIsValuesAndNothingElse() throws {
        let definition = try Self.source(Self.definitionSite)
        #expect(definition.contains("enum Layout"))
        // Foundation-only by design, like Tuck/Motion.swift and Tuck/MascotGeometry.swift: the file
        // holds values and renders nothing.
        #expect(definition.contains("import Foundation"))
        #expect(!definition.contains("import SwiftUI"))
    }

    // Exact equalities, not a range: the value is pinned at the definition site so that the call
    // sites can be checked by name. Drop one half and the pair proves nothing.
    @Test func everyTokenHoldsTheValueTheScaleWasWrittenWith() {
        #expect(Layout.root == 24)
        #expect(Layout.section == 20)
        #expect(Layout.container == 16)
        #expect(Layout.pair == 8)
        #expect(Layout.overrideSection == 28)
        #expect(Layout.footerStack == 14)
        #expect(Layout.choiceStack == 12)
        #expect(Layout.cardInterior == 10)
        #expect(Layout.textInset == 24)
        #expect(Layout.plateY == 12)
        #expect(Layout.plateInsetX == 14)
        #expect(Layout.plateInsetY == 8)
        #expect(Layout.hitMin == 44)
        #expect(Layout.radiusPlate == 16)
        #expect(Layout.radiusCard == 20)
    }

    // A token nothing reads is inventory, not a scale — it drifts away from the drawing without
    // anything going red. This is why `radiusBrandCard` (24) and `radiusPill` (100) from the
    // original design's brand layer were deliberately not built: neither has a call site anywhere in the repo.
    @Test func everyTokenHasAtLeastOneReader() throws {
        let names = ["root", "section", "container", "pair", "overrideSection", "footerStack",
                     "choiceStack", "cardInterior", "textInset", "plateY", "plateInsetX",
                     "plateInsetY", "hitMin", "radiusPlate", "radiusCard"]
        var sources: [String] = []
        for file in try Self.scannedFiles() { sources.append(Self.withoutComments(try Self.source(file))) }
        let corpus = sources.joined(separator: "\n")
        for name in names {
            #expect(corpus.contains("Layout.\(name)"), "Layout.\(name) is read nowhere — dead token inventory")
        }
    }

    // The one 44 in the app that is deliberately NOT the hit-target token. `headerHeight` carries
    // the same number by coincidence — it is the height of the onboarding header bar, a layout
    // measurement, and the back chevron inside it happens to fill it. Migrating it would make two
    // unrelated decisions move together, the same accident `Motion.stepOverride` and
    // `breathLabelCrossfade` avoid by staying two names for one 0.6. Written down here rather than
    // left as a silent omission from the scan.
    @Test func theOnboardingHeaderHeightStaysItsOwnNumber() throws {
        let text = try Self.source("Tuck/OnboardingFlowView.swift")
        #expect(text.contains("private static let headerHeight: CGFloat = 44"))
        #expect(text.contains("Grund: keine Trefferfläche"),
                "the header height lost the comment that says why it is not the hit-target token")
    }
}
