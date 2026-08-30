@testable import TFTUI
import XCTest

final class CompSuggestionRankingTests: XCTestCase {
    // MARK: - Fixtures

    private func makeComp(
        id: String,
        tier: Comp.Tier,
        units: [CompUnit],
        carries: [CompCarry] = []
    ) throws -> Comp {
        try CompFixture.make(id: id, tier: tier, units: units, carries: carries)
    }

    private func unit(_ name: String, cost: Int, role: CompUnit.Role = .frontline) -> CompUnit {
        CompFixture.unit(name, cost: cost, role: role)
    }

    // MARK: - Empty roster

    func testEmptyOwnedSetScoresEveryCompAtZeroAndListsAllUnitsMissing() throws {
        let comp = try makeComp(id: "test", tier: .a, units: [unit("Ashe", cost: 5, role: .carry)])
        let ranked = CompSuggestionRanking.rank(owned: [], comps: [comp])

        XCTAssertEqual(ranked.count, 1)
        XCTAssertEqual(ranked[0].overlapScore, 0)
        XCTAssertTrue(ranked[0].matchedUnits.isEmpty)
        XCTAssertEqual(ranked[0].missingUnits.map(\.name), ["Ashe"])
    }

    // MARK: - Exact match

    func testExactMatchScoresOneWithNothingMissing() throws {
        let comp = try makeComp(
            id: "test",
            tier: .b,
            units: [unit("Ashe", cost: 5, role: .carry), unit("Ornn", cost: 1)]
        )
        let ranked = CompSuggestionRanking.rank(owned: ["Ashe", "Ornn"], comps: [comp])

        XCTAssertEqual(ranked[0].overlapScore, 1, accuracy: 1e-9)
        XCTAssertTrue(ranked[0].missingUnits.isEmpty)
        XCTAssertEqual(ranked[0].matchedCount, 2)
        XCTAssertEqual(ranked[0].totalCount, 2)
    }

    // MARK: - Carry weighting actually changes the outcome

    /// Naive raw-count ranking would call these two comps tied: each has 2
    /// of 3 units owned. But comp A's match is a matched 5-cost carry plus
    /// a matched 1-cost frontline unit, while comp B's match is two matched
    /// 1-cost frontline units and its carry is the missing piece. A carries
    /// far more than B does despite an identical count, so the weighted
    /// ranking must put A above B while a count-only ranking would tie them
    /// (or, depending on tie-break, could easily rank them the wrong way).
    ///
    /// The ids are deliberately reversed against the expected order: a
    /// count-only implementation ties these two, falls through to the
    /// `comp.id` tie-break, and returns `["alpha-comp", "zeta-comp"]` — the
    /// wrong answer. So the order assertion below fails on a count-only
    /// implementation instead of passing by luck.
    func testCarryWeightedOrderingDisagreesWithNaiveCountAndOursIsRight() throws {
        let compA = try makeComp(
            id: "zeta-comp",
            tier: .b,
            units: [
                unit("Ashe", cost: 5, role: .carry),
                unit("Ornn", cost: 1),
                unit("Volibear", cost: 1),
            ],
            carries: [CompCarry(unit: "Ashe", itemPriority: [])]
        )
        let compB = try makeComp(
            id: "alpha-comp",
            tier: .b,
            units: [
                unit("Kindred", cost: 5, role: .carry),
                unit("Ornn", cost: 1),
                unit("Poppy", cost: 1),
            ],
            carries: [CompCarry(unit: "Kindred", itemPriority: [])]
        )
        // Owns A's carry plus one of its frontline units (missing Volibear),
        // and owns both of B's frontline units but not its carry Kindred.
        let owned: Set = ["Ashe", "Ornn", "Poppy"]

        /// Naive raw match count: both comps have 2 of 3 units owned.
        func naiveCount(_ comp: Comp) -> Int {
            comp.units.filter { owned.contains($0.name) }.count
        }
        XCTAssertEqual(naiveCount(compA), naiveCount(compB), "the naive metric must see these as tied")

        let ranked = CompSuggestionRanking.rank(owned: owned, comps: [compA, compB])
        XCTAssertEqual(ranked.map(\.comp.id), ["zeta-comp", "alpha-comp"], "the carry-weighted score must prefer A")
        XCTAssertGreaterThan(ranked[0].overlapScore, ranked[1].overlapScore)
    }

    // MARK: - Missing-unit lists

    func testMissingUnitsAreOrderedByValueWithCarriesFirst() throws {
        let comp = try makeComp(
            id: "test",
            tier: .a,
            units: [
                unit("Ornn", cost: 1),
                unit("Ashe", cost: 5, role: .carry),
                unit("Poppy", cost: 3),
            ],
            carries: [CompCarry(unit: "Ashe", itemPriority: [])]
        )
        let ranked = CompSuggestionRanking.rank(owned: [], comps: [comp])

        XCTAssertEqual(ranked[0].missingUnits.map(\.name), ["Ashe", "Poppy", "Ornn"])
    }

    func testMatchedAndMissingUnitsPartitionTheFullRosterExactly() throws {
        let comp = try makeComp(
            id: "test",
            tier: .c,
            units: [unit("Ashe", cost: 5, role: .carry), unit("Ornn", cost: 1), unit("Poppy", cost: 2)]
        )
        let ranked = CompSuggestionRanking.rank(owned: ["Ashe"], comps: [comp])

        XCTAssertEqual(ranked[0].matchedUnits.map(\.name), ["Ashe"])
        XCTAssertEqual(Set(ranked[0].missingUnits.map(\.name)), ["Ornn", "Poppy"])
        XCTAssertEqual(ranked[0].matchedCount + ranked[0].missingUnits.count, ranked[0].totalCount)
    }

    // MARK: - Determinism

    func testTieBreakingIsDeterministicAcrossRepeatedRuns() throws {
        let compA = try makeComp(id: "a", tier: .b, units: [unit("Ashe", cost: 3)])
        let compB = try makeComp(id: "b", tier: .b, units: [unit("Ornn", cost: 3)])
        let compC = try makeComp(id: "c", tier: .b, units: [unit("Poppy", cost: 3)])

        let firstRun = CompSuggestionRanking.rank(owned: [], comps: [compC, compA, compB])
        let secondRun = CompSuggestionRanking.rank(owned: [], comps: [compB, compC, compA])

        XCTAssertEqual(firstRun.map(\.comp.id), ["a", "b", "c"], "equal scores must always land in id order")
        XCTAssertEqual(firstRun.map(\.comp.id), secondRun.map(\.comp.id), "input order must not affect the result")
    }

    // MARK: - Owned champion in no comp

    func testAnOwnedChampionThatAppearsInNoCompIsSimplyIgnored() throws {
        let comp = try makeComp(id: "test", tier: .b, units: [unit("Ashe", cost: 5, role: .carry)])
        let ranked = CompSuggestionRanking.rank(owned: ["Ashe", "SomeoneNotInAnyComp"], comps: [comp])

        XCTAssertEqual(ranked[0].overlapScore, 1, accuracy: 1e-9)
        XCTAssertTrue(ranked[0].missingUnits.isEmpty)
    }

    // MARK: - Name normalisation

    func testOwnershipMatchesThroughPunctuationAndCasingVariants() throws {
        let comp = try makeComp(id: "test", tier: .b, units: [unit("Kai'Sa", cost: 4, role: .carry)])
        let ranked = CompSuggestionRanking.rank(owned: ["KaiSa"], comps: [comp])

        XCTAssertEqual(ranked[0].matchedUnits.map(\.name), ["Kai'Sa"])
        XCTAssertTrue(ranked[0].missingUnits.isEmpty)
    }

    // MARK: - Real corpus smoke test

    /// Not an assertion on exact numbers — the real corpus changes every
    /// time the maintainer re-runs the scraper — just proof the ranking
    /// runs end to end over real data without crashing or losing units.
    func testRealCorpusRanksWithoutLosingAnyUnits() throws {
        let comps = try CompLoader.bundledFixtures()
        let owned = Set(comps.first?.units.prefix(2).map(\.name) ?? [])

        let ranked = CompSuggestionRanking.rank(owned: owned, comps: comps)

        XCTAssertEqual(ranked.count, comps.count)
        for suggestion in ranked {
            XCTAssertEqual(
                suggestion.matchedUnits.count + suggestion.missingUnits.count,
                suggestion.comp.units.count
            )
            XCTAssertGreaterThanOrEqual(suggestion.overlapScore, 0)
            XCTAssertLessThanOrEqual(suggestion.overlapScore, 1)
        }
    }
}
