import CoreGraphics
@testable import TFTUI
import XCTest

final class CompRosterTests: XCTestCase {
    private func unit(
        _ name: String,
        cost: Int,
        role: CompUnit.Role = .frontline,
        starTarget: Int = 2
    ) -> CompUnit {
        CompUnit(name: name, cost: cost, starTarget: starTarget, role: role, traits: ["Trait"])
    }

    func testItemisedCarriesLeadInCompCarryOrder() {
        let entries = CompRoster.entries(
            units: [
                unit("Tank", cost: 4),
                unit("Second", cost: 1, role: .carry),
                unit("Primary", cost: 3, role: .carry),
            ],
            carries: [
                CompCarry(unit: "Primary", itemPriority: ["Infinity Edge"]),
                CompCarry(unit: "Second", itemPriority: ["Guinsoo's Rageblade"]),
            ]
        )

        XCTAssertEqual(
            entries.map(\.unit.name),
            ["Primary", "Second", "Tank"],
            "carries lead in the comp's own carry order, ahead of a more expensive non-carry"
        )
    }

    func testNonCarriesFollowByDescendingCostThenName() {
        let entries = CompRoster.entries(
            units: [
                unit("Alpha", cost: 1),
                unit("Zeta", cost: 5),
                unit("Beta", cost: 5),
                unit("Gamma", cost: 3),
            ],
            carries: []
        )

        XCTAssertEqual(entries.map(\.unit.name), ["Beta", "Zeta", "Gamma", "Alpha"])
    }

    /// The user-visible promise of "the list should show full rosters":
    /// every comp draws every unit, never a carry-only subset.
    func testEveryUnitOfEveryFixtureIsRepresentedExactlyOnce() throws {
        for comp in try CompLoader.bundledFixtures() {
            XCTAssertEqual(
                CompRoster.entries(for: comp).map(\.unit.name).sorted(),
                comp.units.map(\.name).sorted(),
                "\(comp.id) roster must be the whole roster, not a subset"
            )
        }
    }

    func testOnlyItemisedUnitsCarryItems() {
        let entries = CompRoster.entries(
            units: [unit("Carry", cost: 4, role: .carry), unit("Tank", cost: 2)],
            carries: [CompCarry(unit: "Carry", itemPriority: ["Infinity Edge", "Bloodthirster"])]
        )

        XCTAssertEqual(entries.first?.items, ["Infinity Edge", "Bloodthirster"])
        XCTAssertEqual(entries.first?.isCarry, true)
        XCTAssertEqual(entries.last?.items.isEmpty, true, "a non-carry must draw no item slots at all")
        XCTAssertEqual(entries.last?.isCarry, false)
    }

    /// A `carries` entry with no items says nothing about what to buy, so it
    /// must not jump ahead of the units a player actually looks for.
    func testCarryWithoutItemsDoesNotLead() {
        let entries = CompRoster.entries(
            units: [unit("Empty", cost: 1, role: .carry), unit("Expensive", cost: 5)],
            carries: [CompCarry(unit: "Empty", itemPriority: [])]
        )

        XCTAssertEqual(entries.map(\.unit.name), ["Expensive", "Empty"])
    }

    func testItemsAreCappedAtOneLoadoutButFullPriorityIsKept() {
        let priority = ["A", "B", "C", "D", "E"]
        let entry = CompRosterEntry(unit: unit("Carry", cost: 4, role: .carry), allItems: priority)

        XCTAssertEqual(entry.items, ["A", "B", "C"], "a cell draws one loadout's worth of items")
        XCTAssertEqual(entry.allItems, priority, "the alternatives are kept for the tooltip")
    }

    func testCaseMismatchBetweenCarryAndUnitStillResolvesItems() {
        let entries = CompRoster.entries(
            units: [unit("Ashe", cost: 3, role: .carry), unit("Tank", cost: 2)],
            carries: [CompCarry(unit: "ashe", itemPriority: ["Infinity Edge"])]
        )

        XCTAssertEqual(entries.first?.unit.name, "Ashe")
        XCTAssertEqual(entries.first?.items, ["Infinity Edge"])
    }

    // MARK: - Cell geometry

    func testEveryCellIsTheSameWidthAndFitsItsItemRow() {
        for portrait in [28, 34, 44, 56, 72].map(CGFloat.init) {
            let metrics = CompRosterMetrics(portrait: portrait)
            XCTAssertGreaterThanOrEqual(
                metrics.cellWidth,
                metrics.itemRowWidth,
                "a \(portrait)pt cell must be wide enough for the items under it"
            )
            XCTAssertGreaterThanOrEqual(metrics.cellWidth, portrait)
            XCTAssertGreaterThan(metrics.itemIcon, 0)
        }
    }

    func testNameStaysLegibleAtTheSmallestPortraitSize() {
        XCTAssertGreaterThanOrEqual(CompRosterMetrics(portrait: 28).nameFontSize, 9)
    }
}
