@testable import TFTData
import XCTest

private struct FixtureError: Error, Sendable, Equatable {}

private struct FakeSetDataSource: SetDataSource {
    var contentVersion: Result<String, FixtureError> = .success("v1")
    var setData: Result<Data, FixtureError> = .success(Data())

    func fetchContentVersion() async throws -> String {
        try contentVersion.get()
    }

    func fetchSetData() async throws -> Data {
        try setData.get()
    }
}

/// `fetchSetData` call counting needs reference semantics; `FakeSetDataSource`
/// above stays a value type for simple cases, this wraps it for tests that
/// need to assert "the full document was/wasn't re-fetched".
private actor CallCountingSource: SetDataSource {
    private(set) var fetchSetDataCallCount = 0
    private var contentVersion: Result<String, FixtureError> = .success("v1")
    private var setData: Result<Data, FixtureError> = .success(Data())

    func setContentVersion(_ value: Result<String, FixtureError>) {
        contentVersion = value
    }

    func setSetData(_ value: Result<Data, FixtureError>) {
        setData = value
    }

    func fetchContentVersion() async throws -> String {
        try contentVersion.get()
    }

    func fetchSetData() async throws -> Data {
        fetchSetDataCallCount += 1
        return try setData.get()
    }
}

private struct FakeFallbackDataProvider: FallbackDataProvider {
    var envelope: CacheEnvelope?
    func load() -> CacheEnvelope? {
        envelope
    }
}

final class TFTDataServiceTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TFTDataServiceTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    private func sampleEnvelope(contentVersion: String) -> CacheEnvelope {
        CacheEnvelope(
            schemaVersion: CacheEnvelope.currentSchemaVersion,
            dataVersion: DataVersion(setNumber: 18, contentVersion: contentVersion, fetchedAt: Date()),
            champions: [Champion(id: "DA_18_Ahri", name: "Ahri", cost: 4, traitIDs: [])],
            traits: [],
            items: [],
            augments: []
        )
    }

    private func rawSetData(contentApiName: String) -> Data {
        Data(#"""
        {
            "items": [],
            "sets": {
                "18": {
                    "name": "Set10",
                    "champions": [
                        {"apiName": "\#(contentApiName)", "name": "Fetched", "cost": 3, "traits": ["Elderwood"]}
                    ],
                    "traits": [
                        {"apiName": "DA_18_Elderwood", "name": "Elderwood", "effects": []}
                    ]
                }
            }
        }
        """#.utf8)
    }

    // MARK: - loadCurrentStore

    func testLoadCurrentStorePrefersDiskCacheOverFallback() async {
        let cache = FileDataCache(directory: tempDirectory)
        cache.save(sampleEnvelope(contentVersion: "cached"))
        let service = TFTDataService(
            cache: cache,
            source: FakeSetDataSource(),
            fallback: FakeFallbackDataProvider(envelope: sampleEnvelope(contentVersion: "fallback"))
        )

        let result = await service.loadCurrentStore()

        XCTAssertEqual(result.origin, .diskCache)
        XCTAssertEqual(result.store.version?.contentVersion, "cached")
    }

    func testLoadCurrentStoreFallsBackWhenNoCacheExists() async {
        let service = TFTDataService(
            cache: FileDataCache(directory: tempDirectory),
            source: FakeSetDataSource(),
            fallback: FakeFallbackDataProvider(envelope: sampleEnvelope(contentVersion: "fallback"))
        )

        let result = await service.loadCurrentStore()

        XCTAssertEqual(result.origin, .bundledFallback)
        XCTAssertEqual(result.store.version?.contentVersion, "fallback")
        XCTAssertFalse(result.store.champions.isEmpty, "app must be usable offline from the fallback pack")
    }

    func testLoadCurrentStoreWithNothingAvailableReturnsEmptyStoreNotACrash() async {
        let service = TFTDataService(
            cache: FileDataCache(directory: tempDirectory),
            source: FakeSetDataSource(),
            fallback: FakeFallbackDataProvider(envelope: nil)
        )

        let result = await service.loadCurrentStore()

        XCTAssertEqual(result.origin, .none)
        XCTAssertTrue(result.store.champions.isEmpty)
    }

    // MARK: - checkAndRefreshIfNeeded

    func testUpToDateWhenContentVersionMatchesCache() async throws {
        let cache = FileDataCache(directory: tempDirectory)
        cache.save(sampleEnvelope(contentVersion: "same"))
        let source = CallCountingSource()
        await source.setContentVersion(.success("same"))
        let service = TFTDataService(cache: cache, source: source, fallback: FakeFallbackDataProvider())

        let outcome = await service.checkAndRefreshIfNeeded()

        XCTAssertEqual(
            outcome,
            try .upToDate(DataVersion(
                setNumber: 18,
                contentVersion: "same",
                fetchedAt: XCTUnwrap(cache.loadEnvelope()?.dataVersion.fetchedAt)
            ))
        )
        let callCount = await source.fetchSetDataCallCount
        XCTAssertEqual(
            callCount,
            0,
            "must not download the full document when the cheap version check says nothing changed"
        )
    }

    func testRefreshesAndCachesWhenContentVersionChanges() async {
        let cache = FileDataCache(directory: tempDirectory)
        cache.save(sampleEnvelope(contentVersion: "old"))
        let source = CallCountingSource()
        await source.setContentVersion(.success("new"))
        await source.setSetData(.success(rawSetData(contentApiName: "DA_18_New")))
        let service = TFTDataService(cache: cache, source: source, fallback: FakeFallbackDataProvider())

        let outcome = await service.checkAndRefreshIfNeeded()

        guard case let .refreshed(version) = outcome else {
            return XCTFail("expected .refreshed, got \(outcome)")
        }
        XCTAssertEqual(version.contentVersion, "new")
        let callCount = await source.fetchSetDataCallCount
        XCTAssertEqual(callCount, 1)

        let cached = cache.loadEnvelope()
        XCTAssertEqual(cached?.dataVersion.contentVersion, "new")
        XCTAssertEqual(cached?.champions.map(\.id), ["DA_18_New"])
    }

    func testNetworkFailureOnVersionCheckDegradesQuietly() async {
        let cache = FileDataCache(directory: tempDirectory)
        cache.save(sampleEnvelope(contentVersion: "cached"))
        var source = FakeSetDataSource()
        source.contentVersion = .failure(FixtureError())
        let service = TFTDataService(cache: cache, source: source, fallback: FakeFallbackDataProvider())

        let outcome = await service.checkAndRefreshIfNeeded()

        XCTAssertEqual(outcome, .networkUnavailable)
        // Cached data must still be there — a network failure never wipes
        // what's already usable.
        XCTAssertEqual(cache.loadEnvelope()?.dataVersion.contentVersion, "cached")
    }

    func testNetworkFailureOnFullFetchDegradesQuietly() async {
        let cache = FileDataCache(directory: tempDirectory)
        cache.save(sampleEnvelope(contentVersion: "old"))
        var source = FakeSetDataSource()
        source.contentVersion = .success("new")
        source.setData = .failure(FixtureError())
        let service = TFTDataService(cache: cache, source: source, fallback: FakeFallbackDataProvider())

        let outcome = await service.checkAndRefreshIfNeeded()

        XCTAssertEqual(outcome, .networkUnavailable)
        XCTAssertEqual(
            cache.loadEnvelope()?.dataVersion.contentVersion,
            "old",
            "must not clobber the cache with a failed refresh"
        )
    }

    func testUnparsableResponseReportsParseFailedAndKeepsOldCache() async {
        let cache = FileDataCache(directory: tempDirectory)
        cache.save(sampleEnvelope(contentVersion: "old"))
        var source = FakeSetDataSource()
        source.contentVersion = .success("new")
        source.setData = .success(Data("garbage, not json".utf8))
        let service = TFTDataService(cache: cache, source: source, fallback: FakeFallbackDataProvider())

        let outcome = await service.checkAndRefreshIfNeeded()

        XCTAssertEqual(outcome, .parseFailed)
        XCTAssertEqual(cache.loadEnvelope()?.dataVersion.contentVersion, "old")
    }
}
