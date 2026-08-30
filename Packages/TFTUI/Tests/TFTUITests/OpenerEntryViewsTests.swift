import SwiftUI
@testable import TFTUI
import XCTest

/// The meta-pickups bar (#108 review): whatever magnitude it draws must fall
/// as the list does, because it sits beside a second, differently-ordered
/// number (`topTierRosterCount`) and a reader has no way to tell the two
/// apart except by looking.
///
/// `OpenersView.metaPickups` is `OpenerIndex.topOpeners`, already sorted by
/// `openerScore` descending. `MetaPickupRow.fraction` has to be derived from
/// that same `openerScore` and nothing else — derive it from a plain count
/// instead (`topTierRosterCount` or `sharedCompCount`) and the bar can go
/// *up* the list on the real corpus, because the ranking also weights how
/// much of a comp's early roster a unit is: a unit that is one comp's whole
/// opening board can outscore one that merely appears on more boards.
///
/// Runs against the real bundled corpus, not a synthetic fixture — the whole
/// point is that this is the shape of bug a small hand-built fixture would
/// not happen to reproduce.
@MainActor
final class OpenerEntryViewsTests: XCTestCase {
    /// Every row `OpenersView` actually renders (`OpenersView.rankingLimit`),
    /// not just the first three the PR review happened to screenshot — a
    /// fix that only straightens the top of the list is not a fix.
    private static let rankingLimit = 6

    /// Mirrors `OpenersView.metaPickups` / the `maximumScore` it passes to
    /// each `MetaPickupRow`, so this test exercises the exact values the
    /// panel renders rather than a hand-rolled approximation of them.
    private func metaPickupRows() throws -> [MetaPickupRow] {
        let comps = try CompLoader.bundledFixtures()
        let index = OpenerIndex(comps: comps)
        let metaPickups = Array(index.topOpeners.prefix(Self.rankingLimit))
        let maximumScore = metaPickups.first?.openerScore ?? 1
        return metaPickups.map { unit in
            MetaPickupRow(unit: unit, maximumScore: maximumScore, leadsTo: [], onSelectComp: { _ in })
        }
    }

    /// The regression guard for the #108 review: the bar's fraction must be
    /// non-increasing down the whole rendered list, on the real corpus.
    ///
    /// This is not a tautology on `topOpeners`' own sort order — it only
    /// holds because `fraction` is derived from the same `openerScore` that
    /// order is sorted by. See
    /// `testFractionDrivenByTheWrongCountIsNotMonotonicOnTheRealCorpus` for
    /// the mutation this pins against: swap `fraction`'s source to a plain
    /// count and this corpus produces a rise, not just a synthetic one.
    func testTheMetaPickupBarFallsMonotonicallyDownTheWholeRenderedList() throws {
        let rows = try metaPickupRows()
        XCTAssertGreaterThan(rows.count, 3, "Fewer than four meta pickups on the real corpus; widen the fixture")

        for (previous, current) in zip(rows, rows.dropFirst()) {
            XCTAssertGreaterThanOrEqual(
                previous.fraction,
                current.fraction,
                "\(current.unit.name) (fraction \(current.fraction)) draws a longer bar than "
                    + "\(previous.unit.name) (fraction \(previous.fraction)) above it, "
                    + "even though the ranking put it lower"
            )
        }
    }

    /// Demonstrates the property above is real, not vacuous: computing the
    /// same rows' bar fraction from `topTierRosterCount` instead of
    /// `openerScore` — the plain count that sits beside the bar in the UI —
    /// is *not* monotonic on this corpus, because that count and
    /// `openerScore` order units differently (see `OpenerIndex` — roster
    /// share can put a unit that opens one comp above a unit that opens
    /// several). A test that cannot fail this way would not have caught the
    /// #108 review's screenshot.
    func testFractionDrivenByTheWrongCountIsNotMonotonicOnTheRealCorpus() throws {
        let comps = try CompLoader.bundledFixtures()
        let index = OpenerIndex(comps: comps)
        let metaPickups = Array(index.topOpeners.prefix(Self.rankingLimit))
        let maximumCount = metaPickups.first?.topTierRosterCount ?? 1
        let mistakenFractions = metaPickups.map { unit in
            maximumCount > 0 ? Double(unit.topTierRosterCount) / Double(maximumCount) : 0
        }

        let isMonotonic = zip(mistakenFractions, mistakenFractions.dropFirst()).allSatisfy { $0 >= $1 }
        XCTAssertFalse(
            isMonotonic,
            "topTierRosterCount happens to be monotonic on this corpus (\(mistakenFractions)) — "
                + "this fixture no longer demonstrates the bug the row above guards against"
        )
    }
}
