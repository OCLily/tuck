import Testing
import Foundation
@testable import Tuck

struct ScreenTimeNoticeTests {
    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suite = "ScreenTimeNoticeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        body(defaults)
    }

    private let now = Date(timeIntervalSince1970: 1_788_000_000)

    @Test func thirtyMinuteWindowThresholdIsTwentyMinutes() {
        #expect(ScreenTimeNotice.thresholdMinutes(forWindowSeconds: 30 * 60) == 20)
    }

    @Test func theThresholdScalesWithTheWindow() {
        #expect(ScreenTimeNotice.thresholdMinutes(forWindowSeconds: 60 * 60) == 40)
        #expect(ScreenTimeNotice.thresholdMinutes(forWindowSeconds: 45 * 60) == 30)
    }

    // A window below the SDK's fifteen-minute monitoring floor gets no event at all. Clamping its
    // threshold up to a minute instead would fire almost the moment the interval starts, which
    // would put the line on every single morning.
    @Test func aDegenerateWindowGetsNoThresholdAtAll() {
        #expect(ScreenTimeNotice.thresholdMinutes(forWindowSeconds: 0) == nil)
        #expect(ScreenTimeNotice.thresholdMinutes(forWindowSeconds: 60) == nil)
        #expect(ScreenTimeNotice.thresholdMinutes(forWindowSeconds: 15 * 60 - 1) == nil)
        #expect(ScreenTimeNotice.thresholdMinutes(forWindowSeconds: 15 * 60) == 10)
    }

    // The one path that can actually produce such a window: the reconciler rebuilds it from the two
    // stored ends, without the 30-minute clamp the anchored initializer applies.
    @Test func aWindowReconstructedWithIdenticalEndsGetsNoThreshold() {
        let degenerate = MorningBlockWindow(
            start: DateComponents(hour: 7, minute: 0),
            end: DateComponents(hour: 7, minute: 0)
        )

        #expect(ScreenTimeNotice.thresholdMinutes(forWindowSeconds: degenerate.durationSeconds) == nil)
    }

    @Test func nothingRecordedMeansNothingToSay() {
        withDefaults { defaults in
            #expect(ScreenTimeNotice.take(now: now, in: defaults) == false)
        }
    }

    // The whole point of the feature: said once, then gone. A second read on the same morning must
    // not repeat the line, and nothing may accumulate behind it.
    @Test func aNoticeIsConsumedByTheFirstRead() {
        withDefaults { defaults in
            ScreenTimeNotice.record(now: now, in: defaults)

            #expect(ScreenTimeNotice.take(now: now, in: defaults) == true)
            #expect(ScreenTimeNotice.take(now: now, in: defaults) == false)
        }
    }

    @Test func aNoticeSurvivesUntilTheMorningIsOver() {
        withDefaults { defaults in
            ScreenTimeNotice.record(now: now, in: defaults)

            #expect(ScreenTimeNotice.take(now: now.addingTimeInterval(6 * 60 * 60 - 1), in: defaults) == true)
        }
    }

    // "Heute Morgen" has to still be true when the line appears — yesterday's flag may never end up
    // on today's screen.
    @Test func aStaleNoticeIsNotShown() {
        withDefaults { defaults in
            ScreenTimeNotice.record(now: now, in: defaults)

            #expect(ScreenTimeNotice.take(now: now.addingTimeInterval(6 * 60 * 60 + 1), in: defaults) == false)
        }
    }

    @Test func aNoticeFromTheFutureIsIgnored() {
        withDefaults { defaults in
            ScreenTimeNotice.record(now: now, in: defaults)

            #expect(ScreenTimeNotice.take(now: now.addingTimeInterval(-1), in: defaults) == false)
        }
    }

    // Nothing was shown, so nothing was consumed. The clear used to be a `defer` and ran here too;
    // the next `record` overwrites the key anyway, so a kept expired flag costs one stale key —
    // against a flag the app could otherwise erase before it managed to read it.
    @Test func aStaleNoticeIsLeftWhereItIs() {
        withDefaults { defaults in
            ScreenTimeNotice.record(now: now, in: defaults)
            _ = ScreenTimeNotice.take(now: now.addingTimeInterval(24 * 60 * 60), in: defaults)

            #expect(defaults.object(forKey: "screenTimeNoticeRecordedAt") != nil)
        }
    }

    // Six hours are a retry window, not a single shot: a read that misses the monitor extension's
    // write must leave it for the next foregrounding inside the same morning.
    @Test func aReadThatFoundNothingLeavesTheNoticeForTheNextOne() {
        withDefaults { defaults in
            ScreenTimeNotice.record(now: now, in: defaults)

            #expect(ScreenTimeNotice.take(now: now.addingTimeInterval(-1), in: defaults) == false)
            #expect(ScreenTimeNotice.take(now: now, in: defaults) == true)
        }
    }

    // The copy is the feature. The measurement behind it cannot distinguish a phone call from
    // scrolling, so anything that accuses, asks for a justification or demands something would be
    // a guilt signal the data does not carry.
    @Test func theCopyObservesRatherThanJudges() {
        let line = MorningCopy.screenTime

        #expect(!line.contains("?"))
        #expect(!line.contains("!"))
        for word in ["solltest", "musst", "hättest", "warum", "wirklich", "zu viel"] {
            #expect(!line.lowercased().contains(word))
        }
    }

    // Three rules the line broke before: "viel" is a magnitude judgment the measurement cannot
    // carry (a phone call and scrolling raise the same flag), "oft" is a frequency judgment the
    // measurement carries even less (40 minutes straight and 40 minutes in twenty check-ins trip
    // the same threshold), and the past tense made it the only look back in a copy pool whose own
    // header rule is "Aussagen über die Gegenwart".
    @Test func theCopyNeitherQuantifiesNorLooksBack() {
        let line = MorningCopy.screenTime.lowercased()

        for word in ["viel", "lange", "ständig", "dauernd", "oft", "häufig", "immer wieder"] {
            #expect(!line.contains(word))
        }
        for word in [" war ", " warst ", " hattest "] {
            #expect(!line.contains(word))
        }
    }
}
