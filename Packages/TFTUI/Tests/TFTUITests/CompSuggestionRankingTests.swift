@testable import TFTUI
import XCTest

final class CompSuggestionRankingTests: XCTestCase {
    // MARK: - Fixtures

    /// `Comp` only decodes (ADR 0002's schema is the source of truth, not a
    /// memberwise initializer), so hand-made fixtures for logic assertions
    /// go through the same JSON path the app itself uses, with every field
    /// the schema requires but this suite doesn't care about pinned to a
    /// fixed, boring value.
    private func makeComp(
        id: String,
        tier: Comp.Tier,
        units: [CompUnit],
        carries: [CompCarry] = []
    ) throws -> Comp {
        let unitsJSON = units.map { unit in
            """
            {"name": "\(unit.name)", "cost": \(unit.cost), "starTarget": \(unit.starTarget), \
            "role": "\(unit.role.rawValue)", "traits": []}
            """
        }.joined(separator: ",")
        let carriesJSON = carries.map { carry in
            """
            {"unit": "\(carry.unit)", "itemPriority": []}
            """
        }.joined(separator: ",")
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
          "difficulty": "medium",
          "units": [\(unitsJSON)],
          "carries": [\(carriesJSON)],
          "boardPositioning": {"grid": [[]]},
          "augmentPreferences": {"tier1": [], "tier2": [], "tier3": []},
          "levelPlan": [],
          "earlyOpener": "",
          "pivotNotes": ""
        }
        """
        return try CompLoader.load(Data(json.utf8))
    }

    private func unit(_ name: String, cost: Int, role: CompUnit.Role = .frontline) -> CompUnit {
        CompUnit(name: name, cost: cost, starTarget: 2, role: role, traits: [])
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

    // MARK: - Tier as a near-tie nudge, not an override

    /// Tier should only decide between comps the player is about equally
    /// close to. A comp with real overlap far ahead of another must not be
    /// outranked just because the other is S-tier.
    func testTierNeverOverridesALargeOverlapGap() throws {
        let sTierFarAway = try makeComp(id: "s-tier", tier: .s, units: [unit("Ashe", cost: 5, role: .carry)])
        let dTierAlmostThere = try makeComp(
            id: "d-tier",
            tier: .d,
            units: [unit("Ornn", cost: 1), unit("Poppy", cost: 1)]
        )
        let ranked = CompSuggestionRanking.rank(owned: ["Ornn", "Poppy"], comps: [sTierFarAway, dTierAlmostThere])

        XCTAssertEqual(ranked.map(\.comp.id), ["d-tier", "s-tier"], "a real overlap gap must beat tier")
    }

    /// But between two comps the player is genuinely about-equally close
    /// to, tier should decide, so a reachable S-tier comp isn't buried
    /// under a marginally-closer D-tier one.
    func testTierBreaksANearTieBetweenComps() throws {
        let sTier = try makeComp(
            id: "s-tier",
            tier: .s,
            units: [unit("Ashe", cost: 5, role: .carry), unit("Ornn", cost: 1)],
            carries: [CompCarry(unit: "Ashe", itemPriority: [])]
        )
        let dTier = try makeComp(
            id: "d-tier",
            tier: .d,
            units: [unit("Volibear", cost: 5, role: .carry), unit("Poppy", cost: 1)],
            carries: [CompCarry(unit: "Volibear", itemPriority: [])]
        )
        // Owns each comp's carry but neither comp's cheap frontline unit,
        // so the two comps have identical (partial) overlap fractions.
        let ranked = CompSuggestionRanking.rank(owned: ["Ashe", "Volibear"], comps: [sTier, dTier])

        XCTAssertEqual(ranked[0].overlapScore, ranked[1].overlapScore, "the two comps must be a real overlap tie")
        XCTAssertEqual(ranked.map(\.comp.id), ["s-tier", "d-tier"], "tier should decide the near-tie")
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
