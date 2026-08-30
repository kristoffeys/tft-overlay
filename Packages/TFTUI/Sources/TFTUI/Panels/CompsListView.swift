import SwiftUI

/// Scrollable comp list (#23): search by unit/trait/comp name, filter by
/// tier and playstyle.
public struct CompsListView: View {
    let comps: [Comp]
    let onSelect: (Comp) -> Void
    let onTogglePin: ((Comp) -> Void)?
    @ObservedObject private var pinnedStoreBox: PinnedCompsStoreBox

    @State private var searchText = ""
    @State private var tierFilter: Comp.Tier?
    @State private var playstyleFilter: Comp.Playstyle?
    /// Collapsed by default — see `CompsListChrome`.
    @State private var showsFilters = false

    /// - Parameter onTogglePin: when non-nil, the pin button reports the tap
    ///   here instead of mutating the store itself. A host that treats
    ///   pinning as a *commit* gesture — with consequences beyond the star,
    ///   like switching the whole overlay onto that build — has to own the
    ///   transition, and it cannot infer "pin" from "unpin" after the fact.
    ///   Left nil, the row keeps toggling the store directly.
    public init(
        comps: [Comp],
        pinnedStore: PinnedCompsStore? = nil,
        onTogglePin: ((Comp) -> Void)? = nil,
        onSelect: @escaping (Comp) -> Void = { _ in }
    ) {
        self.comps = comps
        pinnedStoreBox = PinnedCompsStoreBox(pinnedStore)
        self.onTogglePin = onTogglePin
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

    /// The build the player has committed to, i.e. the current pin — and only
    /// when it survives the active filters, since a player who is searching
    /// for something else is not asking about their own build.
    var committedBuild: Comp? {
        guard let id = pinnedStore?.currentPinnedID else { return nil }
        return filtered.first { $0.id == id }
    }

    /// Everything else, in the usual tier-then-name order.
    var otherComps: [Comp] {
        guard let committedBuild else { return filtered }
        return filtered.filter { $0.id != committedBuild.id }
    }

    public var body: some View {
        VStack(spacing: 0) {
            CompsListChrome(
                searchText: $searchText,
                tierFilter: $tierFilter,
                playstyleFilter: $playstyleFilter,
                showsFilters: $showsFilters
            )
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    // The committed build leads the list under its own
                    // heading. A filled star at the far right of one row
                    // among fifteen is not an answer to "which one is
                    // mine" — you have to scan for it. Sorting it out of
                    // the pack is.
                    if let committedBuild {
                        heading("Your build", color: TFTTheme.accent)
                        row(committedBuild, isCommitted: true)
                        heading("All comps", color: TFTTheme.textSecondary)
                    }
                    if filtered.isEmpty {
                        Text("No comps match.")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(TFTTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    }
                    ForEach(otherComps) { comp in
                        row(comp, isCommitted: false)
                    }
                }
                .padding(12)
            }
        }
        .background(TFTTheme.background)
    }

    private func row(_ comp: Comp, isCommitted: Bool) -> some View {
        // A tap gesture, not a Button: the row contains its own pin Button,
        // and a Button nested in another Button's label never receives the
        // click — the outer one owns the whole label as its hit area, so the
        // pin toggle silently did nothing here while working fine in the
        // detail header.
        CompRow(comp: comp, pinnedStore: pinnedStore, isCommitted: isCommitted, onTogglePin: togglePin)
            .contentShape(Rectangle())
            .onTapGesture { onSelect(comp) }
    }

    private func heading(_ text: String, color: Color) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .foregroundStyle(color)
            .padding(.top, 2)
    }

    private func togglePin(_ comp: Comp) {
        if let onTogglePin {
            onTogglePin(comp)
        } else {
            pinnedStore?.toggle(comp.id)
        }
    }
}

private struct CompRow: View {
    let comp: Comp
    let pinnedStore: PinnedCompsStore?
    let isCommitted: Bool
    let onTogglePin: (Comp) -> Void

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
                            onTogglePin(comp)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            isCommitted ? TFTTheme.elevatedBackground : TFTTheme.panelBackground,
            in: RoundedRectangle(cornerRadius: TFTTheme.cornerRadius, style: .continuous)
        )
        // A lit border, not a heavier fill alone: the row has to read as
        // "yours" from peripheral vision, and the accent is the one colour
        // this palette reserves for that.
        .overlay {
            if isCommitted {
                RoundedRectangle(cornerRadius: TFTTheme.cornerRadius, style: .continuous)
                    .strokeBorder(TFTTheme.accent, lineWidth: 1.5)
            }
        }
    }

    private var distinctTraits: [String] {
        Array(Set(comp.units.flatMap(\.traits))).sorted()
    }
}

#Preview {
    CompsListView(comps: (try? CompLoader.bundledFixtures()) ?? [])
        .frame(width: 380, height: 560)
}
