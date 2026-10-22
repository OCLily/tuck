import Foundation
import Testing

// The half that cannot be expressed in Swift. `BrandPalette` compiles into the app
// target like any other enum, so nothing stops a view from reading `Color.BrandPalette.dawnRed`;
// what forbids it is a product decision — Morgenrot is the layer the app is seen *before* it is
// opened (store listing, website, icon), and the screens are built to hold none of it at 6 a.m.
// A rule with no mechanism is a rule that survives until the first person who has not read
// design-system.md, which is why this is a source scan and not a comment.
//
// Same idiom as BodyInkSweepTests and HitTargetTests, and for the same reason those give: there is
// no snapshot or view-inspection layer here, and a colour set through `.foregroundStyle` or handed
// to `AlarmAttributes` is invisible to every runtime assertion available.
//
// All five compiled directories, not "the view files". Tuck/WakeAlarmScheduler.swift is the case
// that makes the difference: it is not a View, it draws nothing, and it still carries a colour —
// the AlarmKit tint, which travels out of the app into the system's own alarm surface. A scan
// restricted to views would wave exactly that one through.
//
// Zero exceptions on purpose. `tools/` is not scanned because it is not an Xcode target and never
// compiles into a bundle; inside these five directories there is no second place the tokens may
// appear, not even a font or accent line — the only surface that legitimately reads Morgenrot is
// tools/AppIconComposition.swift, which is outside all five.
struct BrandPaletteContainmentTests {
    static let scannedDirectories = [
        "Tuck",
        "Shared",
        "TuckShield",
        "TuckShieldAction",
        "TuckMonitor"
    ]

    static let definitionSite = "Tuck/Color+Palette.swift"

    private static var repository: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    // Relative paths rebuilt from the repository root rather than the last path component, so a
    // file added one directory deeper is still scanned under a path the exception list can match.
    private static func swiftFiles(in directory: String) -> [String] {
        let root = repository.appendingPathComponent(directory)
        let prefix = repository.path.hasSuffix("/") ? repository.path : repository.path + "/"
        guard let enumerator = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: nil
        ) else { return [] }

        return enumerator
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
            .map { $0.path.replacingOccurrences(of: prefix, with: "") }
            .sorted()
    }

    @Test(arguments: scannedDirectories)
    func noCompiledFileOutsideThePaletteReadsTheBrandTokens(directory: String) throws {
        let files = Self.swiftFiles(in: directory)
        #expect(!files.isEmpty, "\(directory) produced no Swift files — the scan is looking at nothing")

        for file in files where file != Self.definitionSite {
            let source = try String(
                contentsOf: Self.repository.appendingPathComponent(file),
                encoding: .utf8
            )
            #expect(!source.contains("BrandPalette"),
                    "\(file) reads BrandPalette. Morgenrot is the external brand layer and may not enter a product surface; the only in-repo consumer is tools/AppIconComposition.swift, which is not a compiled target.")
        }
    }

    // The other direction: the scan is worthless the day the enum moves and every file passes
    // because none of them mentions a name that no longer exists anywhere.
    @Test func theDefinitionSiteStillHoldsTheEnum() throws {
        let source = try String(
            contentsOf: Self.repository.appendingPathComponent(Self.definitionSite),
            encoding: .utf8
        )
        #expect(source.contains("enum BrandPalette"))
    }
}
