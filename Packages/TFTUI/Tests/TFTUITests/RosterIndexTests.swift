@testable import TFTUI
import XCTest

final class RosterIndexTests: XCTestCase {
    private var comps: [Comp] = []
    private var index: RosterIndex!

    override func setUpWithError() throws {
        comps = try CompLoader.bundledFixtures()
        index = RosterIndex(comps: comps)
    }

    func testUnitsAreSortedByCostThenName() {
        let costs = index.units.map(\.cost)
        XCTAssertEqual(costs, costs.sorted())

        for cost in Set(costs) {
            let namesAtCost = index.units.filter { $0.cost == cost }.map(\.name)
            XCTAssertEqual(namesAtCost, namesAtCost.sorted())
        }
    }

    func testUnitResolvesCostTraitsItemsAndComps() throws {
        let ashe = try XCTUnwrap(index.unit(named: "Ashe"))

        XCTAssertEqual(ashe.cost, 5)
        XCTAssertEqual(ashe.traits, ["Blossom", "Hunter"])
        XCTAssertEqual(ashe.recommendedItems, ["Infinity Edge", "Giant Slayer", "Runaan's Hurricane"])
        XCTAssertEqual(ashe.comps.map(\.id), ["hunters-ashe"])
    }

    func testUnitWithNoCarryEntryHasNoRecommendedItems() throws {
        let ornn = try XCTUnwrap(index.unit(named: "Ornn"))
        XCTAssertTrue(ornn.recommendedItems.isEmpty)
    }

    func testUnitAppearingInMultipleCompsListsAllOfThem() throws {
        // Hunter is shared, but no single unit spans both fixture comps today;
        // guard the aggregation logic instead using a synthetic index.
        let shared = CompUnit(name: "Shared Unit", cost: 3, starTarget: 2, role: .carry, traits: ["Test"])
        let compA = try comp(id: "a", name: "A", units: [shared])
        let compB = try comp(id: "b", name: "B", units: [shared])
        let synthetic = RosterIndex(comps: [compA, compB])

        let unit = try XCTUnwrap(synthetic.unit(named: "Shared Unit"))
        XCTAssertEqual(Set(unit.comps.map(\.id)), ["a", "b"])
    }

    func testTraitResolvesUnitsThatCarryIt() throws {
        let hunter = try XCTUnwrap(index.trait(named: "Hunter"))
        let expectedUnits = ["Ashe", "Caitlyn", "Cinderling", "Sivir", "Tristana"]
        XCTAssertEqual(hunter.units.map(\.name), expectedUnits)
    }

    func testTraitBreakpointsComeFromTheCatalog() throws {
        let elderwood = try XCTUnwrap(index.trait(named: "Elderwood"))
        XCTAssertEqual(elderwood.breakpoints.map(\.count), [2, 4, 6, 8])
        XCTAssertEqual(elderwood.breakpoints.map(\.style), [.bronze, .silver, .gold, .chromatic])
    }

    func testTraitNotInCatalogHasEmptyBreakpointsInsteadOfCrashing() throws {
        let unit = CompUnit(name: "Mystery Unit", cost: 1, starTarget: 1, role: .support, traits: ["Uncatalogued"])
        let synthetic = try RosterIndex(comps: [comp(id: "x", name: "X", units: [unit])])

        let trait = try XCTUnwrap(synthetic.trait(named: "Uncatalogued"))
        XCTAssertTrue(trait.breakpoints.isEmpty)
    }

    /// Every unit a trait claims to carry must, in turn, claim that trait —
    /// the cross-link (#26) must be consistent in both directions.
    func testCrossLinksAreBidirectionallyConsistent() throws {
        for trait in index.traits {
            for unitRef in trait.units {
                let unit = try XCTUnwrap(index.unit(named: unitRef.name))
                XCTAssertTrue(unit.traits.contains(trait.name))
            }
        }
        for unit in index.units {
            for compRef in unit.comps {
                let comp = try XCTUnwrap(comps.first { $0.id == compRef.id })
                XCTAssertTrue(comp.units.contains { $0.name == unit.name })
            }
        }
    }

    func testUnknownNamesResolveToNil() {
        XCTAssertNil(index.unit(named: "Nonexistent"))
        XCTAssertNil(index.trait(named: "Nonexistent"))
    }

    // MARK: - Helpers

    private func comp(id: String, name: String, units: [CompUnit]) throws -> Comp {
        let json = """
        {
            "schemaVersion": "1.0.0",
            "id": "\(id)",
            "name": "\(name)",
            "set": 18,
            "patch": "18.1",
            "source": "hand-authored",
            "tier": "A",
            "playstyle": "fast_8",
            "difficulty": "easy",
            "units": \(unitsJSON(units)),
            "carries": [],
            "boardPositioning": { "grid": [] },
            "augmentPreferences": { "tier1": [], "tier2": [], "tier3": [] },
            "levelPlan": [],
            "earlyOpener": "",
            "pivotNotes": ""
        }
        """
        return try CompLoader.load(Data(json.utf8))
    }

    private func unitsJSON(_ units: [CompUnit]) -> String {
        let entries = units.map { unit in
            let traits = unit.traits.map { "\"\($0)\"" }.joined(separator: ", ")
            return """
            { "name": "\(unit.name)", "cost": \(unit.cost), "starTarget": \(unit.starTarget), \
            "role": "\(unit.role.rawValue)", "traits": [\(traits)] }
            """
        }
        return "[" + entries.joined(separator: ", ") + "]"
    }
}
