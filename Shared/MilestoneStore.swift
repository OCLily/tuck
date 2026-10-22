import Foundation

// Same App-Group suite and the same injectable-defaults shape as MorningProgressStore and
// MorningBlockDurationStore. It keeps no second copy of the streak: the mornings stay
// MorningProgressStore's, this remembers only the highest count it has ever seen.
enum MilestoneStore {
    private static let reachedMorningsKey = "milestoneReachedMornings"
    private static let celebratedMorningsKey = "milestoneCelebratedMornings"
    private static let colorVariantKey = "mascotColorVariant"

    private nonisolated static var defaults: UserDefaults {
        UserDefaults(suiteName: TuckIdentifiers.appGroupSuiteName) ?? .standard
    }
    // Never a step backwards. Everything below is MascotMilestone's pure derivation over one

    // number, and this is that number: a ratchet rather than the live count, so a milestone that
    // was reached stays reached even if the counter it derives from ever comes back partially
    // lower — a lost App-Group write, a bug in the counting path, a foreign writer on the shared
    // container. A full App-Group restore is NOT covered: this key travels back with the counter it
    // guards. Taking a colour away that someone earned would be exactly the punishment this app
    // does not do.
    @discardableResult
    nonisolated static func reachedMornings(in defaults: UserDefaults = Self.defaults) -> Int {
        let counted = MorningProgressStore.completedMornings(in: defaults)
        let recorded = defaults.integer(forKey: reachedMorningsKey)
        guard counted > recorded else { return recorded }
        defaults.set(counted, forKey: reachedMorningsKey)
        return counted
    }

    nonisolated static func reachedMilestones(in defaults: UserDefaults = Self.defaults) -> [MascotMilestone] {
        MascotMilestone.reached(completedMornings: reachedMornings(in: defaults))
    }

    nonisolated static func unlockedColorVariants(in defaults: UserDefaults = Self.defaults) -> [MascotColorVariant] {
        MascotMilestone.colorVariants(completedMornings: reachedMornings(in: defaults))
    }

    nonisolated static func unlockedIdleAnimations(in defaults: UserDefaults = Self.defaults) -> Set<MascotIdleAnimation> {
        MascotMilestone.idleAnimations(completedMornings: reachedMornings(in: defaults))
    }

    nonisolated static func unlockedBadges(in defaults: UserDefaults = Self.defaults) -> [MascotBadge] {
        MascotMilestone.badges(completedMornings: reachedMornings(in: defaults))
    }

    // The one piece of state that is not derivable, kept apart from the derivation above: whether a
    // milestone has already been celebrated. It exists so the next phase's message can fire exactly
    // once; it never takes a reward away, an uncelebrated milestone is still reached.
    nonisolated static func uncelebratedMilestones(in defaults: UserDefaults = Self.defaults) -> [MascotMilestone] {
        let celebrated = celebratedMornings(in: defaults)
        return reachedMilestones(in: defaults).filter { !celebrated.contains($0.completedMornings) }
    }

    nonisolated static func recordCelebration(of milestone: MascotMilestone, in defaults: UserDefaults = Self.defaults) {
        var celebrated = celebratedMornings(in: defaults)
        celebrated.insert(milestone.completedMornings)
        defaults.set(celebrated.sorted(), forKey: celebratedMorningsKey)
    }

    private nonisolated static func celebratedMornings(in defaults: UserDefaults) -> Set<Int> {
        Set(defaults.array(forKey: celebratedMorningsKey) as? [Int] ?? [])
    }

    // Falls back to the original for an absent key, for a name this build does not know, and for a
    // variant that is not unlocked. The write below already refuses a locked variant, so the third
    // case only comes from outside this build — a value written by a later version, or by another
    // process on the shared container.
    nonisolated static func selectedColorVariant(in defaults: UserDefaults = Self.defaults) -> MascotColorVariant {
        guard let stored = defaults.string(forKey: colorVariantKey),
              let variant = MascotColorVariant(rawValue: stored),
              unlockedColorVariants(in: defaults).contains(variant)
        else { return .charcoalGreen }
        return variant
    }

    nonisolated static func selectColorVariant(_ variant: MascotColorVariant, in defaults: UserDefaults = Self.defaults) {
        guard unlockedColorVariants(in: defaults).contains(variant) else { return }
        defaults.set(variant.rawValue, forKey: colorVariantKey)
    }
}
