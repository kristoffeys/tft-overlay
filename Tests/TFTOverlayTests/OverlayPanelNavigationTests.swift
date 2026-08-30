@testable import TFTOverlay
import TFTUI
import XCTest

/// The panel tab bar's contract with `OverlayAppState`.
///
/// The overlay used to expose its four panels only through blind ⌥C cycling —
/// nothing on screen said which panel you were on or that others existed. The
/// tab bar fixes that, and these pin down the model side of it: which panels
/// are tabs, which tab lights up for a drill-down, and that the hotkey and the
/// bar agree on what "next panel" means.
///
/// Since #82 the tab set depends on the mode, so every case here says which
/// mode it is talking about. `OverlayModeTests` covers the transitions between
/// them.
@MainActor
final class OverlayPanelNavigationTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        suiteName = "OverlayPanelNavigationTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    /// Isolated from the developer's own pins — reading `.standard` made every
    /// case here depend on whatever was last pinned in the real app.
    private func state() -> OverlayAppState {
        OverlayAppState(pinnedComps: PinnedCompsStore(defaults: defaults))
    }

    /// Focuses the state on its first comp and returns that comp.
    private func focused(_ state: OverlayAppState) throws -> Comp {
        let comp = try XCTUnwrap(state.comps.first, "Bundled comp fixtures failed to load")
        state.commit(to: comp)
        XCTAssertEqual(state.mode, .focus)
        return comp
    }

    // MARK: - Which panels are tabs

    func testDetailIsADrillDownNotATab() {
        XCTAssertFalse(OverlayAppState.Panel.compDetail.isDestination)
        for mode in [OverlayAppState.Mode.browse, .focus] {
            XCTAssertFalse(OverlayAppState.Panel.destinations(in: mode).contains(.compDetail))
        }
    }

    /// Each mode's tab set, leading with the panel that answers the mode's
    /// question. Focus deliberately does *not* offer the comps list as a
    /// fourth tab: leaving Focus is the bar's trailing accessory, so the
    /// browse chrome stays behind an explicit decision.
    ///
    /// Browse gained Openers and My Champions in #85/#86 — both answer "what
    /// should I play?", so both live here and neither is in Focus.
    func testEachModeOffersItsOwnTabs() {
        XCTAssertEqual(
            OverlayAppState.Panel.destinations(in: .browse),
            [.compsList, .openers, .myChampions, .itemCheatSheet, .reference]
        )
        XCTAssertEqual(
            OverlayAppState.Panel.destinations(in: .focus),
            [.focusBuild, .itemCheatSheet, .reference]
        )
    }

    /// Focus stays at exactly three cycled tabs plus its Browse accessory.
    ///
    /// Pinned separately from the list above because it is the invariant, not
    /// the arrangement: Focus is "one build, nothing else on screen", and every
    /// new Browse panel is a chance to widen Focus by accident. The tab bar's
    /// trailing accessory is not counted here — by design it is not a tab and
    /// cycling never reaches it.
    func testFocusKeepsExactlyThreeTabsNoMatterWhatBrowseGains() {
        let focus = OverlayAppState.Panel.destinations(in: .focus)
        XCTAssertEqual(focus.count, 3, "Focus offers \(focus.map(\.title))")
        for panel in OverlayAppState.Panel.allCases where panel.isBrowseOnly {
            XCTAssertFalse(
                focus.contains(panel),
                "\(panel.title) is a Browse surface and must not be a Focus tab"
            )
        }
    }

    /// The two new panels are top-level destinations, not drill-downs: you
    /// pick them cold from the bar, and both open on something useful with no
    /// prior selection (Openers ranks the corpus; My Champions opens on the
    /// picker).
    func testTheNewPanelsAreTabsAndAreBrowseOnly() {
        for panel in [OverlayAppState.Panel.openers, .myChampions] {
            XCTAssertTrue(panel.isDestination)
            XCTAssertTrue(panel.isBrowseOnly)
            XCTAssertTrue(OverlayAppState.Panel.destinations(in: .browse).contains(panel))
        }
        XCTAssertFalse(
            OverlayAppState.Panel.compsList.isBrowseOnly,
            "The list leads Browse, it is not browse-only chrome"
        )
    }

    func testTheCommittedBuildIsNotATabInBrowseMode() {
        XCTAssertFalse(OverlayAppState.Panel.destinations(in: .browse).contains(.focusBuild))
        XCTAssertFalse(OverlayAppState.Panel.destinations(in: .focus).contains(.compsList))
    }

    /// Every panel maps to exactly one tab *of the mode it is shown in*, and
    /// every tab maps to itself — otherwise the bar can end up with nothing
    /// highlighted.
    func testEveryPanelHighlightsATabInEveryMode() {
        for mode in [OverlayAppState.Mode.browse, .focus] {
            let tabs = OverlayAppState.Panel.destinations(in: mode)
            for panel in OverlayAppState.Panel.allCases {
                XCTAssertTrue(
                    tabs.contains(panel.destination(in: mode)),
                    "\(panel.title) highlights \(panel.destination(in: mode).title), not a tab in \(mode)"
                )
            }
        }
        XCTAssertEqual(OverlayAppState.Panel.compDetail.destination(in: .browse), .compsList)
        XCTAssertEqual(OverlayAppState.Panel.compDetail.destination(in: .focus), .focusBuild)
        XCTAssertEqual(OverlayAppState.Panel.reference.destination(in: .focus), .reference)
    }

    func testEveryTabHasANonEmptyTitle() {
        for mode in [OverlayAppState.Mode.browse, .focus] {
            for panel in OverlayAppState.Panel.destinations(in: mode) {
                XCTAssertFalse(panel.title.isEmpty)
            }
        }
    }

    // MARK: - Cycling

    func testCyclingWalksTheBrowseTabsInOrder() {
        let state = state()
        XCTAssertEqual(state.panel, .compsList)

        state.cycleForward()
        XCTAssertEqual(state.panel, .openers)
        state.cycleForward()
        XCTAssertEqual(state.panel, .myChampions)
        state.cycleForward()
        XCTAssertEqual(state.panel, .itemCheatSheet)
        state.cycleForward()
        XCTAssertEqual(state.panel, .reference)
        state.cycleForward()
        XCTAssertEqual(state.panel, .compsList, "Cycling should wrap")

        state.cycleBackward()
        XCTAssertEqual(state.panel, .reference)
    }

    /// Cycling onto a Browse-only panel while a build is pinned has to *stay*
    /// coherent: `mode` is derived, so a panel that only exists in Browse must
    /// bring Browse with it rather than leaving the bar showing Focus's three
    /// tabs with an Openers panel underneath.
    func testCyclingOntoABrowseOnlyPanelKeepsTheModeAgreeingWithIt() throws {
        let state = state()
        _ = try focused(state)
        state.browse()
        XCTAssertEqual(state.mode, .browse)

        state.cycleForward()
        XCTAssertEqual(state.panel, .openers)
        XCTAssertEqual(state.mode, .browse, "Openers is a Browse panel, so the mode has to be Browse")
        XCTAssertNotNil(state.committedBuild, "Browsing does not throw the build away")
    }

    /// The invariant #82 has to preserve: ⌥C walks whatever the bar is
    /// showing. In Focus that means it stays inside Focus — if cycling could
    /// step onto the comps list it would drop the player out of their build
    /// by accident, and the build would then be unreachable by hotkey.
    func testCyclingWalksTheFocusTabsAndStaysInFocus() throws {
        let state = state()
        _ = try focused(state)
        XCTAssertEqual(state.panel, .focusBuild)

        state.cycleForward()
        XCTAssertEqual(state.panel, .itemCheatSheet)
        XCTAssertEqual(state.mode, .focus)
        state.cycleForward()
        XCTAssertEqual(state.panel, .reference)
        XCTAssertEqual(state.mode, .focus)
        state.cycleForward()
        XCTAssertEqual(state.panel, .focusBuild, "Cycling should wrap back onto the build")
        XCTAssertEqual(state.mode, .focus)

        state.cycleBackward()
        XCTAssertEqual(state.panel, .reference)
    }

    /// ⌥C used to be able to land on the detail panel, which shows
    /// "No comp selected" whenever nothing has been picked — a dead end you
    /// could reach by accident.
    func testCyclingNeverLandsOnTheDrillDownInEitherMode() throws {
        for pinFirst in [false, true] {
            let state = state()
            if pinFirst {
                _ = try focused(state)
            }
            for _ in 0 ..< (OverlayAppState.Panel.allCases.count * 3) {
                state.cycleForward()
                XCTAssertNotEqual(state.panel, .compDetail)
            }
            for _ in 0 ..< (OverlayAppState.Panel.allCases.count * 3) {
                state.cycleBackward()
                XCTAssertNotEqual(state.panel, .compDetail)
            }
        }
    }

    /// Cycling out of a drill-down continues from the section it belongs to.
    func testCyclingFromTheDrillDownResumesFromItsSection() throws {
        let state = state()
        let comp = try XCTUnwrap(state.comps.first, "Bundled comp fixtures failed to load")

        state.select(comp)
        XCTAssertEqual(state.panel, .compDetail)

        state.cycleForward()
        XCTAssertEqual(state.panel, .openers, "Detail belongs to Comps, so forward is the tab after Comps")
    }

    /// Cycling only ever lands on a panel the bar is currently offering — the
    /// single invariant that keeps the hotkey and the bar from disagreeing.
    func testCyclingOnlyEverLandsOnACurrentTab() throws {
        for pinFirst in [false, true] {
            let state = state()
            if pinFirst {
                _ = try focused(state)
            }
            for _ in 0 ..< 12 {
                state.cycleForward()
                XCTAssertTrue(
                    OverlayAppState.Panel.destinations(in: state.mode).contains(state.panel),
                    "\(state.panel.title) is not a tab in \(state.mode)"
                )
            }
        }
    }

    // MARK: - Back from a drill-down (#91)

    /// The Browse comps list drilling into a comp and backing out lands back
    /// on the list — the path this already worked for.
    func testBackFromDetailEnteredViaCompsListReturnsToCompsList() throws {
        let state = state()
        let comp = try XCTUnwrap(state.comps.first, "Bundled comp fixtures failed to load")

        state.select(comp)
        XCTAssertEqual(state.panel, .compDetail)

        state.goBack()
        XCTAssertEqual(state.panel, .compsList)
        XCTAssertEqual(state.mode, .browse)
    }

    /// Drilling into a comp from Reference while Browsing backs out to
    /// Reference, not the list.
    func testBackFromDetailEnteredViaReferenceInBrowseReturnsToReference() throws {
        let state = state()
        let comp = try XCTUnwrap(state.comps.first, "Bundled comp fixtures failed to load")

        state.show(.reference)
        state.select(comp)
        XCTAssertEqual(state.panel, .compDetail)

        state.goBack()
        XCTAssertEqual(state.panel, .reference)
        XCTAssertEqual(state.mode, .browse)
    }

    /// The reported bug: Reference → champion → comp → Back used to land on
    /// the committed build instead of back on Reference. Back must return
    /// where the drill-down was entered from and must not cross out of Focus.
    func testBackFromDetailEnteredViaReferenceInFocusReturnsToReferenceNotTheBuild() throws {
        let state = state()
        _ = try focused(state)
        XCTAssertEqual(state.panel, .focusBuild)

        state.show(.reference)
        let anotherComp = try XCTUnwrap(state.comps.dropFirst().first ?? state.comps.first)
        state.select(anotherComp)
        XCTAssertEqual(state.panel, .compDetail)

        state.goBack()
        XCTAssertEqual(state.panel, .reference, "Back should return to Reference, not the committed build")
        XCTAssertEqual(state.mode, .focus, "Back must not drop the player out of Focus")
    }

    /// Openers drills into a comp, so Back has to return to Openers — not to
    /// the comps list, which is a different panel the player was not on.
    func testBackFromDetailEnteredViaOpenersReturnsToOpeners() throws {
        let state = state()
        let comp = try XCTUnwrap(state.comps.first, "Bundled comp fixtures failed to load")

        state.show(.openers)
        state.select(comp)
        XCTAssertEqual(state.panel, .compDetail)

        state.goBack()
        XCTAssertEqual(state.panel, .openers)
        XCTAssertEqual(state.mode, .browse)
    }

    /// Same for My Champions. Its suggestions commit rather than drill, but the
    /// panel is a destination and `select` can be reached from it, so the
    /// origin still has to be recorded.
    func testBackFromDetailEnteredViaMyChampionsReturnsToMyChampions() throws {
        let state = state()
        let comp = try XCTUnwrap(state.comps.first, "Bundled comp fixtures failed to load")

        state.show(.myChampions)
        state.select(comp)
        XCTAssertEqual(state.panel, .compDetail)

        state.goBack()
        XCTAssertEqual(state.panel, .myChampions)
        XCTAssertEqual(state.mode, .browse)
    }

    /// Back returns to where the drill-down was entered from, for *every*
    /// destination — the #91 guarantee, restated over the widened tab set so a
    /// future panel cannot be added without an origin.
    func testBackReturnsToEveryDestinationItCanBeEnteredFrom() throws {
        for origin in OverlayAppState.Panel.destinations(in: .browse) {
            let state = state()
            let comp = try XCTUnwrap(state.comps.first, "Bundled comp fixtures failed to load")

            state.show(origin)
            XCTAssertEqual(state.panel, origin)
            state.select(comp)
            XCTAssertEqual(state.panel, .compDetail)

            state.goBack()
            XCTAssertEqual(state.panel, origin, "Back from a detail entered via \(origin.title)")
        }
    }

    // MARK: - Which tab lights up

    /// The bar must not contradict itself: the tab it lights up and the tab
    /// Back returns to are the same tab, for every origin that can drill in.
    ///
    /// Found by looking at the running app — drilling into a comp from Openers
    /// lit "Comps" while the Back chevron beside it went to Openers.
    func testTheLitTabIsAlwaysWhereBackWouldReturnTo() throws {
        for origin in OverlayAppState.Panel.destinations(in: .browse) {
            let state = state()
            let comp = try XCTUnwrap(state.comps.first, "Bundled comp fixtures failed to load")

            state.show(origin)
            XCTAssertEqual(state.selectedTab, origin, "\(origin.title) should light its own tab")

            state.select(comp)
            XCTAssertEqual(
                state.selectedTab,
                origin,
                "A comp entered from \(origin.title) should keep \(origin.title) lit"
            )

            state.goBack()
            XCTAssertEqual(state.panel, origin, "Back and the lit tab must agree")
        }
    }

    /// Whatever the route, the lit tab is one the bar is currently offering —
    /// otherwise the bar is left with nothing highlighted at all.
    func testTheLitTabIsAlwaysOneOfTheCurrentTabs() throws {
        let state = state()
        let comp = try XCTUnwrap(state.comps.first, "Bundled comp fixtures failed to load")
        let routes: [(String, () -> Void)] = [
            ("openers", { state.show(.openers) }),
            ("drill in", { state.select(comp) }),
            ("commit", { state.commit(to: comp) }),
            ("items", { state.show(.itemCheatSheet) }),
            ("drill in while focused", { state.select(comp) }),
            ("back", { state.goBack() }),
            ("browse", { state.browse() }),
            ("my champions", { state.show(.myChampions) }),
            ("drill in from mine", { state.select(comp) }),
            ("cycle", { state.cycleForward() }),
        ]

        for (label, step) in routes {
            step()
            XCTAssertTrue(
                OverlayAppState.Panel.destinations(in: state.mode).contains(state.selectedTab),
                "after \(label): \(state.selectedTab.title) is not a tab in \(state.mode)"
            )
        }
    }

    /// Drilling in while focused keeps Focus's own tab lit, so a comp the
    /// player is merely comparing never reads as having replaced their build.
    func testADrillDownWhileFocusedLightsTheTabItCameFrom() throws {
        let state = state()
        _ = try focused(state)

        state.show(.reference)
        let another = try XCTUnwrap(state.comps.dropFirst().first ?? state.comps.first)
        state.select(another)

        XCTAssertEqual(state.selectedTab, .reference)
        XCTAssertEqual(state.mode, .focus)
    }

    // MARK: - Openers hands over by drilling in (#85)

    /// Openers reports comps as `OpenerIndex.CompSummary`, which carries an id
    /// and no units, so the app resolves it against the corpus.
    func testSelectingAnOpenersCompByIDDrillsIntoIt() throws {
        let state = state()
        let comp = try XCTUnwrap(state.comps.dropFirst().first ?? state.comps.first)

        state.show(.openers)
        state.select(compID: comp.id)

        XCTAssertEqual(state.panel, .compDetail)
        XCTAssertEqual(state.selectedComp?.id, comp.id)
    }

    /// Drilling in is deliberately *not* committing: Openers is a pre-commit
    /// surface, and a capsule tap there must not silently pin a build the
    /// player has not looked at yet.
    func testSelectingAnOpenersCompDoesNotCommitToIt() throws {
        let state = state()
        let comp = try XCTUnwrap(state.comps.first, "Bundled comp fixtures failed to load")

        state.show(.openers)
        state.select(compID: comp.id)

        XCTAssertFalse(state.pinnedComps.isPinned(comp.id), "Reading a comp is not choosing it")
        XCTAssertNil(state.committedBuild)
        XCTAssertEqual(state.mode, .browse)
    }

    /// A summary naming a comp this corpus does not carry must not navigate to
    /// an empty detail panel.
    func testSelectingAnUnknownCompIDDoesNothing() {
        let state = state()
        state.show(.openers)

        state.select(compID: "a-comp-that-does-not-exist")

        XCTAssertEqual(state.panel, .openers)
    }

    // MARK: - Tab taps

    /// What a tab tap does.
    func testShowSwitchesPanelsDirectly() {
        let state = state()
        state.show(.reference)
        XCTAssertEqual(state.panel, .reference)
        state.show(.itemCheatSheet)
        XCTAssertEqual(state.panel, .itemCheatSheet)
    }

    /// The build tab with nothing committed has nothing to draw, so it must
    /// not be reachable as an empty panel.
    func testShowingTheBuildTabWithNothingCommittedFallsBackToBrowse() {
        let state = state()
        state.show(.focusBuild)
        XCTAssertEqual(state.panel, .compsList)
        XCTAssertEqual(state.mode, .browse)
    }
}
