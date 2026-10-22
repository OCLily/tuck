import Foundation
import Testing
@testable import Tuck

// The one place this app could burn reciprocity without anyone noticing. The morning screen is where
// something is GIVEN — a ring the user filled, an animal they raised, a line they earned — and the
// moment a request hangs off a given moment, the gift has been turned into a lead magnet.
//
// This is green today (verified at all three call sites: SettingsView, OverrideFlowView,
// BedtimeSetupView — GutenMorgenView.swift contains no `Paywall` occurrence at all). It costs
// nothing and it is cheaper than the review that would later have to argue it back out again.
struct MorningScreenReciprocityTests {
    private static func source(_ relativePath: String) throws -> String {
        try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    @Test func theMorningScreenHasNoPathToTheCashRegister() throws {
        let morning = try Self.source("Tuck/GutenMorgenView.swift")
        for symbol in ["PaywallView", "showPaywall"] {
            #expect(!morning.contains(symbol),
                    """
                    `\(symbol)` reached the morning screen. Nothing on this screen asks for \
                    anything: no upsell after a counted morning, no rating prompt after a block \
                    window that went well. What is given here is given.
                    """)
        }

        // The other direction, so this scan cannot go green because `PaywallView` disappeared —
        // the lesson LayoutContainmentTests.theScanHasSomethingToScan records for
        // BrandPaletteContainmentTests, learned the hard way.
        for host in ["Tuck/SettingsView.swift", "Tuck/OverrideFlowView.swift", "Tuck/BedtimeSetupView.swift"] {
            #expect(try Self.source(host).contains("showPaywall"),
                    "\(host) no longer opens the paywall — this scan is now measuring nothing")
        }
        #expect(try Self.source("Tuck/OverrideFlowView.swift").contains("PaywallView()"))
        #expect(try Self.source("Tuck/BedtimeSetupView.swift").contains("PaywallView()"))
    }
}
