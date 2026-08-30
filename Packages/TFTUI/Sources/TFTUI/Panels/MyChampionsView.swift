import SwiftUI

/// The manual-input panel (#86) and its payoff (#87): mark the champions you
/// have, then see which comps you are already closest to.
///
/// The overlay cannot see the board — vision is Phase 2 (#43) — so the player
/// tells it, in a few taps, and that unlocks the most useful question in the
/// game. Input and results live in one panel because they are one loop: you
/// mark a unit, you look at what it changed, you mark another.
///
/// Layout decisions at the real 460pt panel width:
///
/// - Champions are grouped by cost, because that is how the shop is
///   organised, so a mid-game scan matches what is on screen in the game.
/// - A search field is right *here* and nowhere else in the overlay: this
///   panel is a picker you operate, not a surface you glance at.
/// - **Clear is a first-class control, not a menu item.** The roster
///   describes one game's bench and goes stale every single game, and a
///   stale roster is worse than an empty one because it lies about what is
///   reachable. It sits in the panel's head in both modes, lit whenever
///   there is anything to clear.
/// - Nothing essential is behind hover. A locked overlay is click-through
///   and receives no mouse events at all (#83).
///
/// **Honesty.** Suggestions are ordered by the units the player actually has;
/// `Comp.tier` only breaks near-ties, and it is authored metadata from a
/// scraped tier list (ADR 0004), not measured placement data. So a suggestion
/// reads "7/9 — missing Ashe, Kindred", never a percentage: the named gap is
/// what a player can act on, and a percentage would imply a statistic that
/// does not exist behind it.
public struct MyChampionsView: View {
    private let comps: [Comp]
    private let champions: [UnitReference]
    private let onCommitBuild: (Comp) -> Void
    @ObservedObject private var store: OwnedChampionsStore

    @State private var mode: Mode = .champions
    @State private var searchText = ""

    enum Mode: String, CaseIterable, Identifiable {
        case champions = "Champions"
        case suggestions = "Suggestions"

        var id: String {
            rawValue
        }
    }

    /// - Parameter onCommitBuild: fired when the player commits to a
    ///   suggestion. Deliberately a callback rather than a store write: the
    ///   host owns what "commit" means — switching the whole overlay onto
    ///   that build (Focus mode, #82) — and this panel must not decide that
    ///   for it.
    public init(
        comps: [Comp],
        ownedStore: OwnedChampionsStore,
        onCommitBuild: @escaping (Comp) -> Void = { _ in }
    ) {
        self.comps = comps
        champions = RosterIndex(comps: comps).units
        store = ownedStore
        self.onCommitBuild = onCommitBuild
    }

    public var body: some View {
        VStack(spacing: 0) {
            PanelTabBar(
                tabs: Mode.allCases,
                selection: mode,
                title: \.rawValue,
                style: .secondary
            ) { mode = $0 }
                .padding(.top, 4)
                .padding(.bottom, 4)
            head
            if mode == .suggestions, showsBasisNote {
                basisNote
            }
            ScrollView {
                switch mode {
                case .champions: rosterContent
                case .suggestions: suggestionsContent
                }
            }
        }
        .background(TFTTheme.background)
    }

    // MARK: - Head

    /// Search (picker mode only) alongside the clear control, which is
    /// present in both modes. Above the scroll view, so clearing a stale
    /// roster never depends on where the player happens to be scrolled.
    var head: some View {
        HStack(spacing: 8) {
            if mode == .champions {
                searchField
            } else {
                Text(ownedCount == 0
                    ? "Nothing marked yet"
                    : "From the \(ownedCount) champion\(ownedCount == 1 ? "" : "s") you marked")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(TFTTheme.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            clearButton
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(TFTTheme.textTertiary)
            TextField("Search champion", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundStyle(TFTTheme.textPrimary)
        }
        .font(.system(size: 13, weight: .medium))
        .padding(9)
        .background(
            TFTTheme.panelBackground,
            in: RoundedRectangle(cornerRadius: TFTTheme.smallCornerRadius, style: .continuous)
        )
    }

    var ownedCount: Int {
        store.ownedKeys.count
    }

    /// Lit and carrying its count whenever there is a roster to wipe, muted
    /// and inert when there is not — so "is anything marked" is answerable
    /// from the same glance that answers "how do I reset this".
    private var clearButton: some View {
        Button {
            store.clear()
            searchText = ""
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "trash")
                    .font(.system(size: 10, weight: .heavy))
                Text(ownedCount == 0 ? "Clear" : "Clear \(ownedCount)")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(ownedCount == 0 ? TFTTheme.textTertiary : .black.opacity(0.85))
            .padding(.horizontal, 9)
            .padding(.vertical, 9)
            .background(
                ownedCount == 0 ? TFTTheme.panelBackground : TFTTheme.accent,
                in: RoundedRectangle(cornerRadius: TFTTheme.smallCornerRadius, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .focusable(false)
        .disabled(ownedCount == 0)
        .accessibilityLabel("Clear the champions you marked")
        .help("Clear the champions you marked — this roster is only good for one game")
    }

    // MARK: - Champion picker

    var filteredChampions: [UnitReference] {
        guard !searchText.isEmpty else { return champions }
        return champions.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }

    var championsByCost: [(cost: Int, champions: [UnitReference])] {
        let grouped = Dictionary(grouping: filteredChampions, by: \.cost)
        return grouped.keys.sorted().map { (cost: $0, champions: grouped[$0] ?? []) }
    }

    /// Scroll content, split out so it can be rasterised without a scrolling
    /// host (see `ViewSnapshot`).
    var rosterContent: some View {
        LazyVStack(alignment: .leading, spacing: 10) {
            if filteredChampions.isEmpty {
                Text(champions.isEmpty ? "No champions loaded." : "No champion matches.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TFTTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            }
            ForEach(championsByCost, id: \.cost) { group in
                Text("\(group.cost)-Cost".uppercased())
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(TFTTheme.costColor(group.cost))
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: ChampionPickerTile.width), spacing: 6, alignment: .top),
                    ],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(group.champions) { champion in
                        ChampionPickerTile(
                            name: champion.name,
                            cost: champion.cost,
                            isOwned: store.isOwned(champion.name)
                        ) {
                            store.toggle(champion.name)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }

    // MARK: - Suggestions

    /// How many suggestions are worth showing.
    ///
    /// Two units into a game the ranking has something to say about nearly
    /// every comp in the corpus, and a list of thirty "1/8 — missing seven"
    /// rows buries the handful that are genuinely close. Browsing the whole
    /// corpus is what the comps list is for; this panel answers "what can I
    /// reach from here", and the answer is at the top.
    static let suggestionLimit = 12

    /// The comps the player is closest to, closest first.
    ///
    /// Comps with nothing matched are dropped rather than listed at the
    /// bottom: "0/8 — missing all eight" is not a suggestion.
    var suggestions: [CompSuggestion] {
        CompSuggestionRanking.rank(owned: store.ownedKeys, comps: comps)
            .filter { $0.matchedCount > 0 }
            .prefix(Self.suggestionLimit)
            .map { $0 }
    }

    var suggestionsContent: some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            if ownedCount == 0 {
                emptyNote(
                    "Mark the champions you have on the Champions tab, and every comp gets ranked "
                        + "by how close you already are to it."
                )
            } else if suggestions.isEmpty {
                emptyNote("No comp in this list uses any champion you marked.")
            } else {
                ForEach(suggestions) { suggestion in
                    CompSuggestionRow(suggestion: suggestion) {
                        onCommitBuild(suggestion.comp)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }

    /// Whether there is a ranking for the basis note to describe.
    ///
    /// The note explains an order, so it has nothing to say when there is
    /// nothing ordered — both empty states carry their own copy instead.
    var showsBasisNote: Bool {
        ownedCount > 0 && !suggestions.isEmpty
    }

    /// How many comps the roster matches at all, before `suggestionLimit`
    /// truncates the list.
    ///
    /// The count the player cannot otherwise see. With a full roster 36 comps
    /// match and 12 are drawn, and nothing in the panel used to hint that the
    /// other 24 existed — so the cap read as "these are the only reachable
    /// comps" rather than "these are the top of a longer list".
    var matchingCount: Int {
        CompSuggestionRanking.rank(owned: store.ownedKeys, comps: comps)
            .filter { $0.matchedCount > 0 }
            .count
    }

    /// Whether every drawn suggestion sits in the same overlap band, i.e.
    /// whether overlap decided any of this order at all.
    ///
    /// This is the full-roster case: mark all 63 champions and all 12 rows
    /// read "8/8 — You have every unit", every entry ties, and the order is
    /// then 100% authored tier list. Saying "near-ties fall back to the tier
    /// list" there understates it to the point of being wrong — *nothing* but
    /// the tier list is ordering the list. Uses the ranking's own band
    /// function so this cannot drift from the rule that actually sorted them.
    var suggestionsAreTiedOnOverlap: Bool {
        guard suggestions.count > 1 else { return false }
        let bands = Set(suggestions.map { CompSuggestionRanking.overlapBand($0.overlapScore) })
        return bands.count == 1
    }

    /// The basis note's copy, as a string so a test can read it.
    ///
    /// Pluralised, because exactly one match is a real state — mark a single
    /// champion no other comp uses and you get it — and "The 1 comps you are
    /// closest to" is the panel visibly not proofreading itself, in the one
    /// place whose whole job is to be believed. `head` above already gets
    /// this right for its champion count; this follows it.
    ///
    /// States the total whenever the cap hides anything, and says so plainly
    /// when overlap did not order the list. The honesty framing everywhere
    /// else in this panel is the reason to believe it here.
    var basisNoteText: String {
        let shown = suggestions.count
        let lead = if matchingCount > shown {
            "The \(shown) closest of \(matchingCount) matching comps"
        } else if shown == 1 {
            "The comp you are closest to"
        } else {
            "The \(shown) comps you are closest to"
        }

        let ordering = suggestionsAreTiedOnOverlap
            ? "These all match what you have equally well, so the order here is nothing but "
            + "this app's authored tier list — not win rates."
            : "Near-ties fall back to this app's authored tier list, not to win rates."

        return lead
            + ", by the units you have — weighted towards carries and expensive units. "
            + ordering
    }

    /// Says what the order is, in the panel, where a player can see it.
    ///
    /// Above the scroll view, like the openers panel's note and for the same
    /// reason: a disclaimer you have to scroll to is a disclaimer that does
    /// not exist. It used to be the first child of `suggestionsContent`, which
    /// put it inside the `ScrollView` and scrolled it out of sight after one
    /// flick. Rendered as its own member so a snapshot test can measure it —
    /// see `ViewSnapshot`'s note on `ScrollView` rasterising blank.
    var basisNote: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "info.circle")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(TFTTheme.textTertiary)
            Text(basisNoteText)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(TFTTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func emptyNote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(TFTTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 24)
    }
}

#Preview {
    MyChampionsView(
        comps: (try? CompLoader.bundledFixtures()) ?? [],
        ownedStore: OwnedChampionsStore(
            defaults: UserDefaults(suiteName: "MyChampionsView.preview") ?? .standard,
            storageKey: "preview.ownedChampions"
        )
    )
    .frame(width: 460, height: 640)
}
