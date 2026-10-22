import Testing
@testable import Tuck

struct BlocklistSuggestionsTests {
    // Die Labels müssen wörtlich Apples deutschen Kategorien entsprechen, sonst zeigt der
    // Vorschlag auf eine Zeile, die es im Picker nicht gibt.
    @Test func theLabelsMatchTheGermanApplePickerRows() {
        #expect(BlocklistSuggestions.primary.map(\.label) == ["Soziale Netze", "Unterhaltung"])
        #expect(BlocklistSuggestions.secondary.map(\.label) == ["Spiele", "Informationen & Lesen"])
    }

    @Test func kurzvideoIsOnlyAnExampleLineAndNeverASuggestion() {
        let labels = (BlocklistSuggestions.primary + BlocklistSuggestions.secondary).map(\.label)
        #expect(!labels.contains { $0.localizedCaseInsensitiveContains("Kurzvideo") })
        #expect(BlocklistSuggestions.shortVideoExamples.contains("TikTok"))
        #expect(BlocklistSuggestions.shortVideoExamples.contains("Instagram Reels"))
        #expect(BlocklistSuggestions.shortVideoExamples.contains("YouTube Shorts"))
    }

    @Test func theMessengerWarningStaysAttachedToSozialeNetze() {
        #expect(BlocklistSuggestions.socialNetworksNote.contains("WhatsApp"))
        #expect(BlocklistSuggestions.socialNetworksNote.contains("Soziale Netze"))
        #expect(BlocklistSuggestions.socialNetworksNote.contains("einzelne Apps"))
    }

    @Test func theSecondaryLineNamesBothDeEmphasizedCategories() {
        #expect(BlocklistSuggestions.secondaryLine == "Auch möglich, wenn du magst: Spiele oder Informationen & Lesen.")
    }

    @Test func noSuggestionLineShouts() {
        let lines = (BlocklistSuggestions.primary + BlocklistSuggestions.secondary).map(\.reason)
            + [BlocklistSuggestions.intro, BlocklistSuggestions.shortVideoExamples, BlocklistSuggestions.socialNetworksNote]
        for line in lines {
            #expect(!line.contains("!"))
        }
    }
}
