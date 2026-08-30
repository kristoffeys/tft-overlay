import SwiftUI

/// A **pointy-top** hexagon: vertices at top and bottom, flat *vertical*
/// edges left and right.
///
/// The orientation is load-bearing, not cosmetic. A TFT row is seven hexes
/// that are all neighbours of each other, and two hexes side by side at the
/// same height can only share an edge if that edge is vertical — so a board
/// laid out as offset rows requires pointy-top. This shape was previously
/// flat-top (flat edge on top, points left/right), which tessellates by
/// offset *columns* instead; pairing it with a row-offset layout is what
/// made the cells overlap no matter how the spacing was tuned.
struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let points = [
            CGPoint(x: width * 0.5, y: 0),
            CGPoint(x: width, y: height * 0.25),
            CGPoint(x: width, y: height * 0.75),
            CGPoint(x: width * 0.5, y: height),
            CGPoint(x: 0, y: height * 0.75),
            CGPoint(x: 0, y: height * 0.25),
        ]
        var path = Path()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

/// Tessellation constants for `HexagonShape`, derived from the geometry of a
/// regular pointy-top hexagon rather than tuned by eye — every value here
/// follows from "the hexagon is regular" and nothing else.
enum HexMetrics {
    /// Height as a multiple of width. A regular pointy-top hexagon of width
    /// `w` has side `w/√3` and height `2w/√3`.
    static let heightRatio: CGFloat = 2 / CGFloat(3.0.squareRoot())

    /// Row-to-row pitch as a fraction of hex height. Adjacent rows interlock
    /// by a quarter of a hex, so each row advances three quarters.
    static let rowPitchRatio: CGFloat = 0.75

    /// How far every other row shifts sideways, as a fraction of hex width.
    static let rowOffsetRatio: CGFloat = 0.5

    /// Gap left between neighbouring cells, as a fraction of hex width. The
    /// grid pitch stays exact; each hexagon is simply drawn slightly inside
    /// its cell, so tiles read as separate the way the real board does
    /// without the layout maths having to absorb a fudge factor.
    static let insetRatio: CGFloat = 0.03

    static func height(for width: CGFloat) -> CGFloat {
        width * heightRatio
    }

    /// Negative, because rows overlap: the pitch is shorter than a hexagon.
    static func rowSpacing(for width: CGFloat) -> CGFloat {
        height(for: width) * (rowPitchRatio - 1)
    }
}

/// Renders a comp's `boardPositioning.grid` (4 rows x 7 hex columns, row 0
/// closest to the enemy) as a staggered hex board.
public struct BoardGridView: View {
    let grid: [[String?]]
    let cellSize: CGFloat
    let unitIndex: CompUnitIndex

    public init(grid: [[String?]], cellSize: CGFloat = 44, unitIndex: CompUnitIndex = .empty) {
        self.grid = grid
        self.cellSize = cellSize
        self.unitIndex = unitIndex
    }

    public var body: some View {
        // Standard offset-row honeycomb: neighbours in a row butt up against
        // each other along their vertical edges (pitch is exactly one hex
        // wide, hence zero spacing), rows advance three quarters of a hex so
        // they interlock, and every other row shifts half a hex sideways.
        // See `HexMetrics` — all three numbers fall out of the hexagon being
        // regular.
        VStack(spacing: HexMetrics.rowSpacing(for: cellSize)) {
            ForEach(Array(grid.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 0) {
                    if rowIndex.isMultiple(of: 2) == false {
                        Spacer().frame(width: cellSize * HexMetrics.rowOffsetRatio)
                    }
                    ForEach(Array(row.enumerated()), id: \.offset) { _, unitName in
                        BoardHexCell(
                            unitName: unitName,
                            size: cellSize,
                            summary: unitName.map { unitIndex.summary(for: $0) }
                        )
                    }
                }
            }
        }
        .padding(cellSize * 0.2)
    }
}

private struct BoardHexCell: View {
    let unitName: String?
    let size: CGFloat
    let summary: UnitItemSummary?

    @Environment(\.tftAssetCatalog) private var catalog

    var body: some View {
        ZStack {
            HexagonShape()
                .fill(unitName == nil ? TFTTheme.panelBackground.opacity(0.5) : TFTTheme.elevatedBackground)
            if let unitName {
                // Fills the hexagon's bounding box and is clipped to the
                // hexagon itself; `cornerRadius: 0` because the hex clip is
                // what shapes it, and a rounded-rect clip underneath would
                // eat into the hexagon's own points.
                AssetImage(url: catalog.championImageURL(named: unitName), cornerRadius: 0) {
                    Text(initials(unitName))
                        .font(.system(size: size * 0.24, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
                .clipShape(HexagonShape())
            }
            HexagonShape()
                .stroke(
                    unitName == nil ? Color.white.opacity(0.10) : TFTTheme.accent.opacity(0.75),
                    lineWidth: unitName == nil ? 1 : 2
                )
        }
        // Inset inside the cell, not subtracted from it: the grid pitch stays
        // exactly one hexagon so the tessellation holds, while the drawn tiles
        // sit just inside their cells and read as separate.
        .padding(size * HexMetrics.insetRatio)
        .frame(width: size, height: HexMetrics.height(for: size))
        .contentShape(HexagonShape())
        // The card renders in its own window (see `FloatingTooltip`), so a
        // hex on any edge of the board gets a full card instead of one
        // clipped by the panel — which is what the board's own clamped
        // in-window overlay used to do.
        .unitItemTooltipOnHover(summary)
    }

    private func initials(_ name: String) -> String {
        String(name.split(separator: " ").compactMap(\.first).prefix(2)).uppercased()
    }
}

#Preview {
    BoardGridView(grid: [
        [nil, "Krug", "The Elder Dragon", "The Elder Dragon", "Cinderling", nil, nil],
        [nil, nil, nil, nil, nil, nil, nil],
        ["Caitlyn", nil, nil, nil, nil, nil, "Tristana"],
        [nil, "Ashe", nil, nil, nil, "Sivir", nil],
    ], unitIndex: CompUnitIndex(
        units: [CompUnit(name: "Ashe", cost: 5, starTarget: 2, role: .carry, traits: ["Hunter"])],
        carries: [CompCarry(unit: "Ashe", itemPriority: ["Infinity Edge", "Giant Slayer"], itemNotes: "IE first.")]
    ))
    .padding()
    .background(TFTTheme.background)
}
