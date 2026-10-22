import Foundation
import Testing
@testable import Tuck

// What is pinned here is the bookkeeping (version, outcome, read-back) that every future
// migration inherits and cannot re-decide, plus — since schema 2 — the one step that exists so far:
// the bedtime-registration backfill below.
struct SchemaMigrationTests {
    // Throwaway suite per test, the same shape as MilestoneStoreTests: nothing here may touch the
    // App-Group container the app actually uses.
    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suite = "SchemaMigrationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        body(defaults)
    }

    @Test func aFreshInstallEndsUpOnTheCurrentVersion() {
        withDefaults { defaults in
            #expect(SchemaVersion.stored(in: defaults) == nil)
            #expect(Migrations.runIfNeeded(in: defaults) == .migrated(from: nil, to: SchemaVersion.current))
            #expect(SchemaVersion.stored(in: defaults) == SchemaVersion.current)
        }
    }

    // The case this whole file exists for: no key is a container to bring up to date, not a fault.
    // `integer(forKey:)` would have answered 0 here and made it indistinguishable from a stored 0.
    @Test func anAbsentVersionKeyIsSomethingToMigrateRatherThanAnError() {
        withDefaults { defaults in
            let outcome = Migrations.runIfNeeded(in: defaults)
            #expect(outcome == .migrated(from: nil, to: SchemaVersion.current))
            if case .failed = outcome { Issue.record("an absent key was treated as a failure") }
            if case .ahead = outcome { Issue.record("an absent key was treated as a later version") }
        }
    }

    @Test func aSecondLaunchOnTheSameVersionRunsNothing() {
        withDefaults { defaults in
            Migrations.runIfNeeded(in: defaults)
            #expect(Migrations.runIfNeeded(in: defaults) == .alreadyCurrent(SchemaVersion.current))
        }
    }

    // A container written by a later build, reached by a downgrade or a restored backup. This build
    // does not know what that version's shape is, so it says so instead of stamping its own number
    // over it and claiming a conversion nobody ran.
    @Test func aVersionFromTheFutureIsReportedRatherThanOverwritten() {
        withDefaults { defaults in
            let future = SchemaVersion.current + 1
            defaults.set(future, forKey: SchemaVersion.key)
            #expect(Migrations.runIfNeeded(in: defaults) == .ahead(stored: future, current: SchemaVersion.current))
            #expect(SchemaVersion.stored(in: defaults) == future)
        }
    }

    // Guards the one way to break this silently: raising `current` without adding the step that
    // earns it. The number is the persisted format, and every launch of an older container is
    // measured against it.
    @Test func theCurrentVersionIsTheOneShippedShape() {
        #expect(SchemaVersion.current == 2)
        #expect(SchemaVersion.key == "tuckSchemaVersion")
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    private func date(hour: Int, minute: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 9,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }

    // The state an update install is in, and it is not reachable through the store's own API: a
    // device that registered its bedtime window under a build from before bedtimeBlockRegisteredAt
    // existed has the flag set and no stamp. `store` writes the flag false, `recordBlockRegistration`
    // always writes both — so the key is set directly here, which is exactly what that older build
    // did.
    private func stageUpdateInstall(in defaults: UserDefaults) {
        let bedtime = date(hour: 22, minute: 30, day: 1)
        let window = MorningBlockWindow.centeredOn(bedtime, halfDuration: .seconds(30 * 60), calendar: calendar)
        BedtimeStore.store(bedtime: bedtime, window: window, calendar: calendar, in: defaults)
        defaults.set(true, forKey: "bedtimeBlockRegistrationSucceeded")
        defaults.set(1, forKey: SchemaVersion.key)
    }

    // The control group is the first two expectations: on the staged pre-fix container the evening
    // audit is structurally blind — countableOccurrence answers nil for an occurrence days later,
    // so auditBedtimeCallback can never count a miss and reports the same 0 a working evening does.
    @Test func theBackfillMakesTheEveningAuditReachableOnAnUpdateInstall() {
        withDefaults { defaults in
            stageUpdateInstall(in: defaults)
            // Relative to the wall clock, not to a fixed calendar date: the backfilled stamp is
            // `.now`, so only an occurrence after this run can be countable.
            let laterOccurrence = Date.now.addingTimeInterval(24 * 3600)

            #expect(BedtimeStore.blockRegistrationSucceeded(in: defaults))
            #expect(BedtimeStore.blockRegisteredAt(in: defaults) == nil)
            #expect(BedtimeStore.countableOccurrence(now: laterOccurrence, calendar: calendar, in: defaults) == nil)

            #expect(Migrations.runIfNeeded(in: defaults) == .migrated(from: 1, to: SchemaVersion.current))

            let stamp = BedtimeStore.blockRegisteredAt(in: defaults)
            #expect(stamp != nil)
            #expect(BedtimeStore.countableOccurrence(now: laterOccurrence, calendar: calendar, in: defaults) != nil)
        }
    }

    // .now rather than .distantPast: the backfill behaves like a fresh arm, so the occurrence that
    // started before the stamp stays uncountable. A backdated stamp would make the audit report
    // missing callbacks for nights nothing was monitoring.
    @Test func theBackfilledStampDoesNotReachBackOverNightsNobodyMonitored() {
        withDefaults { defaults in
            stageUpdateInstall(in: defaults)
            Migrations.runIfNeeded(in: defaults)

            guard let stamp = BedtimeStore.blockRegisteredAt(in: defaults) else {
                Issue.record("the backfill wrote no stamp")
                return
            }
            #expect(abs(stamp.timeIntervalSinceNow) < 5)
            #expect(BedtimeStore.countableOccurrence(now: stamp, calendar: calendar, in: defaults) == nil)
        }
    }

    @Test func aSecondRunLeavesAnExistingStampAlone() {
        withDefaults { defaults in
            stageUpdateInstall(in: defaults)
            let existing = date(hour: 20, minute: 0, day: 2)
            BedtimeStore.recordBlockRegistration(succeeded: true, at: existing, in: defaults)

            #expect(Migrations.runIfNeeded(in: defaults) == .migrated(from: 1, to: SchemaVersion.current))
            #expect(BedtimeStore.blockRegisteredAt(in: defaults) == existing)

            // Idempotent on its own terms, not only because the version key stops it: the step is run
            // again from an unversioned container and still leaves the stamp where it was.
            defaults.removeObject(forKey: SchemaVersion.key)
            Migrations.runIfNeeded(in: defaults)
            #expect(BedtimeStore.blockRegisteredAt(in: defaults) == existing)
        }
    }

    // A window that never registered has no moment its occurrences could be counted from, and
    // inventing one would make the audit vouch for an evening that was never armed.
    @Test func aBedtimeThatNeverRegisteredGetsNoStamp() {
        withDefaults { defaults in
            let bedtime = date(hour: 22, minute: 30, day: 1)
            let window = MorningBlockWindow.centeredOn(bedtime, halfDuration: .seconds(30 * 60), calendar: calendar)
            BedtimeStore.store(bedtime: bedtime, window: window, calendar: calendar, in: defaults)
            defaults.set(1, forKey: SchemaVersion.key)

            #expect(Migrations.runIfNeeded(in: defaults) == .migrated(from: 1, to: SchemaVersion.current))
            #expect(BedtimeStore.blockRegisteredAt(in: defaults) == nil)
            #expect(BedtimeStore.countableOccurrence(now: date(hour: 23, minute: 0, day: 4), calendar: calendar, in: defaults) == nil)
        }
    }

    // The wiring, the way OnboardingStepPersistenceTests reads its own: every assertion above would
    // pass on an entry point nobody calls.
    @Test func theAppRunsTheMigrationAtStartup() throws {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Tuck/TuckApp.swift")
        let lines = try String(contentsOf: source, encoding: .utf8).components(separatedBy: "\n")

        #expect(lines.contains { $0.contains("Migrations.runIfNeeded()") })
    }

    // The other half of that wiring. `runIfNeeded` does the read-back itself and returns `.failed`
    // when the write did not survive it — but a call site that discards the answer turns a detected
    // failure back into the silence the check exists to break. Pinned in the same DEBUG-fatalError
    // shape as the App-Group guard two lines above it in that init.
    @Test func theStartupCallSiteNoticesAMigrationThatDidNotPersist() throws {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Tuck/TuckApp.swift")
        let lines = try String(contentsOf: source, encoding: .utf8).components(separatedBy: "\n")

        let callSite = try #require(lines.firstIndex { $0.contains("Migrations.runIfNeeded()") })
        let call = lines[callSite].trimmingCharacters(in: .whitespaces)
        #expect(call.hasPrefix("let ") && call.contains("= Migrations.runIfNeeded()"),
                "the outcome is discarded at the call site: \(call)")

        let guardStart = try #require(lines[callSite...].dropFirst().firstIndex { $0.contains("#if DEBUG") })
        let guardEnd = try #require(lines[guardStart...].dropFirst().firstIndex { $0.contains("#endif") })
        #expect(lines[guardStart..<guardEnd].contains { $0.contains("case .failed") })
    }
}
