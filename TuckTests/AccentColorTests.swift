import SwiftUI
import Testing
import UIKit
@testable import Tuck

// A colorset entry without a color value is not a build error: it resolves to nothing and every
// system-tinted control (both wheel pickers, ProgressView, FamilyActivityPicker) falls back to iOS
// system blue — a colour the palette does not contain. Only a resolved lookup catches that.
//
// Resolved against an explicit trait collection: the palette token is a dynamic colour
// now, so comparing two unresolved UIColors would only have proved they agree on whatever
// appearance the test host happens to run in.
struct AccentColorTests {
    @Test func theGlobalAccentColorFollowsTheTextTokenInBothAppearances() {
        guard let accent = UIColor(named: "AccentColor") else {
            Issue.record("AccentColor did not resolve from the asset catalog")
            return
        }

        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            #expect(
                Self.components(of: accent.resolvedColor(with: traits))
                    == Self.components(of: UIColor(Color.tuckCharcoalGreen).resolvedColor(with: traits))
            )
        }
    }

    private static func components(of color: UIColor) -> [Int] {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return [red, green, blue, alpha].map { Int(($0 * 255).rounded()) }
    }
}
