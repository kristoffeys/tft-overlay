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

    /// What the panel actually gets: the expanded height minus the persistent
    /// tab bar and the panel's own bottom padding.
    private var glanceBudget: CGFloat {
        expanded.height - PanelTabBar<String>.height - 12
    }

    private func companion(_ comp: Comp, band: StageBand) -> StageCompanionView {
        StageCompanionView(comp: comp, band: band, advanceHint: "⌥S", onSelectBand: { _ in })
    }

    // MARK: - The glance fits

    func testEveryCompAndBandAnswersTheQuestionWithoutScrolling() throws {
        var worstLabel = ""
        var worstHeight: CGFloat = 0
        for comp in try CompLoader.bundledFixtures() {
            for band in StageBand.allCases {
                let height = try ViewSnapshot.measuredSize(
                    of: companion(comp, band: band).glance,
                    proposedWidth: expanded.width - 24
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
            "\(worstLabel) needs \(worstHeight)pt of the \(glanceBudget)pt above the fold"
        )
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

    // MARK: - The player who never advances the stage

    /// The failure that matters: someone ignores the control for a whole game.
    /// The default band must still be a complete view of the plan, so the full
    /// panel has to be taller than its own glance — that difference *is* the
    /// other two bands still being on screen below the fold.
    func testTheDefaultBandStillShowsTheWholePlanBelowTheFold() throws {
        let comp = try XCTUnwrap(CompLoader.bundledFixtures().first { $0.id == "blossom-spellweavers" })
        let view = companion(comp, band: .initial)
        let glance = try ViewSnapshot.measuredSize(of: view.glance, proposedWidth: expanded.width - 24).height
        let whole = try ViewSnapshot.measuredSize(of: view.content, proposedWidth: expanded.width).height

        XCTAssertGreaterThan(whole, glance + 60, "the other bands are not being drawn below the current one")
        try assertRendersWithin(
            view.content,
            size: CGSize(width: expanded.width, height: whole),
            rightMargin: 6
        )
    }
}
