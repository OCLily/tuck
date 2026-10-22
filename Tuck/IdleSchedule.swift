import Foundation

// When the next unprompted idle beat is allowed to fall. Pulled out of the running loop for the one
// reason that matters: a reaction the simulator cannot prove is a reaction nobody has measured,
// and an arithmetic over two Date values is the one thing it can prove. Same cut as
// MorningCelebration.kind(acknowledged:completed:) — a pure function over two numbers, answerable
// without a rendered view.
//
// The draw stays at the call site: `.random(in: Motion.idleIntervalMin...Motion.idleIntervalMax)`
// belongs to the loop, not to this function, so this one is deterministic and therefore testable.
enum IdleSchedule {
    /// `periodStart` is the beginning of the wait currently running, NOT the moment of the check.
    ///
    /// The distinction is the whole change. Against the check time the floor is arithmetically dead:
    /// with `draw >= Motion.idleIntervalMin` and a reaction that always lies in the past,
    /// `now + draw >= lastReaction + Motion.idleQuietAfterReaction` holds for every input, so a
    /// `from: .now` is a complete no-op that passes every test of this function. The floor can only
    /// bind when the deadline is recomputed mid-sleep against a reaction that arrived AFTER
    /// `periodStart`.
    static func nextDeadline(from periodStart: Date, draw: Double, lastReaction: Date?) -> Date {
        let drawn = periodStart.addingTimeInterval(draw)
        guard let lastReaction else { return drawn }
        return max(drawn, lastReaction.addingTimeInterval(Motion.idleQuietAfterReaction))
    }
}
