@testable import TFTUI
import XCTest

/// The one contract `CompSuggestionRanking` makes about authored tier:
/// it may only break ties between comps the player is about equally close to,
/// and may never reorder comps separated by a real overlap gap. Split out of
/// `CompSuggestionRankingTests` because it is a contract in its own right and
/// the boundary cases need room to be spelled out.
final class CompSuggestionTierBandTests: XCTestCase {
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

    private let totalWeight = CompFixture.dominantShapeTotalWeight

    private let sCompNames = ["Ashe", "Kindred", "Jinx", "Poppy", "Ornn", "Volibear", "Yasuo", "Zed"]
    private let dCompNames = ["KaiSa", "Aphelios", "Ezreal", "Sett", "Leona", "Braum", "Malphite", "Nasus"]

    // MARK: - A real overlap gap always wins

    /// The regression this whole banding scheme exists for, on the shape 33
    /// of the 36 real comps have. The player owns one whole extra unit of the
    /// D-tier comp and is measurably closer to fielding it; the old additive
    /// 0.02-per-tier-step nudge (up to +0.08 across S..D) buried it under the
    /// S-tier comp anyway, because one matched unit of a real comp is worth
    /// as little as 0.0286 of that comp's total weight. On the exact question
    /// this type exists to answer, that was misleading output.
    func testAWholeExtraMatchedUnitBeatsFourTiersOfAuthoredOpinion() throws {
        let sComp = try CompFixture.dominantShape(id: "s-comp", tier: .s, names: sCompNames)
        let dComp = try CompFixture.dominantShape(id: "d-comp", tier: .d, names: dCompNames)
        // Three of the S comp's units (carry + both 4-costs) against four of
        // the D comp's (carry + both 4-costs + a 1-cost).
        let owned: Set = ["Ashe", "Kindred", "Jinx", "KaiSa", "Aphelios", "Ezreal", "Malphite"]

        let ranked = CompSuggestionRanking.rank(owned: owned, comps: [sComp, dComp])

        XCTAssertEqual(ranked.first?.overlapScore ?? 0, 16.5 / totalWeight, accuracy: 1e-9)
        XCTAssertEqual(ranked.last?.overlapScore ?? 0, 15.5 / totalWeight, accuracy: 1e-9)
        XCTAssertEqual(
            ranked.map(\.comp.id),
            ["d-comp", "s-comp"],
            "4/8 must outrank 3/8 of the same comp shape no matter how the tiers fall"
        )
    }

    /// A whole-comp gap obviously still beats tier. The coarse sanity check;
    /// the boundary tests below are what actually pin the contract.
    func testTierNeverOverridesALargeOverlapGap() throws {
        let sTierFarAway = try makeComp(
            id: "s-tier",
            tier: .s,
            units: [unit("Ashe", cost: 5, role: .carry)],
            carries: [CompCarry(unit: "Ashe", itemPriority: [])]
        )
        let dTierAlmostThere = try makeComp(
            id: "d-tier",
            tier: .d,
            units: [unit("Ornn", cost: 1), unit("Poppy", cost: 1)]
        )
        let ranked = CompSuggestionRanking.rank(owned: ["Ornn", "Poppy"], comps: [sTierFarAway, dTierAlmostThere])

        XCTAssertEqual(ranked.map(\.comp.id), ["d-tier", "s-tier"], "a real overlap gap must beat tier")
    }

    // MARK: - Both sides of the epsilon boundary

    /// Upper half: a gap of `0.5 / 24.5 = 0.0204`, barely over
    /// `scoreEpsilon`, must already be enough to shut tier out entirely.
    func testAGapJustOverEpsilonIsSettledOnOverlapAlone() throws {
        let sComp = try CompFixture.dominantShape(id: "s-comp", tier: .s, names: sCompNames)
        let dComp = try CompFixture.dominantShape(id: "d-comp", tier: .d, names: dCompNames)
        // S: carry + both 4-costs = 15.5. D: everything but the carry and one
        // 1-cost = 4 + 4 + 3 + 2 + 2 + 1 = 16.
        let owned: Set = [
            "Ashe", "Kindred", "Jinx",
            "Aphelios", "Ezreal", "Sett", "Leona", "Braum", "Malphite",
        ]

        let ranked = CompSuggestionRanking.rank(owned: owned, comps: [sComp, dComp])
        let gap = (16.0 - 15.5) / totalWeight

        XCTAssertGreaterThan(gap, CompSuggestionRanking.scoreEpsilon, "this fixture must sit just above the band")
        XCTAssertEqual(ranked.map(\.comp.id), ["d-comp", "s-comp"], "at or past epsilon, tier must not participate")
    }

    /// Lower half: a gap of `14/27 - 1/2 = 0.0185`, just under `scoreEpsilon`
    /// and inside one band, is a near-tie — so the S-tier comp wins despite
    /// the D-tier comp's marginally higher overlap. This is the half of the
    /// contract that keeps a reachable S-tier comp from being buried under a
    /// hair-closer D-tier one.
    func testAGapJustUnderEpsilonIsDecidedByTier() throws {
        // 3 / 6 = 0.5 exactly.
        let sComp = try makeComp(
            id: "s-comp",
            tier: .s,
            units: [unit("Ashe", cost: 3), unit("Kindred", cost: 3)]
        )
        // 14 / 27 = 0.5185..., which falls in the same epsilon band as 0.5.
        let dComp = try makeComp(
            id: "d-comp",
            tier: .d,
            units: [
                unit("KaiSa", cost: 5), unit("Aphelios", cost: 4), unit("Ezreal", cost: 4),
                unit("Sett", cost: 3), unit("Leona", cost: 3), unit("Braum", cost: 3),
                unit("Malphite", cost: 2), unit("Nasus", cost: 2), unit("Zed", cost: 1),
            ]
        )
        let owned: Set = ["Ashe", "KaiSa", "Aphelios", "Sett", "Malphite"]

        let ranked = CompSuggestionRanking.rank(owned: owned, comps: [sComp, dComp])
        let sScore = try XCTUnwrap(ranked.first(where: { $0.comp.id == "s-comp" })?.overlapScore)
        let dScore = try XCTUnwrap(ranked.first(where: { $0.comp.id == "d-comp" })?.overlapScore)

        XCTAssertEqual(sScore, 0.5, accuracy: 1e-9)
        XCTAssertEqual(dScore, 14.0 / 27.0, accuracy: 1e-9)
        XCTAssertLessThan(dScore - sScore, CompSuggestionRanking.scoreEpsilon, "this fixture must be a near-tie")
        XCTAssertGreaterThan(dScore, sScore, "and the lower-tier comp must be the marginally closer one")
        XCTAssertEqual(ranked.map(\.comp.id), ["s-comp", "d-comp"], "inside one band, tier decides")
    }

    /// Adjacent tiers, exact overlap tie: S must lead A. The ids are
    /// deliberately the wrong way round for the `comp.id` tie-break, so this
    /// only passes if tier really is consulted first.
    func testTierBreaksANearTieBetweenAdjacentTierComps() throws {
        let sTier = try makeComp(
            id: "s-tier",
            tier: .s,
            units: [unit("Ashe", cost: 5, role: .carry), unit("Ornn", cost: 1)],
            carries: [CompCarry(unit: "Ashe", itemPriority: [])]
        )
        let aTier = try makeComp(
            id: "a-tier",
            tier: .a,
            units: [unit("Volibear", cost: 5, role: .carry), unit("Poppy", cost: 1)],
            carries: [CompCarry(unit: "Volibear", itemPriority: [])]
        )
        // Owns each comp's carry but neither comp's cheap frontline unit, so
        // the two comps have identical (partial) overlap fractions.
        let ranked = CompSuggestionRanking.rank(owned: ["Ashe", "Volibear"], comps: [sTier, aTier])

        XCTAssertEqual(ranked[0].overlapScore, ranked[1].overlapScore, "the two comps must be a real overlap tie")
        XCTAssertEqual(ranked.map(\.comp.id), ["s-tier", "a-tier"], "tier should decide the near-tie")
    }

    // MARK: - The epsilon constant, tied to the corpus it was chosen against

    /// `scoreEpsilon` is only defensible while it stays below the smallest
    /// contribution any single unit makes to its own comp. That is a fact
    /// about the corpus, and the corpus is regenerated whenever the
    /// maintainer re-runs the scraper — so assert it against the live data
    /// rather than trusting the number in the doc-comment.
    func testEveryBundledCompsCheapestUnitOutweighsTheTierBand() throws {
        let comps = try CompLoader.bundledFixtures()
        XCTAssertFalse(comps.isEmpty, "the bundled corpus must not be empty")

        var worstShare = Double.infinity
        var worstCompID = ""
        var bestShare = 0.0
        for comp in comps {
            let carryKeys = CompSuggestionRanking.carryKeys(of: comp)
            let weights = comp.units.map { CompSuggestionRanking.unitWeight($0, carryKeys: carryKeys) }
            let total = weights.reduce(0, +)
            guard total > 0, let cheapest = weights.min() else { continue }
            let share = cheapest / total
            if share < worstShare {
                worstShare = share
                worstCompID = comp.id
            }
            bestShare = max(bestShare, share)
        }

        XCTAssertLessThan(worstShare, .infinity, "no comp in the corpus had any weighted units")
        XCTAssertGreaterThan(
            worstShare,
            CompSuggestionRanking.scoreEpsilon,
            """
            Comp "\(worstCompID)" has a unit worth only \(worstShare) of its total weight, which is at or below \
            CompSuggestionRanking.scoreEpsilon (\(CompSuggestionRanking.scoreEpsilon)). That breaks the guarantee \
            rank(owned:comps:) documents: tier may only reorder comps whose overlap differs by less than one \
            matched unit, and epsilon is what encodes "less than one matched unit". If the corpus has genuinely \
            changed (a re-scrape, a new comp shape), lower scoreEpsilon below \(worstShare) and update its \
            doc-comment with the new measured floor — do not just relax this assertion. Highest per-comp minimum \
            share in this corpus, for reference: \(bestShare).
            """
        )
    }
}
