@testable import TFTOverlay
import TFTUI
import XCTest

/// #111: the app hands the panels an item recipe index, and it is useful
/// before anything finishes loading.
///
/// `TFTUI`'s environment default would make recipes appear even with the app
/// wiring missing entirely, which is exactly why this asserts on
/// `OverlayAppState.itemRecipes` — the value the app actually publishes —
/// rather than on a rendered view.
@MainActor
final class OverlayItemRecipeWiringTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        suiteName = "OverlayItemRecipeWiringTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func state() -> OverlayAppState {
        OverlayAppState(
            pinnedComps: PinnedCompsStore(defaults: defaults),
            ownedChampions: OwnedChampionsStore(defaults: defaults)
        )
    }

    /// Unlike the asset catalog, which starts `.empty` and waits for a load,
    /// recipes are static set data the package already ships — so a build
    /// shows what to make from the first frame.
    func testRecipesAreAnsweredBeforeAnyStoreLoads() {
        let recipes = state().itemRecipes
        guard case let .components(first, second) = recipes.recipe(forItemNamed: "Infinity Edge") else {
            return XCTFail("a freshly constructed app state has no recipe for Infinity Edge")
        }
        XCTAssertEqual([first.name, second.name], ["B.F. Sword", "Sparring Gloves"])
        XCTAssertEqual(
            recipes.recipe(forItemNamed: "Rapid Firecannon"),
            .notCraftable,
            "the artifacts have to be labelled from the first frame too"
        )
    }
}
