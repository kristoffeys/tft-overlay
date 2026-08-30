@testable import TFTUI
import XCTest

final class TraitTagLayoutTests: XCTestCase {
    /// Traits from the committed Set 18 fixtures. "Executioner" is the one that
    /// wrapped to "Execution / er" in the 460pt overlay panel.
    private let elderwoodTraits = ["Brawler", "Defender", "Elderwood", "Executioner"]

    /// Regression for the overlay wrapping bug.
    ///
    /// In the shipped 460pt panel the trait row gets roughly 210pt after the tier
    /// badge, two unit portraits and padding. All four fixture traits cannot fit in
    /// that, and the old code showed them anyway, so SwiftUI wrapped the text inside
    /// the capsules. The layout must drop tags instead.
    func testTraitRowNeverExceedsTheOverlayBudget() {
        let available: CGFloat = 210
        let result = TraitTagLayout.fit(elderwoodTraits, availableWidth: available)

        XCTAssertLessThan(
            result.shown.count,
            elderwoodTraits.count,
            "All four traits cannot fit in \(available)pt; some must be dropped"
        )
        XCTAssertGreaterThan(result.overflow, 0)
        XCTAssertEqual(result.shown.count + result.overflow, elderwoodTraits.count)
        assertFits(result, availableWidth: available)
    }

    /// The selection plus its "+N" counter must always fit the budget — that is the
    /// whole point, and an off-by-one here reintroduces the wrap.
    func testSelectionAlwaysFitsAcrossWidths() {
        for available in stride(from: 40.0, through: 600.0, by: 10.0) {
            let result = TraitTagLayout.fit(elderwoodTraits, availableWidth: CGFloat(available))
            assertFits(result, availableWidth: CGFloat(available))
        }
    }

    func testGenerousWidthShowsEverythingWithNoOverflow() {
        let result = TraitTagLayout.fit(elderwoodTraits, availableWidth: 1000)
        XCTAssertEqual(result.shown, elderwoodTraits)
        XCTAssertEqual(result.overflow, 0)
    }

    func testWidthTooSmallForAnyTagShowsNothing() {
        let result = TraitTagLayout.fit(elderwoodTraits, availableWidth: 10)
        XCTAssertTrue(result.shown.isEmpty)
        XCTAssertEqual(result.overflow, elderwoodTraits.count)
    }

    func testEmptyInputIsHandled() {
        let result = TraitTagLayout.fit([], availableWidth: 200)
        XCTAssertTrue(result.shown.isEmpty)
        XCTAssertEqual(result.overflow, 0)
    }

    func testLongerTraitNameMeasuresWider() {
        XCTAssertGreaterThan(
            TraitTagLayout.width(of: "Executioner"),
            TraitTagLayout.width(of: "Coven")
        )
    }

    // MARK: - Helper

    /// Asserts the shown tags plus the overflow counter fit inside `availableWidth`.
    private func assertFits(
        _ result: TraitTagLayout.Fit,
        availableWidth: CGFloat,
        spacing: CGFloat = 4,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for (index, tags) in result.lines.enumerated() where !tags.isEmpty {
            var total = tags.reduce(0) { $0 + TraitTagLayout.width(of: $1) }
            total += spacing * CGFloat(tags.count - 1)
            let isLastLine = index == result.lines.count - 1
            if isLastLine, result.overflow > 0 {
                total += spacing + TraitTagLayout.width(of: TraitTagLayout.overflowLabel(result.overflow))
            }

            XCTAssertLessThanOrEqual(
                total,
                availableWidth,
                "Line \(index) renders \(total)pt wide but only \(availableWidth)pt is available",
                file: file,
                line: line
            )
        }
    }
}

/// Which traits survive a squeeze, and why.
final class TraitTagPriorityTests: XCTestCase {
    private let elderwoodTraits = ["Brawler", "Defender", "Elderwood", "Executioner"]

    /// The behaviour the tag row shipped with: alphabetical input order meant
    /// the *least* relevant trait was the one guaranteed a slot.
    func testHighestWeightedTraitSurvivesASqueeze() {
        let priority = ["Elderwood": 6, "Executioner": 3, "Defender": 2, "Brawler": 1]
        let fit = TraitTagLayout.fit(elderwoodTraits, availableWidth: 120, priority: priority)

        XCTAssertGreaterThan(fit.overflow, 0, "120pt should not fit all four tags")
        XCTAssertEqual(fit.shown.first, "Elderwood")
        XCTAssertFalse(fit.shown.contains("Brawler"), "The one-unit trait should be the first dropped")
    }

    /// Without priority the caller's order is preserved exactly, so existing
    /// call sites are unaffected.
    func testNoPriorityLeavesInputOrderAlone() {
        let fit = TraitTagLayout.fit(elderwoodTraits, availableWidth: 1000)
        XCTAssertEqual(fit.shown, elderwoodTraits)
    }

    func testEqualWeightsAreStable() {
        let flat = Dictionary(uniqueKeysWithValues: elderwoodTraits.map { ($0, 1) })
        XCTAssertEqual(TraitTagLayout.prioritized(elderwoodTraits, by: flat), elderwoodTraits)
    }

    /// `hidden` must come from the ranked order, not the caller's array —
    /// otherwise the overflow tooltip names the wrong traits.
    func testHiddenTraitsComeFromTheRankedOrder() {
        let priority = ["Brawler": 9]
        let fit = TraitTagLayout.fit(elderwoodTraits, availableWidth: 120, priority: priority)

        XCTAssertEqual(fit.shown.first, "Brawler")
        XCTAssertEqual(fit.overflow, fit.hidden.count)
        XCTAssertTrue(fit.hidden.allSatisfy { !fit.shown.contains($0) })
        XCTAssertEqual(Set(fit.shown).union(fit.hidden), Set(elderwoodTraits))
    }

    func testCompWeightsCountUnitsCarryingEachTrait() throws {
        let comps = try CompLoader.bundledFixtures()
        let comp = try XCTUnwrap(comps.first { !$0.units.isEmpty })
        let weights = TraitRelevance.weights(in: comp)

        for (trait, weight) in weights {
            XCTAssertEqual(weight, comp.units.filter { $0.traits.contains(trait) }.count)
        }
        // Several traits can tie for the top count, so assert on the weight
        // rather than on one arbitrary winner.
        let topWeight = try XCTUnwrap(weights.values.max())
        let fit = TraitTagLayout.fit(
            Array(weights.keys).sorted(),
            availableWidth: 140,
            priority: weights
        )
        let first = try XCTUnwrap(fit.shown.first)
        XCTAssertEqual(weights[first], topWeight)
    }

    /// A trait that activates off one unit outranks one that needs a crowd.
    func testUnitTraitWeightsFavourCheapActivations() {
        let weights = TraitRelevance.weightsForUnitTraits(["Elderwood", "Apex Predator"])
        XCTAssertGreaterThan(weights["Apex Predator"] ?? 0, weights["Elderwood"] ?? 0)
    }

    func testUncataloguedTraitsSortLast() {
        let traits = ["Not A Real Trait", "Hunter"]
        let weights = TraitRelevance.weightsForUnitTraits(traits)
        XCTAssertEqual(weights["Not A Real Trait"], 0)
        XCTAssertEqual(TraitTagLayout.prioritized(traits, by: weights), ["Hunter", "Not A Real Trait"])
    }
}
