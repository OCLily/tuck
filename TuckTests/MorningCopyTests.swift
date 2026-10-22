import Testing
import Foundation
@testable import Tuck

struct MorningCopyTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    private func date(hour: Int, minute: Int, day: Int = 1) -> Date {
        calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026, month: 9, day: day, hour: hour, minute: minute
        ))!
    }

    private var alarm: WakeAlarmStore.ScheduledAlarm {
        WakeAlarmStore.ScheduledAlarm(
            id: UUID(),
            fireDate: date(hour: 7, minute: 0),
            blockWindowStart: DateComponents(hour: 7, minute: 0, second: 0),
            blockWindowEnd: DateComponents(hour: 7, minute: 30, second: 0)
        )
    }

    @Test func theMorningIndexIsSharedInsideOneWindowAndOneHigherTheNextDay() {
        let early = MorningCopy.morningIndex(for: date(hour: 7, minute: 1), alarm: alarm, calendar: calendar)
        let late = MorningCopy.morningIndex(for: date(hour: 7, minute: 28), alarm: alarm, calendar: calendar)
        let nextDay = MorningCopy.morningIndex(for: date(hour: 7, minute: 10, day: 2), alarm: alarm, calendar: calendar)

        #expect(early == late)
        #expect(nextDay == early + 1)
    }

    // Regression guard against a hashValue-based pick: Swift seeds String hashing per process
    // launch, so the line would silently change on every app restart.
    @Test func theSameIndexAlwaysYieldsTheSameLine() {
        for index in 0..<40 {
            let first = MorningCopy.subline(morningIndex: index, completedMornings: 4, isPastBlockWindowToday: false)
            let second = MorningCopy.subline(morningIndex: index, completedMornings: 4, isPastBlockWindowToday: false)
            #expect(first == second)
            #expect(MorningCopy.sublines.contains(first))
        }
    }

    @Test func negativeIndicesStayInsideThePool() {
        #expect(MorningCopy.sublines.contains(MorningCopy.subline(morningIndex: -1, completedMornings: 4, isPastBlockWindowToday: false)))
    }

    @Test func milestonesReplaceThePoolLineExactlyOnce() {
        #expect(MorningCopy.subline(morningIndex: 0, completedMornings: 1, isPastBlockWindowToday: false) == "Erster Morgen.")
        #expect(MorningCopy.subline(morningIndex: 0, completedMornings: 7, isPastBlockWindowToday: false) == "Siebter Morgen.")
        #expect(MorningCopy.subline(morningIndex: 0, completedMornings: 30, isPastBlockWindowToday: false) == "Dreißigster Morgen.")
        #expect(MorningCopy.sublines.contains(MorningCopy.subline(morningIndex: 0, completedMornings: 8, isPastBlockWindowToday: false)))
    }

    @Test func noPoolLineShoutsOrRuns() {
        for line in MorningCopy.sublines + MorningCopy.wiedersehen + MascotStage.allCases.flatMap(\.encouragements) {
            #expect(!line.contains("!"))
            #expect(line.count <= 60)
        }
    }

    // Three of the four tone choices used to roll dice. A deterministic pick is testable; a
    // random one is not, and that is the whole argument — the answer always came either way.
    @Test func theSameMorningAndTheSameTapAlwaysYieldTheSameLine() {
        let pool = MascotStage.eingespielt.encouragements
        for index in 0..<40 {
            for tap in 0..<3 {
                let first = MorningCopy.line(from: pool, index: index + 1 + tap)
                let second = MorningCopy.line(from: pool, index: index + 1 + tap)
                #expect(first == second)
                #expect(pool.contains(first))
            }
        }
        #expect(MorningCopy.line(from: pool, index: -1) == MorningCopy.line(from: pool, index: -1))
        #expect(pool.contains(MorningCopy.line(from: pool, index: -1)))
    }

    @Test func twoTapsInTheSameMorningDoNotGetTheSameLine() {
        let pool = MascotStage.start.encouragements
        for index in 0..<40 {
            let lines = (0..<3).map { MorningCopy.line(from: pool, index: index + 1 + $0) }
            #expect(Set(lines).count == 3, "morning \(index) repeats a line across its three taps")
            // ...and none of them is the greeting's own line, which comes out of the same pool.
            #expect(!lines.contains(MorningCopy.line(from: pool, index: index)))
        }
    }

    // The scan is the actual value of this test: it holds the rule when the next pass "just quickly" rolls
    // a line again.
    @Test func theMorningScreenRollsNoDiceForItsTone() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Tuck/GutenMorgenView.swift"),
            encoding: .utf8
        )
        #expect(!source.contains("randomElement()"))
    }

    // The end node is by construction NOT a pool member — it is its own case before the pool
    // fallback, like the three milestone lines — so `everyScreenPoolIsTranslated` does not reach it
    // and it needs its own coverage on both sides.
    @Test func theLineAfterTheWindowNeitherPraisesNorConsoles() {
        let line = MorningCopy.subline(morningIndex: 3, completedMornings: 12, isPastBlockWindowToday: true)

        #expect(!MorningCopy.sublines.contains(line))
        #expect(!line.contains("!"))
        // No number, no praise, no regret, no invitation to come back.
        #expect(line.rangeOfCharacter(from: .decimalDigits) == nil)
        for word in ["gut", "schade", "leider", "wieder da", "komm", "geschafft", "stolz"] {
            #expect(!line.lowercased().contains(word), "\(line) judges or consoles")
        }
        // ...and with the axis off, the same morning index gets its pool line back.
        #expect(MorningCopy.sublines.contains(
            MorningCopy.subline(morningIndex: 3, completedMornings: 12, isPastBlockWindowToday: false)))
    }

    // The ranking, pinned instead of described: a line that appears once in a user's life may not be
    // pushed aside by one that can appear on every day with an alarm. Same cut as
    // `milestonesReplaceThePoolLineExactlyOnce`, one axis further.
    @Test func aMilestoneStillOutranksTheLineAfterTheWindow() {
        #expect(MorningCopy.subline(morningIndex: 0, completedMornings: 1, isPastBlockWindowToday: true) == "Erster Morgen.")
        #expect(MorningCopy.subline(morningIndex: 0, completedMornings: 7, isPastBlockWindowToday: true) == "Siebter Morgen.")
        #expect(MorningCopy.subline(morningIndex: 0, completedMornings: 30, isPastBlockWindowToday: true) == "Dreißigster Morgen.")
    }

    @Test func theGreetingIsMorningOnlyBetweenFourAndTen() {
        #expect(MorningCopy.greeting(at: date(hour: 6, minute: 0), calendar: calendar) == "Guten Morgen")
        #expect(MorningCopy.greeting(at: date(hour: 10, minute: 59), calendar: calendar) == "Guten Morgen")
        #expect(MorningCopy.greeting(at: date(hour: 3, minute: 0), calendar: calendar) != "Guten Morgen")
        #expect(MorningCopy.greeting(at: date(hour: 15, minute: 0), calendar: calendar) != "Guten Morgen")
    }
}
