import SwiftUI

enum MorningSky {
    static func progress(now: Date,
                         alarm: WakeAlarmStore.ScheduledAlarm?,
                         calendar: Calendar = .current) -> Double {
        if let alarm,
           let anchor = MorningBlockWindow.mostRecentStart(of: alarm.blockWindowStart,
                                                           atOrBefore: now,
                                                           calendar: calendar) {
            let startSecond = secondOfDay(alarm.blockWindowStart)
            let endSecond = secondOfDay(alarm.blockWindowEnd)
            let length = Double((endSecond - startSecond + 86_400) % 86_400)
            guard length > 0 else { return 1 }
            return min(max(now.timeIntervalSince(anchor) / length, 0), 1)
        }

        let components = calendar.dateComponents([.hour, .minute, .second], from: now)
        let secondOfDay = Double((components.hour ?? 0) * 3600 + (components.minute ?? 0) * 60 + (components.second ?? 0))
        return min(max((secondOfDay - 18_000) / 14_400, 0), 1)
    }

    // Exposed separately from gradient(progress:) because LinearGradient hides its stops: the
    // rising glow band is only correct while these stay monotonically increasing.
    static func stopLocations(progress p: Double) -> [Double] {
        [0, 0.80 - 0.26 * p, 0.92 - 0.20 * p, 1.00]
    }

    // Exposed for the same reason `stopLocations` is, and it took longer to notice: the COLOURS were
    // the half no test could read back out of a LinearGradient, so both sky contrast tests measured a
    // hand-copied second version of these four expressions that lived in the test target
    // (`Appearance.skyStops`). A change here left all three pinned numbers — 2,44 / 4,16 / 3,36 —
    // green while the shipped sky moved. Verified rather than assumed: with stop 1 detuned to
    // `by: p * 0.5` and the tests still reading the copy, 673 tests passed; with the same detune and
    // the tests reading this function, the pinned 4,16 went red.
    static func stops(progress p: Double) -> [Color] {
        [
            .tuckDawnShadow.mix(with: .tuckDaySky, by: p),
            .tuckDaySky.mix(with: .tuckDawnGlow, by: 0.35 + 0.25 * p),
            .tuckDawnGlow.mix(with: .tuckCream, by: 0.30),
            .tuckCream.mix(with: .tuckSage, by: 0.45 - 0.15 * p)
        ]
    }

    static func gradient(progress p: Double) -> LinearGradient {
        let locations = stopLocations(progress: p)
        let colors = stops(progress: p)
        return LinearGradient(
            stops: zip(colors, locations).map { .init(color: $0, location: $1) },
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private static func secondOfDay(_ components: DateComponents) -> Int {
        (components.hour ?? 0) * 3600 + (components.minute ?? 0) * 60 + (components.second ?? 0)
    }
}

private struct LightSource: View {
    let progress: Double
    let breath: Double
    let season: Season

    // The reason it sits HERE and not in `stops`: the pinned sky span (2,44 / 4,16 / 3,36) is
    // measured against the gradient, and a season that is not an input of `stops` cannot move any of
    // the three by construction. The honest cost, which the design system now records: that pin measures
    // the gradient, not the effective ground — this radial lies over it and enters no contrast
    // number of the app. That gap exists today; summer is the first thing to use it deliberately,
    // which is why it was measured separately before this was built.
    private var summerWarmth: Double { season == .summer ? 0.05 : 0 }

    var body: some View {
        RadialGradient(colors: [Color.tuckDawnGlow.opacity(0.55), .clear],
                       center: .center, startRadius: 6, endRadius: 150 + 20 * summerWarmth / 0.05)
            .frame(width: 300, height: 300)
            .blur(radius: 24)
            .offset(y: 96 - 118 * progress)
            .opacity(0.30 + 0.28 * progress + 0.035 * breath + summerWarmth)
            .allowsHitTesting(false)
    }
}

struct MorningAmbience: View {
    let progress: Double
    let mascotCenterY: CGFloat
    // Reaches the light, never the creature: SeasonalAccent's first rule is about the animal; this is the sky.
    var season: Season = .autumn

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.animation(minimumInterval: Motion.ambientTick,
                                paused: reduceMotion || scenePhase != .active)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            let breath = sin(t * 2 * .pi / Motion.breathCycle)

            GeometryReader { geometry in
                ZStack {
                    LightSource(progress: progress, breath: breath, season: season)
                        .position(x: geometry.size.width / 2, y: mascotCenterY)

                    Canvas { context, size in
                        for i in 0..<24 {
                            let fi = Double(i)
                            let sx = (fi * 0.6180339887).truncatingRemainder(dividingBy: 1)
                            let speed = 0.010 + 0.008 * (fi * 0.7548).truncatingRemainder(dividingBy: 1)
                            let y = 1 - (sx * 0.37 + t * speed).truncatingRemainder(dividingBy: 1)
                            let x = sx + 0.045 * sin(t * (0.09 + 0.05 * sx) + fi)
                            let r = 1.4 + 2.0 * (fi * 0.3183).truncatingRemainder(dividingBy: 1)
                            var a = 0.10 + 0.16 * (fi * 0.5137).truncatingRemainder(dividingBy: 1)
                            let edge = min(1, min(y, 1 - y) / 0.12)
                            let d = hypot(x - 0.5, y - 0.62)
                            let column = 0.45 + 0.55 * max(0, 1 - d / 0.45)
                            a *= edge * column * (1 + 0.08 * breath)
                            let rect = CGRect(x: x * size.width - r, y: y * size.height - r,
                                              width: 2 * r, height: 2 * r)
                            context.fill(Path(ellipseIn: rect),
                                         with: .color(Color.tuckDaySky.opacity(min(a, 0.26))))
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
