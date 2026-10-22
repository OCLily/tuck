import SwiftUI

@main
struct TuckApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding", store: TuckIdentifiers.appGroupDefaults)
    private var hasCompletedOnboarding = false

    // Owned here, not by the paywall: the Transaction.updates listener has to outlive the screen
    // that sells the subscription, or a renewal that arrives while the paywall is closed never
    // reaches the cached tier the quota reads.
    @State private var subscriptions = SubscriptionController()

    // A missing App Group is a provisioning fault, not a runtime condition: it cannot be recovered
    // from inside the app, and every screen after this point would report a block that no extension
    // can ever see. Loud in Debug, so it is found on the desk rather than on a stranger's morning —
    // and honest in Release, where GutenMorgenView states it instead of claiming the window.
    init() {
        #if DEBUG
        if !TuckIdentifiers.appGroupIsProvisioned {
            fatalError("""
            App Group \(TuckIdentifiers.appGroupSuiteName) is not provisioned for this build. \
            Every store would silently fall back to a private container: no shield, no counted \
            morning, no armed window. Check the entitlements of all four targets and the \
            provisioning profile.
            """)
        }
        #endif

        // Before the first body evaluation, not in a `.task`: every screen from here on reads the
        // App Group, and a migration that ran after the first read would convert a container that
        // had already been answered from. An App init runs once per process, which is what makes
        // this safe here and unsafe in a View init.
        let migrationOutcome = Migrations.runIfNeeded()
        #if DEBUG
        if case .failed = migrationOutcome {
            fatalError("Schema migration did not persist: \(migrationOutcome). The App Group write did not survive its own read-back.")
        }
        if case .stepFailed = migrationOutcome {
            fatalError("Schema migration did not persist: \(migrationOutcome). The App Group write did not survive its own read-back.")
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    GutenMorgenView()
                } else {
                    OnboardingFlowView()
                }
            }
            .environment(subscriptions)
            // No trial start here any more. Launching is not a use of Plus, and the
            // fourteen days measured from it ran out for people who had never met the boundary they
            // exist to argue about. TrialTrigger.plusBoundaryReached owns the clock now, at the two
            // screens where the product says no.
            .task { await subscriptions.refreshEntitlement() }
            // The `.task` above runs once per view identity, and Transaction.updates carries
            // renewals, revocations and Ask-to-Buy approvals but not a period that simply ends
            // unrenewed. Without this pass a resident process keeps a cached "plus" past the real
            // expiration until the next cold launch.
            .onChange(of: scenePhase) {
                guard scenePhase == .active else { return }
                Task { await subscriptions.refreshEntitlement() }
            }
        }
    }
}
