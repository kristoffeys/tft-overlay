import CoreGraphics
@testable import OverlayKit
import XCTest

/// Regression coverage for #83: hover cards never appeared anywhere in the
/// overlay because AppKit never delivered `mouseMoved` events to the panel,
/// which SwiftUI's `.onHover` needs to detect the cursor entering a view.
final class OverlayPanelHoverTests: XCTestCase {
    @MainActor
    func testPanelAcceptsMouseMovedEvents() {
        let panel = OverlayPanel(contentRect: CGRect(x: 0, y: 0, width: 400, height: 300))

        XCTAssertTrue(
            panel.acceptsMouseMovedEvents,
            "the panel must accept mouseMoved events, or SwiftUI's .onHover " +
                "(and every hover affordance built on it) never fires"
        )
    }

    /// `.onHover`'s tracking area also needs the window to actually be able
    /// to become key — a non-activating panel can do this without stealing
    /// focus from the game, but only if this stays true.
    @MainActor
    func testPanelCanBecomeKey() {
        let panel = OverlayPanel(contentRect: CGRect(x: 0, y: 0, width: 400, height: 300))

        XCTAssertTrue(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain, "must never become main — that would fight the game's window")
    }
}
