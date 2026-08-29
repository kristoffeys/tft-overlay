@testable import TFTData
import XCTest

final class FileDataCacheTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TFTDataCacheTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    private func makeEnvelope(schemaVersion: Int = CacheEnvelope.currentSchemaVersion) -> CacheEnvelope {
        CacheEnvelope(
            schemaVersion: schemaVersion,
            dataVersion: DataVersion(setNumber: 18, contentVersion: "test-version-1", fetchedAt: Date()),
            champions: [Champion(id: "DA_18_Ahri", name: "Ahri", cost: 4, traitIDs: ["DA_18_Spellweaver"])],
            traits: [Trait(id: "DA_18_Spellweaver", name: "Spellweaver", breakpoints: [2, 4, 6])],
            items: [Item(id: "DA_Component_BFSword", name: "B.F. Sword")],
            augments: [Augment(id: "DA_FocusedFire", name: "Focused Fire", tier: 1, text: "text")]
        )
    }

    func testRoundTripsAnEnvelopeThroughDisk() {
        let cache = FileDataCache(directory: tempDirectory)
        XCTAssertNil(cache.loadEnvelope(), "nothing saved yet")

        let envelope = makeEnvelope()
        cache.save(envelope)

        XCTAssertEqual(cache.loadEnvelope(), envelope)
    }

    func testClearRemovesTheCachedFile() {
        let cache = FileDataCache(directory: tempDirectory)
        cache.save(makeEnvelope())
        XCTAssertNotNil(cache.loadEnvelope())

        cache.clear()

        XCTAssertNil(cache.loadEnvelope())
    }

    func testLoadingAnUnrecognizedSchemaVersionIsATreatedCacheMiss() {
        let cache = FileDataCache(directory: tempDirectory)
        cache.save(makeEnvelope(schemaVersion: CacheEnvelope.currentSchemaVersion + 1))

        // The migration strategy for this package is discard-and-refetch,
        // not a field-by-field upgrade: a foreign/future schema version on
        // disk must come back as "no cache", never a crash or garbage data.
        XCTAssertNil(cache.loadEnvelope())
    }

    func testLoadingCorruptJSONIsATreatedCacheMiss() throws {
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let fileURL = tempDirectory.appendingPathComponent("set-data-cache.json")
        try Data("{ not valid json".utf8).write(to: fileURL)

        let cache = FileDataCache(directory: tempDirectory)
        XCTAssertNil(cache.loadEnvelope())
    }
}
