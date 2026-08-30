import TFTData
@testable import TFTUI
import XCTest

final class RecipeMatrixTests: XCTestCase {
    func testEveryCompletedItemIsReachableFromExactlyOneComponentPair() {
        let matrix = RecipeMatrix()
        var seenPairs = Set<String>()
        for item in matrix.completedItems {
            guard let recipe = matrix.recipe(for: item) else {
                XCTFail("\(item.name) has no resolvable recipe")
                continue
            }
            XCTAssertEqual(matrix.completedItem(recipe.0, recipe.1)?.id, item.id)
            let key = [recipe.0.id, recipe.1.id].sorted().joined(separator: "|")
            XCTAssertTrue(
                seenPairs.insert(key).inserted,
                "Duplicate component pair produces both \(item.name) and another item"
            )
        }
        // 8 components taken 2 at a time with repetition = 36.
        let count = matrix.components.count
        XCTAssertEqual(matrix.completedItems.count, count * (count + 1) / 2)
    }

    func testGridIsSymmetric() {
        let matrix = RecipeMatrix()
        for first in matrix.components {
            for second in matrix.components {
                XCTAssertEqual(matrix.completedItem(first, second)?.id, matrix.completedItem(second, first)?.id)
            }
        }
    }

    func testUnknownComponentPairIsNil() {
        let matrix = RecipeMatrix()
        let bogus = Item(id: "not-a-real-component", name: "Bogus")
        XCTAssertNil(matrix.completedItem(bogus, StandardItems.bfSword))
    }

    func testReverseLookupFindsUnitsWantingAnItem() throws {
        let comps = try CompLoader.bundledFixtures()
        let index = ItemDemandIndex(comps: comps)
        let entries = index.entries(forItemNamed: "Infinity Edge")
        XCTAssertFalse(
            entries.isEmpty,
            "Infinity Edge is referenced by fixture comps and should be reachable in reverse lookup"
        )
        XCTAssertTrue(entries.contains { $0.unit == "Ashe" })
    }

    func testReverseLookupIsEmptyForUnwantedItem() throws {
        let comps = try CompLoader.bundledFixtures()
        let index = ItemDemandIndex(comps: comps)
        // A real Set 18 item that no bundled comp asks for by name — the
        // fixtures used to be small enough for Warmog's Armor to serve here,
        // but the scraped set (ADR 0004) wants it in a third of the comps.
        XCTAssertTrue(index.entries(forItemNamed: "Thief's Gloves").isEmpty)
    }
}
