import AppKit
import SwiftUI
@testable import TFTUI
import XCTest

/// #111's hover card: every item icon in the app answers "what is this made
/// of", including the roster grid's 11-20pt ones that cannot carry inline
/// component art.
///
/// Hover itself needs a real window and cannot be tested here — it is
/// verified live. What is testable is everything that made #83's cards
/// invisible: the card has to measure non-zero before it is ever shown, and
/// it has to fit the fixed width `FloatingTooltip` places it at.
@MainActor
final class ItemRecipeTooltipTests: XCTestCase {
    private let index = ItemRecipeIndex.bundled

    private func card(_ name: String) -> ItemRecipeTooltip {
        ItemRecipeTooltip(name: name, recipe: index.recipe(forItemNamed: name))
    }

    // MARK: - The card can be placed at all

    /// `FloatingTooltip.show` sizes the card's own window from
    /// `NSHostingView.fittingSize` before it is on screen; a card that
    /// measures zero is a card nobody ever sees (#83).
    func testEveryKindOfCardMeasuresNonZeroForItsOwnWindow() {
        for name in ["Infinity Edge", "Deathblade", "Executioner Emblem", "Rapid Firecannon"] {
            let hosting = NSHostingView(rootView: AnyView(card(name)))
            XCTAssertGreaterThan(hosting.fittingSize.width, 0, name)
            XCTAssertGreaterThan(hosting.fittingSize.height, 0, name)
        }
    }

    // MARK: - Component names fit beside their icons

    /// The card spells the components out, which is the whole reason it
    /// exists — the initials tile is a supported rendering and "BF" is not a
    /// recipe. So the longest component name in the set has to sit on one
    /// line: `Rabadon's Deathcap` is two Needlessly Large Rods, and if that
    /// wraps the card is taller than the same card with short names.
    func testTheLongestComponentNamesDoNotWrap() throws {
        let short = try ViewSnapshot.measuredSize(
            of: card("Deathblade"),
            proposedWidth: ItemRecipeTooltip.width
        ).height
        let long = try ViewSnapshot.measuredSize(
            of: card("Rabadon's Deathcap"),
            proposedWidth: ItemRecipeTooltip.width
        ).height
        XCTAssertEqual(
            long,
            short,
            accuracy: 1,
            "Needlessly Large Rod wrapped: \(long)pt against \(short)pt for B.F. Sword"
        )
    }

    /// Every item any carry in the corpus names, and both of the set's
    /// artifacts, at the card's fixed width — with a clear right margin, so
    /// nothing is laid out flush against the card's own edge.
    func testEveryCorpusItemsCardFitsTheCardWidth() throws {
        var names: Set = ["Rapid Firecannon", "Statikk Shiv", "Executioner Emblem"]
        for comp in try CompLoader.bundledFixtures() {
            for carry in comp.carries {
                names.formUnion(carry.itemPriority)
            }
        }
        XCTAssertGreaterThan(names.count, 20, "the corpus should name plenty of items")
        for name in names.sorted() {
            let view = card(name)
            let measured = try ViewSnapshot.measuredSize(of: view, proposedWidth: ItemRecipeTooltip.width)
            XCTAssertLessThanOrEqual(
                measured.width,
                ItemRecipeTooltip.width + ViewSnapshot.widthTolerance,
                "\(name)'s card wants \(measured.width)pt inside \(ItemRecipeTooltip.width)pt"
            )
            let raster = try ViewSnapshot.render(view, size: measured)
            // Inside the border, not including it: the card's accent stroke
            // runs all four edges and is ink by any threshold, so
            // `rightMarginIsClear` reports every card as overflowing. The
            // question worth asking is whether *content* reached the 10pt
            // padding, so this looks at the strip between the border and the
            // content, top and bottom rows excluded for the same reason.
            XCTAssertFalse(
                hasInk(
                    raster,
                    x: (raster.width - 9) ..< (raster.width - 3),
                    y: 4 ..< (raster.height - 4)
                ),
                "\(name)'s card draws content into its own 10pt right padding"
            )
        }
    }

    private func hasInk(_ raster: Raster, x columns: Range<Int>, y rows: Range<Int>) -> Bool {
        for x in columns {
            for y in rows where raster.luminance(x: x, y: y) > Raster.inkThreshold {
                return true
            }
        }
        return false
    }

    // MARK: - The artifacts

    /// The card says the item is an artifact instead of showing an empty
    /// pair, which means it is *shorter* than a card with two component rows
    /// and taller than nothing at all.
    func testAnArtifactsCardSaysSoInsteadOfShowingAnEmptyPair() throws {
        let craftable = try ViewSnapshot.measuredSize(
            of: card("Infinity Edge"),
            proposedWidth: ItemRecipeTooltip.width
        ).height
        for name in ["Rapid Firecannon", "Statikk Shiv"] {
            let view = card(name)
            XCTAssertEqual(view.recipe, .notCraftable, name)
            let measured = try ViewSnapshot.measuredSize(of: view, proposedWidth: ItemRecipeTooltip.width)
            XCTAssertLessThan(measured.height, craftable, "\(name) is drawing component rows it does not have")
            let raster = try ViewSnapshot.render(view, size: measured)
            XCTAssertGreaterThan(raster.inkCoverage(), 0.005, "\(name)'s card rendered effectively blank")
        }
    }

    // MARK: - An item with no recipe gets no card

    /// The hover is attached to `ItemIconPlaceholder` itself, so it is asked
    /// about every item name in the app — including ones the index has never
    /// heard of. Those get no card: a card saying nothing is worse than none,
    /// and not knowing an item is not evidence about how it is built.
    func testNoCardIsSummonedForAnItemWithNoKnownRecipe() {
        XCTAssertFalse(ItemRecipeTooltip.shows(index.recipe(forItemNamed: "Sword of a Thousand Truths")))
        XCTAssertTrue(ItemRecipeTooltip.shows(index.recipe(forItemNamed: "Infinity Edge")))
        XCTAssertTrue(
            ItemRecipeTooltip.shows(index.recipe(forItemNamed: "Statikk Shiv")),
            "an artifact does get a card — saying it cannot be built is the answer"
        )
    }
}
