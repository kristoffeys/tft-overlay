import SwiftUI
@testable import TFTUI
import XCTest

/// #111: the detail panel's "Carries & Items" cards show what each item is
/// built from.
///
/// This is the primary surface — behind the "Full build detail" disclosure
/// and inside a `ScrollView`, so it has no height budget and the recipes can
/// be legible rather than merely present. What it does still have is a width
/// budget: 460pt by default and 420pt at the resize floor.
@MainActor
final class CarryCardRecipeTests: XCTestCase {
    /// The width one card gets inside the panel's 16pt page padding and the
    /// section card's own 12pt, at both panel widths.
    private let cardWidths: [CGFloat] = [460 - 2 * 16 - 2 * 12, 420 - 2 * 16 - 2 * 12]

    private func carryCards(_ comp: Comp) -> [CarryCard] {
        comp.carryUnits.map { CarryCard(carry: $0.carry, unit: $0.unit) }
    }

    private func comp(_ id: String) throws -> Comp {
        try XCTUnwrap(CompLoader.bundledFixtures().first { $0.id == id }, id)
    }

    // MARK: - The recipes are in this surface

    /// Measured against the same card with recipes switched off through the
    /// environment, so the claim is "this card draws recipes", not "this card
    /// is some height". A card that went back to bare `ItemIconPlaceholder`s
    /// measures identically to the opted-out one and fails here.
    func testACarryCardIsTallerThanTheSameCardWithoutRecipes() throws {
        let card = try XCTUnwrap(carryCards(comp("blossom-spellweavers")).first)
        for width in cardWidths {
            let withRecipes = try ViewSnapshot.measuredSize(of: card, proposedWidth: width).height
            let without = try ViewSnapshot.measuredSize(
                of: card.tftItemRecipes(.empty),
                proposedWidth: width
            ).height
            XCTAssertGreaterThanOrEqual(
                withRecipes,
                without + 24,
                "at \(width)pt the card is \(withRecipes)pt with recipes and \(without)pt without — "
                    + "the component row is not being drawn"
            )
        }
    }

    /// Every comp, so a carry with three items or an unusually long item name
    /// is caught here rather than on screen.
    func testEveryCarryCardInTheCorpusFitsBothPanelWidths() throws {
        for comp in try CompLoader.bundledFixtures() {
            for card in carryCards(comp) {
                for width in cardWidths {
                    let measured = try ViewSnapshot.measuredSize(of: card, proposedWidth: width)
                    XCTAssertLessThanOrEqual(
                        measured.width,
                        width + ViewSnapshot.widthTolerance,
                        "\(comp.id): a carry card wants \(measured.width)pt inside \(width)pt"
                    )
                }
            }
        }
    }

    /// The one comp in the corpus whose carry names an artifact. Its card must
    /// still be taller than the no-recipe rendering — the "ARTIFACT" label is
    /// the answer for that item, and a blank slot would not be.
    func testACarryHoldingAnArtifactStillSaysSomethingUnderIt() throws {
        var checked = 0
        for comp in try CompLoader.bundledFixtures() {
            for pair in comp.carryUnits {
                let artifacts = pair.carry.itemPriority.filter {
                    ItemRecipeIndex.bundled.recipe(forItemNamed: $0) == .notCraftable
                }
                guard !artifacts.isEmpty else { continue }
                checked += 1
                let card = CarryCard(carry: pair.carry, unit: pair.unit)
                let withRecipes = try ViewSnapshot.measuredSize(of: card, proposedWidth: cardWidths[0]).height
                let without = try ViewSnapshot.measuredSize(
                    of: card.tftItemRecipes(.empty),
                    proposedWidth: cardWidths[0]
                ).height
                XCTAssertGreaterThan(
                    withRecipes,
                    without,
                    "\(comp.id)/\(pair.unit.name) holds \(artifacts) and draws nothing under them"
                )
            }
        }
        XCTAssertGreaterThan(checked, 0, "no comp in the corpus names an artifact — this test proved nothing")
    }

    // MARK: - The card still draws

    func testACarryCardRendersInkThroughoutAtBothWidths() throws {
        let card = try XCTUnwrap(carryCards(comp("blossom-spellweavers")).first)
        for width in cardWidths {
            let height = try ViewSnapshot.measuredSize(of: card, proposedWidth: width).height
            try assertRendersWithin(
                card,
                size: CGSize(width: width, height: height),
                rightMargin: 4
            )
        }
    }
}
