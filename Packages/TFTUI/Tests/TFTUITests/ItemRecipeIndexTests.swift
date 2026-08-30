import TFTData
@testable import TFTUI
import XCTest

/// #111: the name -> recipe bridge the build surfaces read.
final class ItemRecipeIndexTests: XCTestCase {
    private let index = ItemRecipeIndex.bundled

    private func components(_ name: String) -> (Item, Item)? {
        guard case let .components(first, second) = index.recipe(forItemNamed: name) else { return nil }
        return (first, second)
    }

    func testTheBundledIndexIsActuallyPopulated() {
        // The premise for everything below: `.bundled` silently degrades to
        // `.standard` if the resource cannot be read, and `.standard` has
        // never heard of an artifact or an emblem.
        XCTAssertEqual(index.recipe(forItemNamed: "Rapid Firecannon"), .notCraftable)
        XCTAssertNotEqual(
            ItemRecipeIndex.standard.recipe(forItemNamed: "Rapid Firecannon"),
            .notCraftable,
            "if the standard pool knows this item, this test no longer proves the bundled pack was read"
        )
    }

    func testACompletedItemResolvesToItsTwoComponents() throws {
        let recipe = try XCTUnwrap(components("Infinity Edge"))
        XCTAssertEqual([recipe.0.name, recipe.1.name], ["B.F. Sword", "Sparring Gloves"])
    }

    func testADoubledComponentRecipeNamesTheComponentTwice() throws {
        let recipe = try XCTUnwrap(components("Deathblade"))
        XCTAssertEqual([recipe.0.name, recipe.1.name], ["B.F. Sword", "B.F. Sword"])
    }

    // MARK: - The two artifacts

    /// `Rapid Firecannon` and `Statikk Shiv` survived the Set 18 rotation as
    /// artifacts with empty `componentIDs`. They are the only items any carry
    /// in the corpus names that cannot be built, and rendering two blank
    /// slots for them sends the player after components that do not exist.
    func testTheSetsArtifactsReportNotCraftableRatherThanUnknown() {
        for name in ["Rapid Firecannon", "Statikk Shiv"] {
            XCTAssertEqual(index.recipe(forItemNamed: name), .notCraftable, name)
        }
    }

    func testAnItemTheIndexHasNeverHeardOfIsUnknownRatherThanNotCraftable() {
        XCTAssertEqual(index.recipe(forItemNamed: "Sword of a Thousand Truths"), .unknown)
    }

    // MARK: - Non-standard components

    /// A recipe can name a component outside the standard eight. Resolving
    /// component ids against `StandardItems.components` — which is what
    /// `RecipeMatrix`'s default init does — loses this one entirely.
    func testARecipeNamingANonStandardComponentStillResolves() throws {
        let recipe = try XCTUnwrap(components("Executioner Emblem"))
        XCTAssertEqual([recipe.0.name, recipe.1.name], ["Frying Pan", "Sparring Gloves"])
        XCTAssertFalse(
            StandardItems.components.contains(where: { $0.name == "Frying Pan" }),
            "the premise: Frying Pan is not one of the eight standard components"
        )
        XCTAssertNil(
            RecipeMatrix().recipe(for: Item(
                id: "DA_18_EmblemExecutioner",
                name: "Executioner Emblem",
                componentIDs: ["DA_Component_FryingPan", "DA_Component_SparringGloves"]
            )),
            "and the premise for the wider component list: the standard matrix cannot resolve it"
        )
    }

    // MARK: - Name matching

    /// Comps are authored with conventional English punctuation and
    /// Community Dragon is not, which is why this keys on `TFTNameKey`.
    func testNamesMatchAcrossPunctuationAndCasing() throws {
        let canonical = try XCTUnwrap(components("Guinsoo's Rageblade"))
        for variant in ["guinsoos rageblade", "GUINSOO'S RAGEBLADE", "Guinsoos  Rageblade"] {
            let recipe = try XCTUnwrap(components(variant), variant)
            XCTAssertEqual(recipe.0.id, canonical.0.id, variant)
        }
    }

    // MARK: - Every item the corpus asks about

    /// The corpus-wide claim the ticket rests on: 29 of the 31 items named by
    /// any carry are craftable, and the two that are not are the artifacts.
    func testEveryCarryItemInTheCorpusIsCraftableOrAKnownArtifact() throws {
        var craftable: Set<String> = []
        var notCraftable: Set<String> = []
        for comp in try CompLoader.bundledFixtures() {
            for carry in comp.carries {
                for name in carry.itemPriority {
                    switch index.recipe(forItemNamed: name) {
                    case .components: craftable.insert(name)
                    case .notCraftable: notCraftable.insert(name)
                    case .unknown: XCTFail("\(name) (\(comp.id)) is not in the bundled item pack at all")
                    }
                }
            }
        }
        XCTAssertEqual(notCraftable, ["Rapid Firecannon", "Statikk Shiv"])
        XCTAssertEqual(craftable.count + notCraftable.count, 31)
    }

    // MARK: - Opting out

    func testTheEmptyIndexAnswersNothing() {
        XCTAssertEqual(ItemRecipeIndex.empty.recipe(forItemNamed: "Infinity Edge"), .unknown)
    }

    func testAnIndexBuiltFromAStoreUsesTheStoresItems() {
        let store = TFTDataStore(items: [
            Item(id: "c1", name: "Left Thing"),
            Item(id: "c2", name: "Right Thing"),
            Item(id: "x", name: "Made Up Item", componentIDs: ["c1", "c2"]),
        ])
        guard case let .components(first, second) = ItemRecipeIndex(store: store)
            .recipe(forItemNamed: "made up item")
        else { return XCTFail("a store-built index has to answer for its own items") }
        XCTAssertEqual([first.name, second.name], ["Left Thing", "Right Thing"])
    }
}
