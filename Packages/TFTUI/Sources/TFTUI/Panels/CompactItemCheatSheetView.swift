import SwiftUI
import TFTData

/// A compact, always-visible variant of the item cheat sheet: the same
/// data-derived grid at a small fixed cell size, no scrolling, no chrome —
/// meant to stay on screen during a live game.
public struct CompactItemCheatSheetView: View {
    private let matrix: RecipeMatrix
    private let cellSize: CGFloat

    public init(matrix: RecipeMatrix = RecipeMatrix(), cellSize: CGFloat = 26) {
        self.matrix = matrix
        self.cellSize = cellSize
    }

    public var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                Color.clear.frame(width: cellSize, height: cellSize)
                ForEach(matrix.components) { component in
                    componentLabel(component.name)
                }
            }
            ForEach(matrix.components) { row in
                HStack(spacing: 2) {
                    componentLabel(row.name)
                    ForEach(matrix.components) { col in
                        if let item = matrix.completedItem(row, col) {
                            Text(abbreviation(item.name))
                                .font(.system(size: cellSize * 0.38, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(width: cellSize, height: cellSize)
                                .background(
                                    TFTTheme.elevatedBackground,
                                    in: RoundedRectangle(cornerRadius: 4, style: .continuous)
                                )
                        } else {
                            Color.clear.frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
        }
        .padding(6)
        .background(TFTTheme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func componentLabel(_ name: String) -> some View {
        Text(String(name.prefix(2)).uppercased())
            .font(.system(size: cellSize * 0.34, weight: .heavy, design: .rounded))
            .foregroundStyle(TFTTheme.accent)
            .frame(width: cellSize, height: cellSize)
    }

    private func abbreviation(_ name: String) -> String {
        let words = name.split(separator: " ").filter { $0.first?.isLetter == true }
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

#Preview {
    CompactItemCheatSheetView()
        .padding(40)
        .background(Color.gray)
}
