import Foundation

/// `DataCacheStore` backed by a JSON file on disk, under Application
/// Support by default. Pure Foundation (`FileManager`) — no AppKit, no
/// window, no host: this is data persistence, not UI.
///
/// Only the target directory is stored, not a `FileManager` instance
/// (`FileManager` isn't `Sendable`); `.default` is used at each call site,
/// which is safe since it's a thread-safe singleton.
public struct FileDataCache: DataCacheStore {
    private let fileURL: URL

    /// - Parameter directory: Where to store the cache file. Defaults to
    ///   `~/Library/Application Support/<bundle-id-or-fallback>/TFTData/`.
    ///   Tests should pass a temporary directory instead of touching the
    ///   real Application Support folder.
    public init(directory: URL? = nil) {
        let base = directory ?? Self.defaultDirectory()
        fileURL = base.appendingPathComponent("set-data-cache.json")
    }

    private static func defaultDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let bundleID = Bundle.main.bundleIdentifier ?? "tft-overlay"
        return appSupport.appendingPathComponent(bundleID, isDirectory: true).appendingPathComponent(
            "TFTData",
            isDirectory: true
        )
    }

    public func loadEnvelope() -> CacheEnvelope? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        guard let envelope = try? JSONDecoder().decode(CacheEnvelope.self, from: data) else { return nil }
        guard envelope.schemaVersion == CacheEnvelope.currentSchemaVersion else { return nil }
        return envelope
    }

    public func save(_ envelope: CacheEnvelope) {
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }

    public func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
