import FamilyControls
import Foundation
import Testing
@testable import Tuck

// Screen composition is a review matter, not a testable one — its targets are ratios on a
// rendered screen and this project has no snapshot layer. What can be pinned is the wiring the
// composition hangs off: the way back exists, it sits outside the scroll layer, and the anchor the
// step animation depends on survived the rework.
struct OnboardingCompositionTests {
    private func flowSource() throws -> [String] {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Tuck/OnboardingFlowView.swift")
        return try String(contentsOf: source, encoding: .utf8).components(separatedBy: "\n")
    }

    @Test func everyStepButTheFirstHasOneBehindIt() {
        #expect(OnboardingStep.welcome.previous == nil)
        for step in OnboardingStep.allCases.dropFirst() {
            let previous = step.previous
            #expect(previous != nil)
            #expect(previous?.rawValue == step.rawValue - 1)
        }
    }

    @Test func theHeaderSitsOutsideTheScrollLayer() throws {
        let lines = try flowSource()
        let header = try #require(lines.firstIndex { $0.contains("private var header: some View") })
        let scrollWrapper = try #require(lines.firstIndex { $0.contains("ScrollViewReader { proxy in") })
        // The body composes header and steps as siblings, so the header cannot be inside the
        // ScrollView the steps build — at accessibility text sizes it would scroll out of reach.
        let bodyStart = try #require(lines.firstIndex { $0.contains("var body: some View") })
        let headerUse = try #require(lines[bodyStart...].firstIndex { $0.trimmingCharacters(in: .whitespaces) == "header" })
        #expect(headerUse < scrollWrapper)
        #expect(header > bodyStart)
    }

    @Test func theWayBackIsAFullHitArea() throws {
        let lines = try flowSource()
        let chevron = try #require(lines.firstIndex { $0.contains("chevron.left") })
        let frame = lines[chevron...].prefix(6)
        #expect(frame.contains { $0.contains("width: Self.headerHeight, height: Self.headerHeight") })
        #expect(frame.contains { $0.contains(".contentShape(Rectangle())") })
        #expect(lines.contains { $0.contains("private static let headerHeight: CGFloat = 44") })
    }

    private func code() throws -> [String] {
        try flowSource().map { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") ? "" : $0 }
    }

    // The line range of a `private var <name>: some View` property, from its declaration to the
    // line before the next one. Enough structure for the two checks below; the file has no
    // top-level declaration between these properties.
    private func propertyRange(_ name: String, in lines: [String]) throws -> Range<Int> {
        let start = try #require(lines.firstIndex { $0.contains("private var \(name): some View") })
        let next = lines[(start + 1)...].firstIndex { $0.contains("private var ") && $0.contains(": some View") }
        return start..<(next ?? lines.count)
    }

    // The offset reset hangs on a constant anchor. `.id(step)` would reset it too and throw
    // away the ScrollView identity the step animation cross-fades across.
    @Test func theConstantScrollAnchorSurvivedTheRecomposition() throws {
        let lines = try flowSource()
        #expect(lines.contains { $0.contains("proxy.scrollTo(Self.topAnchor, anchor: .top)") })
        #expect(lines.contains { $0.contains(".id(Self.topAnchor)") })
        let code = lines.filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
        #expect(!code.contains { $0.contains(".id(step)") })
    }

    // The brace-balanced body of the `step` setter. The block holds no string literal and no
    // comment survives `code()`, so counting braces is enough here — unlike HitTargetTests, which
    // scans whole view files and needs a real scanner.
    private func setterRange(in lines: [String]) throws -> ClosedRange<Int> {
        let start = try #require(lines.firstIndex { $0.contains("nonmutating set") })
        var depth = 0
        for index in lines.indices.dropFirst(start) {
            depth += lines[index].filter { $0 == "{" }.count
            depth -= lines[index].filter { $0 == "}" }.count
            if depth == 0 { return start...index }
        }
        Issue.record("the step setter's block never closes")
        return start...start
    }

    // "Richtungsgebend": the direction is decided in the `step` setter, and it has to be read
    // off the current step *before* the assignment overwrites the value behind it. Reversed, the
    // comparison would be `newValue.rawValue >= newValue.rawValue` — always true, always forward,
    // and nothing on screen would say so: the back button would slide in from the same side as
    // "Weiter".
    //
    // And it reads `step`, not `storedStep`: the raw int is the one value here that can be out of
    // range, which is why `resuming(from:)` exists. A stored 99 renders as `.welcome`, so the
    // first "Los geht's" is 1 >= 0, forward; against the raw int it was 1 >= 99, false, and the
    // very first tap of the flow travelled backwards. That is the whole of the control group for
    // this line — there is no live repro to build, because the two expressions differ only on
    // values the getter never lets the rest of the view see.
    @Test func theDirectionIsDecidedBeforeTheStepIsOverwritten() throws {
        let lines = try code()
        let body = Array(lines[try setterRange(in: lines)])

        let direction = try #require(body.firstIndex { $0.contains("movingForward =") },
                                     "the step setter decides no direction at all")
        let overwrite = try #require(body.firstIndex { $0.contains("storedStep = newValue.rawValue") })
        #expect(direction < overwrite,
                "the direction is computed after storedStep was already overwritten")
        #expect(body[direction].contains("newValue.rawValue >= step.rawValue"),
                "the direction compares something other than the incoming step against the current one")
        #expect(!body[direction].contains("storedStep"),
                "the direction reads the raw stored int past `resuming(from:)` — an out-of-range value points the first tap the wrong way")
    }

    // Every "Weiter" and the one back button go through `step =`, so the setter above covers them
    // all. `storedStep` is written directly in exactly one place — the last step, winding the flow
    // back as it is left — and that one has no direction to get wrong because the view goes away.
    @Test func nothingButTheSetterAndTheExitWritesTheStoredStep() throws {
        let lines = try code()
        let setter = try setterRange(in: lines)
        let doneRange = try propertyRange("done", in: lines)
        for index in lines.indices where lines[index].contains("storedStep =")
            && !lines[index].contains("private var storedStep") {
            #expect(setter.contains(index) || doneRange.contains(index),
                    "line \(index + 1) writes storedStep past the setter — its step change has no direction")
        }
    }

    // The parenthesis-balanced text of the `.transition(…)` call in `content`, as one string.
    // Like `setterRange` this may count characters instead of parsing: `code()` has already blanked
    // the comments, and the call holds no string literal. Counted rather than taken as a fixed
    // number of lines, so that rewrapping the argument list is not a red test.
    private func transitionCall(in lines: [String]) throws -> String {
        let contentRange = try propertyRange("content", in: lines)
        let start = try #require(lines[contentRange].firstIndex { $0.contains(".transition(") },
                                 "the switched column carries no transition")
        var depth = 0
        for index in lines.indices.dropFirst(start) {
            depth += lines[index].filter { $0 == "(" }.count
            depth -= lines[index].filter { $0 == ")" }.count
            if depth == 0 { return lines[start...index].joined(separator: " ") }
        }
        Issue.record("the transition call never closes")
        return ""
    }

    // The travel itself: the arriving step comes in from the trailing edge going forward and from
    // the leading edge going back, combined with opacity — a bare slide reads mechanical where this
    // flow is meant to read quiet. Under Reduce Motion what is left is the `.opacity` branch, which
    // nothing interpolates: `.animation(nil, value: step)` in `body` makes the step change a hard
    // cut — the fade is the shape of the fallback, not something a user sees.
    //
    // The removal stays direction-free, and the test pins that rather than leaving it to taste: a
    // removal transition is resolved from the view that is leaving, i.e. from its previous render,
    // where `movingForward` still carries the direction of the *last* change. A `.move` there sends
    // the old screen the wrong way on every change of direction — caught on a 60-fps capture of the
    // first build (frames b153–b160 of the back tap). This is the one place where the obvious,
    // symmetric-looking code is wrong, so it gets a test and not just a comment.
    //
    // Checked as pieces, not as one concatenated line: an exact source string makes a reformat
    // red and says nothing about what the transition does — the same brittleness an earlier check
    // had to be taken off.
    @Test func theStepTransitionIsDirectionalAndReversible() throws {
        let call = try transitionCall(in: try code())
        let insertionKey = try #require(call.range(of: "insertion:"), "the transition names no insertion")
        let removalKey = try #require(call.range(of: "removal:"), "the transition names no removal")
        #expect(insertionKey.upperBound < removalKey.lowerBound)

        let gate = String(call[..<insertionKey.lowerBound])
        #expect(gate.contains("reduceMotion"), "the transition is not gated on Reduce Motion")
        #expect(gate.contains(".opacity"), "Reduce Motion is left with something other than the fade-only branch")
        #expect(!gate.contains(".move"), "the Reduce Motion branch still travels")
        #expect(gate.contains(".asymmetric"), "one symmetric transition cannot point two ways")

        let insertion = String(call[insertionKey.upperBound..<removalKey.lowerBound])
        #expect(insertion.contains(".move"), "the arriving step does not travel")
        #expect(insertion.contains("movingForward"), "the arriving step ignores the direction it was given")
        #expect(insertion.contains(".trailing") && insertion.contains(".leading"),
                "the arriving step has only one edge to come from")
        #expect(insertion.contains(".opacity"), "a bare slide reads mechanical")

        let removal = String(call[removalKey.upperBound...])
        #expect(removal.contains(".opacity"))
        #expect(!removal.contains(".move"),
                "a directional removal is read off the outgoing view's stale direction — see the comment above")
        #expect(!removal.contains("movingForward"),
                "the removal reads a direction that belongs to the previous step change")
    }

    // No step centres its content between a pair of Spacers any more. A single Spacer
    // above the button stays allowed, so what is checked is the leading one.
    @Test func noStepOpensWithASpacer() throws {
        let lines = try flowSource()
        let columns = lines.indices.filter { lines[$0].contains("VStack(spacing: Layout.section) {") }
        // The guard this loop went without at first: a matcher over a spelling that no longer
        // occurs iterates zero times and passes in silence. The step columns are six, and a change
        // that leaves none of them findable is a broken test, not a clean screen.
        #expect(!columns.isEmpty,
                "no step column matches any more — this test iterates over nothing and checks nothing")
        for index in columns {
            #expect(lines[index + 1].trimmingCharacters(in: .whitespaces) != "Spacer()",
                    "step column at line \(index + 1) still opens with a Spacer")
        }
    }

    // The flow's own step change is a rhythm of taps, not a report — the override keeps 0.6 s.
    // Reduce Motion still turns it off entirely rather than shortening it.
    @Test func theStepTransitionIsAQuarterSecondAndStillGated() throws {
        let lines = try flowSource()
        let animation = try #require(lines.first { $0.contains(".animation(reduceMotion") })
        // The call site names the duration; the 0.25 itself is pinned once, at the
        // definition site, by MotionTokenTests.everyNamedDurationCarriesTheValueSixOneDecided.
        #expect(animation.contains("nil : .easeInOut(duration: Motion.stepOnboarding)"))
        #expect(Motion.stepOnboarding == 0.25)
    }

    // The flow ends on the tone the morning sky ends on, deep enough to be seen.
    @Test func theFlowAnnouncesTheMorningSkyItLeadsTo() throws {
        let lines = try flowSource()
        #expect(lines.contains { $0.contains("Color.tuckCream, Color.tuckSage.opacity(0.6)") })
    }

    @Test func aSelectionIsCountedTheSameWayBeforeAndAfterItIsStored() {
        #expect(FamilyActivitySelectionStore.count(of: FamilyActivitySelection()) == 0)
    }

    // The suggestion line is built from the picker's own category labels, so it cannot point at a
    // row that is not in the list.
    @Test func theSuggestionLineNamesExactlyThePrimaryCategories() {
        #expect(BlocklistSuggestions.primaryLine == "Vorschlag: Soziale Netze und Unterhaltung.")
        for suggestion in BlocklistSuggestions.primary {
            #expect(BlocklistSuggestions.primaryLine.contains(suggestion.label))
        }
    }

    // The `.modifier(...)` lines directly under a call, stopping at the first line that is neither
    // one of those nor a comment — the next sibling view in the VStack. Comment lines extend the
    // window (the "why" behind a modifier must not push a later modifier out of it) but are
    // dropped from the result: prose explaining what a modifier deliberately omits would otherwise
    // read as the modifier itself.
    private func modifierChain(after index: Int, in lines: ArraySlice<String>) -> [String] {
        var end = index + 1
        while end < lines.endIndex {
            let trimmed = lines[end].trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix(".") || trimmed.hasPrefix("//") else { break }
            end += 1
        }
        return lines[(index + 1)..<end].filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
    }

    // MascotView wires its own .onTapGesture regardless of what the host passes for onTap — the
    // rig on welcome/explain/done is tappable whether or not a caller gives it meaning. Without an
    // accessibility element of its own it either announces nothing or exposes its unlabeled inner
    // shapes one by one; VoiceOver users on these three screens hit whichever of the two happened
    // to be true, silently.
    @Test func everyOnboardingMascotHasItsOwnAccessibilityElement() throws {
        let lines = try flowSource()
        for step in ["welcome", "explain", "done"] {
            let range = try propertyRange(step, in: lines)
            let mascot = try #require(
                lines[range].firstIndex { $0.contains("MascotView(stage:") },
                "no MascotView( call in \(step)"
            )
            let following = modifierChain(after: mascot, in: lines[range])
            #expect(
                following.contains { $0.contains(".accessibilityElement(children: .ignore)") },
                "\(step): MascotView is missing .accessibilityElement(children: .ignore)"
            )
            #expect(
                following.contains { $0.contains(".accessibilityLabel(") },
                "\(step): MascotView is missing .accessibilityLabel("
            )
        }
    }

    // The tap on these three screens is cosmetic (a no-op onTap, no bubble) — unlike
    // GutenMorgenView's mascot, it drives no reply a VoiceOver user could act on. Claiming
    // .isButton here would promise an action that isn't there.
    @Test func theOnboardingMascotClaimsNoButtonTrait() throws {
        let lines = try flowSource()
        for step in ["welcome", "explain", "done"] {
            let range = try propertyRange(step, in: lines)
            let mascot = try #require(lines[range].firstIndex { $0.contains("MascotView(stage:") })
            let following = modifierChain(after: mascot, in: lines[range])
            #expect(!following.contains { $0.contains(".accessibilityAddTraits(.isButton)") })
            #expect(!following.contains { $0.contains(".accessibilityAction") })
        }
    }
}
