@testable import TFTUI
import XCTest

final class CompUnitIndexTests: XCTestCase {
    private let ashe = CompUnit(name: "Ashe", cost: 5, starTarget: 2, role: .carry, traits: ["Blossom", "Hunter"])
    private let ornn = CompUnit(name: "Ornn", cost: 4, starTarget: 2, role: .frontline, traits: ["Elderwood"])
    private let asheCarry = CompCarry(
        unit: "Ashe",
        itemPriority: ["Infinity Edge", "Giant Slayer", "Runaan's Hurricane"],
        itemNotes: "Runaan's first into wide boards."
    )

    private var index: CompUnitIndex {
        CompUnitIndex(units: [ashe, ornn], carries: [asheCarry])
    }

    func testSummaryForCarryCarriesItemPriorityAndNotes() {
        let summary = index.summary(for: "Ashe")

        XCTAssertEqual(summary.name, "Ashe")
        XCTAssertEqual(summary.cost, 5)
        XCTAssertEqual(summary.role, .carry)
        XCTAssertEqual(summary.starTarget, 2)
        XCTAssertEqual(summary.itemPriority, ["Infinity Edge", "Giant Slayer", "Runaan's Hurricane"])
        XCTAssertEqual(summary.itemNotes, "Runaan's first into wide boards.")
        XCTAssertTrue(summary.hasItemPriority)
    }

    func testSummaryForNonCarryKeepsIdentityButHasNoItems() {
        let summary = index.summary(for: "Ornn")

        XCTAssertEqual(summary.name, "Ornn")
        XCTAssertEqual(summary.role, .frontline)
        XCTAssertEqual(summary.starTarget, 2)
        XCTAssertTrue(summary.itemPriority.isEmpty)
        XCTAssertNil(summary.itemNotes)
        XCTAssertFalse(summary.hasItemPriority)
    }

    /// A board grid can name a unit the roster doesn't list; the hover card
    /// should still identify it rather than vanish.
    func testSummaryForUnknownNameFallsBackToTheNameAlone() {
        let summary = index.summary(for: "Nobody")

        XCTAssertEqual(summary.name, "Nobody")
        XCTAssertNil(summary.cost)
        XCTAssertNil(summary.role)
        XCTAssertNil(summary.starTarget)
        XCTAssertFalse(summary.hasItemPriority)
    }

    func testLookupToleratesCasingDifferences() {
        let summary = index.summary(for: "ashe")

        XCTAssertEqual(summary.name, "Ashe", "the canonical roster spelling wins over the queried one")
        XCTAssertEqual(summary.itemPriority.first, "Infinity Edge")
        XCTAssertNotNil(index.unit(named: "ORNN"))
        XCTAssertNotNil(index.carry(named: "ASHE"))
    }

    func testEmptyIndexAnswersWithNameOnly() {
        let summary = CompUnitIndex.empty.summary(for: "Ashe")

        XCTAssertEqual(summary.name, "Ashe")
        XCTAssertFalse(summary.hasItemPriority)
    }

    func testPriorityLabelsMatchTheCarryCardWording() {
        XCTAssertEqual(UnitItemSummary.priorityLabel(0), "BiS")
        XCTAssertEqual(UnitItemSummary.priorityLabel(1), "Alt 1")
        XCTAssertEqual(UnitItemSummary.priorityLabel(2), "Alt 2")
    }

    /// The index is what the detail view hands the board grid, so every
    /// itemised carry in a real fixture has to resolve through it.
    func testFixtureCarriesResolveThroughTheIndex() throws {
        let comps = try CompLoader.bundledFixtures()
        XCTAssertFalse(comps.isEmpty)

        for comp in comps {
            let index = CompUnitIndex(comp: comp)
            for pair in comp.carryUnits {
                let summary = index.summary(for: pair.unit.name)
                XCTAssertEqual(summary.itemPriority, pair.carry.itemPriority, "\(comp.id)/\(pair.unit.name)")
                XCTAssertEqual(summary.starTarget, pair.unit.starTarget)
            }
            for name in comp.boardPositioning.grid.flatMap({ $0 }).compactMap({ $0 }) {
                XCTAssertNotNil(index.unit(named: name), "\(comp.id) board names \(name), which is not in its roster")
            }
        }
    }
}
