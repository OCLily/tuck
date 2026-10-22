import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Color {
    // The light half of the palette, unchanged: every literal here is the value docs/design/palette.md
    // derived and docs/design/design-system.md measured. Still named rather than inlined, but for one
    // surface now instead of two: the AlarmKit tint, which is encoded into `AlarmAttributes` — a
    // Codable ActivityKit type (`encode(to:)` in the real interface), and SwiftUI's Codable
    // conformance for Color writes resolved components, not a per-appearance table. The shield left
    // this list: its transport turned out to be NSKeyedArchiver, which does
    // carry the table.
    enum LightPalette {
        static let sage = Color(hex: 0xD8E2D3)
        static let cream = Color(hex: 0xF5EFE6)
        static let dustyRose = Color(hex: 0xE8C4B8)
        static let charcoalGreen = Color(hex: 0x6B7A6E)
        // Body ink. Charcoal green's own hue and saturation (132°, 0.123) at a
        // lower brightness (0.478 → 0.402) — a sibling of the brand colour, not a second one.
        static let ink = Color(hex: 0x5A665C)
        static let dustyBlue = Color(hex: 0x6C7A85)
        static let warmSand = Color(hex: 0x8A7A6B)
        static let softLavender = Color(hex: 0x7A6E85)
    }

    // The marken-side half, and the one palette in this file that is deliberately *not* reachable
    // from a product surface. Morgenrot is the store listing, the website and the
    // app icon's dawn — the places the app is seen before it is opened — and it is exactly the
    // saturated red the screens themselves are built to avoid at 6 a.m. BrandPaletteContainmentTests
    // pins that: it may appear in this file and nowhere else in the five compiled targets.
    //
    // It sits here, outside the UIKit gate below, for a mechanical reason rather than a tidiness
    // one: tools/render-app-icon.sh compiles this file into a plain macOS binary with no UIKit, and
    // the icon's dawn gradient reads both values as tokens. Inside the gate they would not exist
    // there at all.
    //
    // Measured, not asserted (BrandPaletteContrastTests): Night Ink on Morgenrot is 4,94:1 and
    // Morgenrot-Tief on Cream 5,36:1, so both carry small text; Cream on Morgenrot is 2,96:1 and
    // carries none. The figures first claimed for those three (5,0 / 5,2 / 2,9) do not recompute.
    enum BrandPalette {
        static let dawnRed = Color(hex: 0xE0674C)
        static let dawnRedDeep = Color(hex: 0xA84028)
    }

    // Everything from here to the end of the file is UIKit-only, because the appearance mechanism
    // *is* UIKit: there is no appearance-resolving Color without a UIColor provider behind it, so
    // off UIKit there is nothing to conditionally compile — the dark half simply does not exist.
    // The one non-UIKit build of this file is tools/render-shield-mascot.sh, which compiles it for
    // macOS and reads only LightPalette and init(hex:) above (see ShieldMascotIcon).
    #if canImport(UIKit)
    // "Mondlicht": its own character, not a mechanical inversion. A deep
    // green-black instead of a generic grey-on-black, a warm moonlight gold instead of the dusty
    // rose, and a dimmed sage-white instead of a stark one for text — this app is read at bedtime
    // and on waking, where a near-white body text is the one thing the eye cannot take.
    enum DarkPalette {
        static let nightInk = Color(hex: 0x17201B)
        static let midnightSage = Color(hex: 0x2A3830)
        static let moonGlow = Color(hex: 0xE4C9A0)
        static let moonSage = Color(hex: 0xCDD3C9)

        // The one dark value that is not the counterpart of a light token. Charcoal green is a text
        // colour in fifty-odd places and a *fill* in one — the filled primary button — and the two
        // roles cannot share a dark value: mapping the fill to Moon Sage would turn the button into
        // a near-white slab at 4 a.m., mapping it to Night Ink would make it the page. This is the
        // fill half: Night Ink lifted towards Moon Sage until the plate reads as raised (2.10:1
        // against the page) while Moon Sage still sits on it at 5.21:1.
        static let moonPlate = Color(hex: 0x47544C)

        // The three mascot inks, dark counterparts. Same hue family (206° / 29° / 271°) and the
        // same HSB saturation (0.19 / 0.23 / 0.17) as their light originals, but lifted rather than
        // darkened: on a Midnight Sage body the ink is the light half of the pair, exactly as it is
        // the dark half in light mode. What was derived and not copied is the brightness. The
        // design system's rule is equal *luminance*, not equal HSB brightness — at Moon Sage's own brightness the
        // three would have spread from 0.47 to 0.52 against its 0.64, three times the band the
        // light three hold. Each one's V is therefore solved for its hue until it lands on Moon
        // Sage's luminance, which puts all three inside the same 0.04 the light test already checks.
        // The mascot's own body in the dark. Originally the animal was drawn in
        // Midnight Sage - the same value the settings rows and the secondary plates are filled
        // with, so the one thing on the screen that is supposed to be alive was painted in the
        // app's furniture colour and separated from the page by 1,3558:1. This is that same dark
        // sage lifted rather than a new hue (142,5 deg / 0,216 / 0,290 against Midnight Sage's
        // 145,7 / 0,250 / 0,220), which takes the body to 1,7742:1 against Night Ink while all
        // four milestone inks still clear the non-text bar on it with room (5,98 to 6,19).
        static let moonBody = Color(hex: 0x3A4A40)
        static let moonDustyBlue = Color(hex: 0xBCD5E8)
        static let moonWarmSand = Color(hex: 0xE7CCB3)
        static let moonSoftLavender = Color(hex: 0xDBC6F0)
    }

    static let tuckSage = Color(light: LightPalette.sage, dark: DarkPalette.midnightSage)
    static let tuckCream = Color(light: LightPalette.cream, dark: DarkPalette.nightInk)
    static let tuckDustyRose = Color(light: LightPalette.dustyRose, dark: DarkPalette.moonGlow)
    static let tuckCharcoalGreen = Color(light: LightPalette.charcoalGreen, dark: DarkPalette.moonSage)

    // Running text, footers, captions — and nothing else. The role split the
    // buttons already made once, made a second time for the one that costs the app its hierarchy:
    // charcoal green tops out at 3,96:1 on cream, so the contrast rule has to buy every body line
    // back with the large-text exception, which is why the app's running text is set at weight 700
    // — heavier than the headline above it. Everything on one screen shouts at the same volume, and
    // that is what reads as a wall.
    //
    // The fix is a darker ink for that one role, not a darker palette: charcoal green is also the
    // app icon, the darkest stop of the sky gradient, the filled button's plate and the mascot's
    // outline, and none of those has a contrast problem to solve. Light is 5,26:1 on cream, and it
    // clears 4,5:1 on *every* text ground the app has, including the DustyRose hint card that has
    // always been the worst one (4,53:1) — so a body line may drop to weight 400 anywhere, without
    // a per-surface exemption. Dark is byte-identical to tuckCharcoalGreen's: Moon Sage on Night Ink
    // is already 10,93:1, the problem this token exists for does not exist there, and a second dark
    // value would be a difference with no reason behind it.
    static let tuckInk = Color(light: LightPalette.ink, dark: DarkPalette.moonSage)

    // The filled primary button, split out of tuckCharcoalGreen because that token is a text
    // colour everywhere else and a dark-mode swap has to send the two roles to different values
    // (see DarkPalette.moonPlate). Light is byte-identical to what the button carried before.
    static let tuckPrimaryPlate = Color(light: LightPalette.charcoalGreen, dark: DarkPalette.moonPlate)
    // Its label, split out of tuckCream for the mirrored reason: cream is the page background
    // *and* the label on the charcoal plate, and in dark those two are Night Ink and Moon
    // Sage. Left as one token the button would have drawn its label in its own page colour.
    static let tuckPrimaryPlateLabel = Color(light: LightPalette.cream, dark: DarkPalette.moonSage)
    // The disabled pair. A disabled control has to lose its
    // presence without losing its label, and in light that fixes the direction: charcoal green is
    // the darkest ink this palette has, so a filled plate that keeps a readable label can only get
    // *paler*, never darker — the cream label has to give way to the ink. Sage at full strength is
    // the point on that curve where the plate is still a plate (1,17:1 against the page) and the
    // ink still clears the large-text bar with reserve (3,40:1, the same ground the morning
    // screen's own buttons stand on). Dark mirrors it with the palette's own pair: the plate drops
    // from Moon Plate to Midnight Sage, which recedes towards the page (2,10:1 → 1,36:1) while the
    // label stays Moon Sage and *gains* contrast (5,21:1 → 8,06:1). Both values are existing
    // palette entries under a new role, exactly as `tuckPrimaryPlate` is charcoal green.
    static let tuckDisabledPlate = Color(light: LightPalette.sage, dark: DarkPalette.midnightSage)
    static let tuckDisabledPlateLabel = Color(light: LightPalette.charcoalGreen, dark: DarkPalette.moonSage)
    // The floating elevation. Its light value is the documented `.white` exception, which is
    // not a token and so could not follow the palette on its own; at 0.9 over a dark sky it would
    // have stayed a white slab with unreadable Moon Sage text on it (1.4:1).
    static let tuckFloatingPlate = Color(light: .white, dark: DarkPalette.moonPlate)
    // The 2.5-pt dot in the mascot's eye. It is not a colour but a position in the pair: the ink is
    // the pupil, the catchlight is the far pole from it, so it follows the ink instead of staying
    // put. Left as the plain `.white` it survived the palette swap as a white dot on a Moon Sage
    // pupil — 1,53:1, invisible, and the one place in the app where the dark mode drew nothing at
    // all. Light stays `.white` to the byte.
    static let tuckMascotCatchlight = Color(light: .white, dark: DarkPalette.nightInk)

    // The mascot's body, and only the mascot's body - every ear, the stem, the bud and the leaves
    // included, because a two-tone animal with sage ears on a darker body is not what "one body
    // colour" means. Light is `tuckSage` to the byte: the separate light body originally proposed
    // (`#C8D6C2`) stays rejected on the recorded numbers (docs/design/design-system.md), and nothing about
    // this token reopens it. Only the dark half is new.
    static let tuckMascotBody = Color(light: LightPalette.sage, dark: DarkPalette.moonBody)

    // Derived, not palette entries: docs/design/palette.md stays the single source for the base hex
    // values, and mixing keeps the contrast inside its "wenig Kontrast" band by construction.
    //
    // The dark side makes the same move with the role-mapped operands, with two calls worth naming.
    // Dawn shadow mixes towards Night Ink, not towards the text token: its role is the darkest stop
    // of the pre-dawn sky, and the light formula reaches that by mixing towards the darkest token
    // it has — which is charcoal green in light and Night Ink in dark. Taking the text token
    // literally would have lightened it and inverted the gradient. Day sky is the one tone whose
    // factor does not transfer: cream ⊕ white @0.35 is a four-point nudge because cream is already
    // near the top of the range, while Night Ink has the whole range above it — 0.35 towards Moon
    // Sage would have produced a mid grey. 0.12 off Midnight Sage keeps the role (the brightest
    // stop, where day arrives) at a luminance the dark palette can carry.
    static let tuckDawnShadow = Color(
        light: LightPalette.sage.mix(with: LightPalette.charcoalGreen, by: 0.30),
        dark: DarkPalette.midnightSage.mix(with: DarkPalette.nightInk, by: 0.30)
    )
    static let tuckDawnGlow = Color(
        light: LightPalette.dustyRose.mix(with: LightPalette.cream, by: 0.35),
        dark: DarkPalette.moonGlow.mix(with: DarkPalette.nightInk, by: 0.35)
    )
    static let tuckDaySky = Color(
        light: LightPalette.cream.mix(with: .white, by: 0.35),
        dark: DarkPalette.midnightSage.mix(with: DarkPalette.moonSage, by: 0.12)
    )

    static let tuckDustyBlue = Color(light: LightPalette.dustyBlue, dark: DarkPalette.moonDustyBlue)
    static let tuckWarmSand = Color(light: LightPalette.warmSand, dark: DarkPalette.moonWarmSand)
    static let tuckSoftLavender = Color(light: LightPalette.softLavender, dark: DarkPalette.moonSoftLavender)

    // SwiftUI has no appearance-conditional Color initializer of its own — Color.resolve(in:) reads
    // an environment, it cannot define one. UIColor's dynamic provider is the mechanism SwiftUI
    // does resolve against the trait collection it derives from the environment, so one token works
    // in .foregroundStyle, .background, .fill and .listRowBackground alike, including inside List
    // rows. An asset colorset resolves the same way but would move ten tokens out of this file,
    // which the design system makes the one place the palette may live.
    init(light: Color, dark: Color) {
        let lightColor = UIColor(light)
        let darkColor = UIColor(dark)
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? darkColor : lightColor })
    }
    #endif

    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

#if canImport(UIKit)
// The shield's four colours, named here rather than inside the extension so a test can reach them:
// TuckShield is a system extension the Simulator never launches, and the screen itself is
// rendered by another process, so a computed ratio against the values it actually passes is the
// only verification this screen can get.
//
// **They resolve per appearance**, which an earlier version had assumed
// impossible. Verified against the shipped frameworks rather than reasoned about: ManagedSettingsUI
// hands each colour to `NSKeyedArchiver.archivedData(withRootObject:requiringSecureCoding: true)`
// and ScreenTimeUI's `STBlockingViewController` reads it back with
// `unarchivedObjectOfClass:UIColor fromData:` and assigns it straight to `setBackgroundColor:` /
// `setTextColor:` / `setBaseForegroundColor:` — with no `resolvedColor(with:)` anywhere on that
// path. A dynamic UIColor archives as a baked per-trait table, not as a resolved value, so it
// arrives in the host process still dynamic and is re-resolved there by UIKit on every trait
// change. The data source never has to be called again; that is why this works without any hook
// for one. `ShieldPaletteArchiveTests` pins the round trip with the exact call pair those two
// frameworks make. The icon does *not* travel this way — it is flattened to PNG bytes in this
// process — which is why it stays a single appearance-neutral drawing.
//
// Why the primary button carries its own label token instead of `tuckPrimaryPlateLabel`:
// everywhere else in the app a weak ratio is paid for with the large-text exception of the contrast rule —
// >=14 pt at weight 700, where the bar drops to 3:1. Here that is not available.
// `ShieldConfiguration.Label` has no font parameter at all; iOS picks the size and the weight.
// This label therefore has to clear AA's 4.5:1 for small text on its own. In light the
// house pairing is cream on charcoal at 3,96:1 and misses, so the button keeps white
// (4,53:1) — the one white label left in the app. In dark the same question was asked again and
// answered the other way: Moon Sage on Moon Plate is 5,21:1 and clears the bar unaided, so the
// exception is not carried over. A near-white label would have reached 7,95:1 and been the wrong
// kind of right — the palette chose Moon Sage over a near-white on purpose, and dark mode has the room
// light mode did not.
enum ShieldPalette {
    static let background = Color.tuckCream
    static let text = Color.tuckCharcoalGreen
    static let primaryButtonBackground = Color.tuckPrimaryPlate
    static let primaryButtonLabel = Color(light: .white, dark: Color.DarkPalette.moonSage)
}
#endif
