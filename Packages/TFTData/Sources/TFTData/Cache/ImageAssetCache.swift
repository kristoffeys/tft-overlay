import Foundation
import os

/// The one network call `ImageAssetCache` makes, behind a protocol so tests
/// can inject a fake and never touch the real mirror.
public protocol ImageDataFetching: Sendable {
    /// - Returns: The raw bytes of the asset.
    /// - Throws: Anything at all — the cache treats every failure the same
    ///   way (no image; the caller keeps its text placeholder).
    func fetchImageData(from url: URL) async throws -> Data
}

extension URLSession: ImageDataFetching {
    public func fetchImageData(from url: URL) async throws -> Data {
        let (data, response) = try await data(from: url)
        // A 404 from the mirror comes back as a perfectly successful
        // transfer of an HTML error page. Storing that as "the icon" would
        // poison the disk cache permanently, so status is checked here.
        if let http = response as? HTTPURLResponse, !(200 ..< 300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

/// Disk-backed store for Community Dragon image assets, so an icon is
/// fetched over the network **at most once ever** rather than once per
/// launch.
///
/// Deliberately mirrors `FileDataCache`: a plain directory of files under
/// Application Support, no database, no expiry. Game art for a given path
/// is immutable — CDragon publishes a *new* path when art changes, and a
/// set rotation brings entirely new paths — so there is nothing to
/// invalidate. `clear()` exists for the "user wants their disk back" case,
/// not for correctness.
///
/// Lives in `TFTData` rather than `TFTUI` because it is network and disk
/// I/O, which the architecture split keeps out of the UI package. It is an
/// `actor` (unlike `FileDataCache`) because it coalesces concurrent
/// requests: a panel showing eight copies of the same item icon must
/// produce one fetch, not eight.
public actor ImageAssetCache {
    /// Shared instance so every view in the app coalesces against the same
    /// in-flight table and the same directory.
    public static let shared = ImageAssetCache()

    private let directory: URL
    private let fetcher: ImageDataFetching
    private let logger = Logger(subsystem: "com.tftoverlay.tftdata", category: "imagecache")

    /// URLs currently being fetched, so N simultaneous askers share one
    /// request instead of racing to write the same file.
    private var inFlight: [URL: Task<Data?, Never>] = [:]
    /// URLs that failed this session. Without this, a panel scrolling over
    /// a missing asset would retry it on every appearance, forever. Not
    /// persisted: a failure is usually "offline", which is exactly the
    /// thing that changes between launches.
    private var failedThisSession: Set<URL> = []

    /// - Parameters:
    ///   - directory: Where to store fetched images. Defaults to
    ///     `~/Library/Application Support/<bundle-id-or-fallback>/TFTData/Images/`.
    ///     Tests should pass a temporary directory.
    ///   - fetcher: Injectable for tests; defaults to the shared URLSession.
    public init(directory: URL? = nil, fetcher: ImageDataFetching = URLSession.shared) {
        self.directory = directory ?? Self.defaultDirectory()
        self.fetcher = fetcher
    }

    private static func defaultDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let bundleID = Bundle.main.bundleIdentifier ?? "tft-overlay"
        return appSupport
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("TFTData", isDirectory: true)
            .appendingPathComponent("Images", isDirectory: true)
    }

    /// Image bytes for `url`, from disk when already fetched, otherwise
    /// over the network (once). `nil` means "no image available" — offline,
    /// 404, empty response — and is never an error the caller has to
    /// handle: the UI keeps its text placeholder.
    public func imageData(for url: URL) async -> Data? {
        if let cached = dataOnDisk(for: url) {
            return cached
        }
        if failedThisSession.contains(url) {
            return nil
        }
        if let existing = inFlight[url] {
            return await existing.value
        }

        let task = Task<Data?, Never> { [fetcher] in
            do {
                let data = try await fetcher.fetchImageData(from: url)
                return data.isEmpty ? nil : data
            } catch {
                return nil
            }
        }
        inFlight[url] = task
        let data = await task.value
        inFlight[url] = nil

        guard let data else {
            failedThisSession.insert(url)
            logger
                .debug("Image asset unavailable, keeping the text placeholder: \(url.absoluteString, privacy: .public)")
            return nil
        }
        writeToDisk(data, for: url)
        return data
    }

    /// True when `url` is already on disk, i.e. displayable with no network
    /// at all. Exposed so the UI can skip an async hop for the common warm
    /// case — and for tests to assert "fetched at most once".
    public func isCached(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: url).path)
    }

    /// Removes every stored image. Not needed for correctness (asset paths
    /// are immutable); here for a future "clear cached data" affordance.
    public func clear() {
        try? FileManager.default.removeItem(at: directory)
        failedThisSession.removeAll()
    }

    private func dataOnDisk(for url: URL) -> Data? {
        guard let data = try? Data(contentsOf: fileURL(for: url)), !data.isEmpty else { return nil }
        return data
    }

    private func writeToDisk(_ data: Data, for url: URL) {
        let destination = fileURL(for: url)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: destination, options: .atomic)
    }

    /// One flat file per URL. The filename is a hash of the full URL rather
    /// than its path: asset paths nest several directories deep and collide
    /// on their last component (`.../set18/tft18_emblem_primal.png` vs a
    /// same-named file under another set), so flattening by hash is both
    /// collision-free and free of any path-traversal question about
    /// feed-supplied strings.
    private func fileURL(for url: URL) -> URL {
        directory.appendingPathComponent(Self.filename(for: url))
    }

    static func filename(for url: URL) -> String {
        let hash = FNV1a64.hash(url.absoluteString)
        let suffix = url.pathExtension.isEmpty ? "png" : url.pathExtension.lowercased()
        return String(format: "%016llx", hash) + "." + suffix
    }
}

/// FNV-1a, 64-bit. Used purely to derive a stable, collision-resistant
/// filename from a URL — not for anything security-sensitive. Hand-rolled
/// because CryptoKit would be a whole framework dependency for a filename,
/// and `Hasher` is explicitly seeded per-process, so its values are not
/// stable across launches — which is exactly what a cache filename needs to
/// be.
enum FNV1a64 {
    static func hash(_ string: String) -> UInt64 {
        var value: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in string.utf8 {
            value ^= UInt64(byte)
            value &*= 0x0000_0100_0000_01B3
        }
        return value
    }
}
