@testable import TFTData
import XCTest

/// The transform itself is pure string work; the paths below are real ones
/// lifted from the live `cdragon/tft/en_us.json` on 2026-08-29, and the
/// expected URLs were each fetched by hand and confirmed to return 200 with
/// real art (128x128 for champion/item/augment, 32x32 for trait glyphs).
final class CDragonAssetURLTests: XCTestCase {
    func testBuildsChampionPortraitURLFromTexturePath() {
        XCTAssertEqual(
            CDragonAssetURL.imageURL(forGamePath: "assets/characters/tft18_gromp/tft18_gromp_square.tex"),
            URL(
                string: "https://raw.communitydragon.org/latest/game/assets/characters/tft18_gromp/tft18_gromp_square.png"
            )
        )
    }

    func testLowercasesMixedCasePaths() {
        // The feed is inconsistently cased; the mirror only serves lowercase.
        XCTAssertEqual(
            CDragonAssetURL.imageURL(forGamePath: "ASSETS/Maps/TFT/Icons/Items/Hexcore/TFT_Item_BFSword.tex"),
            URL(
                string: "https://raw.communitydragon.org/latest/game/assets/maps/tft/icons/items/hexcore/tft_item_bfsword.png"
            )
        )
    }

    func testBuildsTraitIconURL() {
        XCTAssertEqual(
            CDragonAssetURL.imageURL(forGamePath: "assets/ux/traiticons/trait_icon_18_elderwood.tex"),
            URL(string: "https://raw.communitydragon.org/latest/game/assets/ux/traiticons/trait_icon_18_elderwood.png")
        )
    }

    func testBuildsAugmentIconURL() {
        XCTAssertEqual(
            CDragonAssetURL.imageURL(forGamePath: "assets/maps/tft/icons/augments/hexcore/marksman_i.tex"),
            URL(
                string: "https://raw.communitydragon.org/latest/game/assets/maps/tft/icons/augments/hexcore/marksman_i.png"
            )
        )
    }

    func testAcceptsDDSAsWellAsTex() {
        XCTAssertEqual(
            CDragonAssetURL.imageURL(forGamePath: "assets/characters/tft18_ahri/tft18_ahri_square.dds")?
                .lastPathComponent,
            "tft18_ahri_square.png"
        )
    }

    func testPassesThroughPathsAlreadyPointingAtAnImage() {
        XCTAssertEqual(
            CDragonAssetURL.imageURL(forGamePath: "assets/ux/traiticons/trait_icon_18_fae.png")?.lastPathComponent,
            "trait_icon_18_fae.png"
        )
    }

    func testStripsLeadingSlashSoTheURLDoesNotDoubleUp() {
        XCTAssertEqual(
            CDragonAssetURL.imageURL(forGamePath: "/assets/ux/traiticons/trait_icon_18_fae.tex")?.absoluteString,
            "https://raw.communitydragon.org/latest/game/assets/ux/traiticons/trait_icon_18_fae.png"
        )
    }

    func testTrimsSurroundingWhitespace() {
        XCTAssertEqual(
            CDragonAssetURL.imageURL(forGamePath: "  assets/ux/traiticons/trait_icon_18_fae.tex\n")?.lastPathComponent,
            "trait_icon_18_fae.png"
        )
    }

    // MARK: - Degrading to no image

    func testReturnsNilForMissingOrEmptyPath() {
        XCTAssertNil(CDragonAssetURL.imageURL(forGamePath: nil))
        XCTAssertNil(CDragonAssetURL.imageURL(forGamePath: ""))
        XCTAssertNil(CDragonAssetURL.imageURL(forGamePath: "   "))
        XCTAssertNil(CDragonAssetURL.imageURL(forGamePath: "/"))
    }

    func testReturnsNilForNonImageReferences() {
        // A path that isn't art (or a shape we don't recognise) must yield
        // no URL rather than one that 404s on every single launch.
        XCTAssertNil(CDragonAssetURL.imageURL(forGamePath: "assets/characters/tft18_ahri/tft18_ahri.bin"))
        XCTAssertNil(CDragonAssetURL.imageURL(forGamePath: "assets/characters/tft18_ahri"))
    }

    func testReturnsNilRatherThanEscapingTheAssetBase() {
        // Feed-supplied strings never reach the filesystem, but they do
        // build a URL — a path with unexpected characters is refused
        // instead of being encoded into something that resolves elsewhere.
        XCTAssertNil(CDragonAssetURL.imageURL(forGamePath: "assets/../../etc/passwd.tex"))
        XCTAssertNil(CDragonAssetURL.imageURL(forGamePath: "assets/a b/c.tex"))
        XCTAssertNil(CDragonAssetURL.imageURL(forGamePath: "https://evil.example.com/x.tex"))
    }
}
