import Foundation
import TFTData
@testable import TFTUI
import XCTest

final class OpenerIndexTests: XCTestCase {
    // MARK: - Fixture construction

    /// A comp through `CompFixture`, with `earlyUnits` defaulting to every
    /// unit on the final board.
    ///
    /// That default keeps the weighting tests short; the two lists being
    /// *different* is the whole point of this type, so every test about that
    /// passes `earlyUnits` explicitly.
    private func makeComp(
        id: String,
        tier: Comp.Tier,
        units: [CompUnit],
        earlyUnits: [String]? = nil,
        carries: [CompCarry] = []
    ) throws -> Comp {
        try CompFixture.make(
            id: id,
            tier: tier,
            units: units,
            carries: carries,
            earlyUnits: earlyUnits ?? units.map(\.name)
        )
    }

    private func unit(_ name: String, cost: Int, starTarget: Int = 2, role: CompUnit.Role = .frontline) -> CompUnit {
        CompFixture.unit(name, cost: cost, starTarget: starTarget, role: role)
    }

    // MARK: - The input is the early roster, not the final board

    /// The bug #99 is about, as a unit test.
    ///
    /// "Late" is on every final board and no opening board; "Early" is on
    /// every opening board and no final board. A ranking over `units` puts
    /// Late first and never mentions Early; a ranking over `earlyUnits` must
    /// do the exact opposite.
    func testRankingReadsEarlyRostersAndNotFinalBoards() throws {
        let comps = try (1 ... 3).map { number in
            try makeComp(
                id: "s\(number)",
                tier: .s,
                units: [unit("Late", cost: 2)],
                earlyUnits: ["Early"]
            )
        }
        // "Early" is never fielded on a final board, so its cost has to come
        // from the catalog — exactly the case `championCosts` exists for.
        let index = OpenerIndex(comps: comps, championCosts: ["Early": 1])

        XCTAssertEqual(index.topOpeners.map(\.name), ["Early"])
        XCTAssertEqual(index.mostFlexible.map(\.name), ["Early"])
        XCTAssertEqual(index.comps(leadingFrom: "Late"), [], "A final-board-only unit is not an opener")
        XCTAssertEqual(index.comps(leadingFrom: "Early").map(\.id), ["s1", "s2", "s3"])
    }

    /// An early-roster name the corpus never fields and the catalog does not
    /// know has no cost, and this panel leads with cost. It is dropped, not
    /// guessed.
    func testAnEarlyUnitWithNoResolvableCostIsDroppedRatherThanGuessed() throws {
        let comp = try makeComp(
            id: "s1",
            tier: .s,
            units: [unit("Known", cost: 1)],
            earlyUnits: ["Known", "Stranger"]
        )
        let index = OpenerIndex(comps: [comp])

        XCTAssertEqual(index.mostFlexible.map(\.name), ["Known"])
        XCTAssertEqual(index.comps(leadingFrom: "Stranger"), [])
    }

    // MARK: - Cost weighting

    /// A 1-cost seen once outranks a 2-cost seen once, at equal tier and
    /// equal roster size: cheap units are the ones you can actually find and
    /// pair in stage 1, which is what the ranking is for.
    func testACheaperUnitOutranksADearerOneAtEqualPresence() throws {
        let comp = try makeComp(
            id: "s1",
            tier: .s,
            units: [unit("Two", cost: 2), unit("One", cost: 1)]
        )
        let index = OpenerIndex(comps: [comp])

        XCTAssertEqual(index.topOpeners.map(\.name), ["One", "Two"])
        // The flexibility ranking is cost-blind on purpose, so it ties and
        // falls back to the name tie-break.
        XCTAssertEqual(index.mostFlexible.map(\.sharedCompCount), [1, 1])
    }

    /// Cost weighting must not swamp presence outright: a 2-cost on four S
    /// opening boards beats a 1-cost on one.
    func testPresenceStillBeatsCostWhenTheGapIsWideEnough() throws {
        var comps = try (1 ... 4).map { number in
            try makeComp(id: "s\(number)", tier: .s, units: [unit("Two", cost: 2)])
        }
        try comps.append(makeComp(id: "s5", tier: .s, units: [unit("One", cost: 1)]))
        let index = OpenerIndex(comps: comps)

        XCTAssertEqual(index.topOpeners.map(\.name), ["Two", "One"])
    }

    // MARK: - Tier weighting

    /// Raw appearance count among S/A comps would rank "Beta" (3
    /// appearances) over "Alpha" (2), but an S appearance is worth double
    /// an A one, so the tier-weighted ranking flips that: Alpha's two S
    /// appearances outscore Beta's three A appearances.
    func testWeightingByTierChangesOrderFromRawFrequency() throws {
        var comps = try (1 ... 2).map { number in
            try makeComp(id: "s\(number)", tier: .s, units: [unit("Alpha", cost: 2)])
        }
        comps += try (1 ... 3).map { number in
            try makeComp(id: "a\(number)", tier: .a, units: [unit("Beta", cost: 2)])
        }
        let index = OpenerIndex(comps: comps)

        XCTAssertEqual(index.topOpeners.map(\.name), ["Alpha", "Beta"])
        XCTAssertEqual(index.topOpeners.map(\.topTierRosterCount), [2, 3])

        // The same corpus's raw, tier-blind count ranks the other way.
        XCTAssertEqual(index.mostFlexible.map(\.name), ["Beta", "Alpha"])
    }

    // MARK: - Uneven roster sizes

    /// Early rosters are not uniform in size — the real corpus runs from one
    /// unit to five — so a flat appearance count hands a five-unit comp five
    /// votes and a one-unit comp one. Every comp instead casts one vote split
    /// across its opening board, so a unit that is a comp's *entire* opening
    /// plan beats one of five slots in a comp of equal tier.
    func testACompsVoteIsSplitAcrossItsOwnRosterSize() throws {
        let comps = try [
            makeComp(id: "solo", tier: .s, units: [unit("Whole", cost: 1)]),
            makeComp(
                id: "crowd",
                tier: .s,
                units: (1 ... 5).map { unit("Fifth\($0)", cost: 1) }
            ),
        ]
        let index = OpenerIndex(comps: comps)

        XCTAssertEqual(index.topOpeners.first?.name, "Whole")
        let whole = try XCTUnwrap(index.topOpeners.first(where: { $0.name == "Whole" }))
        let fifth = try XCTUnwrap(index.topOpeners.first(where: { $0.name == "Fifth1" }))
        XCTAssertEqual(
            whole.openerScore,
            fifth.openerScore * 5,
            "A one-unit opening roster should carry a whole comp's vote, five times a fifth of one"
        )
    }

    // MARK: - The 3-cost reroll rule

    /// A 3-cost is admitted only where the corpus rerolls it to 3 stars —
    /// the one case where buying it early *is* the plan. The signal lives on
    /// `units[].starTarget`, not on `earlyUnits`, so this is a deliberate
    /// cross-reference between the two lists.
    func testAThreeCostAppearsOnlyWhenItIsARerollCarry() throws {
        let comps = try [
            makeComp(
                id: "s1",
                tier: .s,
                units: [unit("Reroll", cost: 3, starTarget: 3, role: .carry)],
                earlyUnits: ["Reroll", "Stopgap"]
            ),
            makeComp(id: "s2", tier: .s, units: [unit("Stopgap", cost: 3, starTarget: 2)]),
        ]
        let index = OpenerIndex(comps: comps)

        XCTAssertEqual(index.mostFlexible.map(\.name), ["Reroll"])
        XCTAssertEqual(index.comps(leadingFrom: "Stopgap"), [], "A 2-star 3-cost is not an opening plan")
    }

    /// Nothing dearer than a 3-cost is ever an opener, whatever an early
    /// roster claims. The real corpus names no cost-4 or cost-5 unit in any
    /// early roster, so this guards the rule against a future bad scrape
    /// rather than today's data.
    func testAFourOrFiveCostIsNeverAnOpenerEvenIfAnEarlyRosterNamesOne() throws {
        let comp = try makeComp(
            id: "s1",
            tier: .s,
            units: [
                unit("Cheap", cost: 1),
                unit("Dear", cost: 4, starTarget: 3),
                unit("Dearest", cost: 5, starTarget: 3),
            ]
        )
        let index = OpenerIndex(comps: [comp])

        XCTAssertEqual(index.mostFlexible.map(\.name), ["Cheap"])
        XCTAssertEqual(OpenerIndex.maximumOpenerCost, 3)
    }

    // MARK: - Determinism

    func testTiesBreakDeterministicallyByName() throws {
        let comps = try [
            makeComp(id: "s1", tier: .s, units: [unit("Zeta", cost: 2), unit("Alpha", cost: 2)]),
        ]
        let index = OpenerIndex(comps: comps)

        XCTAssertEqual(index.topOpeners.map(\.name), ["Alpha", "Zeta"])
        XCTAssertEqual(index.mostFlexible.map(\.name), ["Alpha", "Zeta"])
    }

    /// "Ambi" appears as a 1-cost in one S-tier comp and a 3-cost in
    /// another. Last-write-wins would make the resolved cost depend on
    /// which comp the tally visits last -- i.e. on input order. Resolving
    /// to the minimum instead must produce the exact same output (not just
    /// the same cost field) whether the comps are fed forward or reversed.
    func testConflictingUnitCostResolvesToMinimumRegardlessOfOrder() throws {
        let comps = try [
            makeComp(id: "s1", tier: .s, units: [unit("Ambi", cost: 1)]),
            makeComp(id: "s2", tier: .s, units: [unit("Ambi", cost: 3)]),
        ]

        let forward = OpenerIndex(comps: comps)
        let reversed = OpenerIndex(comps: comps.reversed())

        XCTAssertEqual(Set(forward.topOpeners), Set(reversed.topOpeners))
        XCTAssertEqual(Set(forward.mostFlexible), Set(reversed.mostFlexible))
        XCTAssertEqual(forward.topOpeners.first?.cost, 1)
        XCTAssertEqual(reversed.topOpeners.first?.cost, 1)
    }

    /// The catalog is authoritative over the corpus, because `earlyUnits`
    /// carries no cost of its own and the catalog is where cost is
    /// single-sourced.
    func testTheSuppliedCatalogWinsOverTheCostTheCorpusBoardsClaim() throws {
        let comp = try makeComp(id: "s1", tier: .s, units: [unit("Mislabelled", cost: 3)])

        XCTAssertEqual(OpenerIndex(comps: [comp]).mostFlexible, [], "A 2-star 3-cost is ineligible")
        XCTAssertEqual(
            OpenerIndex(comps: [comp], championCosts: ["Mislabelled": 1]).mostFlexible.map(\.cost),
            [1]
        )
    }

    // MARK: - Corpus edge cases

    func testACompThatNamesNoEarlyRosterContributesNothing() throws {
        let comps = try [
            makeComp(id: "silent", tier: .s, units: [unit("Alpha", cost: 1)], earlyUnits: []),
            makeComp(id: "spoken", tier: .a, units: [unit("Bravo", cost: 1)]),
        ]
        let index = OpenerIndex(comps: comps)

        XCTAssertEqual(index.mostFlexible.map(\.name), ["Bravo"])
        XCTAssertEqual(index.comps(leadingFrom: "Alpha"), [])
    }

    func testSingleCompCorpusProducesResultsWithoutCrashing() throws {
        let comp = try makeComp(
            id: "solo",
            tier: .s,
            units: [unit("Alpha", cost: 2), unit("Bravo", cost: 5, role: .carry)],
            carries: [CompCarry(unit: "Bravo", itemPriority: ["Infinity Edge"])]
        )
        let index = OpenerIndex(comps: [comp])

        // Bravo is a 5-cost, out of the opener range entirely.
        XCTAssertEqual(index.topOpeners.map(\.name), ["Alpha"])
        XCTAssertEqual(index.mostFlexible.map(\.name), ["Alpha"])
        XCTAssertEqual(index.comps(leadingFrom: "Alpha").map(\.id), ["solo"])
        XCTAssertEqual(index.comps(leadingFrom: "Bravo"), [], "5-cost carries are outside the opener pool")
        XCTAssertEqual(index.componentDemand.map(\.componentName).sorted(), ["B.F. Sword", "Sparring Gloves"])
    }

    func testCorpusWithNoSTierComps() throws {
        let comps = try [
            makeComp(id: "a1", tier: .a, units: [unit("Alpha", cost: 2)]),
            makeComp(
                id: "a2",
                tier: .a,
                units: [unit("Alpha", cost: 2)],
                carries: [CompCarry(unit: "Alpha", itemPriority: ["Infinity Edge"])]
            ),
        ]
        let index = OpenerIndex(comps: comps)

        XCTAssertEqual(index.topOpeners.map(\.name), ["Alpha"])
        XCTAssertEqual(index.topOpeners.first?.topTierRosterCount, 2)
        XCTAssertEqual(index.mostFlexible.map(\.name), ["Alpha"])
        // Component demand only reads S-tier carries; with none present it
        // must be empty, not crash or fall back to A-tier data.
        XCTAssertEqual(index.componentDemand, [])
    }

    func testEmptyCorpusProducesEmptyResultsWithoutCrashing() {
        let index = OpenerIndex(comps: [])

        XCTAssertEqual(index.topOpeners, [])
        XCTAssertEqual(index.mostFlexible, [])
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
            units: [unit("Carry", cost: 3, role: .carry)],
            carries: [CompCarry(unit: "Carry", itemPriority: ["Zeke's Emblem", "Infinity Edge"])]
        )
        let index = OpenerIndex(comps: [comp])

        XCTAssertEqual(index.componentDemand.map(\.componentName).sorted(), ["B.F. Sword", "Sparring Gloves"])
    }

    // MARK: - Distinctness of topOpeners vs. mostFlexible

    /// "Present" opens one S comp, so it tops `topOpeners`. "Shared" opens
    /// four D-tier comps -- zero weight in `topOpeners` (dropped from that
    /// list entirely) but the highest `sharedCompCount` in the corpus, so it
    /// tops `mostFlexible`. The two rankings must disagree on their leaders,
    /// not just reorder the tail.
    func testTopOpenersAndMostFlexibleRankDifferentUnitsFirst() throws {
        var comps = try [makeComp(id: "s1", tier: .s, units: [unit("Present", cost: 2)])]
        comps += try (1 ... 4).map { number in
            try makeComp(id: "d\(number)", tier: .d, units: [unit("Shared", cost: 2)])
        }
        let index = OpenerIndex(comps: comps)

        XCTAssertEqual(index.topOpeners.map(\.name), ["Present"], "Shared has zero S/A weight and must be absent")
        XCTAssertEqual(index.mostFlexible.first?.name, "Shared")
        XCTAssertNotEqual(index.topOpeners.first?.name, index.mostFlexible.first?.name)
    }
}
