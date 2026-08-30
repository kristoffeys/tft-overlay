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

    /// Three tabs per mode, each leading with the panel that answers the
    /// mode's question. Focus deliberately does *not* offer the comps list as
    /// a fourth tab: leaving Focus is the bar's trailing accessory, so the
    /// browse chrome stays behind an explicit decision.
    func testEachModeOffersItsOwnThreeTabs() {
        XCTAssertEqual(
            OverlayAppState.Panel.destinations(in: .browse),
            [.compsList, .itemCheatSheet, .reference]
        )
        XCTAssertEqual(
            OverlayAppState.Panel.destinations(in: .focus),
            [.focusBuild, .itemCheatSheet, .reference]
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
        XCTAssertEqual(state.panel, .itemCheatSheet)
        state.cycleForward()
        XCTAssertEqual(state.panel, .reference)
        state.cycleForward()
        XCTAssertEqual(state.panel, .compsList, "Cycling should wrap")

        state.cycleBackward()
        XCTAssertEqual(state.panel, .reference)
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
        XCTAssertEqual(state.panel, .itemCheatSheet, "Detail belongs to Comps, so forward is Items")
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
