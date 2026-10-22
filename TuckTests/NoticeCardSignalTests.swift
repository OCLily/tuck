import Foundation
import Testing
@testable import Tuck

// The paywall's notice card used to say "this needs your attention" through one
// thing only: its fill changed from sage to dusty rose. For a user with a colour vision deficiency
// that is not a signal at all — and the usual second signal, red, is ruled out by the palette. So the card
// gets a contour, the pattern the period row already gets right: stroke AND glyph, neither of
// them colour alone.
//
// A source scan, like every composition check in this project (there is no snapshot layer). What it
// has to hold is not "a border exists" but the four properties that make it the right border, each
// of which has a plausible wrong version a later hand could introduce.
struct NoticeCardSignalTests {
    private func noticeCardBody() throws -> [String] {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Tuck/PaywallView.swift")
        let lines = try String(contentsOf: source, encoding: .utf8).components(separatedBy: "\n")
        let start = try #require(lines.firstIndex { $0.contains("private func noticeCard(") })
        let end = try #require(lines[start...].dropFirst().firstIndex { $0 == "    }" })
        return Array(lines[start ... end]).map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private func code() throws -> [String] {
        try noticeCardBody().filter { !$0.hasPrefix("//") }
    }

    @Test func theNoticeCardCarriesASecondSignalBesidesItsFill() throws {
        let code = try code()
        #expect(code.contains { $0.contains(".strokeBorder(Color.tuckCharcoalGreen, lineWidth: 2)") },
                "the notice card is back to announcing itself through its fill alone")
    }

    // strokeBorder, not stroke: stroke straddles the path and puts one point outside the card,
    // which moves its frame and clips against the cards beside it.
    @Test func theContourIsDrawnInwardSoTheCardKeepsItsFrame() throws {
        let code = try code()
        for line in code where line.contains("lineWidth:") {
            #expect(line.contains(".strokeBorder("),
                    "`\(line)` uses stroke, which draws half outside the card's own frame")
        }
    }

    // Alpha is allowed on a stroke and never on text, and the period row's unselected state uses 0.35 for
    // exactly that — but there the alpha carries a meaning (not chosen). A notice card is never
    // half noticed, so its contour is opaque.
    @Test func theContourIsOpaque() throws {
        let code = try code()
        let contour = try #require(code.first { $0.contains(".strokeBorder(") })
        #expect(!contour.contains(".opacity("), "the attention signal is dimmed: \(contour)")
    }

    // Everything the notice-card spec already decided stays decided. The change that added the
    // contour is allowed to add a contour and nothing else.
    @Test func nothingElseAboutTheCardMoved() throws {
        let code = try code()
        #expect(code.contains { $0.contains("RoundedRectangle(cornerRadius: Layout.radiusCard)") })
        #expect(code.contains { $0.contains(".fill(Color.tuckDustyRose.opacity(0.45))") })
        #expect(code.contains { $0.contains("Text(noticeTitle(notice))") })
        #expect(code.contains { $0.contains(".font(.body.weight(.bold))") })
        #expect(code.contains { $0.contains(".font(.subheadline.weight(.regular))") })
        #expect(code.contains { $0.contains(".foregroundStyle(Color.tuckInk)") })

        // No red anywhere near this card. The whole reason the second signal is a contour.
        for line in code {
            #expect(!line.contains(".red"), "a red appeared on the notice card: \(line)")
        }
    }

    // The copy template is the one thing about this screen that must NOT be touched, and it is the
    // one thing an earlier specification quotes wrongly — it prints a full stop before \(reason) where
    // the shipped, pinned, localised string has a colon. A "correction" to that spelling
    // would break StatusCopyTests and the string catalogue's key at once. Pinned here as well, next
    // to the change that sits closest to it.
    @Test func theProtectedCopyTemplateStillHasItsColon() throws {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Tuck/StatusCopy.swift")
        let text = try String(contentsOf: source, encoding: .utf8)
        #expect(text.contains("Das sagt iOS dazu: \\(reason)"))
        #expect(!text.contains("Das sagt iOS dazu. \\(reason)"))
    }
}
