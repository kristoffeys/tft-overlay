import CoreGraphics
@testable import OverlayKit
import XCTest

final class OverlayPositioningTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    private let size = CGSize(width: 300, height: 200)

    func testTopTrailingAnchor() {
        let frame = OverlayPositioning.frame(for: size, in: screen, anchor: .topTrailing, padding: 20)

        XCTAssertEqual(frame.origin.x, 1920 - 20 - 300)
        XCTAssertEqual(frame.origin.y, 1080 - 20 - 200)
        XCTAssertEqual(frame.size, size)
    }

    func testBottomLeadingAnchor() {
        let frame = OverlayPositioning.frame(for: size, in: screen, anchor: .bottomLeading, padding: 20)

        XCTAssertEqual(frame.origin.x, 20)
        XCTAssertEqual(frame.origin.y, 20)
        XCTAssertEqual(frame.size, size)
    }

    // MARK: - Clamping (#14 resize min/max)

    func testClampWithinBoundsIsUnchanged() {
        let clamped = OverlayPositioning.clamp(
            CGSize(width: 400, height: 300),
            min: CGSize(width: 240, height: 120),
            max: CGSize(width: 900, height: 1200)
        )
        XCTAssertEqual(clamped, CGSize(width: 400, height: 300))
    }

    func testClampBelowMinimumIsRaised() {
        let clamped = OverlayPositioning.clamp(
            CGSize(width: 10, height: 5),
            min: CGSize(width: 240, height: 120),
            max: CGSize(width: 900, height: 1200)
        )
        XCTAssertEqual(clamped, CGSize(width: 240, height: 120))
    }

    func testClampAboveMaximumIsLowered() {
        let clamped = OverlayPositioning.clamp(
            CGSize(width: 5000, height: 5000),
            min: CGSize(width: 240, height: 120),
            max: CGSize(width: 900, height: 1200)
        )
        XCTAssertEqual(clamped, CGSize(width: 900, height: 1200))
    }

    func testResizedKeepsOriginFixedAndClampsSize() {
        let frame = CGRect(x: 100, y: 50, width: 400, height: 300)
        let resized = OverlayPositioning.resized(
            frame,
            to: CGSize(width: 5000, height: 5000),
            min: CGSize(width: 240, height: 120),
            max: CGSize(width: 900, height: 1200)
        )
        XCTAssertEqual(resized.origin, frame.origin)
        XCTAssertEqual(resized.size, CGSize(width: 900, height: 1200))
    }

    // MARK: - Snap presets (#14)

    func testLeftRailSpansScreenHeight() {
        let frame = OverlayPositioning.frame(
            for: .leftRail,
            contentSize: CGSize(width: 60, height: 200),
            in: screen,
            padding: 8
        )
        XCTAssertEqual(frame.origin.x, 8)
        XCTAssertEqual(frame.origin.y, 8)
        XCTAssertEqual(frame.width, 60)
        XCTAssertEqual(frame.height, screen.height - 16)
    }

    func testRightRailAnchorsToTrailingEdge() {
        let frame = OverlayPositioning.frame(
            for: .rightRail,
            contentSize: CGSize(width: 60, height: 200),
            in: screen,
            padding: 8
        )
        XCTAssertEqual(frame.origin.x, screen.width - 8 - 60)
        XCTAssertEqual(frame.height, screen.height - 16)
    }

    func testBottomStripSpansScreenWidth() {
        let frame = OverlayPositioning.frame(
            for: .bottomStrip,
            contentSize: CGSize(width: 200, height: 48),
            in: screen,
            padding: 8
        )
        XCTAssertEqual(frame.origin.x, 8)
        XCTAssertEqual(frame.origin.y, 8)
        XCTAssertEqual(frame.width, screen.width - 16)
        XCTAssertEqual(frame.height, 48)
    }

    // MARK: - Pixel alignment (#11 — no half-pixel blur on Retina/mixed-DPI)

    func testPixelAlignedRoundsToDeviceGridAt2x() {
        let rect = CGRect(x: 100.3, y: 50.6, width: 300.2, height: 200.8)
        let aligned = OverlayPositioning.pixelAligned(rect, scale: 2)

        // Every component, scaled by 2, must land on a whole device pixel.
        XCTAssertEqual((aligned.origin.x * 2).truncatingRemainder(dividingBy: 1), 0, accuracy: 0.0001)
        XCTAssertEqual((aligned.origin.y * 2).truncatingRemainder(dividingBy: 1), 0, accuracy: 0.0001)
        XCTAssertEqual((aligned.width * 2).truncatingRemainder(dividingBy: 1), 0, accuracy: 0.0001)
        XCTAssertEqual((aligned.height * 2).truncatingRemainder(dividingBy: 1), 0, accuracy: 0.0001)
    }

    func testPixelAlignedIsNoOpForIntegralPointsAt1x() {
        let rect = CGRect(x: 100, y: 50, width: 300, height: 200)
        XCTAssertEqual(OverlayPositioning.pixelAligned(rect, scale: 1), rect)
    }

    // MARK: - Display-loss recovery (#11 multi-display correctness)

    func testValidatedKeepsFrameThatIntersectsAKnownScreen() {
        let frame = CGRect(x: 10, y: 10, width: 100, height: 100)
        let validated = OverlayPositioning.validated(frame, against: [screen], fallbackScreenFrame: screen)
        XCTAssertEqual(validated, frame)
    }

    func testValidatedFallsBackWhenFrameIsOnAVanishedDisplay() {
        let vanished = CGRect(x: 5000, y: 5000, width: 100, height: 100)
        let validated = OverlayPositioning.validated(vanished, against: [screen], fallbackScreenFrame: screen)
        XCTAssertTrue(screen.contains(validated))
        XCTAssertEqual(validated.size, vanished.size)
    }

    // MARK: - Idle auto-revert (#13)

    func testShouldAutoRevertFalseBeforeIdleIntervalElapses() {
        XCTAssertFalse(OverlayPositioning.shouldAutoRevert(lastActivity: 0, now: 5, idleInterval: 8))
    }

    func testShouldAutoRevertTrueAfterIdleIntervalElapses() {
        XCTAssertTrue(OverlayPositioning.shouldAutoRevert(lastActivity: 0, now: 8, idleInterval: 8))
        XCTAssertTrue(OverlayPositioning.shouldAutoRevert(lastActivity: 0, now: 20, idleInterval: 8))
    }
}
