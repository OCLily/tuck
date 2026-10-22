import FamilyControls
import SwiftUI

// The four states of the permission section as peers of each other, the way WakeAlarmSetupView
// models its own. As a leading `if let authorizationError` the failure was an overlay instead: a
// denial arrives twice — thrown out of requestIndividual and again as the status — so tapping
// "Zugriff erlauben" replaced the one sentence that says how to come back with the SDK's
// own wording for the same denial, for the lifetime of the view. The status wins here, and only a
// failure that is not a denial can be seen at all.
enum FamilyControlsAccessState: Equatable {
    case notDetermined
    case approved
    case denied
    case failed(String)

    static func resolve(status: AuthorizationStatus, error: String?) -> FamilyControlsAccessState {
        switch status {
        case .approved: .approved
        case .denied: .denied
        default: error.map(FamilyControlsAccessState.failed) ?? .notDetermined
        }
    }
}

// The permission request and the app picker, shared by onboarding's two steps and by the
// standalone sheet below. Without that sheet, a Release build had exactly one route to the picker:
// the onboarding flow, whose only re-entry sits behind #if DEBUG — so anyone who chose "Später
// erlauben, weiter" could never pick apps again.
struct FamilyControlsAccessSection: View {
    @Binding var authorizationStatus: AuthorizationStatus

    @State private var authorizationError: String?

    var body: some View {
        // No leading Spacer — the fixed content offset of the host puts this column under the
        // safe area, and the pair of Spacers this had centred three lines in a full screen.
        VStack(spacing: Layout.section) {
            Image(systemName: statusIcon)
                .font(.system(size: 40))
                .foregroundStyle(Color.tuckCharcoalGreen)
                .accessibilityHidden(true)
            Text("Bildschirmzeit-Zugriff")
                .font(.title3.weight(.semibold))
                .fontDesign(.rounded)

            statusLine
                .font(.subheadline.weight(.regular))
                .fontDesign(.rounded)
                .foregroundStyle(Color.tuckInk)

            Spacer()

            if authorizationStatus != .approved {
                Button {
                    Task {
                        do {
                            try await FamilyControlsAuthorization.requestIndividual()
                            authorizationError = nil
                        } catch {
                            authorizationError = error.localizedDescription
                        }
                        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
                    }
                } label: {
                    // On the label. Outside the Button these five modifiers drew a 51,33 pt
                    // plate whose accessibility element stayed 19,33 pt — on the one button that
                    // asks for the permission the whole product depends on.
                    Text("Zugriff erlauben")
                        .font(.body.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(Color.tuckCharcoalGreen)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: Layout.radiusPlate).fill(Color.tuckSage.opacity(0.5)))
                }
            }

            // Only here: after a denial iOS never asks again, so the button above can no longer
            // change anything and the sentence beside it names a place this app cannot reach on its
            // own. It stays second because the retry is still this screen's own action, and it stays
            // absent in every other state, where nothing outside the app is missing.
            if accessState == .denied {
                OpenSystemSettingsButton()
            }
        }
        // The error is cleared with every appearance for the same reason it is no longer allowed to
        // outrank the status: it describes one attempt, not the state of the permission.
        .onAppear {
            authorizationStatus = AuthorizationCenter.shared.authorizationStatus
            authorizationError = nil
        }
    }

    private var accessState: FamilyControlsAccessState {
        FamilyControlsAccessState.resolve(status: authorizationStatus, error: authorizationError)
    }

    @ViewBuilder
    private var statusLine: some View {
        switch accessState {
        case .notDetermined:
            EmptyView()
        case .approved:
            Text("Zugriff erteilt.")
        case .denied:
            // The shield glyph above changes with the status, so without this line the
            // only thing separating "denied" from "not asked yet" was the symbol name VoiceOver
            // read out. States what is, never what will be blocked — without this permission
            // no shield can be applied at all. "fehlt noch" rather than "ist abgelehnt":
            // the state is the same, but the second one reads back a verdict on something the
            // user did, and the missing permission is the only part that is actionable.
            Text("Der Zugriff fehlt noch. Du kannst ihn in den Systemeinstellungen geben — bis dahin bleiben die Apps offen.")
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Layout.textInset)
        case .failed(let reason):
            Text(StatusCopy.failure(subject: String(localized: "Der Zugriff"),
                                    verb: String(localized: "erteilen"),
                                    reason: reason))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Layout.textInset)
        }
    }

    private var statusIcon: String {
        switch authorizationStatus {
        case .approved: "checkmark.shield.fill"
        case .denied: "xmark.shield.fill"
        default: "shield.fill"
        }
    }
}

struct ShieldedAppSelectionSection: View {
    let authorizationStatus: AuthorizationStatus
    // The host needs the count to say what its own button does, and only this view sees the picker.
    var onSelectionChange: (Int) -> Void = { _ in }

    // Loaded from, and written back to, the App-Group container: the Monitor extension is a
    // separate process and can only learn which apps to shield from there. Held purely in @State
    // it would never leave this view.
    @State private var activitySelection = FamilyActivitySelectionStore.load() ?? FamilyActivitySelection()
    @State private var whatsAppNoteExpanded = false

    var body: some View {
        // This screen asked one question and then answered it with ~90 words of
        // weight-700 prose — an intro, four category names with a reason each, an examples line, a
        // note box and a footer — all of which shared the screen 50/50 with the picker, because
        // both were equal children of a VStack. The category names are in the picker itself, so
        // the prose restated the list the user was looking at. What is left is the question, one
        // suggestion line, and the one thing the picker does not say (the picker owns
        // the space the prose held).
        VStack(alignment: .leading, spacing: Layout.container) {
            Text("Welche Apps sollen warten?")
                .font(.title3.weight(.semibold))
                .fontDesign(.rounded)
                .fixedSize(horizontal: false, vertical: true)

            Text(BlocklistSuggestions.primaryLine)
                .font(.subheadline.weight(.regular))
                .fontDesign(.rounded)
                .foregroundStyle(Color.tuckInk)
                .fixedSize(horizontal: false, vertical: true)

            // Closed by default, because it answers a question only some people have — and it is
            // the one line the picker cannot say: Apple's own category grouping is not visible in
            // the list, so a messenger disappears into "Soziale Netze" without warning.
            DisclosureGroup(isExpanded: $whatsAppNoteExpanded) {
                Text(BlocklistSuggestions.socialNetworksNote)
                    .font(.subheadline.weight(.regular))
                    .fontDesign(.rounded)
                    .foregroundStyle(Color.tuckInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            } label: {
                // A disclosure row is a tappable element like any other.
                Text("Zählt WhatsApp dazu?")
                    .font(.body.weight(.bold))
                    .fontDesign(.rounded)
                    .frame(maxWidth: .infinity, minHeight: Layout.hitMin, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .tint(Color.tuckCharcoalGreen)

            if authorizationStatus == .approved {
                // The priority is the whole point: without it the picker and the column above were
                // peers and split the screen evenly, whatever the column happened to weigh.
                FamilyActivityPicker(selection: $activitySelection)
                    .layoutPriority(1)

                if selectedCount == 0 {
                    Text("Noch nichts gewählt — ohne Auswahl wartet morgens keine App.")
                        .font(.subheadline.weight(.regular))
                        .fontDesign(.rounded)
                        .foregroundStyle(Color.tuckInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Spacer()
                // Charcoal and 40 pt like every other glyph of this class — it appears only
                // while the access is missing, so it reports a state.
                Image(systemName: "square.stack.3d.up.slash")
                    .font(.system(size: 40))
                    .accessibilityHidden(true)
                    .frame(maxWidth: .infinity)
                Text("Die Auswahl erscheint hier, sobald der Zugriff erlaubt ist.")
                    .font(.subheadline.weight(.regular))
                    .fontDesign(.rounded)
                    .foregroundStyle(Color.tuckInk)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                Spacer()
            }
        }
        .foregroundStyle(Color.tuckCharcoalGreen)
        // Saved on every change rather than on "Weiter": the step is skippable and the picker is
        // reachable again later, so the last edit must not depend on which button ends the step.
        .onChange(of: activitySelection) {
            FamilyActivitySelectionStore.save(activitySelection)
            // Stamped here rather than only at launch, because the tokens just written are bound to
            // THIS device: without it the first reconcile after onboarding would find a selection
            // next to no recorded identity and read its own freshly picked apps as a restore.
            DeviceChangeGuard.recordCurrentDevice()
            onSelectionChange(selectedCount)
        }
        .onAppear { onSelectionChange(selectedCount) }
    }

    private var selectedCount: Int {
        FamilyActivitySelectionStore.count(of: activitySelection)
    }
}

// The standalone host: one screen at a time — ask for the access while it is missing, show the
// picker once it is there — so nobody has to walk through welcome, explain and wake time again to
// reach either.
struct AccessAndAppSelectionView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var authorizationStatus: AuthorizationStatus = AuthorizationCenter.shared.authorizationStatus

    var body: some View {
        VStack(spacing: Layout.container) {
            if authorizationStatus == .approved {
                ShieldedAppSelectionSection(authorizationStatus: authorizationStatus)
            } else {
                // Only this branch needs the wrapper, and only here: the approved branch brings its
                // own ScrollView and the picker, and in onboarding the whole permission step already
                // scrolls. Presented as a sheet this column has no scroll layer at all — at
                // accessibility text sizes it already fills the sheet without any status line, and
                // the denied line below does not truncate, so it would push "Zugriff erlauben" —
                // the only in-app way back to the permission — out of reach.
                FamilyControlsAccessSection(authorizationStatus: $authorizationStatus)
                    .scrollableWhenTallerThanScreen()
            }

            // This was a byte-for-byte copy of onboarding's nextButton chain rather than a
            // call to anything shared, so the two drifted together only by hand.
            Button { dismiss() } label: {
                Text("Schließen").primaryButtonPlate()
            }
        }
        .foregroundStyle(Color.tuckCharcoalGreen)
    }
}

#Preview {
    AccessAndAppSelectionView()
}
