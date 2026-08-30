@testable import TFTUI
import XCTest

/// The recipe grid has to fit the panel it is drawn in.
///
/// It previously used fixed 46/52pt cells, which comes to ~476pt for the
/// eight standard components — wider than the 460pt overlay panel. The
/// surplus silently became a horizontal scroll bar, so the last column of a
/// lookup table sat off-screen until you scrolled for it.
final class RecipeGridMetricsTests: XCTestCase {
    private let components = 8

    /// The real expanded panel, minus the grid's own padding.
    func testFitsTheExpandedOverlayPanel() {
        let available: CGFloat = 460 - 24
        let metrics = RecipeGridMetrics(availableWidth: available, columns: components)
        XCTAssertLessThanOrEqual(metrics.totalWidth(columns: components), available)
        XCTAssertGreaterThan(metrics.cell, RecipeGridMetrics.minimumCell)
    }

    /// And the compact panel, which is where fixed sizing would break worst.
    func testFitsTheCompactOverlayPanel() {
        let available: CGFloat = 300 - 24
        let metrics = RecipeGridMetrics(availableWidth: available, columns: components)
        XCTAssertLessThanOrEqual(metrics.totalWidth(columns: components), available)
    }

    /// Whatever the panel is resized to, the grid stays inside it.
    func testFitsEveryPlausiblePanelWidth() {
        for width in stride(from: CGFloat(240), through: 900, by: 10) {
            let available = width - 24
            let metrics = RecipeGridMetrics(availableWidth: available, columns: components)
            // Below the minimum cell size the grid is allowed to overflow
            // rather than render illegible art; above it, it must fit.
            guard metrics.cell > RecipeGridMetrics.minimumCell else { continue }
            XCTAssertLessThanOrEqual(
                metrics.totalWidth(columns: components),
                available,
                "grid overflows at panel width \(width)"
            )
        }
    }

    /// A very wide panel should not produce a table of enormous icons.
    func testCellsStopGrowingOnAWidePanel() {
        let metrics = RecipeGridMetrics(availableWidth: 4000, columns: components)
        XCTAssertEqual(metrics.cell, RecipeGridMetrics.maximumCell)
    }

    /// Degenerate inputs must not produce a negative or absurd cell size.
    func testClampsRatherThanGoingNegative() {
        XCTAssertEqual(RecipeGridMetrics(availableWidth: 0, columns: components).cell, RecipeGridMetrics.minimumCell)
        XCTAssertEqual(RecipeGridMetrics(availableWidth: -500, columns: components).cell, RecipeGridMetrics.minimumCell)
        XCTAssertGreaterThan(RecipeGridMetrics(availableWidth: 400, columns: 0).cell, 0)
    }
}
