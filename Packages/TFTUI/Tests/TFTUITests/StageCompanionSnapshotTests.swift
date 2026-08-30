import SwiftUI
@testable import TFTUI
import XCTest

/// Layout contract for the stage companion (#84).
///
/// The done criterion is "answers what do I do now *without scrolling*", which
/// is a height claim, and heights are exactly what `swift test` can check and
/// a screenshot can only sample. So the glance region — header, stage control,
/// current band — is measured for every comp in the corpus at every band, and
/// held under the panel it ships in.
@MainActor
final class StageCompanionSnapshotTests: XCTestCase {
    private let expanded = CGSize(width: 460, height: 640)
    private let narrowestWidth: CGFloat = 420

    /// Height OverlayKit's own chrome takes above hosted content, worst case
    /// (the panel is interactive, so the drag-handle header is on screen).
    ///
    /// `TFTUI` must not import `OverlayKit` (see `CLAUDE.md`), so this is a
    /// documented literal rather than a read of
    /// `OverlayChromeMetrics.interactiveHeaderHeight` — cross-checked against
    /// that real value by `StageCompanionHeightBudgetTests` in
    /// `Tests/TFTOverlayTests`, the one place both packages meet.
    private let assumedOverlayChromeHeaderHeight: CGFloat = 24

    /// What the panel actually gets above the fold: the expanded window
    /// height, minus OverlayKit's own chrome, the persistent tab bar, and the
    /// top padding `content` puts before `glance` — the space a player sees
    /// with no scrolling at all. #110: the old budget only subtracted the tab
    /// bar and padding, so it was permissive by exactly the chrome height.
    private var glanceBudget: CGFloat {
        expanded.height
            - assumedOverlayChromeHeaderHeight
            - PanelTabBar<String>.height
            - StageCompanionView.contentPadding
    }

    private func companion(_ comp: Comp, band: StageBand) -> StageCompanionView {
        StageCompanionView(comp: comp, band: band, advanceHint: "⌥S", onSelectBand: { _ in })
    }

    // MARK: - The glance fits

    /// Both widths the expanded panel can be: 460 by default, and 420 at the
    /// resize floor (`AppDelegate`'s `minSize`) — a narrower panel can wrap
    /// text taller, so a budget proven only at 460 could still clip after a
    /// resize.
    func testEveryCompAndBandAnswersTheQuestionWithoutScrolling() throws {
        for width in [expanded.width, narrowestWidth] {
            var worstLabel = ""
            var worstHeight: CGFloat = 0
            for comp in try CompLoader.bundledFixtures() {
                for band in StageBand.allCases {
                    let height = try ViewSnapshot.measuredSize(
                        of: companion(comp, band: band).glance,
                        proposedWidth: width - 2 * StageCompanionView.contentPadding
                    ).height
                    if height > worstHeight {
                        worstHeight = height
                        worstLabel = "\(comp.id) at \(band)"
                    }
                }
            }
            XCTAssertLessThanOrEqual(
                worstHeight,
                glanceBudget,
                "\(worstLabel) needs \(worstHeight)pt of the \(glanceBudget)pt above the fold at \(width)pt wide"
            )
        }
    }

    // MARK: - Item recipes cost the mid band only (#111)

    /// The mid band's itemise card shows each item's components. That is
    /// height, and this band is the one place in the companion where height
    /// is budgeted, so the claim is made against the same view with recipes
    /// switched off rather than against a number: a band that quietly went
    /// back to bare item icons measures identically and fails here.
    func testTheMidBandShowsRecipesUnderTheItemsToItemise() throws {
        var checked = 0
        for comp in try CompLoader.bundledFixtures() {
            guard BuildStagePlan(comp: comp).sections.contains(where: {
                $0.band == .mid && $0.itemisePriority != nil
            }) else { continue }
            checked += 1
            for width in [expanded.width, narrowestWidth] {
                let proposed = width - 2 * StageCompanionView.contentPadding
                let withRecipes = try ViewSnapshot.measuredSize(
                    of: companion(comp, band: .mid).glance,
                    proposedWidth: proposed
                ).height
                let without = try ViewSnapshot.measuredSize(
                    of: companion(comp, band: .mid).glance.tftItemRecipes(.empty),
                    proposedWidth: proposed
                ).height
                XCTAssertGreaterThanOrEqual(
                    withRecipes,
                    without + 22,
                    "\(comp.id) at mid, \(width)pt wide: \(withRecipes)pt with recipes against \(without)pt "
                        + "without — no component row is being drawn"
                )
            }
        }
        XCTAssertGreaterThan(checked, 0, "no comp in the corpus itemises at mid — this test proved nothing")
    }

    /// The other half of that claim, and the one #110 makes load-bearing:
    /// `elderwood-bloom` at Late measures exactly the 570pt budget, with zero
    /// margin. Recipes are not wanted there — Late is the final board and the
    /// pivots — and they must not have leaked in, so Early and Late have to
    /// measure *identically* with recipes on and off, at both widths, for
    /// every comp. An inline recipe anywhere in those bands breaks this.
    func testItemRecipesAddNoHeightToTheEarlyOrLateBands() throws {
        for comp in try CompLoader.bundledFixtures() {
            for band in [StageBand.early, .late] {
                for width in [expanded.width, narrowestWidth] {
                    let proposed = width - 2 * StageCompanionView.contentPadding
                    let withRecipes = try ViewSnapshot.measuredSize(
                        of: companion(comp, band: band).glance,
                        proposedWidth: proposed
                    ).height
                    let without = try ViewSnapshot.measuredSize(
                        of: companion(comp, band: band).glance.tftItemRecipes(.empty),
                        proposedWidth: proposed
                    ).height
                    XCTAssertEqual(
                        withRecipes,
                        without,
                        accuracy: 0.5,
                        "\(comp.id) at \(band), \(width)pt wide: recipes cost it \(withRecipes - without)pt, "
                            + "and this band has none to give"
                    )
                }
            }
        }
    }

    /// The panel must be visibly a different panel per band, not a header
    /// swap: if two bands measure identically the stage control is decorative.
    func testAdvancingTheBandChangesWhatTheGlanceShows() throws {
        let comp = try XCTUnwrap(CompLoader.bundledFixtures().first { $0.id == "blossom-spellweavers" })
        let heights = try StageBand.allCases.map { band in
            try ViewSnapshot.measuredSize(
                of: companion(comp, band: band).glance,
                proposedWidth: expanded.width - 24
            ).height
        }
        XCTAssertEqual(Set(heights).count, heights.count, "bands measured \(heights) — at least two are identical")

        // Distinct heights alone would also be satisfied by three bands that
        // each draw nothing but a differently-padded box, so each one has to
        // put ink on the screen too.
        for (band, height) in zip(StageBand.allCases, heights) {
            try assertRendersWithin(
                companion(comp, band: band).glance,
                size: CGSize(width: expanded.width - 24, height: height),
                rightMargin: 0,
                minimumInk: 0.01
            )
        }
    }

    // MARK: - Nothing overflows

    func testGlanceRendersInsideTheExpandedPanelWidthAtEveryBand() throws {
        let comp = try XCTUnwrap(CompLoader.bundledFixtures().first)
        for band in StageBand.allCases {
            let view = companion(comp, band: band).glance.padding(12)
            let height = try ViewSnapshot.measuredSize(of: view, proposedWidth: expanded.width).height
            try assertRendersWithin(
                view,
                size: CGSize(width: expanded.width, height: height),
                rightMargin: 6
            )
        }
    }

    /// Every fixture, not just the first: a long opener sentence or a wide
    /// component name overflows one card and no other.
    func testEveryFixtureFitsTheExpandedPanelWidth() throws {
        for comp in try CompLoader.bundledFixtures() {
            let content = companion(comp, band: .early).content
            let natural = try ViewSnapshot.measuredSize(of: content, proposedWidth: expanded.width)
            let raster = try ViewSnapshot.render(
                content,
                size: CGSize(width: expanded.width, height: natural.height)
            )
            XCTAssertTrue(
                raster.rightMarginIsClear(inset: 6),
                "\(comp.name) draws inside the panel's right margin at \(expanded.width)pt"
            )
        }
    }

    /// A plan row's notes sit in an `HStack` next to a `Spacer`, which offers
    /// the text its one-line ideal width and then ellipsises the remainder.
    /// That is silent loss of advice in the render — the same failure as
    /// dropping the row — and it showed up the moment two `5-2` rows merged
    /// into one sentence pair.
    func testALongPlanNoteWrapsRatherThanTruncating() throws {
        let width = expanded.width - 44
        let short = LevelPlanEntry(stage: "5-2", level: 9, notes: "Add Zyra.")
        let long = LevelPlanEntry(
            stage: "5-2",
            level: 9,
            notes: "At level 9 you can add: Ashe, Ivern, Maokai. At level 9 you can add: Alistar, Gnar."
        )
        let oneLine = try ViewSnapshot.measuredSize(
            of: LevelPlanRows(entries: [short]),
            proposedWidth: width
        ).height
        let wrapped = try ViewSnapshot.measuredSize(
            of: LevelPlanRows(entries: [long]),
            proposedWidth: width
        ).height
        XCTAssertGreaterThan(
            wrapped,
            oneLine,
            "a note too long for one line measured \(wrapped)pt against \(oneLine)pt — it is being truncated"
        )
    }

    // MARK: - Unplaced rows keep their own identity

    /// Two rows the scraper mangled the same way share `LevelPlanEntry.id`, and
    /// a `ForEach` over duplicate identities is undefined behaviour.
    ///
    /// Asserted on the identity, not on the render: today's macOS lays both
    /// rows out anyway (measured 30pt for one, 66pt for two, with or without
    /// this fix), so a height assertion here would pass in both directions and
    /// guard nothing. The height claim below is the part measurement *can*
    /// answer — that two rows occupy two rows' worth of space.
    func testRowsWithTheSameStageStringGetDistinctIdentities() throws {
        let first = LevelPlanEntry(stage: "bogus", level: 6, notes: "first")
        let second = LevelPlanEntry(stage: "bogus", level: 8, notes: "second")
        XCTAssertEqual(first.id, second.id, "the premise: the corpus can hand us two rows with one id")

        let rows = LevelPlanRows(entries: [first, second]).identifiedRows
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(Set(rows.map(\.id)).count, 2, "two rows must reach the ForEach as two identities")
        XCTAssertEqual(rows.map(\.entry.notes), ["first", "second"], "in corpus order")

        let width = expanded.width - 44
        let one = try ViewSnapshot.measuredSize(
            of: LevelPlanRows(entries: [first]),
            proposedWidth: width
        ).height
        let two = try ViewSnapshot.measuredSize(
            of: LevelPlanRows(entries: [first, second]),
            proposedWidth: width
        ).height
        XCTAssertGreaterThan(one, 0)
        XCTAssertGreaterThanOrEqual(two, one * 2, "two rows measured \(two)pt against \(one)pt for one")
    }

    // MARK: - The player who never advances the stage

    /// The failure that matters: someone ignores the control for a whole game.
    /// The default band must still be a complete view of the plan, with the
    /// other bands scannable below the current one.
    ///
    /// Asserted structurally first, because the height delta this used to
    /// assert on could not carry the claim: the page padding and the
    /// "Full build detail" button contribute 71pt of chrome by themselves, so
    /// `whole > glance + 60` passed with *every other band deleted from the
    /// view* — verified by mutation. The height claim is still here, but its
    /// threshold is now the measured height of the bands that are supposed to
    /// be down there.
    func testTheDefaultBandStillShowsTheWholePlanBelowTheFold() throws {
        for comp in try CompLoader.bundledFixtures() {
            let view = companion(comp, band: .initial)

            // Expectation taken from the plan, not from the view, so that the
            // height threshold below stays honest even if the view stops
            // offering the sections at all.
            let plan = BuildStagePlan(comp: comp)
            let expected = plan.sections.filter { $0.band != .initial }
            XCTAssertEqual(expected.count, plan.sections.count - 1)
            XCTAssertEqual(
                view.otherBandSections.map(\.band),
                expected.map(\.band),
                "\(comp.id): every band other than the current one has to be rendered"
            )

            let glance = try ViewSnapshot.measuredSize(of: view.glance, proposedWidth: expanded.width - 24).height
            let whole = try ViewSnapshot.measuredSize(of: view.content, proposedWidth: expanded.width).height
            // What the summaries for those bands actually need, measured at the
            // width they get inside the panel's 12pt padding. `content` stacks
            // them under the glance with spacing, so the whole panel cannot be
            // shorter than the two added together.
            let othersHeight = try expected.reduce(CGFloat.zero) { total, section in
                try total + ViewSnapshot.measuredSize(
                    of: StageBandSummary(section: section) {},
                    proposedWidth: expanded.width - 24
                ).height
            }
            XCTAssertGreaterThan(othersHeight, 0)
            XCTAssertGreaterThanOrEqual(
                whole,
                glance + othersHeight,
                """
                \(comp.id): the panel is \(whole)pt, the glance \(glance)pt and the other bands \
                \(othersHeight)pt — they are not being drawn below the current one
                """
            )

            try assertRendersWithin(
                view.content,
                size: CGSize(width: expanded.width, height: whole),
                rightMargin: 6
            )
        }
    }

    /// A summary row for a band the player is not in has to be a row with
    /// something in it, not a labelled empty box: two thirds of the corpus
    /// carries no row of its own for Early or Late, and the inherited level
    /// target is the whole reason those bands are still worth reading.
    func testEveryOtherBandSummaryDrawsSomething() throws {
        for comp in try CompLoader.bundledFixtures() {
            for section in companion(comp, band: .initial).otherBandSections {
                let summary = StageBandSummary(section: section) {}
                let height = try ViewSnapshot.measuredSize(
                    of: summary,
                    proposedWidth: expanded.width - 24
                ).height
                try assertRendersWithin(
                    summary,
                    size: CGSize(width: expanded.width - 24, height: height),
                    rightMargin: 4
                )
            }
        }
    }

    // MARK: - Nothing overflows the resized panel either (#100)

    /// `AppDelegate` lets the player resize the expanded panel down to 420pt
    /// wide (`minSize`); a fix verified only at the 460pt default could still
    /// overflow there. `measuredSize` does not clamp, so this is a direct test
    /// of the defect class `solar-riftbeasts` hit — a child wider than the
    /// width it was proposed — rather than a proxy for it: `ViewSnapshot.render`
    /// centres and double-clips an over-wide child, which is exactly how this
    /// defect passed the old raster-only harness before #95.
    ///
    /// Every comp and every band, at both widths, so this is the one place a
    /// future comp with an unusually large roster, item list or component set
    /// gets caught before it ships rather than after.
    func testEveryCompAndBandFitsBothPanelWidths() throws {
        for width in [expanded.width, 420] as [CGFloat] {
            for comp in try CompLoader.bundledFixtures() {
                for band in StageBand.allCases {
                    let measured = try ViewSnapshot.measuredSize(
                        of: companion(comp, band: band).content,
                        proposedWidth: width
                    )
                    XCTAssertLessThanOrEqual(
                        measured.width,
                        width + ViewSnapshot.widthTolerance,
                        "\(comp.id) at \(band) wants \(measured.width)pt inside a \(width)pt panel"
                    )
                }
            }
        }
    }
}
