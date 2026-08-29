import SwiftUI

/// Scrollable comp list (#23): search by unit/trait/comp name, filter by
/// tier and playstyle.
public struct CompsListView: View {
    let comps: [Comp]
    let onSelect: (Comp) -> Void

    @State private var searchText = ""
    @State private var tierFilter: Comp.Tier?
    @State private var playstyleFilter: Comp.Playstyle?

    public init(comps: [Comp], onSelect: @escaping (Comp) -> Void = { _ in }) {
        self.comps = comps
        self.onSelect = onSelect
    }

    private var filtered: [Comp] {
        comps
            .filter { comp in
                (tierFilter == nil || comp.tier == tierFilter)
                    && (playstyleFilter == nil || comp.playstyle == playstyleFilter)
                    && (searchText.isEmpty || comp.searchableText.contains(searchText.lowercased()))
            }
            .sorted { lhs, rhs in
                lhs.tier == rhs.tier ? lhs.name < rhs.name : lhs.tier < rhs.tier
            }
    }

    public var body: some View {
        VStack(spacing: 0) {
            searchField
            filterBar
            ScrollView {
                LazyVStack(spacing: 8) {
                    if filtered.isEmpty {
                        Text("No comps match.")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(TFTTheme.textSecondary)
                            .padding(.top, 40)
                    }
                    ForEach(filtered) { comp in
                        Button {
                            onSelect(comp)
                        } label: {
                            CompRow(comp: comp)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
            }
        }
        .background(TFTTheme.background)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(TFTTheme.textSecondary)
            TextField("Search unit, trait, or comp", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundStyle(TFTTheme.textPrimary)
        }
        .font(.system(size: 13, weight: .medium))
        .padding(9)
        .background(
            TFTTheme.panelBackground,
            in: RoundedRectangle(cornerRadius: TFTTheme.smallCornerRadius, style: .continuous)
        )
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            filterRow(title: "Tier") {
                FilterChip(label: "All", isSelected: tierFilter == nil) { tierFilter = nil }
                ForEach(Comp.Tier.allCases, id: \.self) { tier in
                    FilterChip(label: tier.rawValue, isSelected: tierFilter == tier, color: TFTTheme.tierColor(tier)) {
                        tierFilter = (tierFilter == tier) ? nil : tier
                    }
                }
            }
            filterRow(title: "Style") {
                FilterChip(label: "All", isSelected: playstyleFilter == nil) { playstyleFilter = nil }
                ForEach(Comp.Playstyle.allCases, id: \.self) { style in
                    FilterChip(label: style.displayName, isSelected: playstyleFilter == style) {
                        playstyleFilter = (playstyleFilter == style) ? nil : style
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func filterRow(title: String, @ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(TFTTheme.textSecondary)
                .frame(width: 34, alignment: .leading)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) { content() }
            }
        }
    }
}

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    var color: Color = TFTTheme.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? .black.opacity(0.85) : TFTTheme.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isSelected ? color : TFTTheme.elevatedBackground, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct CompRow: View {
    let comp: Comp

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            TierBadge(comp.tier)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(comp.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(TFTTheme.textPrimary)
                    DifficultyIndicator(comp.difficulty)
                    Spacer()
                    Text(comp.playstyle.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(TFTTheme.textSecondary)
                }
                HStack(spacing: 6) {
                    ForEach(comp.carryUnits, id: \.unit.id) { pair in
                        UnitPortraitPlaceholder(name: pair.unit.name, cost: pair.unit.cost, size: 34)
                    }
                    Spacer(minLength: 8)
                    TraitTagRow(distinctTraits)
                }
            }
        }
        .padding(10)
        .background(
            TFTTheme.panelBackground,
            in: RoundedRectangle(cornerRadius: TFTTheme.cornerRadius, style: .continuous)
        )
    }

    private var distinctTraits: [String] {
        Array(Set(comp.units.flatMap(\.traits))).sorted()
    }
}

#Preview {
    CompsListView(comps: (try? CompLoader.bundledFixtures()) ?? [])
        .frame(width: 380, height: 560)
}
