import StoreKit
import SwiftUI

// The two destinations Guideline 3.1.2 requires next to an auto-renewing subscription. Kept as
// strings in one place rather than inline in the view so the still-missing one is greppable and
// testable — App Store Connect wants the same privacy URL in the listing, and two copies of a
// placeholder are two things to forget on the day it becomes real.
enum PaywallLegal {
    // Apple's own standard EULA. Not a placeholder: it is the licence that applies whenever a
    // developer supplies no custom one, App Store Connect links to this exact document, and it is
    // what Review expects to find behind "Terms of Use" for an app with no terms of its own. If Tuck
    // ever gets custom terms, they replace this string and the listing's EULA field together.
    static let termsOfUse = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"

    // TODO: replace with the hosted privacy policy before submission — a draft of the text exists
    // but is not published anywhere yet (docs/SSOT.md, "Datenschutz-URL
    // als gehostete Seite fehlt"). The same URL goes into App Store Connect's privacy-policy field;
    // an app using the Screen Time APIs is rejected without it. `example.com` is reserved by RFC
    // 2606 and can never accidentally become somebody else's page while this is still unfixed.
    static let privacyPolicy = "https://example.com/tuck/datenschutz"

    // What the TODO above is measured against, so "is this still the placeholder?" is one call
    // rather than a string comparison spread over the tests and the review checklist.
    static var privacyPolicyIsPlaceholder: Bool {
        privacyPolicy.contains("example.com")
    }
}

// There is one paid tier, so this screen no longer compares tiers — it
// says what a morning without a subscription has, what Plus adds, and in which of two periods Plus
// can be bought. Nothing here counts overrides and nothing here expires, so there is no honest way
// to build urgency into it either.
//
// Same contrast rule as the rest of the app (docs/design/design-system.md): charcoal-green on cream
// cannot reach AA's 4.5:1 for small text, so every card title, row label, price and button here
// sits at >=14 pt weight 700 where the bar is 3:1. The six lines that are prose rather than chrome
// — the status detail, the capability lines, the notice detail, the 3.1.2 paragraph, the closing
// sentence and the trial banner's detail — carry `tuckInk` instead. It
// clears 4,5:1 on all three grounds of this screen, the dusty-rose notice card included, so those
// lines may fall to weight 400 and stop outweighing the titles above them.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss

    @Environment(SubscriptionController.self) private var subscriptions
    @State private var showManageSubscriptions = false

    // The app's own gate, not StoreKit's answer: a running trial grants Plus without any entitlement
    // ever having existed, and a screen that reported "kein Abo" while the trial carries the user
    // would state a state that is not true.
    @State private var access = SubscriptionAccess.current()

    // Monthly is preselected because it is the smaller commitment. Preselecting the year would make
    // the choice in the direction that happens to pay more (no dark patterns).
    @State private var selectedPlan: SubscriptionPlan = .plusMonthly

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.root) {
                    statusCard
                    plusCard
                    freeCard
                    if let notice = subscriptions.notice {
                        noticeCard(notice)
                    }
                    footerActions
                    legalSection
                }
                .padding()
            }
            .scrollContentBackground(.hidden)
            .background(Color.tuckCream)
            .navigationTitle("Freischaltungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Schließen") { dismiss() }
                        .font(.body.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(Color.tuckCharcoalGreen)
                }
            }
        }
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
        .task {
            // A notice reports what happened during one attempt. Carrying it into a later visit
            // would state a failure that nothing on this visit has caused.
            subscriptions.notice = nil
            await subscriptions.loadProducts()
            await subscriptions.refreshEntitlement()
            access = SubscriptionAccess.current()
        }
        .onChange(of: subscriptions.entitlement) { access = SubscriptionAccess.current() }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: Layout.pair) {
            Text("Dein Stand")
                .font(.subheadline.weight(.bold))
            Text(statusTitle)
                .font(.title3.weight(.semibold))
            Text(statusDetail)
                .font(.subheadline.weight(.regular))
                .foregroundStyle(Color.tuckInk)
        }
        .fontDesign(.rounded)
        .foregroundStyle(Color.tuckCharcoalGreen)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        // Sage 0.25 is the passive step. This card reports a state and carries nothing to
        // tap, so it must not sit on the action step the plate buttons use.
        .background(RoundedRectangle(cornerRadius: Layout.radiusCard).fill(Color.tuckSage.opacity(0.25)))
    }

    // Led by what the user has right now, not by what StoreKit last said: a trial that is still
    // running outranks an entitlement that lapsed inside it, and the cached tier is what the quota
    // actually uses. `.unresolved` stays its own line rather than falling back to "kein Abo",
    // because the app cannot tell the two apart before StoreKit has answered.
    private var statusTitle: String {
        switch access {
        case .subscribed(let tier): String(localized: "\(tier.displayName) aktiv")
        case .trial(let daysRemaining): String(localized: "Testphase · noch \(daysRemaining) Tage")
        case .free:
            switch subscriptions.entitlement {
            case .unresolved: String(localized: "Noch keine Antwort")
            case .expired(let tier): String(localized: "\(tier.displayName) ist ausgelaufen")
            case .active(let tier): String(localized: "\(tier.displayName) aktiv")
            case .notSubscribed: String(localized: "Kein Abo aktiv")
            }
        }
    }

    private var statusDetail: String {
        switch access {
        case .subscribed: String(localized: "Freischaltungen ohne Tageslimit. Jederzeit kündbar.")
        case .trial:
            String(localized: "Die Testphase hat alles, was Plus hat. Danach gilt \(UnlockQuotaStore.morning.freeUnlockMaximum) Freischaltung pro Tag.")
        case .free:
            switch subscriptions.entitlement {
            case .unresolved:
                String(localized: "Solange das offen ist, ändert sich nichts an deinem Zugang.")
            case .expired:
                String(localized: "Es gilt wieder \(UnlockQuotaStore.morning.freeUnlockMaximum) Freischaltung pro Tag. Nichts geht verloren, dein Weg zählt weiter.")
            case .active:
                String(localized: "Freischaltungen ohne Tageslimit. Jederzeit kündbar.")
            case .notSubscribed:
                String(localized: "Du hast \(UnlockQuotaStore.morning.freeUnlockMaximum) Freischaltung pro Tag.")
            }
        }
    }

    // The action step, because the purchase sits inside this card rather than beside it.
    private var plusCard: some View {
        VStack(alignment: .leading, spacing: Layout.container) {
            VStack(alignment: .leading, spacing: Layout.cardInterior) {
                Text("Tuck Plus")
                    .font(.title3.weight(.semibold))
                capabilityLine("Freischaltungen ohne Tageslimit")
                // Claimable: the evening window is gated from this same access
                // state (BedtimeSetupView, BlockWindowReconciler), so the line has something behind
                // it. Before the gate existed it would have been an overclaim and was deliberately absent.
                capabilityLine("Das Bettzeit-Fenster am Abend")
                capabilityLine("Dieselbe Sperre, dieselbe Wartezeit, dieselbe Begründung")
                capabilityLine("Jederzeit kündbar")
            }

            purchaseSection
        }
        .fontDesign(.rounded)
        .foregroundStyle(Color.tuckCharcoalGreen)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: Layout.radiusCard).fill(Color.tuckSage.opacity(0.5)))
    }

    // What stays without paying, stated as plainly as what Plus adds: a comparison that only lists
    // the paid side is an argument, not a comparison.
    private var freeCard: some View {
        VStack(alignment: .leading, spacing: Layout.cardInterior) {
            Text("Ohne Abo")
                .font(.title3.weight(.semibold))
            capabilityLine("Wecker, Morgenfenster und Sperre")
            capabilityLine("\(UnlockQuotaStore.morning.freeUnlockMaximum) Freischaltung pro Tag")
            capabilityLine("Dein Tuck wächst mit jedem Morgen")
        }
        .fontDesign(.rounded)
        .foregroundStyle(Color.tuckCharcoalGreen)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: Layout.radiusCard).fill(Color.tuckSage.opacity(0.25)))
    }

    // The checkmark keeps charcoal green and weight 700 on purpose: the design system leaves glyphs on the
    // brand colour, and a marker is not the line it marks. Only the sentence beside it is body copy.
    private func capabilityLine(_ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Layout.pair) {
            Image(systemName: "checkmark")
                .font(.subheadline.weight(.bold))
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline.weight(.regular))
                .foregroundStyle(Color.tuckInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var purchaseSection: some View {
        if case .subscribed = access {
            Text("Du hast Plus.")
                .font(.subheadline.weight(.bold))
        } else {
            VStack(spacing: Layout.cardInterior) {
                ForEach(SubscriptionPlan.allCases, id: \.self) { plan in
                    planRow(plan)
                }
            }
            purchaseButton
        }
    }

    // The two periods as one choice rather than as two offers: the design system allows one primary action per
    // screen, and picking a period is not that action — buying is.
    private func planRow(_ plan: SubscriptionPlan) -> some View {
        let isSelected = selectedPlan == plan
        return Button {
            selectedPlan = plan
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: Layout.cardInterior) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.body.weight(.bold))
                    .accessibilityHidden(true)
                // Grund: enger als `pair` (8), weil die beiden Zeilen hier nicht ein Paar sind,
                // sondern eine Zeile mit ihrer eigenen Kleinschrift darunter — 8 pt lesen sich
                // hier als zwei Angaben statt als eine.
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.displayName)
                        .font(.body.weight(.bold))
                    if let equivalent = monthlyEquivalent(for: plan) {
                        Text(equivalent)
                            .font(.subheadline.weight(.bold))
                    }
                }
                Spacer()
                Text(priceLabel(for: plan))
                    .font(.subheadline.weight(.bold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .contentShape(Rectangle())
            // A stroke, not a second fill: the row sits on the card's own sage 0.5, and stacking a
            // second sage on it would push the text towards the 3,40:1 that the design system rules out.
            .background(
                RoundedRectangle(cornerRadius: Layout.radiusPlate)
                    .strokeBorder(Color.tuckCharcoalGreen.opacity(isSelected ? 1 : 0.35),
                                  lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // The one primary action of this screen. The old layout had one per tier card, which is
    // exactly the rule it broke.
    @ViewBuilder
    private var purchaseButton: some View {
        if let product = subscriptions.product(for: selectedPlan) {
            Button {
                Task { await subscriptions.purchase(product) }
            } label: {
                HStack(spacing: Layout.pair) {
                    if subscriptions.isWorking {
                        // Tinted, unlike the sage-plate buttons: the default indicator is a grey
                        // that all but disappears on the charcoal fill.
                        ProgressView()
                            .tint(Color.tuckPrimaryPlateLabel)
                    }
                    Text(subscriptions.isWorking ? "Plus wird abonniert …" : "Plus abonnieren")
                }
                .primaryButtonPlate()
            }
            .disabledWithOwnAppearance(subscriptions.isWorking)
        } else {
            Text("Preis wird geladen …")
                .font(.subheadline.weight(.bold))
        }
    }

    // The App Store price, never a number written into the app: a hardcoded "3,99 €" is wrong in
    // every storefront that is not this one.
    private func priceLabel(for plan: SubscriptionPlan) -> String {
        guard let product = subscriptions.product(for: plan) else { return "—" }
        // displayPrice is already storefront- and locale-formatted; only the period around it is copy.
        switch plan {
        case .plusMonthly: return String(localized: "\(product.displayPrice) / Monat")
        case .plusYearly: return String(localized: "\(product.displayPrice) / Jahr")
        }
    }

    // What the year costs per month, divided out of the price the store actually returned. A
    // percentage written into the copy would be wrong in every storefront whose two prices are not
    // these two, and a saving nobody can recompute from the screen is not a saving, it is a claim.
    private func monthlyEquivalent(for plan: SubscriptionPlan) -> String? {
        guard plan == .plusYearly, let product = subscriptions.product(for: plan) else { return nil }
        let perMonth = (product.price / 12).formatted(product.priceFormatStyle)
        return String(localized: "entspricht \(perMonth) pro Monat")
    }

    private func noticeCard(_ notice: SubscriptionController.Notice) -> some View {
        VStack(alignment: .leading, spacing: Layout.pair) {
            Text(noticeTitle(notice))
                .font(.body.weight(.bold))
            Text(noticeDetail(notice))
                .font(.subheadline.weight(.regular))
                .foregroundStyle(Color.tuckInk)
        }
        .fontDesign(.rounded)
        .foregroundStyle(Color.tuckCharcoalGreen)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: Layout.radiusCard).fill(Color.tuckDustyRose.opacity(0.45)))
        // "Braucht Aufmerksamkeit" hung on a fill change alone — dusty rose 0.45
        // instead of sage — and a fill change alone is no signal for anyone with a colour vision
        // deficiency. Introducing red would be the usual answer and is forbidden here, so the
        // second signal is a contour, after the pattern the period row already gets right: it
        // says "selected" through a stroke AND a glyph, neither of them colour alone.
        //
        // `strokeBorder`, not `stroke`: stroke straddles the path and would draw one point outside
        // the card, changing its frame by a hair and clipping against the neighbouring cards.
        // strokeBorder draws inward, so the card keeps every dimension it had.
        //
        // Full opacity on purpose. Alpha is allowed on a stroke and never on text, and the period
        // row's unselected state uses 0.35 for exactly that — but there the alpha carries a MEANING (not
        // chosen). A notice card is never "half noticed".
        .overlay(
            RoundedRectangle(cornerRadius: Layout.radiusCard)
                .strokeBorder(Color.tuckCharcoalGreen, lineWidth: 2)
        )
    }

    private func noticeTitle(_ notice: SubscriptionController.Notice) -> String {
        switch notice {
        case .awaitingApproval: String(localized: "Wartet auf Freigabe")
        case .unverified: String(localized: "Konnte nicht bestätigt werden")
        case .failed: String(localized: "Hat gerade nicht geklappt")
        }
    }

    private func noticeDetail(_ notice: SubscriptionController.Notice) -> String {
        switch notice {
        case .awaitingApproval:
            String(localized: "Der Kauf braucht noch die Zustimmung deiner Familienorganisation. Bis dahin ändert sich nichts.")
        case .unverified:
            String(localized: "Der App Store hat den Kauf nicht bestätigt. Der Zugang bleibt deshalb, wie er war.")
        case .failed(let message):
            message
        }
    }

    // Guideline 3.1.2: an auto-renewing subscription may not be offered without the length of the
    // period, the fact that it renews, how it is cancelled, and a reachable link to both the terms
    // and the privacy policy — on the screen that takes the money, not two taps away in Settings.
    // The price itself is deliberately not repeated here: it stands in the plan rows above, straight
    // out of the storefront, and a second copy of it is a second place to go stale.
    //
    // The copy rules still hold for these three lines: they state what the subscription is, they do not sell it.
    private var legalSection: some View {
        VStack(alignment: .leading, spacing: Layout.footerStack) {
            Text("Tuck Plus läuft einen Monat oder ein Jahr, je nach gewählter Periode, und verlängert sich zum selben Preis, solange es nicht spätestens 24 Stunden vor dem Ende der laufenden Periode gekündigt wird. Die Abrechnung läuft über deine Apple-ID. Kündigen geht jederzeit über „Abo verwalten“; die Kündigung gilt zum Ende der laufenden Periode.")
                .font(.subheadline.weight(.regular))
                .foregroundStyle(Color.tuckInk)

            // Two Links rather than two Buttons: the destination is a web page, so the system's own
            // handling (long-press preview, copy, open in the browser the user picked) comes for
            // free, and VoiceOver announces it as a link instead of as a button that does something
            // in the app. Both are built from URL(string:) without a force unwrap — a malformed
            // literal would silently drop a mandatory element, which is what
            // PaywallLegalTests.bothLegalDestinationsParseAsURLs is there to catch.
            // Both are custom-label Links rather than the shorthand for one reason —
            // the shorthand has no label to hang the hit area on, and outside the Link the frame
            // grows the layout box without growing the tappable region. A mandatory
            // element under 3.1.2 that a thumb misses is reachable in the same sense as one that
            // is not there.
            if let terms = URL(string: PaywallLegal.termsOfUse) {
                Link(destination: terms) {
                    Text("Nutzungsbedingungen")
                        .frame(minHeight: Layout.hitMin)
                        .contentShape(Rectangle())
                }
                    .font(.body.weight(.bold))
            }

            if let privacy = URL(string: PaywallLegal.privacyPolicy) {
                Link(destination: privacy) {
                    Text("Datenschutzerklärung")
                        .frame(minHeight: Layout.hitMin)
                        .contentShape(Rectangle())
                }
                    .font(.body.weight(.bold))
            }
        }
        .fontDesign(.rounded)
        .foregroundStyle(Color.tuckCharcoalGreen)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footerActions: some View {
        VStack(alignment: .leading, spacing: Layout.footerStack) {
            // The one disabled control in the app with no plate to dim, and on cream there is no
            // ink weaker than charcoal that still clears the contrast rule — so the state has nowhere to go but
            // into the copy, which is where the design system puts it anyway.
            Button {
                Task { await subscriptions.restore() }
            } label: {
                // The label keeps the same ternary it carried as a shorthand title, so
                // the working state still lives in the copy where the design system puts it.
                Text(subscriptions.isWorking ? "Käufe werden wiederhergestellt …" : "Käufe wiederherstellen")
                    .frame(minHeight: Layout.hitMin)
                    .contentShape(Rectangle())
            }
            .font(.body.weight(.bold))
            .fontDesign(.rounded)
            .foregroundStyle(Color.tuckCharcoalGreen)
            .disabledWithOwnAppearance(subscriptions.isWorking)

            Button { showManageSubscriptions = true } label: {
                Text("Abo verwalten")
                    .frame(minHeight: Layout.hitMin)
                    .contentShape(Rectangle())
            }
                .font(.body.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(Color.tuckCharcoalGreen)

            Text("Die Sperre selbst ist mit und ohne Abo gleich streng. Plus nimmt das Tageslimit weg, nie die Verzögerung und nie die Begründung.")
                .font(.subheadline.weight(.regular))
                .fontDesign(.rounded)
                .foregroundStyle(Color.tuckInk)

            // A sentence about the app, never about the user: no second person appears in it at all,
            // so there is nothing in it that could read as a verdict. No contrast framing
            // either — "unlike other apps …" would not be a sentence about Tuck but a judgement on
            // the user's habits, and it would let back in exactly the evaluation the app keeps out.
            Text("Tuck finanziert sich über das Abo und nicht über Aufmerksamkeit. Keine Werbung, keine Empfehlungen, nichts, was länger dauert als nötig.")
                .font(.subheadline.weight(.regular))
                .fontDesign(.rounded)
                .foregroundStyle(Color.tuckInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// The one surface the three trial moments get, and the copy that goes on it. It sits in this
// file rather than in a new one because the decision behind it lives in Shared/SubscriptionAccess
// and this is the app's subscription screen — the two screens that draw it are the two Plus
// boundaries, and neither owns the wording more than the other.
//
// The passive step, sage 0.25, not the dusty-rose notice card: nothing here needs
// attention, nothing here failed, and nothing on it can be tapped. A statement, in the place where
// the user already is — no alert, no badge, no full-screen interruption of a morning.
//
// No number, deliberately: the remaining days stand on the paywall's own status card and on the
// settings row, i.e. where somebody went to look them up. A count that reappears by itself is a
// countdown, and a countdown is the pressure the app rules out.
struct TrialNoticeBanner: View {
    let notice: TrialNotice

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.pair) {
            Text(title)
                .font(.body.weight(.bold))
            Text(detail)
                .font(.subheadline.weight(.regular))
                .foregroundStyle(Color.tuckInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .fontDesign(.rounded)
        .foregroundStyle(Color.tuckCharcoalGreen)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: Layout.radiusCard).fill(Color.tuckSage.opacity(0.25)))
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        switch notice {
        case .started: String(localized: "Deine Testphase läuft")
        case .nearingEnd: String(localized: "Die Testphase geht zu Ende")
        case .ended: String(localized: "Die Testphase ist vorbei")
        }
    }

    // Every one of the three says what stays, not what is lost: the alarm, the morning window and
    // the block are the app, and they are the same with and without Plus. What comes back is the
    // daily limit, named as a number the way every other unlock line in the app names it.
    private var detail: String {
        switch notice {
        case .started:
            String(localized: "Vierzehn Tage lang hat Tuck alles, was Plus hat: Freischaltungen ohne Tageslimit und das Bettzeit-Fenster am Abend.")
        case .nearingEnd:
            String(localized: "Danach gilt wieder \(UnlockQuotaStore.morning.freeUnlockMaximum) Freischaltung pro Tag. Wecker, Morgenfenster und Sperre bleiben, wie sie sind.")
        case .ended:
            String(localized: "Es gilt wieder \(UnlockQuotaStore.morning.freeUnlockMaximum) Freischaltung pro Tag. Wecker, Morgenfenster und Sperre bleiben, wie sie sind.")
        }
    }
}

#Preview {
    PaywallView()
        .environment(SubscriptionController())
}
