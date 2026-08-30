import SwiftUI

/// Scrollable comp list (#23): search by unit/trait/comp name, filter by
/// tier and playstyle.
public struct CompsListView: View {
    let comps: [Comp]
    let onSelect: (Comp) -> Void
    @ObservedObject private var pinnedStoreBox: PinnedCompsStoreBox

    @State private var searchText = ""
    @State private var tierFilter: Comp.Tier?
    @State private var playstyleFilter: Comp.Playstyle?

    public init(comps: [Comp], pinnedStore: PinnedCompsStore? = nil, onSelect: @escaping (Comp) -> Void = { _ in }) {
        self.comps = comps
        pinnedStoreBox = PinnedCompsStoreBox(pinnedStore)
        self.onSelect = onSelect
    }

    private var pinnedStore: PinnedCompsStore? {
        pinnedStoreBox.store
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
                        // A tap gesture, not a Button: the row contains its
                        // own pin Button, and a Button nested in another
                        // Button's label never receives the click — the
                        // outer one owns the whole label as its hit area,
                        // so the pin toggle silently did nothing here while
                        // working fine in the detail header.
                        CompRow(comp: comp, pinnedStore: pinnedStore)
                            .contentShape(Rectangle())
                            .onTapGesture { onSelect(comp) }
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
                .foregroundStyle(TFTTheme.textTertiary)
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
        .padding(.top, 4)
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
    let pinnedStore: PinnedCompsStore?

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
                    if let pinnedStore {
                        PinToggleButton(isPinned: pinnedStore.isPinned(comp.id)) {
                            pinnedStore.toggle(comp.id)
                        }
                    }
                }
                // The full roster, not just the carries: a row that shows
                // two portraits can't answer "is this the comp holding the
                // units I already have", which is the question a player
                // scans this list with.
                CompRosterGrid(comp: comp, portraitSize: 34, spacing: 4)
                // Ranked by how many of this comp's units carry the trait, so
                // the row always shows what the comp *is* ("Elderwood",
                // "Executioner") and drops the one-unit strays — not the
                // other way round, which is what plain alphabetical order
                // gave us.
                TraitTagRow(distinctTraits, priority: TraitRelevance.weights(in: comp))
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
