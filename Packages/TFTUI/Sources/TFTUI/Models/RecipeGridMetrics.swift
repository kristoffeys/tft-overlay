import CoreGraphics

/// Cell sizing for the recipe matrix, solved from the width the grid is
/// actually given.
///
/// The grid was laid out at fixed 46/52pt cells, which comes to ~476pt for
/// the eight-component set — wider than the 460pt overlay panel it lives in.
/// The overflow fell into a horizontal scroll bar, so the last column of a
/// reference table was off-screen by default, which is the one thing a
/// lookup grid must never be. Sizing from the available width instead means
/// it fits the expanded panel, the compact panel and anything in between.
///
/// Pure arithmetic, so the fit is unit-testable without rendering.
public struct RecipeGridMetrics: Equatable, Sendable {
    /// Smallest legible cell; below this the art is mush and the grid stops
    /// being worth showing.
    public static let minimumCell: CGFloat = 18
    /// Cells stop growing past this so a wide panel doesn't render a table
    /// of giant icons.
    public static let maximumCell: CGFloat = 52

    public let cell: CGFloat
    public let spacing: CGFloat

    /// - Parameters:
    ///   - availableWidth: width the grid may occupy, padding already removed.
    ///   - columns: number of components, i.e. body columns. The row-header
    ///     column is accounted for on top of this.
    public init(availableWidth: CGFloat, columns: Int, spacing: CGFloat = 3) {
        self.spacing = spacing
        // One header column plus `columns` body columns is `columns + 1`
        // cells, separated by `columns` gaps.
        let cellCount = CGFloat(max(columns, 0) + 1)
        let gaps = CGFloat(max(columns, 0)) * spacing
        let solved = (availableWidth - gaps) / cellCount
        cell = min(max(solved.rounded(.down), Self.minimumCell), Self.maximumCell)
    }

    /// Width the grid actually occupies at this cell size.
    public func totalWidth(columns: Int) -> CGFloat {
        let cellCount = CGFloat(max(columns, 0) + 1)
        return cell * cellCount + CGFloat(max(columns, 0)) * spacing
    }
}
