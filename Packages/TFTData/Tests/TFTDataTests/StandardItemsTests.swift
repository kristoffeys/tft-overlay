@testable import TFTData
import XCTest

/// `StandardItems` is a hand-transcribed copy of set data that exists only
/// because the cheat-sheet grid needs it synchronously and in a fixed order.
/// These tests are what keep that copy honest: they diff it against the
/// bundled Community Dragon snapshot, so a set rotation (or a typo) fails the
/// build naming the exact items that moved.
final class StandardItemsTests: XCTestCase {
    private func bundledItems() throws -> [String: Item] {
        let envelope = try XCTUnwrap(BundledFallbackData().load(), "bundled fallback pack failed to load")
        return Dictionary(envelope.items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Community Dragon's display names are inconsistently punctuated
    /// ("Warmogs Armor", "Hand Of Justice", "Tear Of The Goddess") where the
    /// UI wants conventional English. Compare on letters only so the copy is
    /// verified to be the same *item* without pinning Riot's typography.
    private func normalized(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    func testEveryComponentMatchesTheBundledCatalog() throws {
        let catalog = try bundledItems()
        for component in StandardItems.components {
            let live = try XCTUnwrap(catalog[component.id], "\(component.name) (\(component.id)) is not in this set")
            XCTAssertEqual(normalized(live.name), normalized(component.name))
            XCTAssertTrue(live.componentIDs.isEmpty, "\(component.name) is not a base component in this set")
        }
    }

    func testEveryCompletedItemMatchesTheBundledCatalogRecipe() throws {
        let catalog = try bundledItems()
        for item in StandardItems.completedItems {
            let live = try XCTUnwrap(catalog[item.id], "\(item.name) (\(item.id)) is not in this set")
            XCTAssertEqual(normalized(live.name), normalized(item.name))
            XCTAssertEqual(
                live.componentIDs.sorted(),
                item.componentIDs.sorted(),
                "\(item.name) is built from different components in this set"
            )
        }
    }

    /// The other direction: nothing the live set builds out of two standard
    /// components may be missing here, or the cheat sheet would show a hole
    /// where a real item exists.
    func testCatalogHasNoStandardCombineMissingFromStandardItems() throws {
        let catalog = try bundledItems()
        let componentIDs = Set(StandardItems.components.map(\.id))
        let liveCombines = catalog.values.filter { item in
            item.componentIDs.count == 2 && item.componentIDs.allSatisfy { componentIDs.contains($0) }
        }
        let known = Set(StandardItems.completedItems.map(\.id))
        let missing = liveCombines.filter { !known.contains($0.id) }.map(\.name).sorted()
        XCTAssertEqual(missing, [], "standard combines present in the set data but missing from StandardItems")
    }

    func testCoversEveryComponentPairExactlyOnce() {
        let count = StandardItems.components.count
        XCTAssertEqual(StandardItems.completedItems.count, count * (count + 1) / 2)
        var pairs = Set<[String]>()
        for item in StandardItems.completedItems {
            XCTAssertTrue(
                pairs.insert(item.componentIDs.sorted()).inserted,
                "\(item.name) duplicates another item's component pair"
            )
        }
    }

    /// Trait emblems and artifacts are equippable items a comp can ask for,
    /// but they rotate every set and are deliberately not transcribed into
    /// `StandardItems` — they must reach the app through the catalog instead.
    func testBundledCatalogCarriesTraitEmblemsAndArtifacts() throws {
        let catalog = try bundledItems()
        XCTAssertNotNil(catalog["DA_18_EmblemExecutioner"], "trait emblems missing from the bundled catalog")
        XCTAssertNotNil(catalog["DA_Artifact_StatikkShiv"], "artifacts missing from the bundled catalog")
    }
}
