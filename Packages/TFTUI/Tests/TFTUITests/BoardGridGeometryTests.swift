import SwiftUI
@testable import TFTUI
import XCTest

/// The hex board's geometry, pinned down.
///
/// This shipped broken twice. `HexagonShape` was drawn **flat-top** (flat
/// edge on top, points left and right) while `BoardGridView` lays cells out
/// as offset *rows* — an arrangement only pointy-top hexagons tessellate in.
/// No amount of tuning the spacing fixes that pairing, and both attempts to
/// tune it produced overlapping cells instead.
///
/// So these assert the invariant rather than the numbers: the shape's
/// orientation, and that the board's size is exactly what the honeycomb
/// formula predicts. Either one failing means the shape and the layout have
/// drifted apart again.
@MainActor
final class BoardGridGeometryTests: XCTestCase {
    /// Every constant follows from "the hexagon is regular"; if one is
    /// hand-edited to make something look right, the rest no longer agree.
    func testMetricsDescribeARegularPointyTopHexagon() {
        // A regular pointy-top hexagon of width w has side w/√3, so its
        // point-to-point height is 2w/√3.
        XCTAssertEqual(HexMetrics.heightRatio, 1.1547, accuracy: 0.0001)
        // Rows advance three quarters of a hex and therefore overlap by a
        // quarter — the spacing must come out negative.
        XCTAssertEqual(HexMetrics.rowSpacing(for: 100), -100 * 1.1547 * 0.25, accuracy: 0.01)
        XCTAssertLessThan(HexMetrics.rowSpacing(for: 44), 0)
        XCTAssertEqual(HexMetrics.rowOffsetRatio, 0.5)
    }

    /// The regression itself: a pointy-top hexagon comes to a point at the
    /// top, so its topmost scanline carries far less ink than its waist. A
    /// flat-top hexagon starts half its width wide and would fail this.
    func testHexagonIsPointyTopNotFlatTop() throws {
        let size = CGSize(width: 60, height: HexMetrics.height(for: 60))
        let raster = try ViewSnapshot.render(
            HexagonShape().fill(Color.white).frame(width: size.width, height: size.height),
            size: size
        )

        let topInk = litPixels(in: raster, row: 1)
        let waistInk = litPixels(in: raster, row: raster.height / 2)

        XCTAssertGreaterThan(waistInk, 0, "hexagon did not render")
        XCTAssertLessThan(
            Double(topInk),
            Double(waistInk) * 0.25,
            "Top scanline is \(topInk)px wide against a \(waistInk)px waist — that is a flat top, "
                + "which does not tessellate in this view's offset-row layout"
        )
    }

    /// A 4x7 board is exactly as wide and tall as the honeycomb formula says.
    /// Cells that overlap (or gap) make this come out short (or long).
    func testBoardMeasuresExactlyOneHoneycomb() throws {
        let cell: CGFloat = 44
        let rows = 4
        let columns = 7
        let grid: [[String?]] = Array(repeating: Array(repeating: nil, count: columns), count: rows)

        let measured = try ViewSnapshot.measuredSize(
            of: BoardGridView(grid: grid, cellSize: cell),
            proposedWidth: 600
        )

        // BoardGridView pads itself by 0.2 cells on every side.
        let padding = cell * 0.2 * 2
        let hexHeight = HexMetrics.height(for: cell)
        // Neighbours in a row share a vertical edge, so the pitch is one full
        // hex; the odd rows' half-hex shift adds to the total width.
        let expectedWidth = CGFloat(columns) * cell + cell * HexMetrics.rowOffsetRatio + padding
        // First row costs a full hex, each row after it three quarters.
        let expectedHeight = hexHeight + CGFloat(rows - 1) * hexHeight * HexMetrics.rowPitchRatio + padding

        XCTAssertEqual(measured.width, expectedWidth, accuracy: 1)
        XCTAssertEqual(measured.height, expectedHeight, accuracy: 1)
    }

    /// The board has to fit the overlay panel it lives in, which is 460pt
    /// wide before the detail view's own padding.
    func testBoardFitsTheOverlayPanelWidth() throws {
        let grid: [[String?]] = Array(repeating: Array(repeating: nil, count: 7), count: 4)
        let measured = try ViewSnapshot.measuredSize(of: BoardGridView(grid: grid), proposedWidth: 460)
        XCTAssertLessThanOrEqual(measured.width, 460)
    }

    /// Number of pixels brighter than the ink threshold on one scanline.
    private func litPixels(in raster: Raster, row: Int) -> Int {
        (0 ..< raster.width).count { raster.luminance(x: $0, y: row) > Raster.inkThreshold }
    }
}
