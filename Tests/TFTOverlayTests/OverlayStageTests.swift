import AppKit
@testable import TFTOverlay
import TFTUI
import XCTest

/// The stage the Build panel is answering for (#84).
///
/// The stage is set by hand until board vision lands (#45), so what these
/// pin down is the mitigation, not just the mechanic: advancing is one call,
/// running off the end is a no-op rather than a wrap back to opener advice,
/// and a player who never advances still starts on the earliest band.
@MainActor
final class OverlayStageTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        suiteName = "OverlayStageTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func state() -> OverlayAppState {
        OverlayAppState(pinnedComps: PinnedCompsStore(defaults: defaults))
    }

    func testStartsOnTheEarliestBand() {
        XCTAssertEqual(state().stageBand, .early)
    }

    func testAdvancingWalksEarlyToMidToLate() {
        let state = state()
        state.advanceStage()
        XCTAssertEqual(state.stageBand, .mid)
        state.advanceStage()
        XCTAssertEqual(state.stageBand, .late)
    }

    func testAdvancingPastLateIsANoOp() {
        let state = state()
        for _ in 0 ..< 5 {
            state.advanceStage()
        }
        XCTAssertEqual(state.stageBand, .late, "wrapping would show opener advice in a top-four fight")
    }

    func testTapSelectionJumpsToAnyBandInEitherDirection() {
        let state = state()
        state.setStageBand(.late)
        XCTAssertEqual(state.stageBand, .late)
        state.setStageBand(.early)
        XCTAssertEqual(state.stageBand, .early, "the only way back is a direct tap; advance never wraps")
    }

    /// Committing to a different line is the closest thing the overlay has to
    /// a "new game" signal, and a stale Late carried into a fresh lobby is the
    /// exact staleness this feature is trying to avoid.
    func testCommittingToADifferentBuildResetsTheStage() throws {
        let state = state()
        try XCTSkipIf(state.comps.count < 2, "Needs at least two bundled comps")
        state.commit(to: state.comps[0])
        state.setStageBand(.late)

        state.commit(to: state.comps[1])
        XCTAssertEqual(state.stageBand, .early)
    }

    func testRecommittingToTheSameBuildKeepsTheStage() throws {
        let state = state()
        try XCTSkipIf(state.comps.isEmpty, "Needs a bundled comp")
        state.commit(to: state.comps[0])
        state.setStageBand(.mid)

        // Leaving for the list and coming back is not a new game.
        state.browse()
        state.show(.focusBuild)
        XCTAssertEqual(state.stageBand, .mid)
    }

    func testAdvanceStageIsBoundToAnOptionHotkeyLikeEveryOtherOverlayAction() {
        let hotkey = AppHotkeyAction.advanceStage.defaultHotkey
        XCTAssertTrue(
            NSEvent.ModifierFlags(rawValue: hotkey.modifierFlags).contains(.option),
            "every overlay hotkey is Option-based so they stay on one hand"
        )
        for action in AppHotkeyAction.allCases where action != .advanceStage {
            XCTAssertNotEqual(
                hotkey,
                action.defaultHotkey,
                "\(action.rawValue) ships the same default combo as advanceStage"
            )
        }
    }
}
