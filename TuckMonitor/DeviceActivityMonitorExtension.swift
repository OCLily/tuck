import DeviceActivity
import ManagedSettings

// One extension serves both windows: the DeviceActivityName arrives as an argument, so which
// named ManagedSettingsStore gets shielded is a lookup, not a second target.
//
// Deliberately does NOT touch MorningProgressStore in either callback. A completed morning is
// counted by StopWakeAlarmIntent — a real user action in the app process, with its own idempotency
// guard — and duplicating it here would inflate the streak from a foreign process whose reliability
// is still unverified. The bedtime window stays out of progress entirely.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        // First, before every guard below: this counts that iOS spoke at all, which is the one
        // thing the five-day observation exists to find out. A count taken after the guards
        // would be a count of successful shields wearing the name of the callback.
        switch activity {
        case .morningBlock:
            BlockDiagnostics.record(.morningIntervalsStarted)
            BlockDiagnostics.recordMorningIntervalStart(at: .now)
        case .bedtimeBlock:
            BlockDiagnostics.record(.bedtimeIntervalsStarted)
            BlockDiagnostics.recordBedtimeIntervalStart(at: .now)
        default:
            break
        }

        guard let storeName = Self.storeName(for: activity) else { return }

        // Before the selection load, so a lapsed access releases the evening window even where there
        // is nothing to shield with: this is the one callback a registration made under Plus keeps
        // reaching after the access ended, and the app process cannot revoke what it never runs to
        // see. The clear is not decoration — an occurrence whose intervalDidEnd never arrived would
        // otherwise leave a shield standing that nothing here takes down.
        guard BlockWindowEntitlement.action(for: activity, access: .current()) == .shield else {
            ShieldRelease.clear(storeName)
            return
        }

        // DeviceActivitySchedule has no weekday parameter — repeats: true is every day — so the
        // morning window stays registered on days the user did not choose and this callback fires
        // there too. The alarm is silent on those days; without this the shield would still go up,
        // which is a block nobody asked for wearing the name of a morning that never started.
        //
        // Below the store lookup and clearing rather than returning bare, for the reason the
        // entitlement guard clears: the morning's intervalDidEnd is documented to go missing, so a
        // Friday shield can still be standing when Saturday's intervalDidStart arrives. Skipping
        // the day silently would then hand a Mo-Fr user a Friday shield across the whole of
        // Saturday's window. A missed block costs one window, a stranded shield blocks forever
        // (Tuck/BlockWindowMonitor.swift).
        //
        // The two diagnostic counters above stay outside the guard on purpose: iOS spoke, and that
        // is what they count. The skipped day gets its own counter below, so the five-day
        // observation can tell it apart from a platform failure.
        guard activity != .morningBlock || WakeAlarmWeekdayStore.morningBlockApplies(on: .now) else {
            ShieldRelease.clear(storeName)
            BlockDiagnostics.record(.weekdaysSkipped)
            return
        }

        // Same clear, same reason: without a selection there is nothing to shield with, and a
        // shield left over from an occurrence whose end never arrived would stay up regardless.
        guard let selection = FamilyActivitySelectionStore.load() else {
            ShieldRelease.clear(storeName)
            return
        }

        // Non-throwing write: without Family-Controls authorization this does nothing and says
        // nothing. Nothing downstream may treat reaching this line as "the shield is up" — the
        // count below says a shield was written, never that one is up.
        ShieldApplication.apply(selection, to: storeName)
        // Off the store name rather than the activity: by this line the name is already narrowed to
        // one of the two windows, and the write that was just made belongs to exactly that one.
        switch storeName {
        case .morningBlock: BlockDiagnostics.record(.morningShieldsApplied)
        case .bedtimeBlock: BlockDiagnostics.record(.bedtimeShieldsApplied)
        default: break
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard let storeName = Self.storeName(for: activity) else { return }
        ShieldRelease.clear(storeName)
    }

    // Both names are checked, not just the event: the callback carries nothing else, so the pair is
    // the only identity there is. An event this build did not register would otherwise write a
    // notice the morning screen then claims as its own.
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        // Same weekday gate as intervalDidStart, for the same reason: on a day nothing was shielded
        // the notice would speak about a window that never held anything back.
        guard event == .screenTimeInWindow, activity == .morningBlock,
              WakeAlarmWeekdayStore.morningBlockApplies(on: .now)
        else { return }
        ScreenTimeNotice.record()
    }

    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
    }

    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)
    }

    // An unknown activity name means a registration this build does not own — shielding the
    // morning store on its behalf would be worse than doing nothing.
    private static func storeName(for activity: DeviceActivityName) -> ManagedSettingsStore.Name? {
        switch activity {
        case .morningBlock: .morningBlock
        case .bedtimeBlock: .bedtimeBlock
        default: nil
        }
    }
}
