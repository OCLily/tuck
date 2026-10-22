import Foundation
import Testing
@testable import Tuck

// The sprout began on morning 7: `the sprout` opened with `if stage != .start`, so the
// first stage of the rig — the one every new user looks at for a week — drew no growth at all. The
// change gives stage 0 a seed and, with it, three *independent* geometries instead of one shared
// scale: the old `.scaleEffect(stage == .eingespielt ? 1.0 : 0.6)` shrank stem and leaf together, so
// "Warm geworden" could not have a longer stem without also having a bigger leaf.
//
// Why a source scan rather than an enum comparison, spelled out because it is the part that looks
// like a shortcut and is not: a control group needs a state of the code where the assertion compiles and fails.
// `MascotStage.start.sproutStage == .seed` cannot do that — before the change the attribute does not
// exist, so the pre-fix run is a compile error, and a compile error is not a red test. The shape of
// the drawing code is the only thing that exists on both sides of the change, so that is what is
// pinned. Same reason and same form as BodyInkSweepTests and HitTargetTests: there is no snapshot or
// view-inspection layer in this project.
//
// What this file deliberately does NOT pin: the stage thresholds 0/7/30, the saturation values
// 0.35/0.7/1.0 and the scale values. They are unchanged by the seed and are pinned where they already
// were (MascotStageProgressTests, docs/design/design-system.md).
struct SproutSourceTests {
    // The drawing this scans is MascotPose, the extracted
    // bodyStack, and `sprout` reads the pose's own `sproutStage` parameter instead of a stage's
    // attribute. What this file pinned before is unchanged — three branches, three independent stem lengths, a
    // bud only in the first — so the file and the two spellings move and nothing else does.
    private static let file = "Tuck/MascotPose.swift"
    private static let signature = "private var sprout: some View {"

    private static func source(_ relativePath: String) throws -> [String] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n")
    }

    // The member's own brace block and nothing around it. A whole-file grep would be answered by
    // neighbouring members that legitimately ask the same questions.
    private static func sproutBody() throws -> [String] {
        let lines = try source(file)
        guard let start = lines.firstIndex(where: { $0.contains(signature) }) else {
            throw SproutScanError.functionNotFound
        }

        var depth = 0
        var body: [String] = []
        for index in start..<lines.count {
            let line = lines[index]
            depth += line.filter { $0 == "{" }.count
            depth -= line.filter { $0 == "}" }.count
            if index > start { body.append(line) }
            if depth == 0 { return body.dropLast().map { $0 } }
        }
        throw SproutScanError.functionNeverCloses
    }

    enum SproutScanError: Error { case functionNotFound, functionNeverCloses }

    // Each `case .<form>:` of the switch mapped to the lines of its *own* branch, the case line
    // itself dropped. Without the split, every question about "what does the seed draw" is really a
    // question about what the whole function draws somewhere, and the answer is yes for all three.
    private static func sproutBranchBodies() throws -> [String: [String]] {
        let body = try sproutBody()
        var branches: [String: [String]] = [:]
        var current: String?
        for line in body {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("case ."), trimmed.hasSuffix(":") {
                let form = String(trimmed.dropFirst("case .".count).dropLast())
                branches[form] = []
                current = form
                continue
            }
            if let form = current { branches[form, default: []].append(line) }
        }
        return branches
    }

    // The factor on `Self.stemLength`, as a number. A branch that passes the constant unmultiplied
    // is 1.0 — the point of parsing rather than comparing text is that `Self.stemLength` and
    // `Self.stemLength * 1.0` are two spellings of one length.
    private static func stemMultiplier(in branch: [String]) -> Double? {
        guard let line = branch.first(where: { $0.contains("stemLength: ") }),
              let label = line.range(of: "stemLength: ") else { return nil }
        let expression = String(line[label.upperBound...].prefix { $0 != ")" })
            .trimmingCharacters(in: .whitespaces)
        guard let star = expression.range(of: "*") else { return 1.0 }
        return Double(expression[star.upperBound...].trimmingCharacters(in: .whitespaces))
    }

    // Written out by hand, and not read off `SproutStage.allCases`, for the reason in the file
    // comment: this file has to *compile* against the pre-fix code to be able to fail against it.
    // A reference to the new type here would turn the control-group run into a build error.
    private static let forms = ["seed", "oneLeaf", "twoLeaves"]

    // The red one. Before the seed this line was the first statement of the function.
    @Test func theSproutNoLongerSkipsTheFirstStage() throws {
        let body = try Self.sproutBody()
        #expect(!body.contains { $0.contains("stage != .start") },
                "\(Self.file): the sprout still draws nothing at stage .start")
    }

    // The other half: gone is not the same as replaced. Without this, deleting the guard outright —
    // which would give every stage two full leaves — would pass the test above.
    @Test func theSproutBranchesOnTheStageAttribute() throws {
        let body = try Self.sproutBody()
        #expect(body.contains { $0.contains("switch sproutStage") },
                "\(Self.file): the sprout does not switch over the sproutStage it was handed")
        for form in Self.forms {
            #expect(body.contains { $0.contains("case .\(form):") },
                    "\(Self.file): the sprout has no branch for .\(form)")
        }
    }

    // The coupling that made three independent lengths impossible. It scaled the whole VStack, so
    // stem and leaf could only ever grow together.
    @Test func theStemAndTheLeafNoLongerShareOneScale() throws {
        let body = try Self.sproutBody()
        #expect(!body.contains { $0.contains(".scaleEffect(") },
                "\(Self.file): the sprout still scales its column instead of sizing stem and leaf apart")
    }

    // Three branches with three different stem lengths — the geometry table
    // (0.6 / 0.8 / 1.0), read off the call sites rather than off the enum that feeds them.
    //
    // Deduplicating the raw source text of the three expressions proved only that they are *spelled*
    // differently, which is not the property the stage rig needs: `Self.stemLength` next to
    // `Self.stemLength * 1.0` reads as two lengths and draws one. The multiplier is parsed out and
    // the numbers are compared — and since the table is a growth table, they have to climb.
    @Test func theThreeStagesDrawThreeDifferentStemLengths() throws {
        let branches = try Self.sproutBranchBodies()
        let perStage = Self.forms.map { ($0, Self.stemMultiplier(in: branches[$0] ?? [])) }
        let multipliers = perStage.compactMap { $0.1 }

        #expect(multipliers.count == Self.forms.count,
                "\(Self.file): no numeric stem length for every sprout stage: \(perStage)")
        #expect(Set(multipliers).count == multipliers.count,
                "\(Self.file): two sprout stages compute the same stem length: \(perStage)")
        #expect(multipliers == multipliers.sorted(),
                "\(Self.file): the stem does not get longer from stage to stage: \(perStage)")
    }

    // Gone is not the same as drawn in the right branch. `case .seed:` existing and a `bud` drawing
    // existing were two checks that never met: a `.seed` branch drawing a `leaf` satisfied both, and
    // the seed — the entire point of the change — would have been a small first leaf. Both directions are
    // needed: the bud has to be in the seed's branch, and *not* in the other two, or "every stage
    // draws a bud" would pass as well.
    @Test func onlyTheSeedBranchDrawsTheBud() throws {
        let branches = try Self.sproutBranchBodies()
        for form in Self.forms {
            guard let crown = branches[form]?
                .map({ $0.trimmingCharacters(in: .whitespaces) })
                .joined(separator: " ") else {
                Issue.record("\(Self.file): the sprout has no branch for .\(form)")
                continue
            }
            if form == "seed" {
                #expect(crown.contains("bud"),
                        "\(Self.file): the .seed branch draws no bud, it draws: \(crown)")
            } else {
                #expect(!crown.contains("bud"),
                        "\(Self.file): the .\(form) branch draws a bud instead of its leaves")
                #expect(crown.contains("leaf"),
                        "\(Self.file): the .\(form) branch draws no leaf")
            }
        }
    }

    // The seed is the one shape that did not exist before: a bud instead
    // of a leaf, in the same fill/outline pair the leaf already uses.
    //
    // The fill it names moved from `tuckSage` to `tuckMascotBody`: in light
    // those two are the same colour to the byte, in dark they are not, and the sprout belongs to
    // the animal rather than to the app's surfaces. Repointed rather than relaxed — a check for
    // "some fill" would pass a bud drawn in the settings rows' own green.
    @Test func theSeedDrawsABudInTheLeafsOwnFillAndOutline() throws {
        let lines = try Self.source(Self.file)
        guard let start = lines.firstIndex(where: { $0.contains("private var bud: some View {") }) else {
            Issue.record("\(Self.file): no `bud` drawing")
            return
        }
        let block = lines[start..<min(start + 8, lines.count)].joined(separator: "\n")

        #expect(block.contains("Circle()"), "\(Self.file): the bud is not a round head")
        #expect(block.contains(".fill(Color.tuckMascotBody)"),
                "\(Self.file): the bud is not filled from the mascot's own body token")
        #expect(block.contains("ink.opacity(0.5)"), "\(Self.file): the bud does not carry the leaf's outline")
    }
}
