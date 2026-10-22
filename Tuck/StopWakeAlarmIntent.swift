import AppIntents
import Foundation
#if DEBUG
import FamilyControls
import ManagedSettings
#endif

// AlarmManager.AlarmConfiguration.alarm(stopIntent:) takes `any AppIntents.LiveActivityIntent`,
// which is a marker protocol refining AppIntent — so the whole AppIntent surface (title,
// init(), perform()) has to be here, not just a stop callback.
//
// Deliberately does NOT call AlarmManager.stop(id:): AlarmPresentation.Alert has no settable
// stop button anymore (`stopButton` is deprecated as "not used anymore"), so the system owns
// dismissal and this intent is only a notification hook. Assumption, not verified — no alarm
// was let ring end-to-end yet.
//
// No longer the only place a morning is counted: this intent covers the dismissal it is
// delivered for, CompletedMorningLedger.recordForegroundEntry covers the mornings it is not
// delivered for at all — reported for a dismissal on an already-unlocked screen and for a Live
// Activity swiped away. Both go through the same ledger, so whichever arrives first counts and the
// other finds the morning claimed. The block window itself still depends on neither
// (docs/product-decisions-2026-09-02.md).
struct StopWakeAlarmIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Wecker stoppen"

    // Not a user-facing action: it is only ever handed to AlarmManager as the alarm's stop
    // callback. Left discoverable (the AppIntent default), it would show up in Shortcuts and
    // Siri, where running it by hand would count a morning without an alarm ever having rung.
    static var isDiscoverable: Bool { false }

    init() {}

    // The dismissal is the per-morning boundary for the streak. Scheduling alone must not
    // count: the recurring alarm is registered once and would otherwise inflate progress without a
    // single morning having happened. The unlock quota is deliberately not refilled here — it
    // resets off the calendar day instead, out of reach of the wake-time picker.
    func perform() async throws -> some IntentResult {
        #if DEBUG
        // Debug builds only: this is the one place a ManagedSettings write happens
        // in the app process the system started in the background, which is a second assumption the
        // foreground case does not answer. It writes the BEDTIME store on purpose — the intent fires
        // seconds into the morning window, where the monitor extension writes the morning store, and
        // there the author of a standing shield would not be distinguishable. Without a stored
        // bedtime nobody registers .bedtimeBlock, so a shield in it can only have come from here.
        //
        // One shot: the flag is cleared before the write, not after. A forgotten switch would write
        // a bedtime shield on every alarm stop, and nothing in this build takes that one down — a
        // debug affordance that builds a permanent block is exactly the failure the product exists to avoid.
        if BlockDiagnostics.intentShieldProbeIsArmed() {
            BlockDiagnostics.disarmIntentShieldProbe()
            if let selection = FamilyActivitySelectionStore.load() {
                ShieldApplication.apply(selection, to: .bedtimeBlock)
                BlockDiagnostics.recordIntentShieldWrite()
            }
        }
        #endif
        CompletedMorningLedger.recordAlarmDismissal()
        return .result()
    }
}
