import Foundation
import SwiftUI
import Testing
@testable import Tuck

// The placement is a pure function precisely so that this file can exist: there is no snapshot or
// view-inspection layer in this project, so the only thing an assertion can reach is either an
// arithmetic or the shape of the source. Both are used below.
//
// Own scan machinery rather than an import of MotionTokenTests', for the reason
// LayoutContainmentTests writes down itself: "so that a change to one scan's definition of a
// violation cannot silently redefine the other's".
struct SeasonalAccentTests {
    private let size = CGSize(width: 390, height: 844)

    // MARK: - The placement

    @Test func theStillImageUnderReduceMotionIsNotOneDotOnTopOfAnother() {
        for season in Season.allCases {
            let particles = SeasonalAccent.particles(season: season, t: 0,
                                                     mascotCenterY: 380, in: size)
            for first in particles.indices {
                for second in particles.indices where second > first {
                    #expect(particles[first].position != particles[second].position,
                            "\(season): two particles share a point at t = 0")
                }
            }
        }
    }

    // This replaces the earlier "draw nothing until the screen has measured itself": that
    // would be an arrival — empty in the first frame, full in the second.
    @Test func theFirstFrameIsNotEmptyJustBecauseTheScreenHasNotMeasuredItself() {
        let particles = SeasonalAccent.particles(season: .winter, t: 0, mascotCenterY: 0, in: size)
        let band = SeasonalAccent.band(mascotCenterY: 0, in: size)

        #expect(!particles.isEmpty)
        for particle in particles {
            #expect(particle.position.y >= band.low)
            #expect(particle.position.y <= band.high)
            // And nowhere near the top-left corner, which is where a naive mascotCenterY == 0 would
            // have put a hard-edged leaf.
            #expect(particle.position.y > size.height * 0.15)
            #expect(particle.position.x > size.width * 0.10)
        }
    }

    @Test func theSamePointInTimeAlwaysProducesTheSameFlakes() throws {
        for t in [0.0, 17.5, 1_000_000.25] {
            let first = SeasonalAccent.particles(season: .autumn, t: t, mascotCenterY: 380, in: size)
            let second = SeasonalAccent.particles(season: .autumn, t: t, mascotCenterY: 380, in: size)
            #expect(first == second)
        }
        #expect(!(try Self.strippedSource("Tuck/SeasonalAccent.swift")).contains("random"))
        #expect(!(try Self.strippedSource("Tuck/Season.swift")).contains("random"))
    }

    // A mechanism instead of prose: the asymmetry of the four seasons is a decision, so a
    // sixth flake has to be one too.
    @Test func everySeasonDrawsTheCountItWasDecidedWith() {
        #expect(SeasonalAccent.count(for: .spring) == 1)
        // Zero is not an omission: summer is a colour parameter in the sky, not a particle.
        #expect(SeasonalAccent.count(for: .summer) == 0)
        #expect(SeasonalAccent.count(for: .autumn) == 2)
        #expect(SeasonalAccent.count(for: .winter) == 3)

        for season in Season.allCases {
            #expect(SeasonalAccent.particles(season: season, t: 3.5, mascotCenterY: 380, in: size).count
                    == SeasonalAccent.count(for: season))
        }
    }

    // Without this, "near the creature" is a claim. The band has to hold over the whole range of
    // mascotCenterY a scrolled column can produce, including values off the screen entirely.
    @Test func theParticlesStayInTheBandAroundTheAnimal() {
        for centre in stride(from: -400.0, through: 1400.0, by: 100.0) {
            let band = SeasonalAccent.band(mascotCenterY: centre, in: size)
            #expect(band.low >= 0)
            #expect(band.high <= size.height)
            for t in stride(from: 0.0, through: 240.0, by: 7.5) {
                for particle in SeasonalAccent.particles(season: .winter, t: t,
                                                         mascotCenterY: centre, in: size) {
                    #expect(particle.position.y >= band.low)
                    #expect(particle.position.y <= band.high)
                    #expect(particle.position.x >= 0)
                    #expect(particle.position.x <= size.width)
                }
            }
        }
    }

    // MARK: - The two rules the accent may never break

    // SeasonalAccent's first rule, mechanically. Not "we decided not to": there is no parameter through which a season
    // could reach the creature, and no call site that would pass one.
    @Test func theSeasonNeverReachesTheAnimal() throws {
        let host = try Self.strippedLines("Tuck/GutenMorgenView.swift")
        let call = try #require(host.firstIndex { $0.contains("MascotView(") })
        let closing = try #require(host[call...].firstIndex { $0.contains(") { tapMascot(index:") })
        for line in host[call...closing] {
            #expect(!line.contains("season"), "a season reaches MascotView: \(line)")
        }

        for file in ["Tuck/MascotView.swift", "Tuck/MascotPose.swift"] {
            #expect(!(try Self.strippedSource(file)).contains("Season"), "\(file) knows about seasons")
        }
    }

    // Eight symbols, ONE list over TWO files — at three scan targets one of them
    // drifts. `MascotStage` and `MorningCelebration` are on it because they are counter disguises:
    // MascotStage is a pure function of completedMornings, and `stage.scale` is exactly the value a
    // placement function reaches for when it wants to sit "properly" on the animal's ground line.
    @Test func theUnearnedChannelTouchesNoCounterAndNoStore() throws {
        let forbidden = ["completedMornings", "MorningProgressStore", "MilestoneStore",
                         "acknowledgedMornings", "unlockQuota", "UserDefaults",
                         "MascotStage", "MorningCelebration"]
        for file in ["Tuck/Season.swift", "Tuck/SeasonalAccent.swift"] {
            let source = try Self.strippedSource(file)
            for symbol in forbidden {
                #expect(!source.contains(symbol),
                        "\(file) reaches the earned channel through `\(symbol)`")
            }
        }
    }

    // Freezing to the t = 0 composition is the same still image Reduce Motion shows anyway, so
    // it is no second case — but the CONDITION may not be spelled `reduceMotion`, or
    // `motionGatedSites` counts it and the pinned number carries two meanings.
    @Test func theAccentGoesStillWhileTheCelebrationRuns() throws {
        let body = try Self.body(of: "var body: some View {",
                                 in: try Self.body(of: "struct SeasonalAccent: View {",
                                                   in: try Self.strippedLines("Tuck/SeasonalAccent.swift")))
        let timeBinding = try #require(body.first { $0.contains("let t =") })

        #expect(timeBinding.contains("quiet"))
        #expect(body.contains { $0.contains("paused:") && $0.contains("quiet") })
        // The still composition is the same one either way — nothing new to look at, nothing to
        // maintain twice.
        #expect(SeasonalAccent.particles(season: .winter, t: 0, mascotCenterY: 380, in: size)
                == SeasonalAccent.particles(season: .winter, t: 0, mascotCenterY: 380, in: size))
    }

    // MARK: - The wiring

    // `enclosing` is not decoration: `var body: some View {` occurs three times in
    // GutenMorgenView.swift, and `body(of:in:)` takes the FIRST match, not a unique one.
    @Test func theAccentSitsBehindTheColumnAndTouchesNothing() throws {
        let host = try Self.body(of: "var body: some View {",
                                 in: try Self.body(of: "struct GutenMorgenView: View {",
                                                   in: try Self.strippedLines("Tuck/GutenMorgenView.swift")))
        let ambience = try #require(host.firstIndex { $0.contains("MorningAmbience(") })
        let object = try #require(host.firstIndex { $0.contains("FoundObjectAccent(") })
        let accent = try #require(host.firstIndex { $0.contains("SeasonalAccent(") })
        let column = try #require(host.firstIndex { $0.contains("VStack(spacing: Layout.root)") })

        #expect(ambience < object)
        #expect(object < accent)
        #expect(accent < column)

        let layer = try Self.strippedLines("Tuck/SeasonalAccent.swift")
        #expect(layer.filter { $0.contains(".accessibilityHidden(true)") }.count == 2)
        #expect(layer.filter { $0.contains(".allowsHitTesting(false)") }.count == 2)
    }

    // MARK: - The second cadence: the found object

    private var objectSize: CGSize { CGSize(width: 390, height: 844) }

    // The fairness invariant of the five placeholders, without rendering: same width, same standing line.
    // A period in which the object were bigger or heavier would be a better period. First Path
    // assertion of this project — `import SwiftUI` in test files is established, `Path.boundingRect`
    // is plain CoreGraphics, and both the ellipse and the arc measured tight to within 5e-7.
    @Test func everyPlaceholderIsTheSameWidthAndStandsOnTheSameLine() {
        let standing = CGPoint(x: 99, y: 500)
        for object in FoundObject.allCases {
            let box = FoundObjectAccent.box(for: object, standingOn: standing)
            let bounds = FoundObjectAccent.path(for: object, in: box).boundingRect

            #expect(abs(bounds.width - FoundObjectAccent.width) < 0.001, "\(object) width")
            #expect(abs(bounds.maxY - standing.y) < 0.001, "\(object) standing line")
            #expect(abs(box.maxY - standing.y) < 0.001, "\(object) box standing line")
        }
    }

    @Test func theFirstFrameAlreadyHasTheObject() {
        let point = FoundObjectAccent.position(mascotCenterY: 0, in: objectSize)

        #expect(point.y >= objectSize.height * 0.18)
        #expect(point.y <= objectSize.height * 0.88)
        #expect(point.x > 0)
        #expect(point.x < objectSize.width)
    }

    // "Beside the animal" as an assertion. The ring radius is 89 — the 178 stands as a literal
    // `.frame(width: 178, …)` in GutenMorgenView and is repeated here with a comment rather than
    // imported, because importing it would make a layout number look like a shared token.
    @Test func theObjectStaysClearOfTheAnimalAndOfTheRing() {
        for centre in stride(from: 0.0, through: 900.0, by: 50.0) {
            let point = FoundObjectAccent.position(mascotCenterY: centre, in: objectSize)
            let horizontal = objectSize.width / 2 - point.x

            #expect(horizontal > MascotGeometry.rigWidth / 2, "centre \(centre)")
            let anchor = centre > 0 ? centre : objectSize.height * 0.42
            #expect(hypot(objectSize.width / 2 - point.x, anchor - point.y) > 89, "centre \(centre)")
        }
    }

    // The clamp, over the whole mascotCenterY range a scrolled column produces — including
    // values far off screen in both directions.
    @Test func theObjectStaysOnScreenAtTheLargestTextSize() {
        for centre in stride(from: -600.0, through: 2000.0, by: 25.0) {
            let point = FoundObjectAccent.position(mascotCenterY: centre, in: objectSize)
            #expect(point.y >= objectSize.height * 0.18, "centre \(centre)")
            #expect(point.y <= objectSize.height * 0.88, "centre \(centre)")
        }
    }

    // The first-frame rule, mechanically. Nine forbidden strings, one assurance: what stands here stood in the first
    // rendered frame. `.now` and `Date()` are two spellings of the same sin and both are needed.
    @Test func theObjectNeverArrives() throws {
        let region = try Self.body(of: "struct FoundObjectAccent: View {",
                                   in: try Self.strippedLines("Tuck/SeasonalAccent.swift"))
            .joined(separator: "\n")

        for forbidden in [".transition(", "withAnimation", ".animation(", "TimelineView",
                          "@State", "onAppear", "Timer", ".now", "Date()"] {
            #expect(!region.contains(forbidden), "the found object arrives through `\(forbidden)`")
        }
        // The other direction, so the scan cannot go green because the region disappeared —
        // LayoutContainmentTests.theScanHasSomethingToScan learned this the hard way.
        #expect(region.contains("FoundObject"))
        #expect(region.count > 400)
    }

    // The found object is deliberately NOT in `motionGatedSites`: a region with zero occurrences
    // pinned to zero can never go red in the direction that list exists for. The sharper check is
    // absence in its own region — an occurrence means either somebody animated it or somebody wrote
    // a second meaning into the token.
    @Test func theStillLayerCarriesNoMotionGate() throws {
        let region = try Self.body(of: "struct FoundObjectAccent: View {",
                                   in: try Self.strippedLines("Tuck/SeasonalAccent.swift"))

        #expect(!region.joined(separator: "\n").contains("reduceMotion"))
        #expect(!region.isEmpty)
    }

    // MARK: - Reading

    private static var repository: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    // Comments stripped before anything is scanned: this layer explains in prose why it does not
    // touch MascotStage, and a sentence about the rule must not read as the rule being broken.
    static func strippedLines(_ relativePath: String) throws -> [String] {
        try String(contentsOf: repository.appendingPathComponent(relativePath), encoding: .utf8)
            .components(separatedBy: "\n")
            .map { line in
                guard let marker = line.range(of: "//") else { return line }
                return String(line[..<marker.lowerBound])
            }
    }

    static func strippedSource(_ relativePath: String) throws -> String {
        try strippedLines(relativePath).joined(separator: "\n")
    }

    enum ScanError: Error { case notFound(String), neverCloses(String) }

    static func body(of signature: String, in lines: [String]) throws -> [String] {
        guard let start = lines.firstIndex(where: { $0.contains(signature) }) else {
            throw ScanError.notFound(signature)
        }
        var depth = 0
        var opened = false
        var body: [String] = []
        for index in start ..< lines.count {
            let line = lines[index]
            depth += line.filter { $0 == "{" }.count
            depth -= line.filter { $0 == "}" }.count
            if depth > 0 { opened = true }
            if index > start { body.append(line) }
            if opened && depth == 0 { return body }
        }
        throw ScanError.neverCloses(signature)
    }
}
