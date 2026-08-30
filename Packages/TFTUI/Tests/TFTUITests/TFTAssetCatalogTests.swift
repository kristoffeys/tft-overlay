@testable import TFTData
@testable import TFTUI
import XCTest

final class TFTAssetCatalogTests: XCTestCase {
    private let ahriURL = URL(string: "https://example.test/ahri_square.png")!
    private let bladeURL = URL(string: "https://example.test/bfsword.png")!
    private let elderwoodURL = URL(string: "https://example.test/elderwood.png")!

    private func makeStore() -> TFTDataStore {
        TFTDataStore(
            champions: [
                Champion(id: "DA_18_Ahri", name: "Ahri", cost: 4, traitIDs: [], imageURL: ahriURL),
                Champion(id: "DA_18_NoArt", name: "No Art", cost: 1, traitIDs: [], imageURL: nil),
            ],
            traits: [Trait(id: "DA_18_Elderwood", name: "Elderwood", breakpoints: [3], imageURL: elderwoodURL)],
            items: [Item(id: "DA_Component_BFSword", name: "B.F. Sword", imageURL: bladeURL)]
        )
    }

    func testResolvesArtByDisplayName() {
        let catalog = TFTAssetCatalog(store: makeStore())
        XCTAssertEqual(catalog.championImageURL(named: "Ahri"), ahriURL)
        XCTAssertEqual(catalog.itemImageURL(named: "B.F. Sword"), bladeURL)
        XCTAssertEqual(catalog.traitImageURL(named: "Elderwood"), elderwoodURL)
    }

    /// Community Dragon drops apostrophes the conventional English names
    /// keep ("Warmogs Armor" vs "Warmog's Armor"). Matching on casing alone
    /// meant one apostrophe cost an item its art and left a "WA" text tile
    /// in the middle of the cheat sheet.
    func testLookupIgnoresPunctuationBecauseCDragonSpellsNamesItsOwnWay() throws {
        let warmogs = try XCTUnwrap(URL(string: "https://example.test/warmogs.png"))
        let store = TFTDataStore(
            champions: [],
            traits: [],
            // As Community Dragon actually spells it: no apostrophe.
            items: [Item(id: "DA_WarmogsArmor", name: "Warmogs Armor", imageURL: warmogs)]
        )
        let catalog = TFTAssetCatalog(store: store)
        // As `StandardItems` and hand-authored comps spell it.
        XCTAssertEqual(catalog.itemImageURL(named: "Warmog's Armor"), warmogs)
        XCTAssertEqual(catalog.itemImageURL(named: "warmogs armor"), warmogs)
    }

    /// The guard that matters: every name the running app looks art up by
    /// has to resolve through the *real* catalog against the *real* bundled
    /// data. Re-implementing the normalisation in a test is how the
    /// apostrophe bug slipped through — the test was more forgiving than the
    /// lookup it was standing in for, so it passed while the UI showed a
    /// text tile.
    func testEveryNameTheAppRendersResolvesThroughTheRealCatalog() throws {
        guard let envelope = BundledFallbackData().load() else {
            return XCTFail("bundled set data failed to load; this check would be vacuous")
        }
        let catalog = TFTAssetCatalog(store: TFTDataStore(
            champions: envelope.champions,
            traits: envelope.traits,
            items: envelope.items
        ))
        let comps = try CompLoader.bundledFixtures()
        XCTAssertFalse(comps.isEmpty)

        for comp in comps {
            for unit in comp.units {
                XCTAssertNotNil(
                    catalog.championImageURL(named: unit.name),
                    "\(comp.id): champion \"\(unit.name)\" renders without art"
                )
            }
            for carry in comp.carries {
                for item in carry.itemPriority {
                    XCTAssertNotNil(
                        catalog.itemImageURL(named: item),
                        "\(comp.id): item \"\(item)\" renders without art"
                    )
                }
            }
        }

        // The cheat sheet renders StandardItems' names, not comp names, so
        // they need the same guarantee — this is where "WA" showed up.
        for item in RecipeMatrix().components + RecipeMatrix().completedItems {
            XCTAssertNotNil(
                catalog.itemImageURL(named: item.name),
                "cheat sheet item \"\(item.name)\" renders without art"
            )
        }
    }

    func testLookupIsCaseInsensitiveBecauseCompsAreHandAuthored() {
        let catalog = TFTAssetCatalog(store: makeStore())
        XCTAssertEqual(catalog.championImageURL(named: "ahri"), ahriURL)
        XCTAssertEqual(catalog.itemImageURL(named: "b.f. SWORD"), bladeURL)
    }

    func testEntriesWithoutArtAndUnknownNamesResolveToNil() {
        let catalog = TFTAssetCatalog(store: makeStore())
        // Both must be nil, and for the same reason as far as the view is
        // concerned: nil is "draw the text placeholder", never an error.
        XCTAssertNil(catalog.championImageURL(named: "No Art"))
        XCTAssertNil(catalog.championImageURL(named: "Someone From Set 19"))
        XCTAssertNil(catalog.itemImageURL(named: "Nonexistent Item"))
    }

    func testEmptyCatalogAnswersNilToEverything() {
        // This is the environment default, and it is what keeps every
        // existing panel rendering exactly as it did before art existed.
        XCTAssertNil(TFTAssetCatalog.empty.championImageURL(named: "Ahri"))
        XCTAssertNil(TFTAssetCatalog.empty.itemImageURL(named: "B.F. Sword"))
        XCTAssertNil(TFTAssetCatalog.empty.traitImageURL(named: "Elderwood"))
    }

    func testDuplicateNamesResolveDeterministicallyRatherThanAtRandom() {
        // Set 18 ships several same-named champion variants (Lux's nine
        // trait forms). Dictionary iteration order is not stable across
        // launches, so without an explicit tie-break the same comp could
        // show a different portrait each run.
        let store = TFTDataStore(champions: [
            Champion(id: "DA_Lux18_Fae", name: "Lux", cost: 5, traitIDs: [], imageURL: ahriURL),
            Champion(id: "DA_Lux18_Base", name: "lux", cost: 5, traitIDs: [], imageURL: bladeURL),
        ])
        let resolved = (0 ..< 20).map { _ in TFTAssetCatalog(store: store).championImageURL(named: "Lux") }
        XCTAssertEqual(Set(resolved).count, 1)
        XCTAssertNotNil(resolved.first ?? nil)
    }

    func testBundledFallbackPackPopulatesTheCatalogForRealSetData() throws {
        // The end-to-end shape of the feature offline: the pack that ships
        // in the app resolves art for real Set 18 names with no network.
        let envelope = try XCTUnwrap(BundledFallbackData().load())
        let catalog = TFTAssetCatalog(store: TFTDataStore(
            champions: envelope.champions,
            traits: envelope.traits,
            items: envelope.items,
            augments: envelope.augments
        ))
        let ahri = try XCTUnwrap(catalog.championImageURL(named: "Ahri"))
        XCTAssertTrue(ahri.absoluteString.hasPrefix("https://raw.communitydragon.org/latest/game/"))
        XCTAssertNotNil(catalog.itemImageURL(named: "Spear of Shojin"))
        XCTAssertNotNil(catalog.traitImageURL(named: "Elderwood"))
    }
}
