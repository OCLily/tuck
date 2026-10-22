import SwiftUI
import UIKit

// The app's only UIApplication.open, and the only place it sends the user anywhere else. It exists
// at the two permission dead ends whose remedy is not in this app at all: Family Controls declined
// (FamilyControlsAccessSection) and the alarm permission declined (WakeAlarmSetupView). The third
// dead end — a stored window whose registration threw — reaches the first of them through
// "Bildschirmzeit-Zugriff prüfen" and needs no button of its own.
//
// Verified against the iOS 26.5 runtime rather than assumed: UIApplication.openSettingsURLString is
// `app-settings:`, the app's own page in the Settings app; the two constants beside it in UIKitCore
// are `app-settings:notifications` and `app-settings:default-applications`, sub-pages of that same
// page. The label therefore promises the Settings app and nothing past it — which row a permission
// sits on there is iOS's arrangement, and naming it would be a claim about a screen we do not draw.
enum SystemSettingsLink {
    static var url: URL? { URL(string: UIApplication.openSettingsURLString) }
}

// A sage plate, because leaving for the Settings app does not conclude either screen — both
// keep their own action above it.
struct OpenSystemSettingsButton: View {
    var body: some View {
        Button {
            guard let url = SystemSettingsLink.url else { return }
            UIApplication.shared.open(url)
        } label: {
            Text("Zu den Systemeinstellungen")
                .font(.body.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(Color.tuckCharcoalGreen)
                .padding()
                .background(RoundedRectangle(cornerRadius: Layout.radiusPlate).fill(Color.tuckSage.opacity(0.5)))
        }
    }
}
