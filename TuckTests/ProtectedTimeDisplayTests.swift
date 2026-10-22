import Foundation
import Testing
@testable import Tuck

// The one surface the counter has. Asserted against StatusCopy rather than against fixed German
// literals, so the suite says the same thing whichever language the host runs in — the wording
// itself is pinned in EnglishLocalizationTests.
struct ProtectedTimeDisplayTests {
    private func unit(_ text: String) -> Substring? {
        text.split(separator: " ").last
    }

    // Zero is a count too, so the absence placeholder is the count one — and anything under
    // an hour is still zero full hours.
    @Test func anythingUnderAnHourDegradesToTheCountPlaceholder() {
        #expect(StatusCopy.fullHours(0) == StatusCopy.emptyCount)
        #expect(StatusCopy.fullHours(1) == StatusCopy.emptyCount)
        #expect(StatusCopy.fullHours(3599) == StatusCopy.emptyCount)
        #expect(StatusCopy.fullHours(3600) != StatusCopy.emptyCount)
    }

    // Rounded down, never up: the row may not claim more time than has passed.
    @Test func hoursAreRoundedDownRatherThanToTheNearest() {
        #expect(StatusCopy.fullHours(3600).contains("1"))
        #expect(StatusCopy.fullHours(7199).contains("1"))
        #expect(!StatusCopy.fullHours(7199).contains("2"))
        #expect(StatusCopy.fullHours(7200).contains("2"))
    }

    // A unit that switches at a threshold is a level-up feeling, and this number has no levels. Past
    // 24 h and past a year it stays the same word it was at two hours.
    @Test func theUnitNeverChangesAnywhereInTheRange() {
        let two = StatusCopy.fullHours(2 * 3600)
        #expect(unit(StatusCopy.fullHours(25 * 3600)) == unit(two))
        #expect(unit(StatusCopy.fullHours(500 * 3600)) == unit(two))
        #expect(StatusCopy.fullHours(25 * 3600).contains("25"))
        // Three digits, not four: past a thousand the number carries its locale's grouping
        // separator, which is the formatter's business and not this rule's.
        #expect(StatusCopy.fullHours(999 * 3600).contains("999"))
    }
}
