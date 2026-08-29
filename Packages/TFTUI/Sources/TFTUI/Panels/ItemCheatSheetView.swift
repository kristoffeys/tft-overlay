import SwiftUI
import TFTData

/// Item cheat sheet + recipe matrix (#25, #19): an interactive
/// component x component -> completed item grid, plus reverse lookup from a
/// completed item to its recipe and the units that want it. The grid is
/// rendered by iterating `RecipeMatrix.components`, not hand-laid-out.
public struct ItemCheatSheetView: View {
    private let matrix: RecipeMatrix
    private let demandIndex: ItemDemandIndex

    @State private var mode: Mode = .grid
    @State private var selectedItem: Item?

    enum Mode: String, CaseIterable, Identifiable {
        case grid = "Grid"
        case lookup = "Lookup"
        var id: String {
            rawValue
        }
    }

    public init(matrix: RecipeMatrix = RecipeMatrix(), comps: [Comp] = []) {
        self.matrix = matrix
        demandIndex = ItemDemandIndex(comps: comps)
    }

    public var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(10)

            Group {
                switch mode {
                case .grid: gridView
                case .lookup: lookupView
                }
            }

            if let selectedItem {
                DetailPanel(item: selectedItem, matrix: matrix, demandIndex: demandIndex) {
                    self.selectedItem = nil
                }
            }
        }
        .background(TFTTheme.background)
    }

    private var gridView: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Color.clear.frame(width: 52, height: 52)
                    ForEach(matrix.components) { component in
                        ItemIconPlaceholder(component, size: 46)
                    }
                }
                ForEach(matrix.components) { rowComponent in
                    HStack(spacing: 4) {
                        ItemIconPlaceholder(rowComponent, size: 52)
                        ForEach(matrix.components) { colComponent in
                            if let item = matrix.completedItem(rowComponent, colComponent) {
                                Button {
                                    selectedItem = item
                                } label: {
                                    ItemIconPlaceholder(item, size: 46)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Color.clear.frame(width: 46, height: 46)
                            }
                        }
                    }
                }
            }
            .padding(12)
        }
    }

    private var lookupView: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(matrix.completedItems) { item in
                    Button {
                        selectedItem = item
                    } label: {
                        HStack(spacing: 10) {
                            ItemIconPlaceholder(item, size: 32)
                            Text(item.name)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(TFTTheme.textPrimary)
                            Spacer()
                            let demand = demandIndex.entries(forItemNamed: item.name)
                            if !demand.isEmpty {
                                Text("\(demand.count) comp\(demand.count == 1 ? "" : "s")")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(TFTTheme.textSecondary)
                            }
                        }
                        .padding(8)
                        .background(
                            TFTTheme.panelBackground,
                            in: RoundedRectangle(cornerRadius: TFTTheme.smallCornerRadius, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
        }
    }
}

private struct DetailPanel: View {
    let item: Item
    let matrix: RecipeMatrix
    let demandIndex: ItemDemandIndex
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ItemIconPlaceholder(item, size: 36)
                Text(item.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(TFTTheme.textPrimary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(TFTTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            if let recipe = matrix.recipe(for: item) {
                HStack(spacing: 6) {
                    Text("Recipe:")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(TFTTheme.textSecondary)
                    ItemIconPlaceholder(recipe.0, size: 26)
                    Text("+").foregroundStyle(TFTTheme.textSecondary)
                    ItemIconPlaceholder(recipe.1, size: 26)
                }
            }
            let demand = demandIndex.entries(forItemNamed: item.name)
            Text("Wanted by".uppercased())
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(TFTTheme.accent)
            if demand.isEmpty {
                Text("No loaded comp prioritizes this item.")
                    .font(.system(size: 12))
                    .foregroundStyle(TFTTheme.textSecondary)
            } else {
                ForEach(demand) { entry in
                    Text("\(entry.unit) — \(entry.compName) (priority \(entry.priorityRank))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(TFTTheme.textPrimary)
                }
            }
        }
        .padding(12)
        .background(
            TFTTheme.elevatedBackground,
            in: RoundedRectangle(cornerRadius: TFTTheme.cornerRadius, style: .continuous)
        )
        .padding(10)
    }
}

#Preview {
    ItemCheatSheetView(comps: (try? CompLoader.bundledFixtures()) ?? [])
        .frame(width: 520, height: 640)
}
