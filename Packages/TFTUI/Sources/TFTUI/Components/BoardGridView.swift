import SwiftUI

struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let points = [
            CGPoint(x: width * 0.25, y: 0),
            CGPoint(x: width * 0.75, y: 0),
            CGPoint(x: width, y: height * 0.5),
            CGPoint(x: width * 0.75, y: height),
            CGPoint(x: width * 0.25, y: height),
            CGPoint(x: 0, y: height * 0.5),
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

/// Renders a comp's `boardPositioning.grid` (4 rows x 7 hex columns, row 0
/// closest to the enemy) as a staggered hex board.
public struct BoardGridView: View {
    let grid: [[String?]]
    let cellSize: CGFloat

    public init(grid: [[String?]], cellSize: CGFloat = 44) {
        self.grid = grid
        self.cellSize = cellSize
    }

    public var body: some View {
        VStack(spacing: -cellSize * 0.14) {
            ForEach(Array(grid.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: cellSize * 0.08) {
                    if rowIndex.isMultiple(of: 2) == false {
                        Spacer().frame(width: cellSize * 0.54)
                    }
                    ForEach(Array(row.enumerated()), id: \.offset) { _, unitName in
                        BoardHexCell(unitName: unitName, size: cellSize)
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

    var body: some View {
        ZStack {
            HexagonShape()
                .fill(unitName == nil ? TFTTheme.panelBackground.opacity(0.5) : TFTTheme.elevatedBackground)
            HexagonShape()
                .stroke(
                    unitName == nil ? Color.white.opacity(0.10) : TFTTheme.accent.opacity(0.75),
                    lineWidth: unitName == nil ? 1 : 2
                )
            if let unitName {
                Text(initials(unitName))
                    .font(.system(size: size * 0.24, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size * 0.86)
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
    ])
    .padding()
    .background(TFTTheme.background)
}
