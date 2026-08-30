import AppKit
import SwiftUI
@testable import TFTUI
import XCTest

/// #111 in the hover card. A bonus surface, never the only place a recipe
/// appears: hover only fires on an unlocked panel (#83), and during a fight
/// the panel is locked and passing clicks through to the game.
///
/// The card is a fixed 200pt wide, which `measuredSize` will report whatever
/// its children want — so the width claim here is built from the children's
/// own measurements instead.
@MainActor
final class UnitItemTooltipRecipeTests: XCTestCase {
    /// Mirrors `UnitItemTooltip`: 200pt wide, 10pt padding each side, 6pt
    /// between item columns.
    private let contentWidth = UnitItemTooltip.width - 2 * 10
    private let columnSpacing: CGFloat = 6

    private func summary(_ items: [String]) -> UnitItemSummary {
        UnitItemSummary(
            name: "Ashe",
            cost: 4,
            role: .carry,
            starTarget: 2,
            itemPriority: items
        )
    }

    private func height(_ view: some View) throws -> CGFloat {
        try ViewSnapshot.measuredSize(of: view, proposedWidth: UnitItemTooltip.width).height
    }

    func testTheCardShowsRecipesUnderItsItems() throws {
        let card = UnitItemTooltip(summary: summary(["Infinity Edge", "Giant Slayer", "Guinsoo's Rageblade"]))
        let withRecipes = try height(card)
        let without = try height(card.tftItemRecipes(.empty))
        XCTAssertGreaterThanOrEqual(
            withRecipes,
            without + 20,
            "\(withRecipes)pt with recipes against \(without)pt without — no component row is drawn"
        )
    }

    /// Every item any carry in the corpus names, at the widest priority list
    /// the corpus actually has: three columns of components inside a 200pt
    /// card is the tightest fit any surface asks of this view.
    func testTheWidestRecipeColumnsInTheCorpusFitTheCard() throws {
        var widest: CGFloat = 0
        var widestName = ""
        var mostItems = 0
        for comp in try CompLoader.bundledFixtures() {
            for carry in comp.carries {
                mostItems = max(mostItems, carry.itemPriority.count)
                for name in carry.itemPriority {
                    let width = try ViewSnapshot.measuredSize(
                        of: ItemWithRecipe(name: name, size: 30, componentSize: 20),
                        proposedWidth: contentWidth
                    ).width
                    if width > widest {
                        widest = width
                        widestName = name
                    }
                }
            }
        }
        XCTAssertGreaterThan(mostItems, 1, "the corpus should carry multi-item priorities")
        let needed = CGFloat(mostItems) * widest + CGFloat(mostItems - 1) * columnSpacing
        XCTAssertLessThanOrEqual(
            needed,
            contentWidth,
            "\(mostItems) columns of \(widestName) need \(needed)pt inside the card's \(contentWidth)pt"
        )
    }

    /// The card is placed in its own window from a measurement taken before
    /// it is ever shown, so a card that cannot measure itself is invisible
    /// (#83). Re-checked with recipes in it.
    func testTheCardWithRecipesStillMeasuresNonZeroForItsOwnWindow() {
        let hosting = NSHostingView(
            rootView: AnyView(UnitItemTooltip(summary: summary(["Infinity Edge", "Rapid Firecannon"])))
        )
        XCTAssertGreaterThan(hosting.fittingSize.width, 0)
        XCTAssertGreaterThan(hosting.fittingSize.height, 0)
    }

    /// A carry holding one of the two artifacts gets the label, not a blank
    /// pair, in here too.
    func testAnArtifactInTheCardIsLabelled() throws {
        let card = UnitItemTooltip(summary: summary(["Rapid Firecannon"]))
        XCTAssertGreaterThan(
            try height(card),
            try height(card.tftItemRecipes(.empty)),
            "Rapid Firecannon drew nothing under it"
        )
    }
}
