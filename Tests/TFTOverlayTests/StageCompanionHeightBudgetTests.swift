import OverlayKit
import TFTUI
import XCTest

/// `TFTUI` must not depend on `OverlayKit` (see `CLAUDE.md`), so
/// `StageCompanionSnapshotTests.assumedOverlayChromeHeaderHeight` keeps its
/// own documented literal for OverlayKit's chrome instead of importing the
/// package that actually owns the number. This is the one place both
/// packages meet, so it is the one place that can prove the literal has not
/// drifted from the real thing (#110).
final class StageCompanionHeightBudgetTests: XCTestCase {
    /// Mirrors `StageCompanionSnapshotTests.assumedOverlayChromeHeaderHeight`
    /// in `Packages/TFTUI`. If this test starts failing, that constant is
    /// stale and needs to move with `OverlayChromeMetrics`.
    private let assumedOverlayChromeHeaderHeight: CGFloat = 24

    func testAssumedChromeHeaderHeightMatchesOverlayKit() {
        XCTAssertEqual(
            OverlayChromeMetrics.interactiveHeaderHeight,
            assumedOverlayChromeHeaderHeight,
            "OverlayKit's real chrome header height moved — update the assumed literal in "
                + "StageCompanionSnapshotTests.glanceBudget (Packages/TFTUI) to match"
        )
    }

    /// Also pins the other two ingredients of the Stage Companion's height
    /// budget, so a future PR that changes either without knowing about the
    /// budget it feeds fails somewhere that says why.
    func testTabBarAndContentPaddingMatchWhatTheBudgetAssumes() {
        XCTAssertEqual(PanelTabBar<String>.height, 34, "StageCompanionSnapshotTests.glanceBudget assumes this")
        XCTAssertEqual(
            StageCompanionView.contentPadding,
            12,
            "StageCompanionSnapshotTests.glanceBudget assumes this"
        )
    }
}
