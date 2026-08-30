import SwiftUI
@testable import TFTUI
import XCTest

/// What the early band draws for the units it tells the player to buy (#107).
///
/// Its own file rather than more of `StageCompanionSnapshotTests`, which owns
/// the panel-wide height and width budgets. These are claims about one card.
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
}
