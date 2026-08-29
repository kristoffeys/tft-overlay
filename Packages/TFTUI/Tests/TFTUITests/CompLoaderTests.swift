@testable import TFTUI
import XCTest

final class CompLoaderTests: XCTestCase {
    func testBundledFixturesDecodeSuccessfully() throws {
        let comps = try CompLoader.bundledFixtures()
        XCTAssertEqual(comps.count, 2)
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
        guard let elderDragon = ashe.units.first(where: { $0.name == "The Elder Dragon" }) else {
            XCTFail("The Elder Dragon unit missing from fixture")
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

    func testEveryCarryItemPriorityResolvesInStandardItemCatalog() throws {
        let comps = try CompLoader.bundledFixtures()
        let catalogNames = Set(RecipeMatrix().completedItems.map(\.name))
        for comp in comps {
            for carry in comp.carries {
                for itemName in carry.itemPriority {
                    XCTAssertTrue(
                        catalogNames.contains(itemName),
                        "\(comp.id): \(carry.unit) wants \"\(itemName)\", which is not reachable in the standard item catalog"
                    )
                }
            }
        }
    }
}
