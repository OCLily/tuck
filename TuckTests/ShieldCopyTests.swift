import Testing
@testable import Tuck

// The shield itself is rendered by com.apple.ManagedSettingsUI.shield-configuration-service, a
// system process the Simulator never starts because Family Controls does not work there. The copy
// is the only part of that screen that can be checked before a device exists.
struct ShieldCopyTests {
    private func content(
        _ context: OverrideContext = .morning,
        allowance: UnlockAllowance = .limited(2)
    ) -> ShieldCopy.Content {
        ShieldCopy.content(for: context, allowance: allowance)
    }

    @Test func theMorningAndTheEveningGreetDifferently() {
        #expect(content(.morning).title == "Guten Morgen")
        #expect(content(.bedtime).title == "Gute Nacht")
    }

    // An exhausted quota changes the copy and removes the way through — "Sperre bleibt", never
    // "du hast versagt". Tapping again must not be able to get anywhere.
    @Test func anExhaustedQuotaSwapsTheCopyAndDropsTheSecondButton() {
        for context in [OverrideContext.morning, .bedtime] {
            let exhausted = content(context, allowance: .limited(0))
            #expect(exhausted.subtitle.hasPrefix("Für heute aufgebraucht."))
            #expect(exhausted.subtitle.contains("Die Sperre bleibt bestehen."))
            #expect(exhausted.secondaryButton == nil)
        }
    }

    // The two pieces OverrideFlowView's exhausted screen renders. It used to hardcode the morning
    // wording from its own catalog, so a free user who spent the evening unlock was told at night
    // that tomorrow is a new morning — and the shield two taps away said "Tag".
    @Test func theExhaustedBodyFollowsTheWindowItBelongsTo() {
        #expect(ShieldCopy.exhaustedBody(for: .morning).hasSuffix("ein neuer Morgen."))
        #expect(ShieldCopy.exhaustedBody(for: .bedtime).hasSuffix("ein neuer Tag."))

        for context in [OverrideContext.morning, .bedtime] {
            #expect(content(context, allowance: .limited(0)).subtitle
                == "\(ShieldCopy.exhaustedHeading). \(ShieldCopy.exhaustedBody(for: context))")
        }
    }

    @Test func aQuotaWithUnlocksLeftOffersTheWayIntoTheApp() {
        for context in [OverrideContext.morning, .bedtime] {
            #expect(content(context, allowance: .limited(1)).secondaryButton == "Ich brauche kurz Zugriff")
        }
    }

    // The tone rules the rest of the app's copy already follows (docs/design/mascot.md, palette/copy
    // discipline in GutenMorgenView and OverrideFlowView), applied to the one screen a blocked user
    // actually sees. "solltest/musst" are the reactance words the app's copy rules
    // ban.
    @Test func noExclamationMarksAndNoDemands() {
        for context in [OverrideContext.morning, .bedtime] {
            for allowance in [UnlockAllowance.limited(0), .limited(2), .unlimited] {
                let copy = ShieldCopy.content(for: context, allowance: allowance)
                let strings = [copy.title, copy.subtitle, copy.primaryButton, copy.secondaryButton]
                    .compactMap { $0 }
                for string in strings {
                    #expect(!string.contains("!"))
                    #expect(!string.lowercased().contains("solltest"))
                    #expect(!string.lowercased().contains("musst"))
                }
            }
        }
    }

    // A negative count can only come from a store that was written by an older build, and it means
    // the same thing zero does.
    @Test func aNegativeCountIsTreatedAsExhausted() {
        #expect(content(allowance: .limited(-1)).secondaryButton == nil)
    }

    // Unlimited access is never exhausted, so the shield always offers the way in — the friction it
    // has to carry is the delay and the reason on the other side, not a number it ran out of.
    @Test func unlimitedAccessNeverReadsAsExhausted() {
        for context in [OverrideContext.morning, .bedtime] {
            let copy = content(context, allowance: .unlimited)
            #expect(copy.secondaryButton == "Ich brauche kurz Zugriff")
            #expect(!copy.subtitle.hasPrefix("Für heute aufgebraucht."))
        }
    }
}
