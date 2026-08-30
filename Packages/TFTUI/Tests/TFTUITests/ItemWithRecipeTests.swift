import SwiftUI
@testable import TFTUI
import XCTest

/// Layout contract for the shared "item plus what it is built from" view
/// (#111).
///
/// Every case here renders with the default asset catalog, which is
/// `TFTAssetCatalog.empty` — the no-art mode the app genuinely runs in on
/// first launch and offline. So these are all the initials-tile fallback,
/// which is the harder case: the recipe has to read as a recipe when both
/// components are text tiles.
@MainActor
final class ItemWithRecipeTests: XCTestCase {
    private let itemSize: CGFloat = 36
    private let componentSize: CGFloat = 24

    private func column(_ name: String) -> ItemWithRecipe {
        ItemWithRecipe(name: name, size: itemSize, componentSize: componentSize)
    }

    private func height(_ view: some View) throws -> CGFloat {
        try ViewSnapshot.measuredSize(of: view, proposedWidth: 200).height
    }

    // MARK: - The recipe is actually drawn

    func testACraftableItemIsTallerThanItsIconByAComponentRow() throws {
        let bare = try height(ItemIconPlaceholder(name: "Infinity Edge", size: itemSize))
        let withRecipe = try height(column("Infinity Edge"))
        XCTAssertEqual(bare, itemSize, accuracy: 1)
        XCTAssertGreaterThanOrEqual(
            withRecipe,
            bare + componentSize,
            "the column measured \(withRecipe)pt — there is no component row under the \(bare)pt icon"
        )
    }

    /// The load-bearing one, and the reason the components are 24pt and not
    /// the 16pt that would have been cheapest: with no art loaded both tiles
    /// fall back to initials, and if only one of them is drawn — or if they
    /// are drawn on top of each other — this is a single smudge rather than a
    /// recipe. Mutation-checked by rendering only `first`: the right half
    /// comes back empty and this fails.
    func testTheComponentPairReadsAsTwoTilesWithNoArt() throws {
        let recipe = column("Infinity Edge").recipeRow
        let size = try ViewSnapshot.measuredSize(of: recipe, proposedWidth: 200)
        XCTAssertEqual(size.height, componentSize, accuracy: 1)
        XCTAssertGreaterThanOrEqual(
            size.width,
            2 * componentSize,
            "\(size.width)pt is not wide enough for two \(componentSize)pt component tiles"
        )

        // Each tile's *own* columns, not the two halves of the row: the "+"
        // glyph sits just past the midpoint, so a half-and-half check passes
        // with the right-hand tile rendered fully transparent — verified by
        // mutation, which is how this assertion got tightened.
        let raster = try ViewSnapshot.render(recipe, size: size)
        let tile = Int(componentSize * ViewSnapshot.scale)
        XCTAssertTrue(
            hasInk(raster, x: 0 ..< tile),
            "the left component drew nothing — the initials tile has to be legible at \(componentSize)pt"
        )
        XCTAssertTrue(
            hasInk(raster, x: (raster.width - tile) ..< raster.width),
            "the right component drew nothing"
        )
    }

    /// `Executioner Emblem` is Frying Pan + Sparring Gloves, and Frying Pan is
    /// not one of the eight standard components. A view that only knew the
    /// standard pool would draw nothing here.
    func testAnItemWhoseRecipeNamesANonStandardComponentStillShowsIt() throws {
        let view = column("Executioner Emblem")
        guard case let .components(first, second) = view.recipe else {
            return XCTFail("expected a component pair, got \(view.recipe)")
        }
        XCTAssertEqual([first.name, second.name], ["Frying Pan", "Sparring Gloves"])
        XCTAssertEqual(
            try height(view),
            try height(column("Infinity Edge")),
            accuracy: 1,
            "a non-standard component draws the same row as a standard one"
        )
    }

    // MARK: - The two artifacts

    /// Rapid Firecannon and Statikk Shiv have no recipe. Two blank slots
    /// there read as missing data, so the view says so instead — which means
    /// it must draw *something*, and something narrower than a component
    /// pair. Both halves of that matter: rendering the pair anyway measures
    /// the craftable height, and rendering nothing measures the bare icon.
    func testAnArtifactIsLabelledRatherThanLeftBlank() throws {
        let bare = try height(ItemIconPlaceholder(name: "Rapid Firecannon", size: itemSize))
        let craftable = try height(column("Infinity Edge"))
        for name in ["Rapid Firecannon", "Statikk Shiv"] {
            let artifact = column(name)
            XCTAssertEqual(artifact.recipe, .notCraftable, name)
            let measured = try height(artifact)
            XCTAssertGreaterThan(measured, bare, "\(name) drew no label at all")
            XCTAssertLessThan(measured, craftable, "\(name) is drawing a component pair it does not have")

            let chip = artifact.recipeRow
            let size = try ViewSnapshot.measuredSize(of: chip, proposedWidth: 200)
            let raster = try ViewSnapshot.render(chip, size: size)
            XCTAssertTrue(hasInk(raster, x: 0 ..< raster.width), "\(name)'s label rendered blank")
        }
    }

    func testTheArtifactLabelSaysSoInTheAccessibilityLabelToo() {
        XCTAssertEqual(
            column("Statikk Shiv").accessibilityLabel,
            "Statikk Shiv, an artifact — not craftable from components"
        )
        XCTAssertEqual(
            column("Infinity Edge").accessibilityLabel,
            "Infinity Edge, built from B.F. Sword and Sparring Gloves"
        )
    }

    // MARK: - An item the index has never heard of

    /// Not `notCraftable`: the index not knowing an item is not evidence the
    /// item cannot be built, so the column collapses back to the plain icon.
    func testAnUnknownItemDrawsNothingExtra() throws {
        let unknown = ItemWithRecipe(name: "Sword of a Thousand Truths", size: itemSize, componentSize: componentSize)
        XCTAssertEqual(unknown.recipe, .unknown)
        XCTAssertEqual(
            try height(unknown),
            try height(ItemIconPlaceholder(name: "Sword of a Thousand Truths", size: itemSize)),
            accuracy: 1
        )
    }

    // MARK: - Helpers

    private func hasInk(_ raster: Raster, x columns: Range<Int>) -> Bool {
        for x in columns {
            for y in 0 ..< raster.height where raster.luminance(x: x, y: y) > Raster.inkThreshold {
                return true
            }
        }
        return false
    }
}
