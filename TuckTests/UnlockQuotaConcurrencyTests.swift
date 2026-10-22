import Testing
import Foundation
@testable import Tuck

struct UnlockQuotaConcurrencyTests {
    // Threads stand in for processes: the real second writer is the Shield-Action extension, and a
    // unit test cannot spawn it. Each thread opens its own UserDefaults on the shared suite the way
    // a second process would, and flock is held per open-file-description rather than per process —
    // so the guard under test here is the same one that separates app from extension.
    private func withSuite(_ body: (String, UserDefaults) -> Void) {
        let suite = "UnlockQuotaConcurrencyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        body(suite, defaults)
    }

    // A spin barrier rather than a semaphore, and real threads rather than a queue: every caller
    // has to be inside the read at the same moment for the interleaving to happen at all, and a
    // pool that runs them one after another hides exactly the bug this asserts against.
    private final class Barrier: @unchecked Sendable {
        private let lock = NSLock()
        private var arrived = 0
        private let expected: Int

        init(expected: Int) { self.expected = expected }

        func wait() {
            lock.lock()
            arrived += 1
            lock.unlock()
            while true {
                lock.lock()
                let count = arrived
                lock.unlock()
                if count >= expected { return }
            }
        }
    }

    private func concurrently(_ count: Int, _ body: @escaping @Sendable () -> Void) {
        let barrier = Barrier(expected: count)
        let group = DispatchGroup()
        for _ in 0..<count {
            group.enter()
            Thread {
                barrier.wait()
                body()
                group.leave()
            }.start()
        }
        group.wait()
    }

    // Five slots rather than the one a free day actually grants: with a single slot there is only
    // ever one caller and the interleaving under test cannot occur. What is being checked is the
    // lock, not the product number — the keys and the rollover hour are the morning's.
    private static let fiveSlotQuota = UnlockQuotaStore(
        freeUnlockMaximum: 5,
        dayRolloverHour: 0,
        remainingUnlocksKey: "remainingUnlocksToday",
        quotaAnchorDayKey: "morningUnlockQuotaAnchorDay"
    )

    // Exactly as many callers as the quota has slots: one slot each, nothing left over. A lost
    // update shows up as a count above zero — two callers read the same value and wrote the same
    // decrement, so one of the two unlocks was handed out without being paid for.
    @Test func concurrentConsumersNeverSpendOneSlotTwice() {
        withSuite { suite, defaults in
            let quota = Self.fiveSlotQuota
            let maximum = quota.freeUnlockMaximum

            for _ in 0..<40 {
                defaults.removeObject(forKey: "remainingUnlocksToday")
                defaults.removeObject(forKey: "morningUnlockQuotaAnchorDay")

                concurrently(maximum) {
                    quota.consumeUnlock(in: UserDefaults(suiteName: suite)!)
                }

                #expect(quota.remainingUnlocks(in: defaults) == 0)
            }
        }
    }

    // Unlimited access takes the counter out of the path entirely, lock included: nothing is
    // written, so there is nothing for two processes to lose an update on.
    @Test func concurrentConsumersOnPlusWriteNothingAtAll() {
        withSuite { suite, defaults in
            SubscriptionTierStore.store(.plus, in: defaults)
            let quota = UnlockQuotaStore.morning

            concurrently(8) {
                quota.consumeUnlock(in: UserDefaults(suiteName: suite)!)
            }

            #expect(defaults.object(forKey: "remainingUnlocksToday") == nil)
            #expect(quota.allowance(in: defaults) == .unlimited)
        }
    }

    // Lets a reader run between consumeUnlock's two writes, which is the one interleaving the lock
    // does not cover: the shield's configuration extension reads the quota without taking it.
    private final class ProbingDefaults: UserDefaults {
        var afterSet: ((UserDefaults) -> Void)?

        override func set(_ value: Int, forKey defaultName: String) {
            super.set(value, forKey: defaultName)
            afterSet?(self)
        }
    }

    // The state that makes the write order visible: yesterday's anchor beside yesterday's spent-out
    // count. Written in the wrong order the new anchor lands first and a reader in the gap sees
    // today's quota as already exhausted — a full morning reported empty. In the right order it
    // sees at worst one spend not yet counted.
    @Test func aReaderBetweenTheTwoWritesNeverSeesTodaysQuotaAsExhausted() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let today = calendar.date(from: DateComponents(
            calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 9, day: 2, hour: 7, minute: 10
        ))!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        withSuite { suite, defaults in
            // The five-slot quota again, for the same reason: the observation this asserts on is
            // "a spend not yet counted", which needs a count that is still above zero afterwards.
            let quota = Self.fiveSlotQuota
            for _ in 0..<quota.freeUnlockMaximum {
                quota.consumeUnlock(now: yesterday, calendar: calendar, in: defaults)
            }
            #expect(quota.remainingUnlocks(now: yesterday, calendar: calendar, in: defaults) == 0)

            let probing = ProbingDefaults(suiteName: suite)!
            var observed: [Int] = []
            probing.afterSet = { store in
                observed.append(quota.remainingUnlocks(now: today, calendar: calendar, in: store))
            }
            quota.consumeUnlock(now: today, calendar: calendar, in: probing)
            probing.afterSet = nil

            #expect(observed.count == 2)
            #expect(observed.allSatisfy { $0 > 0 })
        }
    }
}
