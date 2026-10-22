import Foundation

// The one decision behind the moment a morning is closed: the ring has stood on its new value
// since the screen came up, without ever having been seen to get there. Everything here is a pure
// function over two numbers plus one stored number, so the whole "does this morning get a reaction"
// question is answerable without a rendered view — the same split MascotStage.ringSweepsOnStageChange
// already makes for its half of it.
//
// App-target only, next to MorningRecognition and for the same reason: no extension reads it. What
// it never contains: a random element, a clock, a deadline, or a reason to fire when a morning did
// not happen. The only input is a morning that has already been counted.
enum MorningCelebration {
    enum Kind: Equatable, Sendable { case none, fill, stageSweep }

    // What the ring does about it once Reduce Motion has had its say. `flourishOnly` is the
    // Reduce-Motion form of both moving kinds: the trim lands on its new value without travelling,
    // while the stroke still brightens and thickens — the presentation changes, the statement that
    // this morning counted does not (docs/design/design-system.md).
    enum Presentation: Equatable, Sendable { case none, flourishOnly, fill, sweep }

    private static let acknowledgedKey = "acknowledgedMornings"

    private nonisolated static var defaults: UserDefaults {
        UserDefaults(suiteName: TuckIdentifiers.appGroupSuiteName) ?? .standard
    }

    // nil, not 0, for a store that has never been written. An install that updates into this build
    // with forty mornings behind it has nothing to compare against, and a fill from empty to full
    // would celebrate forty mornings as if they had all happened this one.
    nonisolated static func acknowledgedMornings(in defaults: UserDefaults = Self.defaults) -> Int? {
        defaults.object(forKey: acknowledgedKey) as? Int
    }

    // A ratchet like MilestoneStore's, for the mirror-image reason: there it keeps a reward from
    // being taken away, here it keeps a morning from being celebrated twice. A counter that comes
    // back lower — restored backup, lost App-Group write — must not re-earn mornings it already had.
    nonisolated static func acknowledge(completed: Int, in defaults: UserDefaults = Self.defaults) {
        guard let stored = acknowledgedMornings(in: defaults) else {
            defaults.set(completed, forKey: acknowledgedKey)
            return
        }
        guard completed > stored else { return }
        defaults.set(completed, forKey: acknowledgedKey)
    }

    static func kind(acknowledged: Int?, completed: Int) -> Kind {
        guard let acknowledged, completed > acknowledged else { return .none }
        let sweeps = MascotStage.ringSweepsOnStageChange(
            from: MascotStage.stage(forCompletedMornings: acknowledged),
            to: MascotStage.stage(forCompletedMornings: completed)
        )
        return sweeps ? .stageSweep : .fill
    }

    static func presentation(for kind: Kind, reduceMotion: Bool) -> Presentation {
        switch kind {
        case .none: .none
        case .fill: reduceMotion ? .flourishOnly : .fill
        case .stageSweep: reduceMotion ? .flourishOnly : .sweep
        }
    }

    // Where the ring stands the instant the screen comes up: on the value the user last saw, so the
    // fill has somewhere to travel from. Without it a cold launch would render the new value for a
    // frame and then jump back to animate — the morning's reaction arriving as a flinch.
    static func ringOrigin(acknowledged: Int?, completed: Int) -> Double {
        switch kind(acknowledged: acknowledged, completed: completed) {
        case .none:
            MascotStage.progressTowardNext(completedMornings: completed)
        case .fill, .stageSweep:
            MascotStage.progressTowardNext(completedMornings: acknowledged ?? completed)
        }
    }

    // The mascot answers the morning, not the ring. After the last stage the ring is full and cannot
    // move again — and that morning counted exactly as much as the first one did.
    static func mascotReacts(to kind: Kind) -> Bool { kind != .none }
}
