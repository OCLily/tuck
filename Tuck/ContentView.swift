import FamilyControls
import SwiftUI

// The one alpha on text the app keeps, a deliberate exception: this screen is reachable
// only through the #if DEBUG entry in SettingsView, so no user ever reads it. Written as an
// explicit opacity on a palette colour rather than as `.secondary` — the same value, but a grep
// for `opacity(` or for a palette token now surfaces it, instead of it sitting out every contrast
// audit under a name that looks like a colour choice.
private let developerNoteColor = Color.tuckCharcoalGreen.opacity(0.6)

struct ContentView: View {
    @Binding var previewStage: MascotStage?

    @ObservedObject private var authorizationCenter = AuthorizationCenter.shared
    @AppStorage("hasCompletedOnboarding", store: TuckIdentifiers.appGroupDefaults)
    private var hasCompletedOnboarding = false
    @State private var authorizationError: String?

    var body: some View {
        VStack(spacing: Layout.container) {
            Text("Tuck")
            Text("Status: \(authorizationCenter.authorizationStatus.description)")
            Text("Wecker zuletzt abgestellt: \(WakeAlarmStore.dismissedAt().map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "—")")
            Text("Abgeschlossene Morgen: \(MorningProgressStore.completedMornings()) · Freischaltungen übrig: \(UnlockQuotaStore.morning.allowance().remainingCount.map(String.init) ?? "∞")")
            if let authorizationError {
                Text(authorizationError)
                    .foregroundStyle(.red)
            }
            Button("Zugriff anfragen") {
                Task {
                    do {
                        try await FamilyControlsAuthorization.requestIndividual()
                        authorizationError = nil
                    } catch {
                        authorizationError = error.localizedDescription
                    }
                }
            }
            Button("Onboarding erneut zeigen") { hasCompletedOnboarding = false }

            Divider()

            VStack(spacing: Layout.pair) {
                Text("Wachstumsstufe (Vorschau)")
                Picker("Wachstumsstufe (Vorschau)", selection: $previewStage) {
                    Text("Echt").tag(MascotStage?.none)
                    ForEach(MascotStage.allCases) { stage in
                        Text(stage.displayName).tag(MascotStage?.some(stage))
                    }
                }
                .pickerStyle(.segmented)
                Text("Zeigt die Optik einer Stufe an, ohne den gespeicherten Fortschritt zu ändern. „Echt“ zeigt wieder die Stufe der oben gezählten Morgen.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(developerNoteColor)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView(previewStage: .constant(nil))
}
