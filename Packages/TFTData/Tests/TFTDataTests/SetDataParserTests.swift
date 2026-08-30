@testable import TFTData
import XCTest

/// Parses against fixtures pinned to a real, known snapshot — never the
/// network. `Fixtures/set18-snippet.json` is a hand-trimmed excerpt of
/// Community Dragon's `cdragon/tft/en_us.json`, fetched live on 2026-08-29
/// (content version `16.17.8104348+branch.releases-16-17.content.release`,
/// Set 18 "Enchanted Wilds" / patch 18.1), trimmed to the fields
/// `SetDataParser` reads — not synthetic data, a real subset.
final class SetDataParserTests: XCTestCase {
    private func loadFixture(_ name: String) -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") else {
            XCTFail("missing fixture \(name).json")
            return Data()
        }
        return (try? Data(contentsOf: url)) ?? Data()
    }

    func testParsesCurrentSetNumberFromHighestKey() throws {
        let parsed = try SetDataParser.parse(loadFixture("set18-snippet"))
        XCTAssertEqual(parsed.setNumber, 18)
    }

    func testFiltersOutPvEOnlyChampionsWithNoTraits() throws {
        let parsed = try SetDataParser.parse(loadFixture("set18-snippet"))
        // The fixture includes "Golem" (TFT_BlueGolem, traits: []) alongside
        // 5 real champions. Only the real ones should survive.
        XCTAssertFalse(parsed.champions.contains { $0.name == "Golem" })
        XCTAssertEqual(parsed.champions.count, 5)
    }

    func testResolvesChampionTraitNamesToTraitIDs() throws {
        let parsed = try SetDataParser.parse(loadFixture("set18-snippet"))
        let xayah = try XCTUnwrap(parsed.champions.first { $0.name == "Xayah" })
        // Xayah's raw trait names are ["Elderwood", "Fae", "Rapidfire"], but
        // the fixture's trait list only defines Elderwood — Fae/Rapidfire
        // have no matching trait to resolve against and are dropped rather
        // than crashing or producing a dangling ID.
        XCTAssertEqual(xayah.traitIDs, ["DA_18_Elderwood"])
        XCTAssertEqual(xayah.cost, 1)
    }

    func testKeepsRiftbeastSummonsAsRealChampions() throws {
        let parsed = try SetDataParser.parse(loadFixture("set18-snippet"))
        // Gromp has real traits (Riftbeast, Adaptor is not in the fixture's
        // trait list so only Riftbeast resolves) and counts as a champion,
        // unlike the traitless PvE Golem.
        let gromp = try XCTUnwrap(parsed.champions.first { $0.name == "Gromp" })
        XCTAssertEqual(gromp.traitIDs, ["DA_Riftbeast18"])
    }

    func testParsesTraitLevelsWithStyleTiers() throws {
        let parsed = try SetDataParser.parse(loadFixture("set18-snippet"))
        let elderwood = try XCTUnwrap(parsed.traits.first { $0.id == "DA_18_Elderwood" })
        XCTAssertEqual(elderwood.levels.count, 5)
        XCTAssertEqual(elderwood.levels[0], Trait.Level(minUnits: 3, maxUnits: 4, style: 1))
        XCTAssertEqual(elderwood.breakpoints, [3, 5, 7, 9, 11])
    }

    func testFiltersItemsToRealEquipmentByIconPath() throws {
        let parsed = try SetDataParser.parse(loadFixture("set18-snippet"))
        // The fixture includes a "mechanic" entry (Moonlight Ritual,
        // isAugment: false, icon under .../wands/..., not .../items/...)
        // that must not show up as an equippable item.
        XCTAssertFalse(parsed.items.contains { $0.name == "Moonlight Ritual" })
        let ids = Set(parsed.items.map(\.id))
        XCTAssertEqual(ids, [
            "DA_Component_BFSword",
            "DA_Component_RecurveBow",
            "DA_RedBuff",
            "DA_SpearOfShojin",
            "DA_18_EmblemExecutioner",
        ])
    }

    func testKeepsTraitEmblemsWhoseIconsLiveOutsideTheItemsFolder() throws {
        let parsed = try SetDataParser.parse(loadFixture("set18-snippet"))
        // Trait emblems are equippable items a comp can legitimately ask
        // for, but their icons sit under `.../item_icons/traits/spatula/...`
        // rather than `.../icons/items/...`, so a filter keyed only on the
        // latter silently dropped all 21 of Set 18's emblems.
        let emblem = try XCTUnwrap(parsed.items.first { $0.id == "DA_18_EmblemExecutioner" })
        XCTAssertEqual(emblem.name, "Executioner Emblem")
        XCTAssertEqual(emblem.componentIDs, ["DA_Component_FryingPan", "DA_Component_SparringGloves"])
    }

    func testParsesItemRecipeFromComposition() throws {
        let parsed = try SetDataParser.parse(loadFixture("set18-snippet"))
        let redBuff = try XCTUnwrap(parsed.items.first { $0.id == "DA_RedBuff" })
        XCTAssertEqual(redBuff.componentIDs, ["DA_Component_RecurveBow", "DA_Component_RecurveBow"])
    }

    func testParsesAugmentsWithTierFromNameSuffix() throws {
        let parsed = try SetDataParser.parse(loadFixture("set18-snippet"))
        let noSuffix = try XCTUnwrap(parsed.augments.first { $0.id == "DA_FocusedFire" })
        let goldSuffix = try XCTUnwrap(parsed.augments.first { $0.id == "DA_AdvancedLoan" })
        XCTAssertEqual(noSuffix.tier, 1)
        XCTAssertEqual(goldSuffix.tier, 1) // "Advanced Loan" itself has no "+" in this fixture
        let prismatic = try XCTUnwrap(parsed.augments.first { $0.id == "DA_ChampDeliveryPlusPlus" })
        XCTAssertEqual(prismatic.name, "Champ Delivery++")
        XCTAssertEqual(prismatic.tier, 3)
    }

    func testSanitizesAugmentTextOfTemplateMarkupTags() throws {
        let parsed = try SetDataParser.parse(loadFixture("set18-snippet"))
        let augment = try XCTUnwrap(parsed.augments.first { $0.id == "DA_FocusedFire" })
        XCTAssertFalse(augment.text.contains("<"))
        XCTAssertTrue(augment.text.contains("Attack Damage"))
    }

    // MARK: - Image URLs

    func testAttachesChampionPortraitURLFromTileIcon() throws {
        let parsed = try SetDataParser.parse(loadFixture("set18-snippet"))
        let ahri = try XCTUnwrap(parsed.champions.first { $0.name == "Ahri" })
        // `tileIcon` — not `icon` (a full splash) and not `squareIcon` (a
        // wide splash tile), both of which the same entry also carries.
        // See `RawChampion.tileIcon` for how that was established.
        XCTAssertEqual(
            ahri.imageURL?.absoluteString,
            "https://raw.communitydragon.org/latest/game/assets/characters/tft18_ahri/tft18_ahri_square.png"
        )
    }

    func testAttachesItemIconURL() throws {
        let parsed = try SetDataParser.parse(loadFixture("set18-snippet"))
        let redBuff = try XCTUnwrap(parsed.items.first { $0.id == "DA_RedBuff" })
        // Riot's internal filename lags the renamed item ("rapidfirecannon"
        // for what the game now calls Red Buff). The feed's path is used
        // verbatim — guessing a "corrected" filename would 404.
        XCTAssertEqual(
            redBuff.imageURL?.absoluteString,
            "https://raw.communitydragon.org/latest/game/assets/maps/tft/icons/items/hexcore/tft_item_rapidfirecannon.png"
        )
    }

    func testAttachesTraitIconURL() throws {
        let parsed = try SetDataParser.parse(loadFixture("set18-snippet"))
        let elderwood = try XCTUnwrap(parsed.traits.first { $0.id == "DA_18_Elderwood" })
        XCTAssertEqual(
            elderwood.imageURL?.absoluteString,
            "https://raw.communitydragon.org/latest/game/assets/ux/traiticons/trait_icon_18_elderwood.png"
        )
    }

    func testAttachesAugmentIconURL() throws {
        let parsed = try SetDataParser.parse(loadFixture("set18-snippet"))
        let augment = try XCTUnwrap(parsed.augments.first { $0.id == "DA_FocusedFire" })
        XCTAssertEqual(
            augment.imageURL?.absoluteString,
            "https://raw.communitydragon.org/latest/game/assets/maps/tft/icons/augments/hexcore/marksman_i.png"
        )
    }

    func testMissingIconLeavesImageURLNilWithoutDroppingTheEntry() throws {
        // Art is a progressive enhancement: an entry with no usable icon
        // must still parse, just without a URL, so the UI keeps its text
        // placeholder rather than the champion vanishing.
        let partial = Data(#"""
        {
            "items": [],
            "sets": {
                "18": {
                    "name": "Set10",
                    "champions": [
                        {"apiName": "DA_18_NoArt", "name": "No Art", "cost": 3, "traits": ["Elderwood"]},
                        {"apiName": "DA_18_BadArt", "name": "Bad Art", "cost": 3, "traits": ["Elderwood"], "tileIcon": 42}
                    ],
                    "traits": [
                        {"apiName": "DA_18_Elderwood", "name": "Elderwood", "effects": []}
                    ]
                }
            }
        }
        """#.utf8)
        let parsed = try SetDataParser.parse(partial)
        XCTAssertEqual(Set(parsed.champions.map(\.id)), ["DA_18_NoArt", "DA_18_BadArt"])
        XCTAssertTrue(parsed.champions.allSatisfy { $0.imageURL == nil })
        XCTAssertNil(parsed.traits.first?.imageURL)
    }

    // MARK: - Malformed / partial responses

    func testThrowsOnCompletelyUnusableDocument() {
        let garbage = Data("not json at all".utf8)
        XCTAssertThrowsError(try SetDataParser.parse(garbage)) { error in
            XCTAssertEqual(error as? SetDataParsingError, .noUsableData)
        }
    }

    func testThrowsWhenNoSetsPresent() {
        let empty = Data(#"{"items": [], "sets": {}}"#.utf8)
        XCTAssertThrowsError(try SetDataParser.parse(empty)) { error in
            XCTAssertEqual(error as? SetDataParsingError, .noUsableData)
        }
    }

    func testSkipsUnidentifiableChampionEntriesInsteadOfFailing() throws {
        // "BadCost" has a wrong-typed (not missing) field — that's still
        // gracefully defaulted (cost -> 0), same as a genuinely missing
        // field, since RawChampion only requires apiName/name to identify
        // an entry at all. Only entries that can't even be identified
        // (no apiName, or not an object) get dropped.
        let partial = Data(#"""
        {
            "items": [],
            "sets": {
                "18": {
                    "name": "Set10",
                    "champions": [
                        {"apiName": "DA_18_Good", "name": "Good", "cost": 1, "traits": ["Elderwood"]},
                        {"apiName": "DA_18_BadCost", "name": "BadCost", "cost": "not a number", "traits": ["Elderwood"]},
                        {"name": "MissingApiName", "cost": 2, "traits": ["Elderwood"]},
                        "not even an object"
                    ],
                    "traits": [
                        {"apiName": "DA_18_Elderwood", "name": "Elderwood", "effects": []}
                    ]
                }
            }
        }
        """#.utf8)
        let parsed = try SetDataParser.parse(partial)
        XCTAssertEqual(Set(parsed.champions.map(\.id)), ["DA_18_Good", "DA_18_BadCost"])
        XCTAssertEqual(parsed.champions.first { $0.id == "DA_18_BadCost" }?.cost, 0)
    }

    func testDefaultsMissingOptionalChampionFieldsInsteadOfFailing() throws {
        // A champion missing "cost" entirely (a genuinely partial API
        // response, not just a wrong type) should still decode — with cost
        // defaulted to 0 — rather than dropping the whole set.
        let partial = Data(#"""
        {
            "items": [],
            "sets": {
                "18": {
                    "name": "Set10",
                    "champions": [
                        {"apiName": "DA_18_Bare", "name": "Bare", "traits": ["Elderwood"]}
                    ],
                    "traits": [
                        {"apiName": "DA_18_Elderwood", "name": "Elderwood", "effects": []}
                    ]
                }
            }
        }
        """#.utf8)
        let parsed = try SetDataParser.parse(partial)
        let bare = try XCTUnwrap(parsed.champions.first)
        XCTAssertEqual(bare.cost, 0)
        XCTAssertEqual(bare.traitIDs, ["DA_18_Elderwood"])
    }

    func testSkipsMalformedItemEntriesInsteadOfFailing() throws {
        let partial = Data(#"""
        {
            "items": [
                {
                    "apiName": "DA_Good",
                    "name": "Good Item",
                    "composition": [],
                    "isAugment": false,
                    "icon": "assets/maps/tft/icons/items/hexcore/good.tex"
                },
                {"apiName": "DA_MissingName"},
                123,
                null
            ],
            "sets": {
                "18": {
                    "name": "Set10",
                    "champions": [
                        {"apiName": "DA_18_Anchor", "name": "Anchor", "cost": 1, "traits": ["Elderwood"]}
                    ],
                    "traits": [
                        {"apiName": "DA_18_Elderwood", "name": "Elderwood", "effects": []}
                    ]
                }
            }
        }
        """#.utf8)
        let parsed = try SetDataParser.parse(partial)
        XCTAssertEqual(parsed.items.map(\.id), ["DA_Good"])
    }
}
