import SwiftUI

// The app had two filled primary buttons for one role — the
// onboarding "Weiter" (17 pt semibold, white, `.padding()`, an 8 pt outer inset) and the paywall's
// purchase button (17 pt bold, cream, `.padding(.vertical, 10)`, full bleed). Both cleared the contrast
// rule, but only one can be the house form, and this is it. Cream on charcoal is 3,96:1 and therefore
// depends on the large-text exception — which is exactly why the weight is 700 here and may not be
// lowered. The shield keeps white on charcoal (4,53:1): iOS picks the font there, so no exception
// is available to it.
//
// Applied to the *label* rather than to the Button, unlike the helper it replaces: modifiers hung
// outside a Button grow the plate without growing its hit area, so the old onboarding button was
// only tappable across its text.
//
// A ViewModifier rather than a plain modifier chain, for the one thing a
// chain cannot do: read `@Environment(\.isEnabled)`. The view that writes `.disabled(…)` sits above
// it and still sees `true`; the label closure sits below it and sees the answer. That keeps the
// disabled appearance at the place that paints the plate, and leaves every call site unchanged.
struct PrimaryButtonPlate: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        content
            .font(.body.weight(.bold))
            .fontDesign(.rounded)
            .foregroundStyle(isEnabled ? Color.tuckPrimaryPlateLabel : Color.tuckDisabledPlateLabel)
            // 17 pt at weight 700 is a 20.3 pt line, so 10 pt of vertical
            // padding measured 40.3 pt — under Apple's 44 pt minimum on the one control that closes
            // a screen. Both halves are needed, and for different reasons: the 12 makes the drawn
            // plate 44.3 pt at Dynamic Type "Large", the minHeight makes the *hit area* 44 pt even
            // where the label is shorter than the line box or a future size class shrinks it. A
            // plate that merely looks big enough is exactly what the 44 pt minimum rules out.
            .padding(.vertical, Layout.plateY)
            .frame(maxWidth: .infinity, minHeight: Layout.hitMin)
            .background(
                RoundedRectangle(cornerRadius: Layout.radiusPlate)
                    .fill(isEnabled ? Color.tuckPrimaryPlate : Color.tuckDisabledPlate)
            )
    }
}

extension View {
    func primaryButtonPlate() -> some View {
        modifier(PrimaryButtonPlate())
    }
}
