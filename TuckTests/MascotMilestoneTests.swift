import Testing
import Foundation
import SwiftUI
import UIKit
@testable import Tuck

struct MascotMilestoneTests {
    // The schedule as approved, written out by hand rather than derived from the enum: a table that
    // reads its expectations off the thing it checks would agree with any future edit.
    private static let schedule: [(Int, MascotMilestone.Reward)] = [
        (45, .colorVariant(.dustyBlue)),
        (60, .idleAnimation(.stretch)),
        (90, .badge(.quarterYear)),
        (120, .colorVariant(.warmSand)),
        (180, .idleAnimation(.yawn)),
        (270, .badge(.threeQuarterYear)),
        (365, .colorVariant(.softLavender))
    ]

    @Test func everyMilestoneSitsOnItsApprovedMorningWithItsApprovedReward() {
        #expect(MascotMilestone.allCases.count == Self.schedule.count)
        for (milestone, expected) in zip(MascotMilestone.allCases, Self.schedule) {
            #expect(milestone.completedMornings == expected.0)
            #expect(milestone.reward == expected.1)
        }
    }

    @Test func eachMilestoneUnlocksExactlyOneReward() {
        #expect(Set(MascotMilestone.allCases.map(\.reward)).count == MascotMilestone.allCases.count)
    }

    // The boundary is the threshold itself: 44 mornings is not 45.
    @Test func aMilestoneIsReachedOnItsOwnMorningAndNotTheDayBefore() {
        for milestone in MascotMilestone.allCases {
            let mornings = milestone.completedMornings
            #expect(MascotMilestone.reached(completedMornings: mornings).contains(milestone))
            #expect(!MascotMilestone.reached(completedMornings: mornings - 1).contains(milestone))
        }
    }

    // The gap the schedule fills: MascotStage's last stage lands at 30, the first milestone at 45.
    @Test func nothingIsReachedBeforeTheFirstMilestone() {
        for mornings in [0, 1, 7, 30, 44] {
            #expect(MascotMilestone.reached(completedMornings: mornings).isEmpty)
        }
    }

    @Test func aNegativeCountReachesNothingRatherThanCrashing() {
        #expect(MascotMilestone.reached(completedMornings: -10).isEmpty)
    }

    @Test func theSetOfReachedMilestonesOnlyEverGrows() {
        var previous = 0
        for mornings in 0...400 {
            let reached = MascotMilestone.reached(completedMornings: mornings).count
            #expect(reached >= previous)
            previous = reached
        }
        #expect(previous == MascotMilestone.allCases.count)
    }

    @Test func theOriginalColourIsUnlockedAtEveryCountIncludingZero() {
        for mornings in [-1, 0, 44, 45, 365, 5_000] {
            #expect(MascotMilestone.colorVariants(completedMornings: mornings).first == .charcoalGreen)
        }
    }

    @Test func colourVariantsAppearOnlyOnceTheirOwnMorningIsReached() {
        #expect(MascotMilestone.colorVariants(completedMornings: 44) == [.charcoalGreen])
        #expect(MascotMilestone.colorVariants(completedMornings: 45) == [.charcoalGreen, .dustyBlue])
        #expect(MascotMilestone.colorVariants(completedMornings: 119) == [.charcoalGreen, .dustyBlue])
        #expect(MascotMilestone.colorVariants(completedMornings: 120) == [.charcoalGreen, .dustyBlue, .warmSand])
        #expect(MascotMilestone.colorVariants(completedMornings: 364) == [.charcoalGreen, .dustyBlue, .warmSand])
        #expect(MascotMilestone.colorVariants(completedMornings: 365)
            == [.charcoalGreen, .dustyBlue, .warmSand, .softLavender])
    }

    @Test func idleAnimationsAppearOnlyOnceTheirOwnMorningIsReached() {
        #expect(MascotMilestone.idleAnimations(completedMornings: 59).isEmpty)
        #expect(MascotMilestone.idleAnimations(completedMornings: 60) == [.stretch])
        #expect(MascotMilestone.idleAnimations(completedMornings: 179) == [.stretch])
        #expect(MascotMilestone.idleAnimations(completedMornings: 180) == [.stretch, .yawn])
        #expect(MascotMilestone.idleAnimations(completedMornings: 10_000) == [.stretch, .yawn])
    }

    @Test func badgesAppearOnlyOnceTheirOwnMorningIsReached() {
        #expect(MascotMilestone.badges(completedMornings: 89).isEmpty)
        #expect(MascotMilestone.badges(completedMornings: 90) == [.quarterYear])
        #expect(MascotMilestone.badges(completedMornings: 269) == [.quarterYear])
        #expect(MascotMilestone.badges(completedMornings: 270) == [.quarterYear, .threeQuarterYear])
    }

    // The speech-bubble rule, applied to the seven lines that announce a milestone: they take the
    // same slot as the encouragement pool, which is tested for exactly this, and a celebration is
    // not a different kind of line.
    @Test func everyCelebrationLineKeepsTheBubbleRule() {
        for milestone in MascotMilestone.allCases {
            let line = milestone.celebration
            let words = line.split(whereSeparator: \.isWhitespace)
            #expect(words.count <= 5, "\(line) has \(words.count) words")
            #expect(!line.contains("!"))
            #expect(!line.contains { $0.isNumber })
        }
    }

    // A colour, an idle beat and a badge are three different events, so one line may not stand in
    // for another — the announcement is the only place the reward is named.
    @Test func everyMilestoneAnnouncesItselfWithItsOwnLine() {
        #expect(Set(MascotMilestone.allCases.map(\.celebration)).count == MascotMilestone.allCases.count)
    }

    @Test func everyColourAndEveryBadgeCarriesANameOfItsOwn() {
        #expect(Set(MascotColorVariant.allCases.map(\.displayName)).count == MascotColorVariant.allCases.count)
        #expect(Set(MascotBadge.allCases.map(\.displayName)).count == MascotBadge.allCases.count)
        for name in MascotColorVariant.allCases.map(\.displayName) + MascotBadge.allCases.map(\.displayName) {
            #expect(!name.isEmpty)
            #expect(!name.contains { $0.isNumber })
        }
    }

    // The stage a new user looks at for their first week had no sprout at all — the growth
    // mechanic was invisible until morning 7. Written out by hand like the schedule above, for the
    // same reason: a table read off the enum would agree with any future edit. The thresholds
    // 0/7/30 themselves are untouched by the seed and stay pinned where they are.
    @Test func everyStageShowsASproutAndTheFirstOneShowsASeed() {
        #expect(MascotStage.start.sproutStage == .seed)
        #expect(MascotStage.warmGeworden.sproutStage == .oneLeaf)
        #expect(MascotStage.eingespielt.sproutStage == .twoLeaves)
    }

    // The other direction: no two stages may look the same, or the sprout has stopped being the
    // thing that shows growth.
    @Test func noTwoStagesShareASproutForm() {
        #expect(Set(MascotStage.allCases.map(\.sproutStage)).count == MascotStage.allCases.count)
    }

    // Every reward of the table reaches exactly one of the three lists, and no list invents one.
    @Test func theThreeUnlockListsTogetherCoverTheWholeSchedule() {
        let mornings = 10_000
        #expect(MascotMilestone.colorVariants(completedMornings: mornings).count == 4)
        #expect(MascotMilestone.idleAnimations(completedMornings: mornings).count == MascotIdleAnimation.allCases.count)
        #expect(MascotMilestone.badges(completedMornings: mornings) == MascotBadge.allCases)
    }
}

// The variants are ink on the mascot, not text, so the bar is the 3:1 for graphical objects, and
// the ground that matters is the sage body they are drawn on — the same computation and the same
// formula as ShieldContrastTests, which is where the contrast table's numbers come from.
//
// Explicitly the light half: every token below resolves per appearance, and these
// are the numbers the design system documents. The dark half is DarkMascotColorVariantContrastTests.
struct MascotColorVariantContrastTests {
    // REPOINTED, and the repoint matters more than it looks. It used to resolve
    // `.tuckSage`, which was the mascot's body only for as long as the mascot had no token of its
    // own. In light both tokens resolve to the same LightPalette.sage, so nothing would have gone
    // red — and that is exactly why it is the "lautloser Ausfall" class: a test measuring a colour
    // the animal only still wears by coincidence. The dark twin was repointed on the same grounds
    // earlier the same day (DarkMascotColorVariantContrastTests) and the light half was left
    // standing; this catches it up. Always resolve through the semantic token, never through the
    // one that happens to be identical today.
    @Test func everyVariantClearsTheNonTextThresholdOnTheMascotsOwnBody() {
        let body = Self.light(.tuckMascotBody)
        for variant in MascotColorVariant.allCases {
            let ratio = Self.contrastRatio(Self.light(variant.color), on: body)
            #expect(ratio >= 3.0, "\(variant.rawValue) on the light mascot body: \(ratio)")
        }
    }

    // The four values as exact equalities rather than as "above 3", mirroring the dark pin that has
    // had them as well. A threshold says the palette has not fallen through the floor; an
    // equality says which colour the animal actually wears. Equalities are the house
    // rule here, and the difference is real: any of the four could drift by a tenth without the `>= 3.0` above moving.
    //
    // Independently recomputed before they were written down (WCAG 2.1, sRGB, both colours opaque —
    // no composition, so the Float/Hex question in the contrast table does not touch these four numbers at all).
    @Test func theFourInksKeepTheirMeasuredRatioOnTheLightBody() {
        let body = Self.light(.tuckMascotBody)
        let expected: [(MascotColorVariant, Double)] = [
            (.charcoalGreen, 3.3963),
            (.dustyBlue, 3.3064),
            (.warmSand, 3.1002),
            (.softLavender, 3.5798)
        ]
        #expect(expected.count == MascotColorVariant.allCases.count)
        for (variant, ratio) in expected {
            let measured = Self.contrastRatio(Self.light(variant.color), on: body)
            #expect(Self.roundedToFour(measured) == ratio, "\(variant.rawValue): \(measured)")
        }
    }

    private static func roundedToFour(_ ratio: Double) -> Double { (ratio * 10_000).rounded() / 10_000 }

    @Test func noVariantIsFartherFromTheOriginalThanTheOriginalIsFromTheBody() {
        let original = Self.relativeLuminance(Self.light(.tuckCharcoalGreen))
        for variant in MascotColorVariant.allCases {
            let luminance = Self.relativeLuminance(Self.light(variant.color))
            #expect(abs(luminance - original) < 0.04, "\(variant.rawValue): \(luminance)")
        }
    }

    private static func light(_ color: Color) -> UIColor {
        UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
    }

    // The principle "ruhig vor korrekt-nach-Norm". The band, measured rather than assumed: the four base
    // tokens run from 0.06 (cream) to 0.21 HSB (dusty rose, the most saturated colour the app has),
    // the three variants from 0.17 to 0.23. Warm Sand is the one value marginally above the old
    // maximum, which is why this is written as a band and not as "at most dusty rose" — 0.25 is
    // still far below anything the eye reads as vivid, and it fails the moment a variant is.
    @Test func noVariantLeavesThePalettesLowSaturationBand() {
        for variant in MascotColorVariant.allCases {
            #expect(Self.saturation(Self.light(variant.color)) <= 0.25, "\(variant.rawValue)")
        }
        #expect(Self.saturation(Self.light(.tuckDustyRose)) <= 0.25)
    }

    private static func saturation(_ color: UIColor) -> CGFloat {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return saturation
    }

    private static func contrastRatio(_ foreground: UIColor, on background: UIColor) -> Double {
        let lighter = max(relativeLuminance(foreground), relativeLuminance(background))
        let darker = min(relativeLuminance(foreground), relativeLuminance(background))
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func relativeLuminance(_ color: UIColor) -> Double {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let channels = [red, green, blue].map { channel -> Double in
            let value = Double(channel)
            return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
    }
}
