import SwiftUI

// What `.disabled(true)` does is written out in the shipped
// SwiftUICore interface and is the whole of it: `modifier(_EnvironmentKeyTransformModifier(keyPath:
// \.isEnabled, transform: { $0 = $0 && !disabled }))`. It sets one environment value and dims
// nothing. The dimming is applied by whoever reads that value further down, and on iOS 26.5 the
// reader is the button style itself: `PlainButtonStyle` is a `PrimitiveButtonStyle` whose
// `makeBody` has an opaque return type, so the interface cannot say what it draws — measured on the
// Simulator it draws every primitive of the label at alpha 0.5 (plate #6B7A6E → #B0B4AA, label
// #F5EFE6 → #D3D2C8, 3,96:1 → 1,39:1) and at alpha 0.75 while pressed. The previous fix here
// assumed `.buttonStyle(.plain)` renders the label as written; that premise is dead on this
// runtime, and it was only ever a premise — nothing in the interface promised it.
//
// What does hold, measured the same way: a `ButtonStyle` (not a `PrimitiveButtonStyle`) *replaces*
// the button's body, so `PlainButtonStyle`'s treatment is not in the tree at all. A style that
// hands `configuration.label` straight through renders a disabled button byte-identically to an
// enabled one. That is the mechanism, and it is also why the disabled look now has to be painted
// deliberately: the framework no longer supplies one, and a control that is off has to look off.
// The plate reads `@Environment(\.isEnabled)` for that (`PrimaryButtonPlate`), because the label
// closure sits inside the `.disabled()` scope while the view that writes it does not.
//
// The pressed alpha is ours now too. 0.75 is the framework's own strength, kept so the press does
// not change character; applied to the label as a whole rather than per primitive, which leaves the
// label/plate ratio at 3,96:1 during the press instead of the 2,13:1 the framework's version
// produced.
struct TuckButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

extension View {
    func disabledWithOwnAppearance(_ isDisabled: Bool) -> some View {
        buttonStyle(TuckButtonStyle())
            .disabled(isDisabled)
    }
}
