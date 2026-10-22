import Foundation
import Testing

// The mascot rig's ~20 drawing constants lived as literals in four files at once —
// Tuck/MascotView.swift, Tuck/MascotSurfaces.swift, tools/AppIconComposition.swift and
// TuckShield/ShieldMascotIcon.swift — with no shared source and, contrary to what the design system
// claimed, no running cross-check of any kind. This scan is the mechanism that replaces
// the claim: every size, offset, spacing and line width in those four drawings has to name a
// value in Tuck/MascotGeometry.swift instead of writing a number.
//
// Same idiom and same reason as BrandPaletteContainmentTests, BodyInkSweepTests and
// SproutSourceTests: there is no snapshot or view-inspection layer in this project, so the shape
// of the drawing code is the only thing an assertion can reach. It is also a real control group —
// before the consolidation these four files are nothing but literals, so this file fails on every
// scanned region rather than on a contrived one.
//
// WHAT COUNTS AS A VIOLATION — a choice made
// explicitly rather than silently. `MascotSurfaces.swift` carries two kinds of number: the default
// parameters (`width = 140`, `outlineInk = 0.16`) which ARE the rig's constants under another
// name, and ~11 proportions (`width * 0.66`, `height * 0.36`) which are shading decisions of that
// file expressed against its own named parameters. The definition used here is therefore:
//
//   a violation is a BARE NUMBER at a scanned argument position. A number that is a
//   multiplicative factor on a named expression (`width * 0.66`, `-height * 0.07`) is not.
//
// The proportions stay where they are; what they are a proportion OF now comes from
// MascotGeometry, which is the part that could silently drift. The default parameters do not sit
// at an argument position at all, so they get their own assertion below rather than riding on
// this one — without it they would be a fourth, invisible copy of the body width.
//
// WHAT IS DELIBERATELY NOT SCANNED: shading intensity (opacity, blur radius, saturation, the
// grain's seed and dot count) and animation values (durations, the neutral `1` of a
// `.scaleEffect` ternary). This scan names geometry. `MascotGrain`'s parameters are texture and
// stay literals; `outlineInk`/`outlineWidth` are the one intensity pair that does
// migrate, because they are per-surface *rig parameters* the icon already overrides and
// the breathing circle does as well.
struct MascotGeometryContainmentTests {
    struct ScannedFile {
        let path: String
        // nil means the whole file is drawing code and is scanned end to end. MascotView.swift is
        // the one file that also holds an idle repertoire, tap handling and two gestures, so there
        // the scan is restricted to its drawing members by name.
        let members: [String]?
    }

    static let definitionSite = "Tuck/MascotGeometry.swift"

    static let files: [ScannedFile] = [
        // MascotView draws almost nothing itself: the rig moved to MascotPose. What is
        // left here is the canvas the pose is laid into and the contact shadow beside it, both of
        // which are still rig geometry and still scanned.
        ScannedFile(path: "Tuck/MascotView.swift", members: [
            "var body: some View {",
            "private func bodyStack(sway: Double) -> some View {"
        ]),
        ScannedFile(path: "Tuck/MascotPose.swift", members: nil),
        ScannedFile(path: "Tuck/MascotSurfaces.swift", members: nil),
        ScannedFile(path: "tools/AppIconComposition.swift", members: nil),
        ScannedFile(path: "TuckShield/ShieldMascotIcon.swift", members: nil)
    ]

    // The two call forms and the two bare labels. `.frame(` rather than `.frame(width:` on purpose:
    // the combined `.frame(width:height:)` is one call and a `.frame(height:`-only pattern never
    // matches it, so the whole argument list is taken apart instead of guessing at its spelling.
    static let scannedCalls = [".frame(", ".offset("]
    static let scannedLabels = ["lineWidth:", "spacing:"]

    // MARK: - Reading

    private static var repository: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static func source(_ relativePath: String) throws -> String {
        try String(contentsOf: repository.appendingPathComponent(relativePath), encoding: .utf8)
    }

    enum ScanError: Error { case memberNotFound(String), memberNeverCloses(String) }

    // Line comments are stripped before anything is scanned. Not a convenience: the files being
    // consolidated carry long explanatory comments that quote the very numbers this scan forbids,
    // and a comment that argues why -62 diverges from -70 must not read as a violation of it.
    private static func withoutComments(_ text: String) -> String {
        text.components(separatedBy: "\n")
            .map { line -> String in
                guard let marker = line.range(of: "//") else { return line }
                return String(line[..<marker.lowerBound])
            }
            .joined(separator: "\n")
    }

    private static func member(_ signature: String, in lines: [String]) throws -> String {
        guard let start = lines.firstIndex(where: { $0.contains(signature) }) else {
            throw ScanError.memberNotFound(signature)
        }
        var depth = 0
        var opened = false
        var body: [String] = []
        for index in start..<lines.count {
            let line = lines[index]
            depth += line.filter { $0 == "{" }.count
            depth -= line.filter { $0 == "}" }.count
            if depth > 0 { opened = true }
            if index > start { body.append(line) }
            if opened && depth == 0 { return body.joined(separator: "\n") }
        }
        throw ScanError.memberNeverCloses(signature)
    }

    private static func regions(of file: ScannedFile) throws -> [(String, String)] {
        let text = withoutComments(try source(file.path))
        guard let members = file.members else { return [(file.path, text)] }
        let lines = text.components(separatedBy: "\n")
        return try members.map { ("\(file.path) · \($0)", try member($0, in: lines)) }
    }

    // MARK: - Parsing

    // The parenthesised argument list of the call whose "(" sits at `openIndex`, without the outer
    // parentheses. Nesting-aware, so `.mask(Ellipse().frame(width: width, height: height))` and a
    // call split over two lines are both read correctly.
    private static func argumentList(of text: [Character], openingAt openIndex: Int) -> String? {
        var depth = 0
        var result = ""
        var index = openIndex
        while index < text.count {
            let character = text[index]
            if character == "(" {
                depth += 1
                if depth > 1 { result.append(character) }
            } else if character == ")" {
                depth -= 1
                if depth == 0 { return result }
                result.append(character)
            } else if depth >= 1 {
                result.append(character)
            }
            index += 1
        }
        return nil
    }

    private static func topLevelComponents(_ text: String) -> [String] {
        var depth = 0
        var current = ""
        var parts: [String] = []
        for character in text {
            if character == "(" || character == "[" { depth += 1 }
            if character == ")" || character == "]" { depth -= 1 }
            if character == "," && depth == 0 {
                parts.append(current)
                current = ""
                continue
            }
            current.append(character)
        }
        if !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { parts.append(current) }
        return parts
    }

    // Drops an argument label, and only a label: everything before the first ":" has to be a plain
    // identifier, so the ":" of a ternary (`yawning ? 15 : 22`) never gets mistaken for one and the
    // numbers behind it stay visible to the check.
    private static func value(of component: String) -> String {
        guard let colon = component.firstIndex(of: ":") else { return component }
        let label = component[..<colon].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty,
              label.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }),
              let first = label.first, first.isLetter || first == "_"
        else { return component }
        return String(component[component.index(after: colon)...])
    }

    private static func indices(of needle: String, in text: [Character]) -> [Int] {
        let pattern = Array(needle)
        guard !pattern.isEmpty, text.count >= pattern.count else { return [] }
        var found: [Int] = []
        for start in 0...(text.count - pattern.count) where Array(text[start..<(start + pattern.count)]) == pattern {
            found.append(start)
        }
        return found
    }

    // MARK: - The rule

    private static func nonSpace(_ text: [Character], from index: Int, step: Int) -> Character? {
        var cursor = index
        while cursor >= 0 && cursor < text.count {
            if !text[cursor].isWhitespace { return text[cursor] }
            cursor += step
        }
        return nil
    }

    static func carriesABareNumber(_ expression: String) -> Bool {
        let characters = Array(expression)
        var index = 0
        while index < characters.count {
            guard characters[index].isNumber else {
                index += 1
                continue
            }
            let preceding = index > 0 ? characters[index - 1] : " "
            // Inside an identifier (`iOS26`) or mid-literal — not the start of a number.
            if preceding.isLetter || preceding.isNumber || preceding == "_" || preceding == "." {
                index += 1
                continue
            }
            var end = index
            while end < characters.count, characters[end].isNumber || characters[end] == "." { end += 1 }
            let before = nonSpace(characters, from: index - 1, step: -1)
            let after = nonSpace(characters, from: end, step: 1)
            // A factor on a named expression is a proportion, not a constant: `width * 0.66` says
            // two thirds of whatever the body is, and stays true when the body width moves.
            if before != "*" && after != "*" { return true }
            index = end
        }
        return false
    }

    static func offendingArguments(in region: String) -> [String] {
        let characters = Array(region)
        var offenders: [String] = []

        for call in scannedCalls {
            for start in indices(of: call, in: characters) {
                let open = start + call.count - 1
                guard let list = argumentList(of: characters, openingAt: open) else { continue }
                for component in topLevelComponents(list) {
                    let expression = value(of: component).trimmingCharacters(in: .whitespacesAndNewlines)
                    if carriesABareNumber(expression) { offenders.append("\(call)…\(expression)") }
                }
            }
        }

        for label in scannedLabels {
            for start in indices(of: label, in: characters) {
                // A whole label, not a suffix of one: without this `lineWidth:` also matches the
                // `outlineWidth:` the surface layer declares, and the walk below then runs off the
                // end of the file looking for a closing paren that is not there.
                if start > 0 {
                    let preceding = characters[start - 1]
                    if preceding.isLetter || preceding.isNumber || preceding == "_" { continue }
                }
                // The rest of this argument: up to the next top-level "," or the ")" that closes
                // the call it sits in, and never past the end of its own line.
                var depth = 0
                var expression = ""
                var index = start + label.count
                while index < characters.count {
                    let character = characters[index]
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
                let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
                if carriesABareNumber(trimmed) { offenders.append("\(label) \(trimmed)") }
            }
        }

        return offenders
    }

    // MARK: - Tests

    @Test(arguments: files.map(\.path))
    func noDrawingWritesARawNumberWhereTheRigHasAName(path: String) throws {
        guard let file = Self.files.first(where: { $0.path == path }) else { return }
        for (name, region) in try Self.regions(of: file) {
            let offenders = Self.offendingArguments(in: region)
            #expect(offenders.isEmpty,
                    "\(name) still writes rig geometry as literals instead of reading MascotGeometry: \(offenders)")
        }
    }

    // The half the argument-position scan structurally cannot see:
    // MascotBodySurface and MascotEarSurface carry the body width, the body height, the ear
    // diameter and the contour pair as DEFAULT PARAMETERS. They are the rig's constants under
    // another name, and left out they would sit at 140 in silence on the day the body is
    // remeasured while eyes and mouth have already moved.
    @Test func theSurfaceLayersDefaultsComeFromTheRigAndNotFromItsOwnLiterals() throws {
        let defaults = ["width", "height", "diameter", "outlineInk", "outlineWidth"]
        let lines = Self.withoutComments(try Self.source("Tuck/MascotSurfaces.swift"))
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        for name in defaults {
            let declarations = lines.filter { $0.hasPrefix("var \(name): Double = ") }
            #expect(!declarations.isEmpty, "Tuck/MascotSurfaces.swift declares no `\(name)` default any more")
            for declaration in declarations {
                #expect(declaration.contains("MascotGeometry."),
                        "Tuck/MascotSurfaces.swift: `\(declaration)` is a fourth copy of a rig constant")
            }
        }
    }

    // The two icon-local values that diverge from the app rig on purpose and sit at argument
    // positions this scan does not cover — the 1.15 scale and the contact shadow's own width.
    // The rule for every deliberate divergence is "a named parameter in MascotGeometry, not
    // a silent exception", so they are named and then checked here rather than waved through.
    @Test func theIconsOwnDivergencesAreNamedRatherThanWrittenOut() throws {
        let text = Self.withoutComments(try Self.source("tools/AppIconComposition.swift"))
        for call in ["MascotContactShadow(", ".scaleEffect("] {
            let characters = Array(text)
            let starts = Self.indices(of: call, in: characters)
            #expect(!starts.isEmpty, "tools/AppIconComposition.swift no longer calls \(call)")
            for start in starts {
                guard let list = Self.argumentList(of: characters, openingAt: start + call.count - 1) else { continue }
                #expect(list.contains("MascotGeometry."),
                        "tools/AppIconComposition.swift: \(call)\(list)) writes its divergence from the rig as a number")
            }
        }
    }

    // The other direction, the one BrandPaletteContainmentTests learned the hard way: a scan that
    // passes because the thing it scans for no longer exists anywhere is not a passing scan.
    @Test func theDefinitionSiteExistsAndEveryScannedDrawingReadsIt() throws {
        let definition = try Self.source(Self.definitionSite)
        #expect(definition.contains("enum MascotGeometry"))
        // Foundation-only by design, like Tuck/Motion.swift: the file holds values, not rendering,
        // and it is compiled into the shield extension and into two macOS render binaries.
        #expect(definition.contains("import Foundation"))
        #expect(!definition.contains("import SwiftUI"))

        for file in Self.files {
            let source = try Self.source(file.path)
            #expect(source.contains("MascotGeometry."), "\(file.path) reads no rig constant at all")
        }
    }
}
