@testable import TFTData
import XCTest

/// Exercises the cache against an injected fetcher — never the real mirror.
/// A unit test that reached the network would be slow, flaky offline, and
/// would stop testing the thing that actually matters here: that the
/// network is hit *once*.
final class ImageAssetCacheTests: XCTestCase {
    /// Records every URL it is asked for, so a test can assert the exact
    /// number of network round trips.
    private actor RecordingFetcher: ImageDataFetching {
        private(set) var requested: [URL] = []
        private let result: Result<Data, Error>
        /// Held until `release()` so a test can hold two callers in the
        /// same in-flight window and prove they coalesce.
        private var gate: CheckedContinuation<Void, Never>?
        private let gated: Bool

        init(result: Result<Data, Error>, gated: Bool = false) {
            self.result = result
            self.gated = gated
        }

        func fetchImageData(from url: URL) async throws -> Data {
            requested.append(url)
            if gated {
                await withCheckedContinuation { continuation in
                    gate = continuation
                }
            }
            return try result.get()
        }

        func requestCount() -> Int {
            requested.count
        }

        func release() {
            gate?.resume()
            gate = nil
        }

        func waitUntilRequested() async {
            while requested.isEmpty {
                await Task.yield()
            }
        }
    }

    private struct Offline: Error {}

    private var tempDirectory: URL!
    private let url = URL(string: "https://raw.communitydragon.org/latest/game/assets/x/ahri_square.png")!
    private let pixel = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ImageAssetCacheTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    func testFetchesOnceAndServesEveryLaterCallFromDisk() async {
        let fetcher = RecordingFetcher(result: .success(pixel))
        let cache = ImageAssetCache(directory: tempDirectory, fetcher: fetcher)

        let first = await cache.imageData(for: url)
        let second = await cache.imageData(for: url)

        XCTAssertEqual(first, pixel)
        XCTAssertEqual(second, pixel)
        let count = await fetcher.requestCount()
        XCTAssertEqual(count, 1, "the second read must come off disk")
    }

    func testSurvivesRelaunchWithoutRefetching() async {
        let firstLaunch = RecordingFetcher(result: .success(pixel))
        _ = await ImageAssetCache(directory: tempDirectory, fetcher: firstLaunch).imageData(for: url)

        // A brand-new cache instance over the same directory stands in for
        // the next app launch: "at most once ever", not "once per launch".
        let secondLaunch = RecordingFetcher(result: .failure(Offline()))
        let data = await ImageAssetCache(directory: tempDirectory, fetcher: secondLaunch).imageData(for: url)

        XCTAssertEqual(data, pixel)
        let count = await secondLaunch.requestCount()
        XCTAssertEqual(count, 0)
    }

    func testCoalescesConcurrentRequestsForTheSameURL() async {
        let fetcher = RecordingFetcher(result: .success(pixel), gated: true)
        let cache = ImageAssetCache(directory: tempDirectory, fetcher: fetcher)

        async let first = cache.imageData(for: url)
        await fetcher.waitUntilRequested()
        async let second = cache.imageData(for: url)
        // Give the second caller a chance to reach the cache before the
        // first one's fetch is allowed to complete.
        await Task.yield()
        await fetcher.release()

        let results = await [first, second]
        XCTAssertEqual(results, [pixel, pixel])
        let count = await fetcher.requestCount()
        XCTAssertEqual(count, 1, "eight copies of one item icon on screen must not be eight requests")
    }

    func testFailedFetchReturnsNilAndIsNotRetriedThisSession() async {
        let fetcher = RecordingFetcher(result: .failure(Offline()))
        let cache = ImageAssetCache(directory: tempDirectory, fetcher: fetcher)

        let first = await cache.imageData(for: url)
        let second = await cache.imageData(for: url)

        XCTAssertNil(first, "offline is not an error the caller has to handle — it's just no image")
        XCTAssertNil(second)
        let count = await fetcher.requestCount()
        XCTAssertEqual(count, 1, "a scrolling panel must not re-request a missing asset on every appearance")
        let cached = await cache.isCached(url)
        XCTAssertFalse(cached, "a failure must never be written to disk as if it were art")
    }

    func testEmptyResponseIsTreatedAsNoImage() async {
        let fetcher = RecordingFetcher(result: .success(Data()))
        let cache = ImageAssetCache(directory: tempDirectory, fetcher: fetcher)

        let data = await cache.imageData(for: url)

        XCTAssertNil(data)
        let cached = await cache.isCached(url)
        XCTAssertFalse(cached)
    }

    func testDistinctURLsSharingALastPathComponentDoNotCollide() throws {
        let setEighteen = try XCTUnwrap(URL(string: "https://raw.communitydragon.org/latest/game/a/set18/emblem.png"))
        let setSeventeen = try XCTUnwrap(URL(string: "https://raw.communitydragon.org/latest/game/a/set17/emblem.png"))
        XCTAssertNotEqual(
            ImageAssetCache.filename(for: setEighteen),
            ImageAssetCache.filename(for: setSeventeen)
        )
    }

    func testFilenameIsStableAcrossInstancesSoTheCacheSurvivesRelaunch() {
        let first = ImageAssetCache.filename(for: url)
        let second = ImageAssetCache.filename(for: url)
        XCTAssertEqual(first, second)
        XCTAssertTrue(first.hasSuffix(".png"))
    }

    func testClearRemovesStoredImages() async {
        let fetcher = RecordingFetcher(result: .success(pixel))
        let cache = ImageAssetCache(directory: tempDirectory, fetcher: fetcher)
        _ = await cache.imageData(for: url)
        var cached = await cache.isCached(url)
        XCTAssertTrue(cached)

        await cache.clear()

        cached = await cache.isCached(url)
        XCTAssertFalse(cached)
    }
}
