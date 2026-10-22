import Foundation

// The mascot's ink colour. The original is not a reward and cannot be locked: it is unlocked at
// zero mornings and stays the default, so a fresh install and a 365-morning install both always
// have a colour that is theirs to keep.
enum MascotColorVariant: String, CaseIterable, Sendable {
    case charcoalGreen
    case dustyBlue
    case warmSand
    case softLavender

    // The rawValue stays the stored identity; only this reaches a screen — same split as
    // MascotStage.displayName. This file is compiled into the app target alone, so the literals
    // below do pass a catalog, unlike the SubscriptionAccess.displayName that once did not.
    var displayName: String {
        switch self {
        case .charcoalGreen: String(localized: "Original")
        case .dustyBlue: String(localized: "Staubblau")
        case .warmSand: String(localized: "Warmsand")
        case .softLavender: String(localized: "Soft-Lavendel")
        }
    }
}

// Only the beats that have to be earned. The five original idle beats have no unlock and are not
// listed here — they are MascotView's own repertoire and always available.
enum MascotIdleAnimation: String, CaseIterable, Sendable {
    case stretch
    case yawn
}

// Purely celebratory markers: they unlock nothing, gate nothing and are read by nothing but the
// screen that shows them. Named for the stretch of mornings they mark rather than for its number —
// the number is written down once, as the milestone's raw value.
enum MascotBadge: String, CaseIterable, Sendable {
    case quarterYear
    case threeQuarterYear

    var displayName: String {
        switch self {
        case .quarterYear: String(localized: "Vierteljahr")
        case .threeQuarterYear: String(localized: "Dreivierteljahr")
        }
    }
}

// The post-graduation schedule. MascotStage stops at 30 mornings and stayed flat forever after;
// this carries on from 45, one reward per milestone. The raw value IS the threshold, so each number
// exists exactly once — the same discipline as MascotStage.completedMornings.
enum MascotMilestone: Int, CaseIterable, Sendable, Identifiable {
    case dustyBlue = 45
    case stretch = 60
    case quarterYearBadge = 90
    case warmSand = 120
    case yawn = 180
    case threeQuarterYearBadge = 270
    case softLavender = 365

    var id: Int { rawValue }

    var completedMornings: Int { rawValue }

    var reward: Reward {
        switch self {
        case .dustyBlue: .colorVariant(.dustyBlue)
        case .stretch: .idleAnimation(.stretch)
        case .quarterYearBadge: .badge(.quarterYear)
        case .warmSand: .colorVariant(.warmSand)
        case .yawn: .idleAnimation(.yawn)
        case .threeQuarterYearBadge: .badge(.threeQuarterYear)
        case .softLavender: .colorVariant(.softLavender)
        }
    }

    // Said once, in the mascot's own bubble, under the same rule as MascotStage.encouragements:
    // second person or "wir", present tense, max five words, no exclamation mark, no imperative,
    // never a number. Each line names its own reward, because the three kinds are not the same
    // event — and the two colours the user still has to pick say they are available, not that the
    // animal already wears them: selecting one stays the user's own decision.
    var celebration: String {
        switch self {
        case .dustyBlue: String(localized: "Staubblau steht dir jetzt offen.")
        case .stretch: String(localized: "Wir strecken uns jetzt manchmal.")
        case .quarterYearBadge: String(localized: "Ein Blatt für unseren Weg.")
        case .warmSand: String(localized: "Warmsand gehört jetzt auch dir.")
        case .yawn: String(localized: "Wir gähnen jetzt auch.")
        case .threeQuarterYearBadge: String(localized: "Noch ein Blatt für uns.")
        case .softLavender: String(localized: "Du hast jetzt Soft-Lavendel.")
        }
    }

    enum Reward: Hashable, Sendable {
        case colorVariant(MascotColorVariant)
        case idleAnimation(MascotIdleAnimation)
        case badge(MascotBadge)
    }

    static func reached(completedMornings mornings: Int) -> [MascotMilestone] {
        allCases.filter { mornings >= $0.completedMornings }
    }

    static func colorVariants(completedMornings mornings: Int) -> [MascotColorVariant] {
        [.charcoalGreen] + reached(completedMornings: mornings).compactMap {
            if case let .colorVariant(variant) = $0.reward { variant } else { nil }
        }
    }

    static func idleAnimations(completedMornings mornings: Int) -> Set<MascotIdleAnimation> {
        Set(reached(completedMornings: mornings).compactMap {
            if case let .idleAnimation(animation) = $0.reward { animation } else { nil }
        })
    }

    static func badges(completedMornings mornings: Int) -> [MascotBadge] {
        reached(completedMornings: mornings).compactMap {
            if case let .badge(badge) = $0.reward { badge } else { nil }
        }
    }
}
