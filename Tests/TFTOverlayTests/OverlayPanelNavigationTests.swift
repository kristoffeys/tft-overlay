@testable import TFTOverlay
import XCTest

/// The panel tab bar's contract with `OverlayAppState`.
///
/// The overlay used to expose its four panels only through blind ⌥C cycling —
/// nothing on screen said which panel you were on or that others existed. The
/// tab bar fixes that, and these pin down the model side of it: which panels
/// are tabs, which tab lights up for a drill-down, and that the hotkey and the
/// bar agree on what "next panel" means.
@MainActor
final class OverlayPanelNavigationTests: XCTestCase {
    func testDetailIsADrillDownNotATab() {
        XCTAssertFalse(OverlayAppState.Panel.compDetail.isDestination)
        XCTAssertFalse(OverlayAppState.Panel.destinations.contains(.compDetail))
    }

    /// Derived from `allCases`, so a fifth panel gets a tab for free.
    func testEveryOtherPanelIsATab() {
        XCTAssertEqual(
            OverlayAppState.Panel.destinations,
            [.compsList, .itemCheatSheet, .reference]
        )
        for panel in OverlayAppState.Panel.allCases where panel != .compDetail {
            XCTAssertTrue(panel.isDestination, "\(panel.title) should have a tab")
        }
    }

    /// Every panel maps to exactly one tab, and every tab maps to itself —
    /// otherwise the bar can end up with nothing highlighted.
    func testEveryPanelHighlightsATab() {
        for panel in OverlayAppState.Panel.allCases {
            XCTAssertTrue(
                OverlayAppState.Panel.destinations.contains(panel.destination),
                "\(panel.title) highlights \(panel.destination.title), which is not a tab"
            )
        }
        XCTAssertEqual(OverlayAppState.Panel.compDetail.destination, .compsList)
        XCTAssertEqual(OverlayAppState.Panel.reference.destination, .reference)
    }

    func testEveryTabHasANonEmptyTitle() {
        for panel in OverlayAppState.Panel.destinations {
            XCTAssertFalse(panel.title.isEmpty)
        }
    }

    func testCyclingWalksTheTabsInOrder() {
        let state = OverlayAppState()
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

    /// ⌥C used to be able to land on the detail panel, which shows
    /// "No comp selected" whenever nothing has been picked — a dead end you
    /// could reach by accident.
    func testCyclingNeverLandsOnTheDrillDown() {
        let state = OverlayAppState()
        for _ in 0 ..< (OverlayAppState.Panel.allCases.count * 3) {
            state.cycleForward()
            XCTAssertNotEqual(state.panel, .compDetail)
        }
        for _ in 0 ..< (OverlayAppState.Panel.allCases.count * 3) {
            state.cycleBackward()
            XCTAssertNotEqual(state.panel, .compDetail)
        }
    }

    /// Cycling out of a drill-down continues from the section it belongs to.
    func testCyclingFromTheDrillDownResumesFromItsSection() {
        let state = OverlayAppState()
        guard let comp = state.comps.first else {
            return XCTFail("Bundled comp fixtures failed to load")
        }

        state.select(comp)
        XCTAssertEqual(state.panel, .compDetail)

        state.cycleForward()
        XCTAssertEqual(state.panel, .itemCheatSheet, "Detail belongs to Comps, so forward is Items")
    }

    /// What a tab tap does.
    func testShowSwitchesPanelsDirectly() {
        let state = OverlayAppState()
        state.show(.reference)
        XCTAssertEqual(state.panel, .reference)
        state.show(.itemCheatSheet)
        XCTAssertEqual(state.panel, .itemCheatSheet)
    }
}
