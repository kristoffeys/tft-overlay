import SwiftUI
@testable import TFTUI
import XCTest

/// The suggestions basis note (#87): where it sits, and whether the sentence
/// it draws is true.
///
/// Split out of `MyChampionsViewSnapshotTests` because it is a different kind
/// of assertion. That suite renders geometry; these read the copy. The note is
/// the panel's honesty surface — it is the only thing telling the player the
/// order comes from an authored tier list rather than measured placements
/// (ADR 0004) — so its claims are asserted as strings, which is both stronger
/// than a raster and legible in a failure message.
///
/// Three things shipped wrong here and each has a case below: the note lived
/// inside the `ScrollView` and scrolled away, it rendered "The 1 comps you are
/// closest to", and it named neither the comps the cap hid nor the fact that a
/// full roster ties every entry and leaves the tier list ordering the whole
/// list on its own.
@MainActor
final class MyChampionsBasisNoteTests: XCTestCase {
    private let expanded = CGSize(width: 460, height: 640)
    private let compact = CGSize(width: 300, height: 320)

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        suiteName = "MyChampionsBasisNoteTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func store() -> OwnedChampionsStore {
        OwnedChampionsStore(defaults: defaults)
    }

    private func panel(
        comps: [Comp]? = nil,
        store: OwnedChampionsStore
    ) throws -> MyChampionsView {
        try MyChampionsView(comps: comps ?? CompLoader.bundledFixtures(), ownedStore: store)
    }

    /// Two comps matched at genuinely different overlap, nothing hidden by the
    /// cap.
    ///
    /// A deliberately small corpus rather than the bundled one: three marked
    /// champions already match 23 of the 36 real comps, which overflows the
    /// cap and puts the note into its remainder wording. This shape pins the
    /// un-truncated, overlap-ordered case the real corpus cannot reach.
    ///
    /// The shared unit is a 5-cost carry in one comp and a 1-cost in the
    /// other, so the two land in different overlap bands and tier never gets
    /// to decide the order.
    private func twoCompsAtDifferentOverlap() throws -> [Comp] {
        try [
            CompFixture.dominantShape(
                id: "shared-as-carry",
                tier: .b,
                names: ["Sharedunit", "A4", "A4b", "A3", "A2", "A2b", "A1", "A1b"]
            ),
            CompFixture.dominantShape(
                id: "shared-as-filler",
                tier: .s,
                names: ["B5", "B4", "B4b", "B3", "B2", "B2b", "Sharedunit", "B1b"]
            ),
        ]
    }

    // MARK: - Where it sits

    /// The note explaining the ordering sits above the scroll view, so it
    /// cannot be scrolled out of sight.
    ///
    /// It used to be the first child of `suggestionsContent`, i.e. inside the
    /// `ScrollView`, and one flick made it vanish — the panel's own reasoning
    /// says a disclaimer you have to scroll to does not exist. `basisNote` is
    /// a member rendered by `body` above the `ScrollView`, exactly like the
    /// openers panel's, and it has to stay a footnote rather than grow into a
    /// banner that eats the rankings.
    /// Measured for the *longest* copy the note can produce, not a
    /// comfortable one.
    ///
    /// A full roster puts the note into both its wordiest branches at once —
    /// the remainder clause and the everything-tied clause — so that, at the
    /// narrowest width, is the worst case. Bounding a shorter roster instead
    /// would leave the branch most likely to become a banner unmeasured.
    /// 80pt is five lines of 10pt text plus padding, which is what it takes
    /// at 300pt today; it must not quietly grow past that.
    func testTheSuggestionsBasisNoteIsAFootnoteAtBothPanelWidths() throws {
        let owned = store()
        let probe = try panel(store: owned)
        for champion in probe.filteredChampions {
            owned.add(champion.name)
        }
        let view = try panel(store: owned)
        XCTAssertTrue(view.showsBasisNote)
        XCTAssertTrue(
            view.suggestionsAreTiedOnOverlap && view.matchingCount > view.suggestions.count,
            "This roster is meant to produce the note's longest copy"
        )

        for width in [expanded.width, compact.width] {
            let height = try ViewSnapshot.measuredSize(of: view.basisNote, proposedWidth: width).height
            XCTAssertGreaterThan(height, 0)
            XCTAssertLessThanOrEqual(
                height,
                80,
                "The always-on suggestions basis note is \(height)pt at \(width)pt in its longest "
                    + "form; it should be a footnote, not a banner"
            )
            try assertRendersWithin(
                view.basisNote,
                size: CGSize(width: width, height: height),
                rightMargin: 8,
                // A few lines of 10pt text in a wide strip is sparse ink.
                minimumInk: 0.002
            )
        }
    }

    /// Both empty states carry their own copy, so the note has nothing to
    /// explain and must not draw an ordering claim over an empty list.
    func testTheBasisNoteIsHiddenWhenThereIsNoRankingToDescribe() throws {
        let nothingMarked = try panel(store: store())
        XCTAssertFalse(nothingMarked.showsBasisNote, "Nothing is marked, so there is no order to explain")

        let noMatch = store()
        noMatch.add("Nobodyhasthisunit")
        let unmatched = try panel(store: noMatch)
        XCTAssertEqual(unmatched.ownedCount, 1)
        XCTAssertTrue(unmatched.suggestions.isEmpty)
        XCTAssertFalse(unmatched.showsBasisNote, "Nothing matched, so there is no order to explain")
    }

    // MARK: - What it says

    /// Exactly one match is a reachable state, and the note has to read like
    /// English in it.
    ///
    /// It used to render "The 1 comps you are closest to" — the panel visibly
    /// not proofreading itself, in the one place whose whole job is to be
    /// believed.
    func testTheBasisNoteReadsAsEnglishForASingleMatch() throws {
        let comps = try [
            CompFixture.dominantShape(
                id: "only-match",
                tier: .a,
                names: ["Soleunique", "Four", "Fourb", "Three", "Two", "Twob", "One", "Oneb"]
            ),
            CompFixture.dominantShape(
                id: "no-overlap",
                tier: .s,
                names: ["Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta", "Theta"]
            ),
        ]
        let owned = store()
        owned.add("Soleunique")
        let view = try panel(comps: comps, store: owned)

        XCTAssertEqual(view.suggestions.count, 1, "This fixture is meant to match exactly one comp")
        XCTAssertTrue(
            view.basisNoteText.hasPrefix("The comp you are closest to"),
            "With one match the note reads \"\(view.basisNoteText)\""
        )
        XCTAssertFalse(
            view.basisNoteText.contains("1 comps"),
            "The note says \"1 comps\": \"\(view.basisNoteText)\""
        )
    }

    /// More than one match keeps the count and the plural.
    func testTheBasisNoteCountsAndPluralisesSeveralMatches() throws {
        let owned = store()
        owned.add("Sharedunit")
        let comps = try twoCompsAtDifferentOverlap()
        let view = try panel(comps: comps, store: owned)

        XCTAssertEqual(view.suggestions.count, 2)
        XCTAssertTrue(
            view.basisNoteText.hasPrefix("The 2 comps you are closest to"),
            "With two matches the note reads \"\(view.basisNoteText)\""
        )
    }

    /// A full roster matches 36 comps and the panel draws 12. The note has to
    /// say so, and has to stop claiming overlap ordered a list overlap did not
    /// order.
    ///
    /// With every champion marked, all 12 rows read "8/8 — You have every
    /// unit", every entry ties on overlap, and the order is 100% authored tier
    /// list. The old copy said "near-ties fall back to the tier list", which
    /// understated that to the point of being wrong, and named no total at all
    /// — so 24 equally reachable comps were invisible with nothing in the UI
    /// pointing at them.
    func testTheBasisNoteNamesTheTotalAndTheTierFallbackForAFullRoster() throws {
        let owned = store()
        let view = try panel(store: owned)
        for champion in view.filteredChampions {
            owned.add(champion.name)
        }

        XCTAssertGreaterThan(
            view.matchingCount,
            view.suggestions.count,
            "This roster does not overflow the cap, so there is no hidden remainder to name"
        )
        XCTAssertTrue(
            view.suggestionsAreTiedOnOverlap,
            "A full roster should tie every suggestion on overlap"
        )
        XCTAssertTrue(
            view.basisNoteText.contains("\(view.suggestions.count) closest of \(view.matchingCount) matching"),
            "The note hides the remainder: \"\(view.basisNoteText)\""
        )
        XCTAssertTrue(
            view.basisNoteText.contains("nothing but"),
            "Every entry is tied on overlap but the note still credits overlap: \"\(view.basisNoteText)\""
        )
        XCTAssertFalse(
            view.basisNoteText.contains("Near-ties"),
            "Nothing here is a near-tie — everything is an exact tie: \"\(view.basisNoteText)\""
        )
    }

    /// A corpus small enough that nothing is hidden must not invent a total,
    /// and a list genuinely ordered by overlap must keep the near-tie wording.
    ///
    /// The other half of the full-roster assertion above: the remainder clause
    /// and the tier-fallback clause both have to be conditional, or they are
    /// just new boilerplate that is wrong in the opposite direction.
    func testTheBasisNoteNamesNoTotalWhenNothingIsHidden() throws {
        let owned = store()
        owned.add("Sharedunit")
        let comps = try twoCompsAtDifferentOverlap()
        let view = try panel(comps: comps, store: owned)

        XCTAssertEqual(
            view.matchingCount,
            view.suggestions.count,
            "This corpus is meant to fit under the cap with nothing hidden"
        )
        XCTAssertFalse(
            view.suggestionsAreTiedOnOverlap,
            "The shared unit is a 5-cost carry in one comp and a 1-cost in the other, "
                + "so these should not tie on overlap"
        )
        XCTAssertFalse(
            view.basisNoteText.contains("matching"),
            "Nothing is hidden but the note names a remainder: \"\(view.basisNoteText)\""
        )
        XCTAssertTrue(
            view.basisNoteText.contains("Near-ties"),
            "Overlap ordered this list, so the near-tie wording should stand: \"\(view.basisNoteText)\""
        )
    }
}
