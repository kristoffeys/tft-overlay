@testable import TFTData
import XCTest

/// The bundled pack is what a first launch with no network shows. If its
/// image URLs ever go missing — a regeneration that forgets them, a schema
/// change that drops the field — the app silently degrades to text
/// placeholders everywhere and nothing else fails. Hence this test.
final class BundledFallbackImageURLTests: XCTestCase {
    func testBundledPackIsAtTheCurrentSchemaVersion() throws {
        let envelope = try XCTUnwrap(BundledFallbackData().load(), "bundled fallback pack failed to load")
        XCTAssertEqual(envelope.schemaVersion, CacheEnvelope.currentSchemaVersion)
    }

    func testEveryBundledEntryCarriesAnImageURL() throws {
        let envelope = try XCTUnwrap(BundledFallbackData().load(), "bundled fallback pack failed to load")

        XCTAssertTrue(envelope.champions.allSatisfy { $0.imageURL != nil })
        XCTAssertTrue(envelope.traits.allSatisfy { $0.imageURL != nil })
        XCTAssertTrue(envelope.items.allSatisfy { $0.imageURL != nil })
        XCTAssertTrue(envelope.augments.allSatisfy { $0.imageURL != nil })
    }

    func testBundledImageURLsPointAtTheCommunityDragonAssetMirror() throws {
        let envelope = try XCTUnwrap(BundledFallbackData().load(), "bundled fallback pack failed to load")
        let urls = envelope.champions.compactMap(\.imageURL)
            + envelope.traits.compactMap(\.imageURL)
            + envelope.items.compactMap(\.imageURL)
            + envelope.augments.compactMap(\.imageURL)

        XCTAssertFalse(urls.isEmpty)
        for url in urls {
            XCTAssertTrue(
                url.absoluteString.hasPrefix(CDragonAssetURL.assetBaseURL),
                "\(url) is not on the asset mirror"
            )
            XCTAssertEqual(url.pathExtension, "png")
        }
    }

    func testImageURLsSurviveACacheRoundTrip() throws {
        // The envelope is what gets written to disk and read back on the
        // next launch — image URLs have to survive that, or every restart
        // would go back to text placeholders until the next patch.
        let original = try XCTUnwrap(BundledFallbackData().load())
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CacheEnvelope.self, from: encoded)

        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.champions.first?.imageURL, original.champions.first?.imageURL)
    }
}
