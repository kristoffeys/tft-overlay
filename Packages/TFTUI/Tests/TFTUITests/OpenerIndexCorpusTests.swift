import Foundation
import TFTData
@testable import TFTUI
import XCTest

/// `OpenerIndex` against the real bundled corpus.
///
/// Split from `OpenerIndexTests`, which owns the synthetic cases: those pin
/// the weighting rules with three-comp fixtures, while these ask whether the
/// rules produce sane openers on the 36 comps the app actually ships. The
/// split is the same one `CompSuggestionRankingTests` /
/// `CompSuggestionTierBandTests` already draws, and it keeps the file that
/// carries the #99 regression guard readable.
///
/// The bundled corpus is scraper output (ADR 0004) and changes whenever the
/// maintainer re-runs it, so nothing here asserts an exact unit name or
/// score — only the properties that must hold whatever the scrape says.
final class OpenerIndexCorpusTests: XCTestCase {
    /// The regression guard for the whole class of bug in #99: the
    /// early-roster ranking and a final-board ranking over the *same* real
    /// corpus must not agree.
    ///
    /// The final-board ranking rebuilt here is the one `OpenerIndex` used to
    /// compute — tier-weighted presence in `units`, filtered to costs 1-3 —
    /// so this fails the moment anyone re-points the model at `units` again.
    /// Asserting on cost, not just on order: the measured failure was that
    /// every unit the panel surfaced was a cost 3.
    func testTheEarlyRosterRankingDiffersFromAFinalBoardRankingOnTheRealCorpus() throws {
        let comps = try CompLoader.bundledFixtures()
        let openers = OpenerIndex(comps: comps).topOpeners.prefix(6).map(\.name)
        let finalBoard = Self.finalBoardRanking(comps).prefix(6)

        XCTAssertEqual(openers.count, 6)
        XCTAssertEqual(finalBoard.count, 6)
        XCTAssertTrue(
            Set(openers).isDisjoint(with: Set(finalBoard)),
            "The early-roster ranking (\(openers)) still shares units with a final-board ranking "
                + "(\(Array(finalBoard))), which is the bug #99 is about"
        )
    }

    /// What #99 measured in the real window: the old ranking's top six were
    /// all cost 3. The new one has to be dominated by 1- and 2-costs, and by
    /// construction can contain a 3-cost only as a reroll carry — of which
    /// this corpus's early rosters currently name none.
    func testTheRealCorpusRanksCheapUnitsFirstAndNeverAnExpensiveOne() throws {
        let comps = try CompLoader.bundledFixtures()
        let index = OpenerIndex(comps: comps)
        let top = index.topOpeners.prefix(6)

        XCTAssertEqual(top.count, 6)
        XCTAssertTrue(
            top.allSatisfy { $0.cost <= 2 },
            "Costs in the top six are \(top.map(\.cost)); this corpus's early rosters contain no reroll 3-cost"
        )
        for ranking in [index.topOpeners, index.mostFlexible] {
            XCTAssertTrue(
                ranking.allSatisfy { (1 ... OpenerIndex.maximumOpenerCost).contains($0.cost) },
                "An opener outside cost 1-\(OpenerIndex.maximumOpenerCost) reached the ranking"
            )
        }
        for unit in index.mostFlexible {
            for comp in index.comps(leadingFrom: unit.name) {
                XCTAssertTrue(comps.contains { $0.id == comp.id })
            }
        }
    }

    /// Every opener the real corpus ranks is named by some comp's
    /// `earlyUnits`, and no ranked unit comes from a final board alone.
    func testEveryRankedOpenerIsNamedByAnEarlyRoster() throws {
        let comps = try CompLoader.bundledFixtures()
        let namedEarly = Set(comps.flatMap(\.earlyUnits))
        let index = OpenerIndex(comps: comps)

        XCTAssertFalse(namedEarly.isEmpty, "The bundled corpus carries no early rosters at all")
        for unit in index.mostFlexible {
            XCTAssertTrue(namedEarly.contains(unit.name), "\(unit.name) is ranked but opens nothing")
        }
    }

    /// The ranking `OpenerIndex` used to produce, kept here as the thing the
    /// new one is measured against rather than as a thing anyone should
    /// compute: tier-weighted presence in `units`, the final board.
    private static func finalBoardRanking(_ comps: [Comp]) -> [String] {
        var weightByName: [String: Int] = [:]
        for comp in comps {
            let weight = switch comp.tier {
            case .s: 2
            case .a: 1
            case .b, .c, .d: 0
            }
            for unit in comp.units where (1 ... 3).contains(unit.cost) {
                weightByName[unit.name, default: 0] += weight
            }
        }
        return weightByName
            .filter { $0.value > 0 }
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .map(\.key)
    }
}
