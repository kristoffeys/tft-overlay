import SwiftUI
@testable import TFTUI
import XCTest

/// Layout regressions for the openers panel (#85) at the width the overlay
/// actually ships at.
///
/// The panel is not reachable from a tab yet, so these renders and the
/// SwiftUI preview are the only evidence its layout works — which makes the
/// states that break layouts (an empty corpus, a corpus with no S/A comp, a
/// very long comp or champion name) worth rendering explicitly rather than
/// trusting the happy path.
///
/// Scroll content is rendered as `OpenersView.content`, never wrapped in the
/// `ScrollView`: see the note in `ViewSnapshot`.
@MainActor
final class OpenersViewSnapshotTests: XCTestCase {
    private let expanded = CGSize(width: 460, height: 640)

    // MARK: - The real corpus

    func testOpenersContentRendersWithinTheExpandedPanelWidth() throws {
        let view = try OpenersView(comps: CompLoader.bundledFixtures())
        let natural = try ViewSnapshot.measuredSize(of: view.content, proposedWidth: expanded.width)

        XCTAssertEqual(natural.width, expanded.width, accuracy: 1)
        try assertRendersWithin(
            view.content,
            size: CGSize(width: expanded.width, height: natural.height),
            rightMargin: 8
        )
    }

    /// The disclaimer sits above the scroll view, so it is the one piece of
    /// this panel that is always on screen. If it stopped rendering — or
    /// spilled past the panel — the panel would be presenting an authored
    /// tier list as if it were placement data, which is the one thing #85
    /// says it must not do.
    func testTheBasisNoteRendersAboveTheScrollAndStaysInsideThePanel() throws {
        let view = try OpenersView(comps: CompLoader.bundledFixtures())
        let height = try ViewSnapshot.measuredSize(of: view.basisNote, proposedWidth: expanded.width).height

        XCTAssertGreaterThan(height, 0)
        XCTAssertLessThanOrEqual(
            height,
            60,
            "The always-on basis note is \(height)pt; it should be a two-line footnote, not a banner"
        )
        try assertRendersWithin(
            view.basisNote,
            size: CGSize(width: expanded.width, height: height),
            rightMargin: 8,
            // Two lines of 10pt text in a 460pt strip is sparse ink.
            minimumInk: 0.002
        )
    }

    /// The panel draws the two rankings in two different visual forms
    /// precisely because they disagree. If they ever stopped disagreeing on
    /// the real corpus, the second section would be a duplicate of the first
    /// and the design would be lying about why it exists.
    func testTheTwoRankingsDisagreeOnTheRealCorpus() throws {
        let view = try OpenersView(comps: CompLoader.bundledFixtures())
        let byPresence = view.metaPickups.map(\.name)
        let byFlexibility = view.flexibleUnits.map(\.name)

        XCTAssertFalse(byPresence.isEmpty)
        XCTAssertFalse(byFlexibility.isEmpty)
        XCTAssertNotEqual(
            byPresence,
            byFlexibility,
            "Meta pickups and door-openers rank identically, so the panel shows one ranking twice"
        )
    }

    /// Slam and hold have to be a real split, not a label on one bucket.
    func testComponentsSplitIntoBothSlamAndHoldOnTheRealCorpus() throws {
        let view = try OpenersView(comps: CompLoader.bundledFixtures())
        XCTAssertFalse(view.slamComponents.isEmpty, "Nothing is worth slamming, which cannot be right")
        XCTAssertFalse(view.holdComponents.isEmpty, "Every component is a slam, so the split says nothing")
        XCTAssertEqual(
            view.slamComponents.count + view.holdComponents.count,
            try OpenerIndex(comps: CompLoader.bundledFixtures()).componentDemand.count
        )
    }

    // MARK: - The states that break layouts

    func testAnEmptyCorpusRendersItsEmptyStatesInsideThePanel() throws {
        let view = OpenersView(comps: [])
        XCTAssertTrue(view.metaPickups.isEmpty)
        XCTAssertTrue(view.flexibleUnits.isEmpty)

        let natural = try ViewSnapshot.measuredSize(of: view.content, proposedWidth: expanded.width)
        try assertRendersWithin(
            view.content,
            size: CGSize(width: expanded.width, height: natural.height),
            rightMargin: 8,
            minimumInk: 0.002
        )
    }

    /// A corpus with nothing above B tier: the meta ranking empties out while
    /// the flexibility ranking stays full, which is the asymmetry the two
    /// sections exist to show.
    func testACorpusWithNoTopTierCompStillRendersTheFlexibilityRanking() throws {
        let comps = try (1 ... 3).map { number in
            try CompFixture.dominantShape(
                id: "b-tier-\(number)",
                tier: .b,
                names: ["Carry\(number)", "Four\(number)", "Four\(number)b", "Three", "Two", "Twob", "One", "Oneb"]
            )
        }
        let view = OpenersView(comps: comps)

        XCTAssertTrue(view.metaPickups.isEmpty, "B-tier comps carry no S/A weight")
        XCTAssertFalse(view.flexibleUnits.isEmpty, "Shared-comp counts are tier-blind and should survive")

        let natural = try ViewSnapshot.measuredSize(of: view.content, proposedWidth: expanded.width)
        try assertRendersWithin(
            view.content,
            size: CGSize(width: expanded.width, height: natural.height),
            rightMargin: 8,
            minimumInk: 0.002
        )
    }

    /// A comp name long enough to blow out a capsule, and a champion name
    /// long enough to blow out a tile. Both are one bad scrape away.
    func testLongCompAndChampionNamesStayInsideThePanel() throws {
        let comps = try [Comp.Tier.s, .a, .b].enumerated().map { index, tier in
            try CompFixture.dominantShape(
                id: "Extraordinarily Overlong Reroll Comp Name \(index)",
                tier: tier,
                names: [
                    "Carry", "Four", "Fourb", "Three",
                    "Bartholomew Featherstonehaugh", "Twob", "One", "Oneb",
                ]
            )
        }
        let view = OpenersView(comps: comps)
        let natural = try ViewSnapshot.measuredSize(of: view.content, proposedWidth: expanded.width)
        let raster = try ViewSnapshot.render(
            view.content,
            size: CGSize(width: expanded.width, height: natural.height)
        )
        XCTAssertTrue(
            raster.rightMarginIsClear(inset: 8),
            "A long comp or champion name draws into the panel's right margin at \(expanded.width)pt"
        )
    }

    /// The widths the two opener tiles are designed around, as literals.
    ///
    /// Deliberately *not* `FlexibleUnitTile.width` / `ComponentDemandTile.width`.
    /// A test that compares a constant to itself cannot fail when the constant
    /// changes, which is the only regression it was there to catch — the same
    /// flaw that let `ChampionPickerTile.width = 520` through the whole suite.
    private let expectedFlexibleTileWidth: CGFloat = 62
    private let expectedComponentTileWidth: CGFloat = 66

    /// The tile constants themselves, against the literals the grid column
    /// counts below are derived from.
    ///
    /// Separate from the intrinsic-width render on purpose: that one guards a
    /// *different* bug (a tile that grows with its label rather than clamping
    /// to `.frame(width:)`), and conflating the two left both unguarded.
    func testTheOpenerTileWidthsAreTheOnesTheGridsWereSizedFor() {
        XCTAssertEqual(
            FlexibleUnitTile.width,
            expectedFlexibleTileWidth,
            "FlexibleUnitTile.width is \(FlexibleUnitTile.width)pt, not the "
                + "\(expectedFlexibleTileWidth)pt the grid's column count was derived from"
        )
        XCTAssertEqual(
            ComponentDemandTile.width,
            expectedComponentTileWidth,
            "ComponentDemandTile.width is \(ComponentDemandTile.width)pt, not the "
                + "\(expectedComponentTileWidth)pt the grid's column count was derived from"
        )
    }

    /// A tile that grows with its label staggers every column after it.
    ///
    /// Measured against an effectively unbounded proposal on purpose:
    /// `ImageRenderer` clamps a raster to the width it was proposed, so a
    /// too-wide tile rendered at 460pt comes back looking 460pt wide and the
    /// overflow is invisible. Offering 2000pt reads the *intrinsic* width.
    ///
    /// Asserts the literals, not the constants: this test is load-bearing for
    /// "the `.frame(width:)` calls are still there", and it should fail for a
    /// changed constant too rather than silently following it.
    func testOpenerTilesKeepTheirDeclaredWidthWhateverTheLabel() throws {
        for name in ["Vi", "Bartholomew Featherstonehaugh III"] {
            let unit = OpenerIndex.UnitPresence(
                name: name,
                cost: 2,
                weightedPresence: 9,
                sharedCompCount: 12
            )
            let tile = FlexibleUnitTile(
                unit: unit,
                leadsTo: [OpenerIndex.CompSummary(id: "a", name: "A Comp", tier: .s)]
            )
            let size = try ViewSnapshot.measuredSize(of: tile, proposedWidth: 2000)
            XCTAssertEqual(
                size.width,
                expectedFlexibleTileWidth,
                accuracy: 1,
                "The tile for \"\(name)\" measures \(size.width)pt, not \(expectedFlexibleTileWidth)pt"
            )
        }

        for component in ["B.F. Sword", "Needlessly Large Rod"] {
            let tile = ComponentDemandTile(
                component: OpenerIndex.ComponentDemand(componentName: component, demand: 14)
            )
            let size = try ViewSnapshot.measuredSize(of: tile, proposedWidth: 2000)
            XCTAssertEqual(
                size.width,
                expectedComponentTileWidth,
                accuracy: 1,
                "The tile for \"\(component)\" measures \(size.width)pt, "
                    + "not \(expectedComponentTileWidth)pt"
            )
        }
    }

    /// Six tiles a row is what makes the two grids read as grids rather than
    /// as another list; at five they start looking like the section above.
    ///
    /// Exact counts, not `<=`: asserting only that six tiles *fit* passes for
    /// any tile narrower than the design too, so shrinking a tile to 20pt —
    /// fourteen to a row — used to pass this.
    func testBothOpenerGridsLayOutSixTilesAcrossTheExpandedPanel() {
        let contentWidth = expanded.width - 12 * 2
        let spacing: CGFloat = 6
        for tileWidth in [FlexibleUnitTile.width, ComponentDemandTile.width] {
            let columns = GridColumns.count(
                tileWidth: tileWidth,
                contentWidth: contentWidth,
                spacing: spacing
            )
            XCTAssertEqual(
                columns,
                6,
                "A \(tileWidth)pt tile lays out \(columns) columns in the \(expanded.width)pt panel, "
                    + "not the six the opener grids are designed around"
            )
        }
    }
}
