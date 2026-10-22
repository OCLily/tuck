import FamilyControls

// Shared by ContentView (debug status) and OnboardingFlowView (real entry point) - see
// ContentView.swift for why this needs to be a nonisolated static function rather than
// a plain call site: reading `.shared` inside a nonisolated async context keeps the
// non-Sendable AuthorizationCenter instance from crossing an isolation boundary.
enum FamilyControlsAuthorization {
    nonisolated static func requestIndividual() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    }
}
