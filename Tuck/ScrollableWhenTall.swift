import SwiftUI

// None of this app's screens caps Dynamic Type, so at the accessibility sizes every screen
// grows past the display. A VStack that is starved of height does not clip its Text, it truncates
// it — the welcome copy lost half its sentence, the morning greeting read "Schön, dass d…", the
// setup screens lost their title and their note. Handing the column an unbounded height inside a
// ScrollView is what makes those lines wrap instead.
//
// The minHeight is the second half: without it every Spacer in the wrapped column collapses to
// zero inside the ScrollView and the centred screens would jump to the top at ordinary text sizes.
// With it, nothing moves until the content is genuinely taller than the screen.
//
// The primary button may sit inside this rather than outside, because scrolling is exactly
// what keeps it reachable here.
extension View {
    func scrollableWhenTallerThanScreen() -> some View {
        GeometryReader { proxy in
            ScrollView {
                self.frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}
