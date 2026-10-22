import Foundation
import Testing
@testable import Tuck

// The token already existed and BodyInkContrastTests proved it clears
// 4,5:1 everywhere; what did not exist was its application — two call sites out of the app, so the
// screens still read exactly as they did before, body copy set heavier than the titles above it.
// This file pins the sweep that finished it.
//
// A source scan, like HitTargetTests and OnboardingCompositionTests, and for the same reason: there
// is no snapshot or view-inspection layer in this project, and a colour set through
// `.foregroundStyle` on a Text is invisible to every runtime assertion available here. What is
// pinned is the shape at the call site.
//
// The two halves are pinned together on purpose. `tuckInk` without weight 400 would still be the
// textwall the token was minted to end (the point is the missing hierarchy, not the ratio),
// and weight 400 without `tuckInk` would put running text at 15 pt on charcoal green's 3,96:1 —
// below AA small text with no large-text exception left to claim. Either alone is a regression.
struct BodyInkSweepTests {
    struct Site: Sendable, CustomTestStringConvertible {
        let file: String
        let owner: String

        var testDescription: String { "\(file) — \(owner)" }
    }

    // Every line the sweep moved onto the Fließtext token, by the call-site line that owns it.
    // Deliberately the whole list rather than a count: a count survives one site losing the token
    // while another gains it, which is exactly the shape of the drift this file exists to catch.
    static let sites: [Site] = [
        // Already converted before the sweep, kept here so the two references cannot drift apart.
        Site(file: "Tuck/SettingsView.swift", owner: "Text(text)"),
        Site(file: "Tuck/WakeAlarmSetupView.swift", owner: "Text(\"An den anderen Tagen bleibt auch das Sperrfenster aus.\")"),

        Site(file: "Tuck/OnboardingFlowView.swift", owner: "Text(\"Der Morgen und der Abend sollen dir gehören"),
        Site(file: "Tuck/OnboardingFlowView.swift", owner: "Text(\"Damit wählst du selbst, welche Apps morgens kurz warten müssen"),
        Site(file: "Tuck/OnboardingFlowView.swift", owner: "Text(\"Weiter geht es, sobald der Wecker steht.\")"),
        Site(file: "Tuck/OnboardingFlowView.swift", owner: "Text(\"Guten Morgen sagen wir dir ab jetzt jeden Morgen hier.\")"),

        Site(file: "Tuck/AccessAndAppSelectionView.swift", owner: "statusLine"),
        Site(file: "Tuck/AccessAndAppSelectionView.swift", owner: "Text(BlocklistSuggestions.primaryLine)"),
        Site(file: "Tuck/AccessAndAppSelectionView.swift", owner: "Text(BlocklistSuggestions.socialNetworksNote)"),
        Site(file: "Tuck/AccessAndAppSelectionView.swift", owner: "Text(\"Noch nichts gewählt"),
        Site(file: "Tuck/AccessAndAppSelectionView.swift", owner: "Text(\"Die Auswahl erscheint hier, sobald der Zugriff erlaubt ist.\")"),

        Site(file: "Tuck/PaywallView.swift", owner: "Text(statusDetail)"),
        Site(file: "Tuck/PaywallView.swift", owner: "Text(text)"),
        Site(file: "Tuck/PaywallView.swift", owner: "Text(noticeDetail(notice))"),
        Site(file: "Tuck/PaywallView.swift", owner: "Text(\"Tuck Plus läuft einen Monat oder ein Jahr"),
        Site(file: "Tuck/PaywallView.swift", owner: "Text(\"Die Sperre selbst ist mit und ohne Abo gleich streng."),
        Site(file: "Tuck/PaywallView.swift", owner: "Text(\"Tuck finanziert sich über das Abo"),
        Site(file: "Tuck/PaywallView.swift", owner: "Text(detail)"),

        Site(file: "Tuck/BedtimeSetupView.swift", owner: "Text(\"30 Minuten vor und 30 nach deiner Bettzeit"),
        Site(file: "Tuck/BedtimeSetupView.swift", owner: "Text(Self.windowSentence(BedtimeStore.bedtime()))"),
        Site(file: "Tuck/BedtimeSetupView.swift", owner: "Text(Self.bedtimeRemovedLine)"),
        Site(file: "Tuck/BedtimeSetupView.swift", owner: "statusLine"),

        Site(file: "Tuck/WakeAlarmSetupView.swift", owner: "statusLine"),
        Site(file: "Tuck/WakeAlarmSetupView.swift", owner: "Text(StatusCopy.failure(subject: String(localized: \"Das \\(StatusCopy.blockWindowNoun)\"),"),

        Site(file: "Tuck/OverrideFlowView.swift", owner: "Text(\"Freischalten braucht trotzdem einen Moment"),
        Site(file: "Tuck/OverrideFlowView.swift", owner: "Text(ShieldCopy.exhaustedBody(for: context))"),
        Site(file: "Tuck/OverrideFlowView.swift", owner: "Text(quotaLine(remaining: remaining))")
    ]

    // The three surfaces the sweep was not allowed to touch, and the reason each is out.
    //
    // The two button files are the house form for a primary action: their label is a
    // control, not prose, and it sits on charcoal green or on sage 0.5 where only the large-text
    // path clears the bar at all.
    //
    // GutenMorgenView is the interesting one, and it is excluded for two different reasons, not one.
    // Four of its five sites (subline, blockWindowLine, the override button, the gear glyph) sit
    // directly on the sky, and the design system keeps the sky out of the ink table on purpose: a four-stop
    // gradient running 2,44:1 to 4,16:1, whose accepted span is measured against charcoal
    // green. Weight 400 there would drop the large-text path (>=14 pt at 700, bar 3:1) on the one
    // ground of the app that cannot pay the small-text 4,5:1 in return.
    //
    // The fifth site, SpeechBubble, does NOT carry that reason — an earlier draft of this comment
    // claimed it did. Its ground is tuckFloatingPlate.opacity(0.9), which
    // the design system's own table lists at 5,94:1: tuckInk would clear 4,5:1 there even at weight 400, on
    // contrast alone. It stays bold for a different reason — five words of direct mascot address are
    // voice, not the Fließtext/Footer/Erklärzeile the design system draws the role split around, and converting
    // it would be a voice decision this sweep was not commissioned to make, not an application of
    // one already approved. All five sites are therefore a deliberate outcome, just not the same
    // deliberate outcome — which is a distinction no diff, and no single excluded-file test, can
    // carry by itself; this comment is where it has to live.
    static let excludedFiles = [
        "Tuck/GutenMorgenView.swift",
        "Tuck/PrimaryButtonPlate.swift",
        "Tuck/OpenSystemSettingsButton.swift"
    ]

    static let sweptFiles = [
        "Tuck/SettingsView.swift",
        "Tuck/OnboardingFlowView.swift",
        "Tuck/AccessAndAppSelectionView.swift",
        "Tuck/PaywallView.swift",
        "Tuck/BedtimeSetupView.swift",
        "Tuck/WakeAlarmSetupView.swift",
        "Tuck/OverrideFlowView.swift"
    ]

    private static let inkModifier = ".foregroundStyle(Color.tuckInk)"
    private static let bodyWeight = ".font(.subheadline.weight(.regular))"

    private static func source(_ relativePath: String) throws -> [String] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n")
    }

    private static func trimmed(_ line: String) -> String {
        line.trimmingCharacters(in: .whitespaces)
    }

    // The modifier chain the ink sits in, and nothing else. Bounded by lines that start with "."
    // in both directions: without that bound the window reaches the neighbouring Text of the same
    // VStack, and a card title's legitimate weight 700 two lines up reads as this line's own.
    private static func chain(around index: Int, in lines: [String]) -> [String] {
        var block = [trimmed(lines[index])]
        var above = index - 1
        while above >= 0, trimmed(lines[above]).hasPrefix(".") {
            block.append(trimmed(lines[above]))
            above -= 1
        }
        var below = index + 1
        while below < lines.count, trimmed(lines[below]).hasPrefix(".") {
            block.append(trimmed(lines[below]))
            below += 1
        }
        return block
    }

    // Where an ink block starts: up past its own chain, then up again to the line that opens the
    // view being modified. The second step is not decoration — StatusCopy.failure spans three lines
    // at two call sites, so the first non-modifier line above the chain is an argument of the Text
    // rather than the Text itself.
    private static func owner(of index: Int, in lines: [String]) -> String? {
        var candidate = index - 1
        while candidate >= 0, trimmed(lines[candidate]).hasPrefix(".") { candidate -= 1 }
        let chainTop = candidate

        while candidate >= 0, candidate > chainTop - 8 {
            let line = trimmed(lines[candidate])
            if line.contains("Text(") || line == "statusLine" { return line }
            candidate -= 1
        }
        return chainTop >= 0 ? trimmed(lines[chainTop]) : nil
    }

    private static func inkLines(in lines: [String]) -> [Int] {
        lines.indices.filter { trimmed(lines[$0]) == inkModifier }
    }

    @Test(arguments: sites) func everySweptLineCarriesTheInkTokenAtWeight400(site: Site) throws {
        let lines = try Self.source(site.file)
        let matches = Self.inkLines(in: lines).filter { index in
            Self.owner(of: index, in: lines)?.hasPrefix(site.owner) == true
        }

        #expect(matches.count == 1,
                "\(site.file): expected exactly one `\(Self.inkModifier)` owned by `\(site.owner)`, found \(matches.count)")

        for index in matches {
            // The font has to sit in the same chain, above or below the colour — the whole point of
            // the token is that the line may fall to weight 400, and a `tuckInk` line still set at
            // 700 has taken the ratio and left the hierarchy behind.
            let block = Self.chain(around: index, in: lines)
            #expect(block.contains(Self.bodyWeight),
                    "\(site.file):\(index + 1) `\(site.owner)` has the ink but not \(Self.bodyWeight)")
            #expect(!block.contains { $0.contains(".weight(.bold)") },
                    "\(site.file):\(index + 1) `\(site.owner)` still carries a bold weight in the same chain")
        }
    }

    // The other direction, and the one a per-site list cannot give on its own: no site may acquire
    // the token without appearing above. A body line converted in passing is still a design
    // decision, and the ink token is a role split — a token that spreads by habit has undone it.
    @Test(arguments: sweptFiles) func noFileCarriesAnInkSiteThatIsNotPinned(file: String) throws {
        let lines = try Self.source(file)
        let expected = Set(Self.sites.filter { $0.file == file }.map(\.owner))

        for index in Self.inkLines(in: lines) {
            let owner = Self.owner(of: index, in: lines)
            #expect(owner != nil, "\(file):\(index + 1) ink modifier with no owning call site")
            #expect(expected.contains { owner?.hasPrefix($0) == true },
                    "\(file):\(index + 1) `\(owner ?? "")` carries `\(Self.inkModifier)` and is not in BodyInkSweepTests.sites")
        }
    }

    @Test(arguments: excludedFiles) func theSurfacesOutsideTheSweepKeptTheBrandColour(file: String) throws {
        let lines = try Self.source(file)

        #expect(Self.inkLines(in: lines).isEmpty,
                "\(file) is out of the sweep's scope (button plate, or the sky ground) and must not carry \(Self.inkModifier)")
        #expect(lines.contains { Self.trimmed($0).contains(".weight(.bold)") },
                "\(file) lost the weight 700 its ground still needs")
    }

    // The type ladder is 20 > 17 > 15, and the Fließtext token is one row of it: 15 pt at weight 400.
    // `.footnote` (13 pt) and `.caption` (12 pt) are named there as not to be used for running text
    // at any weight — the one converted site that was written at `.footnote` is on `.subheadline`
    // since this sweep, so the rule holds without an exception to remember.
    @Test(arguments: sweptFiles) func noSweptFilePutsRunningTextBelowTheLadder(file: String) throws {
        let lines = try Self.source(file)

        for index in Self.inkLines(in: lines) {
            for line in Self.chain(around: index, in: lines) {
                #expect(!line.hasPrefix(".font(.footnote"),
                        "\(file):\(index + 1) sets body copy at 13 pt")
                #expect(!line.hasPrefix(".font(.caption"),
                        "\(file):\(index + 1) sets body copy at 12 pt")
            }
        }
    }
}
