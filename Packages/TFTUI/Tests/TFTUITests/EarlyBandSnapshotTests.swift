import SwiftUI
@testable import TFTUI
import XCTest

/// The early band draws the whole build, not only the shopping list (#107).
///
/// Its own file rather than more of `StageCompanionSnapshotTests`, which owns
/// the panel-wide height and width budgets. These are claims about one card:
/// that the expensive half of the roster is on screen, that a transitional
/// opener is visibly marked, and that cost is stated as a number.
@MainActor
final class EarlyBandSnapshotTests: XCTestCase {
    private let expanded = CGSize(width: 460, height: 640)

    private func earlyDetail(_ comp: Comp) -> StageBandDetail {
        StageBandDetail(
            section: BuildStagePlan(comp: comp).section(for: .early),
            comp: comp,
            unitIndex: CompUnitIndex(comp: comp)
        )
    }

    /// The maintainer's request: a 4-cost rolling through the shop in stage 2
    /// has to be recognisable from this band.
    ///
    /// Measured as a height delta against the same comp with nothing but its
    /// openers, because that is the claim a render can carry: if the expensive
    /// half of the roster is not drawn, the two measure the same. Verified by
    /// mutation — deleting the roster from `buyNowCard` collapses the delta to
    /// 0pt and fails here.
    func testEarlyBandDrawsTheExpensiveHalfOfTheBuildToo() throws {
        let openers = ["Ornn", "Xayah", "Alistar"]
        // Both comps carry a carry with the same best-in-slot item, so the
        // components card is identical in each and the delta below can only
        // come from the roster. Without that the earlier version of this test
        // passed with the roster deleted: the expensive comp gained a
        // components card the cheap one never had, and *that* was the delta.
        let openersOnly = try CompFixture.make(
            id: "openers-only",
            tier: .a,
            units: openers.map { CompFixture.unit($0, cost: 1) },
            carries: [CompCarry(unit: "Ornn", itemPriority: ["Infinity Edge"])],
            earlyUnits: openers,
            earlyOpener: "Open Ornn, Xayah, Alistar."
        )
        let wholeBuild = try CompFixture.make(
            id: "whole-build",
            tier: .a,
            units: openers.map { CompFixture.unit($0, cost: 1) } + [
                CompFixture.unit("Hecarim", cost: 3),
                CompFixture.unit("Ezreal", cost: 4, role: .carry),
                CompFixture.unit("Gnar", cost: 5),
            ],
            carries: [CompCarry(unit: "Ezreal", itemPriority: ["Infinity Edge"])],
            earlyUnits: openers,
            earlyOpener: "Open Ornn, Xayah, Alistar."
        )

        let width = expanded.width - 24
        let shopping = try ViewSnapshot.measuredSize(of: earlyDetail(openersOnly), proposedWidth: width).height
        let whole = try ViewSnapshot.measuredSize(of: earlyDetail(wholeBuild), proposedWidth: width).height
        XCTAssertGreaterThan(
            whole,
            shopping + 20,
            "the band measured \(whole)pt with three 3-to-5-costs added and \(shopping)pt without them — "
                + "the rest of the build is not being drawn"
        )
        try assertRendersWithin(
            earlyDetail(wholeBuild),
            size: CGSize(width: width, height: whole),
            rightMargin: 0
        )
    }

    /// A transitional opener has to be *visibly* marked, not only flagged in
    /// the model: a player who buys Cinderling on the panel's instruction and
    /// then cannot find it in the build has been told half the truth.
    func testATransitionalOpenerIsMarkedOnScreen() throws {
        let board = [CompFixture.unit("Gromp", cost: 2), CompFixture.unit("Akali", cost: 1, role: .carry)]
        let allInBuild = try CompFixture.make(
            id: "no-transitional",
            tier: .a,
            units: board,
            earlyUnits: ["Gromp"],
            earlyOpener: "Open Gromp."
        )
        let withTransitional = try CompFixture.make(
            id: "with-transitional",
            tier: .a,
            units: board,
            earlyUnits: ["Gromp", "Cinderling"],
            earlyOpener: "Open Gromp, Cinderling."
        )

        let width = expanded.width - 24
        let plain = try ViewSnapshot.measuredSize(of: earlyDetail(allInBuild), proposedWidth: width).height
        let marked = try ViewSnapshot.measuredSize(of: earlyDetail(withTransitional), proposedWidth: width).height
        XCTAssertGreaterThan(
            marked,
            plain,
            "a band with a transitional opener measured \(marked)pt against \(plain)pt without one — "
                + "the TEMP chip and its footnote are not being drawn"
        )
    }

    /// Cost has to be a number, not only the portrait's border tint: the
    /// question in the shop is "can I hit this yet", and a locked panel takes
    /// no mouse events, so it cannot be a tooltip (#83).
    func testTheRosterStatesCostsAsInk() throws {
        let entries = [1, 2, 3, 4, 5].map { cost in
            CompRosterEntry(unit: CompFixture.unit("Ashe\(cost)", cost: cost))
        }
        let size = CGSize(width: 240, height: 34)
        let withCosts = try ViewSnapshot.render(
            CompRosterGrid(entries: entries, portraitSize: 30, spacing: 5, showsCosts: true, showsItems: false),
            size: size
        )
        let without = try ViewSnapshot.render(
            CompRosterGrid(entries: entries, portraitSize: 30, spacing: 5, showsCosts: false, showsItems: false),
            size: size
        )
        // Not an ink-coverage comparison: the badge draws dark digits on a
        // bright capsule over an already-bright cost tile, so it *lowers*
        // coverage (measured 0.634 against 0.643) and a coverage floor would
        // read the badge as less drawing rather than more. What is unambiguous
        // is that the bottom-left corner of the first cell — where the badge
        // sits — changed at all.
        var changed = 0
        for y in 17 ..< 34 {
            for x in 0 ..< 30 where abs(withCosts.luminance(x: x, y: y) - without.luminance(x: x, y: y)) > 0.05 {
                changed += 1
            }
        }
        XCTAssertGreaterThan(changed, 20, "the cost badge drew nothing over the first cell (\(changed) pixels differ)")
    }
}
