import TFTData
@testable import TFTUI
import XCTest

final class CompLoaderTests: XCTestCase {
    func testBundledFixturesDecodeSuccessfully() throws {
        let comps = try CompLoader.bundledFixtures()
        // Not an exact count: most of data/comps/ is now scraper-produced
        // (ADR 0004) and its size changes as the maintainer re-runs it.
        // What must hold is that decoding didn't silently drop anything and
        // the two original hand-authored comps are still present.
        let bundledFiles = Bundle.module.urls(forResourcesWithExtension: "json", subdirectory: "Comps") ?? []
        XCTAssertGreaterThanOrEqual(bundledFiles.count, 2)
        XCTAssertEqual(comps.count, bundledFiles.count, "a bundled comp file failed to become a Comp")
        XCTAssertTrue(comps.contains { $0.id == "hunters-ashe" })
        XCTAssertTrue(comps.contains { $0.id == "elderwood-bloom" })
    }

    func testCompDecodesAllSchemaFields() throws {
        let comps = try CompLoader.bundledFixtures()
        guard let ashe = comps.first(where: { $0.id == "hunters-ashe" }) else {
            XCTFail("hunters-ashe fixture missing")
            return
        }
        XCTAssertEqual(ashe.tier, .s)
        XCTAssertEqual(ashe.playstyle, .fastEight)
        XCTAssertEqual(ashe.difficulty, .hard)
        XCTAssertEqual(ashe.source, .handAuthored)
        XCTAssertEqual(ashe.boardPositioning.grid.count, 4)
        XCTAssertTrue(ashe.boardPositioning.grid.allSatisfy { $0.count == 7 })
        XCTAssertFalse(ashe.carries.isEmpty)
        XCTAssertFalse(ashe.levelPlan.isEmpty)
        XCTAssertFalse(ashe.earlyOpener.isEmpty)
        XCTAssertFalse(ashe.pivotNotes.isEmpty)
    }

    func testFlexDefaultsToFalseWhenAbsent() throws {
        let comps = try CompLoader.bundledFixtures()
        guard let ashe = comps.first(where: { $0.id == "hunters-ashe" }),
              let asheUnit = ashe.units.first(where: { $0.name == "Ashe" })
        else {
            XCTFail("Ashe unit missing from fixture")
            return
        }
        XCTAssertFalse(asheUnit.flex)
        // "Elder Dragon", not "The Elder Dragon": unit names must match the
        // champion name Riot ships, because that is the key art is resolved
        // by. The fixture used to carry the article and silently lost its
        // portrait on the board.
        guard let elderDragon = ashe.units.first(where: { $0.name == "Elder Dragon" }) else {
            XCTFail("Elder Dragon unit missing from fixture")
            return
        }
        XCTAssertTrue(elderDragon.flex)
    }

    func testSearchableTextMatchesUnitAndTraitNames() throws {
        let comps = try CompLoader.bundledFixtures()
        guard let ashe = comps.first(where: { $0.id == "hunters-ashe" }) else {
            XCTFail("hunters-ashe fixture missing")
            return
        }
        XCTAssertTrue(ashe.searchableText.contains("sivir"))
        XCTAssertTrue(ashe.searchableText.contains("hunter"))
    }

    /// A carry's item priority may legitimately name something outside the
    /// 2-component standard pool — a trait emblem ("Executioner Emblem") or
    /// an artifact ("Statikk Shiv", which is a component combine in some sets
    /// and an artifact in Set 18). Validating against `RecipeMatrix` alone
    /// rejected those, so this checks the full item catalog for the set: the
    /// ordered standard pool the cheat sheet renders, plus everything else
    /// Community Dragon lists as equippable. What it still catches is the
    /// case that matters — an item name that exists in no form this set,
    /// because the comp was written against an older item pool.
    func testEveryCarryItemPriorityResolvesInTheSetItemCatalog() throws {
        let comps = try CompLoader.bundledFixtures()
        let bundledItems = BundledFallbackData().load()?.items ?? []
        XCTAssertFalse(bundledItems.isEmpty, "bundled set catalog failed to load; the check below would be vacuous")
        // Community Dragon punctuates inconsistently ("Warmogs Armor",
        // "Hand Of Justice") — compare on letters only.
        let normalize = { (name: String) in name.lowercased().filter { $0.isLetter || $0.isNumber } }
        let catalogNames = Set((RecipeMatrix().completedItems + bundledItems).map { normalize($0.name) })
        for comp in comps {
            for carry in comp.carries {
                for itemName in carry.itemPriority {
                    XCTAssertTrue(
                        catalogNames.contains(normalize(itemName)),
                        "\(comp.id): \(carry.unit) wants \"\(itemName)\", which is not an item in this set"
                    )
                }
            }
        }
    }

    /// A unit's name is not just a label — it is the key champion art is
    /// resolved by, so a comp naming a champion the set does not have loses
    /// its portrait silently and falls back to initials. `hunters-ashe`
    /// shipped "The Elder Dragon" against a champion Riot calls "Elder
    /// Dragon", and the board showed "TE" in a hex for exactly that reason.
    ///
    /// Compared on letters only, matching the item check above: what this is
    /// for is a name that resolves to no champion at all, not a punctuation
    /// difference the asset lookup already tolerates.
    func testEveryUnitNameResolvesInTheSetChampionCatalog() throws {
        let comps = try CompLoader.bundledFixtures()
        let champions = BundledFallbackData().load()?.champions ?? []
        XCTAssertFalse(champions.isEmpty, "bundled champion catalog failed to load; the check below would be vacuous")
        let normalize = { (name: String) in name.lowercased().filter { $0.isLetter || $0.isNumber } }
        let catalogNames = Set(champions.map { normalize($0.name) })
        for comp in comps {
            for unit in comp.units {
                XCTAssertTrue(
                    catalogNames.contains(normalize(unit.name)),
                    "\(comp.id): unit \"\(unit.name)\" is not a champion in this set, so its art cannot resolve"
                )
            }
        }
    }

    /// Display text has to spell a champion the way the set spells it.
    ///
    /// The two checks above compare on letters only, deliberately: they guard
    /// art resolution, which tolerates Community Dragon's punctuation drift.
    /// That leniency is exactly why `rivals-khazix` could ship a title reading
    /// "Rivals Khazix" one line above its own unit list reading "Kha'Zix" (#98)
    /// — same champion, two spellings, and nothing failing. This is the
    /// display-side counterpart: an exact-string comparison over the text the
    /// user reads, so a title or a prose note cannot disagree with the roster.
    ///
    /// Scope is one word at a time against single-word champion names. A word
    /// of prose cannot identify a multi-word champion ("Mama Beak") or a
    /// parenthesised variant ("Lux (Inferno)"), so those are left out rather
    /// than guessed at; the punctuation-stripping this catches ("Khazix",
    /// "Kogmaw", "RekSai") only ever hits single-word names anyway.
    func testCompDisplayTextSpellsChampionsTheWayTheSetDoes() throws {
        let comps = try CompLoader.bundledFixtures()
        let champions = BundledFallbackData().load()?.champions ?? []
        XCTAssertFalse(champions.isEmpty, "bundled champion catalog failed to load; the check below would be vacuous")
        let normalize = { (name: String) in name.lowercased().filter { $0.isLetter || $0.isNumber } }
        var spelling: [String: String] = [:]
        for champion in champions where !champion.name.contains(" ") {
            spelling[normalize(champion.name)] = champion.name
        }
        XCTAssertEqual(spelling[normalize("Khazix")], "Kha'Zix", "the spelling table this asserts against is wrong")

        for comp in comps {
            var texts: [(field: String, text: String)] = [
                ("name", comp.name),
                ("earlyOpener", comp.earlyOpener),
                ("pivotNotes", comp.pivotNotes),
            ]
            if let description = comp.compDescription {
                texts.append(("description", description))
            }
            for entry in comp.levelPlan {
                if let notes = entry.notes {
                    texts.append(("levelPlan[\(entry.stage)].notes", notes))
                }
            }
            for (field, text) in texts {
                for word in text.split(separator: " ") {
                    // Prose punctuates around names ("add: Zyra, Alune,
                    // Ivern."); only what is inside the word is compared.
                    let bare = word.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
                    guard let expected = spelling[normalize(bare)] else { continue }
                    XCTAssertEqual(
                        bare,
                        expected,
                        "\(comp.id): \(field) spells the champion \"\(bare)\", the set ships \"\(expected)\""
                    )
                }
            }
        }
    }
}
