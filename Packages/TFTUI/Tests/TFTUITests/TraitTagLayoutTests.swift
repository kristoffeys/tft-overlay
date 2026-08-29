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
        _ result: (shown: [String], overflow: Int),
        availableWidth: CGFloat,
        spacing: CGFloat = 4,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard !result.shown.isEmpty else { return }

        var total = result.shown.reduce(0) { $0 + TraitTagLayout.width(of: $1) }
        total += spacing * CGFloat(result.shown.count - 1)
        if result.overflow > 0 {
            total += spacing + TraitTagLayout.width(of: TraitTagLayout.overflowLabel(result.overflow))
        }

        XCTAssertLessThanOrEqual(
            total,
            availableWidth,
            "Tags render \(total)pt wide but only \(availableWidth)pt is available",
            file: file,
            line: line
        )
    }
}
