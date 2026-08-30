import Foundation
import TFTData
@testable import TFTUI
import XCTest

final class OpenerIndexTests: XCTestCase {
    // MARK: - Fixture construction

    /// A unit entry for `makeComp`'s JSON, standing in for `CompUnit` since
    /// tuples over two members trip `large_tuple`.
    private struct UnitFixture {
        let name: String
        let cost: Int
        let role: CompUnit.Role

        init(_ name: String, cost: Int, role: CompUnit.Role = .frontline) {
            self.name = name
            self.cost = cost
            self.role = role
        }
    }

    /// `Comp` has no memberwise initializer (see `Comp.init(from:)`), so
    /// hand-made fixtures go through `CompLoader.load(_:)` like the real
    /// data does. Every field the schema requires gets a harmless default;
    /// only the fields a given test cares about are parameterized.
    private func makeComp(
        id: String,
        tier: Comp.Tier,
        units: [UnitFixture],
        carries: [(unit: String, itemPriority: [String])] = []
    ) throws -> Comp {
        let unitsJSON = units.map { unit in
            """
            {"name": "\(unit.name)", "cost": \(unit.cost), "starTarget": 2, \
            "role": "\(unit.role.rawValue)", "traits": []}
            """
        }.joined(separator: ",")
        let carriesJSON = carries.map { carry in
            let items = carry.itemPriority.map { "\"\($0)\"" }.joined(separator: ",")
            return """
            {"unit": "\(carry.unit)", "itemPriority": [\(items)]}
            """
        }.joined(separator: ",")
        let emptyRow = "[null,null,null,null,null,null,null]"
        let json = """
        {
          "schemaVersion": "1.0.0",
          "id": "\(id)",
          "name": "\(id)",
          "set": 18,
          "patch": "18.1",
          "source": "hand-authored",
          "tier": "\(tier.rawValue)",
          "playstyle": "fast_8",
          "difficulty": "easy",
          "units": [\(unitsJSON)],
          "carries": [\(carriesJSON)],
          "boardPositioning": {"grid": [\(emptyRow),\(emptyRow),\(emptyRow),\(emptyRow)]},
          "augmentPreferences": {"tier1": [], "tier2": [], "tier3": []},
          "levelPlan": [],
          "earlyOpener": "",
          "pivotNotes": ""
        }
        """
        return try CompLoader.load(Data(json.utf8))
    }

    // MARK: - Weighting

    /// Raw appearance count among S/A comps would rank "Beta" (3
    /// appearances) over "Alpha" (2), but an S appearance is worth double
    /// an A one, so the tier-weighted ranking flips that: Alpha's two S
    /// appearances (2*2=4) outscore Beta's three A appearances (3*1=3).
    func testWeightingByTierChangesOrderFromRawFrequency() throws {
        let comps = try [
            makeComp(id: "s1", tier: .s, units: [UnitFixture("Alpha", cost: 2, role: .frontline)]),
            makeComp(id: "s2", tier: .s, units: [UnitFixture("Alpha", cost: 2, role: .frontline)]),
            makeComp(id: "a1", tier: .a, units: [UnitFixture("Beta", cost: 2, role: .frontline)]),
            makeComp(id: "a2", tier: .a, units: [UnitFixture("Beta", cost: 2, role: .frontline)]),
            makeComp(id: "a3", tier: .a, units: [UnitFixture("Beta", cost: 2, role: .frontline)]),
        ]
        let index = OpenerIndex(comps: comps)

        XCTAssertEqual(index.mostPresent.map(\.name), ["Alpha", "Beta"])
        XCTAssertEqual(index.mostPresent.first?.weightedPresence, 4)
        XCTAssertEqual(index.mostPresent.last?.weightedPresence, 3)

        // The same corpus's raw, tier-blind count ranks the other way.
        XCTAssertEqual(index.mostShared.map(\.name), ["Beta", "Alpha"])
    }

    // MARK: - Determinism

    func testTiesBreakDeterministicallyByName() throws {
        let comps = try [
            makeComp(
                id: "s1",
                tier: .s,
                units: [UnitFixture("Zeta", cost: 2, role: .frontline), UnitFixture("Alpha", cost: 2, role: .frontline)]
            ),
        ]
        let index = OpenerIndex(comps: comps)

        XCTAssertEqual(index.mostPresent.map(\.name), ["Alpha", "Zeta"])
        XCTAssertEqual(index.mostShared.map(\.name), ["Alpha", "Zeta"])
    }

    // MARK: - Corpus edge cases

    func testSingleCompCorpusProducesResultsWithoutCrashing() throws {
        let comp = try makeComp(
            id: "solo",
            tier: .s,
            units: [UnitFixture("Alpha", cost: 2, role: .frontline), UnitFixture("Bravo", cost: 5, role: .carry)],
            carries: [(unit: "Bravo", itemPriority: ["Infinity Edge"])]
        )
        let index = OpenerIndex(comps: [comp])

        // Bravo is a 5-cost, out of the opener range entirely.
        XCTAssertEqual(index.mostPresent.map(\.name), ["Alpha"])
        XCTAssertEqual(index.mostShared.map(\.name), ["Alpha"])
        XCTAssertEqual(index.comps(leadingFrom: "Alpha").map(\.id), ["solo"])
        XCTAssertEqual(index.comps(leadingFrom: "Bravo"), [], "5-cost carries are outside the opener pool")
        XCTAssertEqual(index.componentDemand.map(\.componentName).sorted(), ["B.F. Sword", "Sparring Gloves"])
    }

    func testCorpusWithNoSTierComps() throws {
        let comps = try [
            makeComp(id: "a1", tier: .a, units: [UnitFixture("Alpha", cost: 2, role: .frontline)]),
            makeComp(
                id: "a2",
                tier: .a,
                units: [UnitFixture("Alpha", cost: 2, role: .frontline)],
                carries: [(unit: "Alpha", itemPriority: ["Infinity Edge"])]
            ),
        ]
        let index = OpenerIndex(comps: comps)

        XCTAssertEqual(index.mostPresent.map(\.name), ["Alpha"])
        XCTAssertEqual(index.mostPresent.first?.weightedPresence, 2)
        XCTAssertEqual(index.mostShared.map(\.name), ["Alpha"])
        // Component demand only reads S-tier carries; with none present it
        // must be empty, not crash or fall back to A-tier data.
        XCTAssertEqual(index.componentDemand, [])
    }

    func testEmptyCorpusProducesEmptyResultsWithoutCrashing() {
        let index = OpenerIndex(comps: [])

        XCTAssertEqual(index.mostPresent, [])
        XCTAssertEqual(index.mostShared, [])
        XCTAssertEqual(index.componentDemand, [])
        XCTAssertEqual(index.comps(leadingFrom: "Anyone"), [])
    }

    // MARK: - Non-2-component item priorities

    /// "Zeke's Emblem" names a trait emblem, not a 2-component build:
    /// `RecipeMatrix` has no recipe for it. That single entry must be
    /// skipped silently, not crash, and not drop the rest of the carry's
    /// (real) item priorities from the count.
    func testItemPriorityNamingANonComponentItemIsSkippedNotCrashed() throws {
        let comp = try makeComp(
            id: "s1",
            tier: .s,
            units: [UnitFixture("Carry", cost: 3, role: .carry)],
            carries: [(unit: "Carry", itemPriority: ["Zeke's Emblem", "Infinity Edge"])]
        )
        let index = OpenerIndex(comps: [comp])

        XCTAssertEqual(index.componentDemand.map(\.componentName).sorted(), ["B.F. Sword", "Sparring Gloves"])
    }

    // MARK: - Distinctness of mostPresent vs. mostShared

    /// "Present" appears once, in an S comp, so it tops `mostPresent`.
    /// "Shared" appears in four D-tier comps -- zero weight in
    /// `mostPresent` (dropped from that list entirely) but the highest
    /// `sharedCompCount` in the corpus, so it tops `mostShared`. The two
    /// rankings must disagree on their leaders, not just reorder the tail.
    func testMostPresentAndMostSharedRankDifferentUnitsFirst() throws {
        let comps = try [
            makeComp(id: "s1", tier: .s, units: [UnitFixture("Present", cost: 2, role: .frontline)]),
            makeComp(id: "d1", tier: .d, units: [UnitFixture("Shared", cost: 2, role: .frontline)]),
            makeComp(id: "d2", tier: .d, units: [UnitFixture("Shared", cost: 2, role: .frontline)]),
            makeComp(id: "d3", tier: .d, units: [UnitFixture("Shared", cost: 2, role: .frontline)]),
            makeComp(id: "d4", tier: .d, units: [UnitFixture("Shared", cost: 2, role: .frontline)]),
        ]
        let index = OpenerIndex(comps: comps)

        XCTAssertEqual(index.mostPresent.map(\.name), ["Present"], "Shared has zero S/A weight and must be absent")
        XCTAssertEqual(index.mostShared.first?.name, "Shared")
        XCTAssertNotEqual(index.mostPresent.first?.name, index.mostShared.first?.name)
    }

    // MARK: - Smoke test against the real corpus

    func testBundledCorpusProducesNonCrashingResults() throws {
        let comps = try CompLoader.bundledFixtures()
        let index = OpenerIndex(comps: comps)

        // No exact numbers asserted: the bundled corpus is scraper output
        // (ADR 0004) and changes whenever the maintainer re-runs it. All
        // that matters here is that the real data doesn't crash the model
        // and that the entries carry costs inside the documented range.
        XCTAssertTrue(index.mostPresent.allSatisfy { OpenerIndex.openerCostRange.contains($0.cost) })
        XCTAssertTrue(index.mostShared.allSatisfy { OpenerIndex.openerCostRange.contains($0.cost) })
        for unit in index.mostShared {
            for comp in index.comps(leadingFrom: unit.name) {
                XCTAssertTrue(comps.contains { $0.id == comp.id })
            }
        }
    }
}
