import Foundation

// The record of which shape a container is in, and the steps that bring an older one forward.
// Without the version an install that predates versioning is indistinguishable from one already
// migrated — both look identical: a container with no version.
//
// Reads the App Group through TuckIdentifiers.appGroupDefaults, with the same injectable-defaults
// shape as MilestoneStore and MorningProgressStore next to it.
enum SchemaVersion {
    // Bump together with a new case in Migrations.applySteps, never on its own: a raised number
    // with no step marks containers as converted that nobody converted.
    static let current = 2

    static let key = "tuckSchemaVersion"

    // `object(forKey:)` rather than `integer(forKey:)`: the latter answers 0 for an absent key and
    // for a key holding a 0, and those are the two states the whole mechanism has to tell apart.
    nonisolated static func stored(in defaults: UserDefaults = TuckIdentifiers.appGroupDefaults) -> Int? {
        defaults.object(forKey: key) as? Int
    }
}

enum SchemaMigrationOutcome: Equatable {
    // No version stored: either a fresh install or one from before versioning shipped. Not an error — the
    // steps run from `from` and the container ends up current either way.
    case migrated(from: Int?, to: Int)
    case alreadyCurrent(Int)
    // A later build wrote this container and this one cannot know what it did. Left untouched
    // rather than written back down, the way MilestoneStore refuses to lower its ratchet.
    case ahead(stored: Int, current: Int)
    // The write did not survive the read back. Nothing here can repair that — an unprovisioned App
    // Group is the usual cause and it is a provisioning fault — but the caller is told rather than
    // handed a success the container does not support.
    case failed(expected: Int, readBack: Int?)
    // A step's own write did not survive its read back. The version is deliberately left where it
    // was: a container stamped current is one nobody runs the step on again, and a step that never
    // landed would then be permanently skipped rather than retried on the next launch.
    case stepFailed(step: Int)
}

enum Migrations {
    @discardableResult
    nonisolated static func runIfNeeded(in defaults: UserDefaults = TuckIdentifiers.appGroupDefaults) -> SchemaMigrationOutcome {
        let stored = SchemaVersion.stored(in: defaults)
        let current = SchemaVersion.current

        if let stored {
            guard stored != current else { return .alreadyCurrent(current) }
            guard stored < current else { return .ahead(stored: stored, current: current) }
        }

        if let failedStep = applySteps(from: stored, to: current, in: defaults) {
            return .stepFailed(step: failedStep)
        }
        defaults.set(current, forKey: SchemaVersion.key)

        // The project's own failure class: no state reports success it has not read back.
        guard SchemaVersion.stored(in: defaults) == current else {
            return .failed(expected: current, readBack: SchemaVersion.stored(in: defaults))
        }
        return .migrated(from: stored, to: current)
    }

    // One branch per version crossed, in order, each converting the container from n to n+1 and each
    // safe to run on a container that never held the older shape. Returns the step that failed its
    // read back, or nil when every step landed. A missing version counts as 0: an install from
    // before versioning has crossed nothing.
    private nonisolated static func applySteps(from: Int?, to: Int, in defaults: UserDefaults) -> Int? {
        if (from ?? 0) < 2 {
            guard backfillBedtimeRegistrationStamp(in: defaults) else { return 2 }
        }
        return nil
    }

    // 1 → 2. bedtimeBlockRegisteredAt shipped after the flag it belongs to. Its writers are the
    // reconciler's arm/disarm branches and the scheduler's own setBedtime (BedtimeScheduler.swift) —
    // none of which an update install with the flag already true runs again, because
    // bedtimeWindowAction answers .leave there and nothing prompts a re-save of the bedtime. Without
    // this step the stamp stays absent on every such device, countableOccurrence stays nil, and the
    // evening audit reports zero missing callbacks forever: the exact reading of an evening that works.
    //
    // .now, not .distantPast: the same effect as a fresh arm, counting from here on. A backdated
    // stamp would pass judgement on nights nothing was measuring.
    private nonisolated static func backfillBedtimeRegistrationStamp(in defaults: UserDefaults) -> Bool {
        guard BedtimeStore.blockRegistrationSucceeded(in: defaults),
              BedtimeStore.blockRegisteredAt(in: defaults) == nil
        else { return true }

        BedtimeStore.recordBlockRegistration(succeeded: true, at: .now, in: defaults)
        return BedtimeStore.blockRegisteredAt(in: defaults) != nil
    }
}
