import SwiftUI
@testable import TFTUI
import XCTest

/// Layout regressions for the My Champions picker (#86) and the suggestions
/// it feeds (#87), at the width the overlay actually ships at.
///
/// The panel is not reachable from a tab yet, so these renders and the
/// SwiftUI preview are the only evidence its layout works. The states below
/// are the ones that break grids and wrapping text — nothing marked, exactly
/// one thing marked, everything marked, a champion name far longer than a
/// tile, and a suggestion whose missing list runs to several lines.
///
/// Scroll content is rendered as `rosterContent` / `suggestionsContent`,
/// never wrapped in the `ScrollView`: see the note in `ViewSnapshot`.
@MainActor
final class MyChampionsViewSnapshotTests: XCTestCase {
    private let expanded = CGSize(width: 460, height: 640)
    private let compact = CGSize(width: 300, height: 320)

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        suiteName = "MyChampionsViewSnapshotTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func store() -> OwnedChampionsStore {
        OwnedChampionsStore(defaults: defaults)
    }

    private func panel(
        comps: [Comp]? = nil,
        store: OwnedChampionsStore,
        onCommitBuild: @escaping (Comp) -> Void = { _ in }
    ) throws -> MyChampionsView {
        try MyChampionsView(
            comps: comps ?? CompLoader.bundledFixtures(),
            ownedStore: store,
            onCommitBuild: onCommitBuild
        )
    }

    private func assertContentFits(
        _ view: some View,
        width: CGFloat,
        rightMargin: CGFloat = 8,
        minimumInk: Double = 0.005,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let natural = try ViewSnapshot.measuredSize(of: view, proposedWidth: width)
        try assertRendersWithin(
            view,
            size: CGSize(width: width, height: natural.height),
            rightMargin: rightMargin,
            minimumInk: minimumInk,
            file: file,
            line: line
        )
    }

    // MARK: - The picker

    /// Nothing marked: every tile is in its dimmed state and the grid still
    /// has to lay out the whole set without spilling.
    func testEmptyRosterRendersEveryChampionInsideThePanel() throws {
        let view = try panel(store: store())
        XCTAssertEqual(view.ownedCount, 0)
        XCTAssertFalse(view.filteredChampions.isEmpty)
        try assertContentFits(view.rosterContent, width: expanded.width)
    }

    /// Exactly one marked. The lit state adds an accent ring drawn *outside*
    /// the portrait and a badge hung off its corner, either of which could
    /// push a tile past the grid column it lives in.
    func testASingleMarkedChampionDoesNotDisturbTheGrid() throws {
        let bare = try panel(store: store())
        let bareHeight = try ViewSnapshot.measuredSize(
            of: bare.rosterContent,
            proposedWidth: expanded.width
        ).height

        let marked = store()
        try marked.add(XCTUnwrap(bare.filteredChampions.first).name)
        let view = try panel(store: marked)

        XCTAssertEqual(view.ownedCount, 1)
        let markedHeight = try ViewSnapshot.measuredSize(
            of: view.rosterContent,
            proposedWidth: expanded.width
        ).height
        XCTAssertEqual(
            markedHeight,
            bareHeight,
            accuracy: 1,
            "Marking one champion reflowed the grid, so the lit state is a different size to the dim one"
        )
        try assertContentFits(view.rosterContent, width: expanded.width)
    }

    func testEveryChampionMarkedRendersInsideThePanel() throws {
        let all = store()
        let view = try panel(store: all)
        for champion in view.filteredChampions {
            all.add(champion.name)
        }
        XCTAssertEqual(all.ownedKeys.count, view.filteredChampions.count)
        try assertContentFits(view.rosterContent, width: expanded.width)
    }

    /// The picker also has to survive the 300pt compact panel, where the grid
    /// drops to five columns.
    func testThePickerFitsTheCompactPanelWidth() throws {
        let view = try panel(store: store())
        try assertContentFits(view.rosterContent, width: compact.width)
    }

    /// The head is above the scroll view, so clearing never depends on scroll
    /// position — and it must stay one row at both panel widths.
    func testTheHeadIsOneRowAtBothPanelWidths() throws {
        let marked = store()
        marked.add("Ashe")
        for view in try [panel(store: store()), panel(store: marked)] {
            for width in [expanded.width, compact.width] {
                let height = try ViewSnapshot.measuredSize(of: view.head, proposedWidth: width).height
                XCTAssertLessThanOrEqual(
                    height,
                    52,
                    "The picker head is \(height)pt at \(width)pt; search plus Clear should be one row"
                )
            }
        }
    }

    /// The width the picker tile is designed around, as a literal.
    ///
    /// Deliberately *not* written as `ChampionPickerTile.width`. A test that
    /// compares the constant to itself cannot fail when the constant changes,
    /// which is the only regression it was there to catch: setting
    /// `ChampionPickerTile.width = 520` used to leave the whole suite green.
    /// The column counts below are derived from this literal, so changing the
    /// tile width without meaning to fails here first.
    private let expectedTileWidth: CGFloat = 50

    /// The tile constant itself, checked against the literal the rest of this
    /// file reasons about.
    ///
    /// This is the assertion that guards the constant. It is separate from the
    /// intrinsic-width render below on purpose: that one guards a *different*
    /// bug (a tile that grows with its label), and conflating the two left
    /// both unguarded.
    func testThePickerTileWidthIsTheOneTheGridWasSizedFor() {
        XCTAssertEqual(
            ChampionPickerTile.width,
            expectedTileWidth,
            "ChampionPickerTile.width is \(ChampionPickerTile.width)pt, not the \(expectedTileWidth)pt "
                + "the picker grid's column counts were derived from"
        )
    }

    /// A champion name several times longer than its tile must not widen the
    /// tile, or every column after it staggers.
    ///
    /// Measured against an effectively unbounded proposal on purpose:
    /// `ImageRenderer` clamps a raster to the width it was proposed, so a
    /// too-wide tile rendered at 460pt comes back looking 460pt wide and the
    /// overflow is invisible. Offering it 2000pt and reading its *intrinsic*
    /// width is the only way to see the cell actually grow.
    ///
    /// Asserts the literal, not `ChampionPickerTile.width`: this test is
    /// load-bearing for "the `.frame(width:)` calls are still there", and it
    /// should fail for a changed constant too rather than silently following
    /// it.
    func testAChampionTileKeepsItsDeclaredWidthWhateverTheName() throws {
        for name in ["Vi", "Bartholomew Featherstonehaugh III", ""] {
            let tile = ChampionPickerTile(name: name, cost: 3, isOwned: true, onToggle: {})
            let size = try ViewSnapshot.measuredSize(of: tile, proposedWidth: 2000)
            XCTAssertEqual(
                size.width,
                expectedTileWidth,
                accuracy: 1,
                "A tile for \"\(name)\" measures \(size.width)pt, not \(expectedTileWidth)pt"
            )
        }
    }

    /// The grid has to give the narrow panel exactly five columns, and the
    /// expanded panel exactly seven.
    ///
    /// Exact counts, not `<=`: asserting only that five tiles *fit* passes for
    /// any tile narrower than the design as well, so shrinking the tile to
    /// 20pt — fourteen to a row, a completely different layout — used to pass.
    /// Below five the picker stops reading as a grid and becomes a list you
    /// scroll to find a 5-cost in; far above it the portraits are too small to
    /// recognise.
    func testThePickerGridColumnCountsAreTheDesignedOnes() {
        let spacing: CGFloat = 6
        for (panelWidth, expected) in [(compact.width, 5), (expanded.width, 7)] {
            let columns = GridColumns.count(
                tileWidth: ChampionPickerTile.width,
                contentWidth: panelWidth - 12 * 2,
                spacing: spacing
            )
            XCTAssertEqual(
                columns,
                expected,
                "A \(ChampionPickerTile.width)pt tile lays out \(columns) columns in the "
                    + "\(panelWidth)pt panel, not the \(expected) the picker is designed around"
            )
        }
    }

    /// The same name, rendered through the whole panel: the grid still lays
    /// out and nothing spills into the panel's margin.
    func testAVeryLongChampionNameStaysInsideThePanel() throws {
        let comps = try [
            CompFixture.dominantShape(
                id: "long-name",
                tier: .s,
                names: [
                    "Bartholomew Featherstonehaugh III", "Four", "Fourb", "Three",
                    "Two", "Twob", "One", "Oneb",
                ]
            ),
        ]
        let view = try panel(comps: comps, store: store())
        try assertContentFits(view.rosterContent, width: expanded.width, minimumInk: 0.002)
    }

    // MARK: - Suggestions

    func testSuggestionsWithNothingMarkedRenderTheirEmptyState() throws {
        let view = try panel(store: store())
        XCTAssertTrue(view.suggestions.isEmpty)
        try assertContentFits(view.suggestionsContent, width: expanded.width, minimumInk: 0.002)
    }

    /// A champion no comp uses: the ranking is empty even though the roster
    /// is not, and the panel has to say so rather than render nothing.
    func testAChampionInNoCompRendersTheNoMatchState() throws {
        let owned = store()
        owned.add("Nobodyhasthisunit")
        let view = try panel(store: owned)
        XCTAssertEqual(view.ownedCount, 1)
        XCTAssertTrue(view.suggestions.isEmpty)
        try assertContentFits(view.suggestionsContent, width: expanded.width, minimumInk: 0.002)
    }

    func testSuggestionsFromARealRosterRenderInsideThePanel() throws {
        let owned = store()
        for name in ["Diana", "Hecarim", "Tristana", "Ornn", "Vi", "Ashe"] {
            owned.add(name)
        }
        let view = try panel(store: owned)
        XCTAssertFalse(view.suggestions.isEmpty)
        try assertContentFits(view.suggestionsContent, width: expanded.width)
    }

    /// The number of suggestions the panel is allowed to draw, as a literal.
    ///
    /// Deliberately not `MyChampionsView.suggestionLimit`: the old assertion
    /// compared the constant to itself, so setting `suggestionLimit = 999` ran
    /// the whole suite green and the 28-row list the cap exists to prevent
    /// could come back silently.
    private let expectedSuggestionLimit = 12

    /// A full roster matches far more comps than the panel shows, and the cap
    /// is the only thing standing between the player and a list of every comp
    /// in the corpus.
    ///
    /// Marks every champion the corpus knows, which makes *every* comp match,
    /// then asserts the rendered count is exactly the literal cap. Guards the
    /// premise too — if the corpus ever shrank below the cap there would be
    /// nothing to truncate and the assertion would be vacuous.
    func testTheSuggestionListIsCappedWhateverTheRosterSize() throws {
        let owned = store()
        let view = try panel(store: owned)
        for champion in view.filteredChampions {
            owned.add(champion.name)
        }

        let corpus = try CompLoader.bundledFixtures()
        let matching = CompSuggestionRanking
            .rank(owned: owned.ownedKeys, comps: corpus)
            .filter { $0.matchedCount > 0 }
        XCTAssertGreaterThan(
            matching.count,
            expectedSuggestionLimit,
            "Only \(matching.count) comps match a full roster, so this test cannot see the cap work"
        )
        XCTAssertEqual(
            view.suggestions.count,
            expectedSuggestionLimit,
            "\(matching.count) comps match and the panel drew \(view.suggestions.count) of them; "
                + "it should draw exactly \(expectedSuggestionLimit)"
        )
    }

    /// The cap constant itself, against the literal the assertion above uses.
    func testTheSuggestionLimitIsTheOneTheListWasSizedFor() {
        XCTAssertEqual(
            MyChampionsView.suggestionLimit,
            expectedSuggestionLimit,
            "MyChampionsView.suggestionLimit is \(MyChampionsView.suggestionLimit), not "
                + "the \(expectedSuggestionLimit) the suggestions list is designed around"
        )
    }

    /// The named missing list is the actionable half of a suggestion, so it
    /// wraps instead of truncating. A comp missing eight long-named units is
    /// the case where that wrapping either works or spills off the panel.
    func testASuggestionWithALongMissingListWrapsInsteadOfSpilling() throws {
        let names = [
            "Bartholomew Featherstonehaugh", "Reginald Wintermantle", "Persephone Quicksilver",
            "Constantine Thistlewood", "Evangeline Nightingale", "Maximilian Ravensworth",
            "Anastasia Cloudbreaker", "Wolfgang Ashenvale",
        ]
        let comps = try [CompFixture.dominantShape(id: "long-missing", tier: .s, names: names)]
        let owned = store()
        owned.add(names[0])
        let view = try panel(comps: comps, store: owned)

        let suggestion = try XCTUnwrap(view.suggestions.first)
        XCTAssertEqual(suggestion.matchedCount, 1)
        XCTAssertEqual(suggestion.missingUnits.count, 7)
        try assertContentFits(view.suggestionsContent, width: expanded.width)
    }

    // MARK: - Clearing

    /// One gesture, and it has to survive a store whose in-memory snapshot
    /// disagrees with what is on disk.
    func testClearingEmptiesTheRosterAndThereforeTheSuggestions() throws {
        let owned = store()
        for name in ["Diana", "Hecarim", "Tristana"] {
            owned.add(name)
        }
        let view = try panel(store: owned)
        XCTAssertFalse(view.suggestions.isEmpty)

        owned.clear()

        XCTAssertEqual(view.ownedCount, 0)
        XCTAssertTrue(view.suggestions.isEmpty)
        XCTAssertTrue(OwnedChampionsStore(defaults: defaults).ownedKeys.isEmpty)
    }
}
