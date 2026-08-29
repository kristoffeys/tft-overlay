import Foundation
import os

/// Where a loaded `TFTDataStore` actually came from — surfaced so the UI
/// can be honest about it ("showing bundled data, last refreshed never")
/// rather than silently presenting stale/fallback data as if it were live.
public enum DataOrigin: Sendable, Equatable {
    case diskCache
    case bundledFallback
    /// Neither a disk cache nor the bundled fallback pack decoded. Only
    /// reachable if the bundled resource itself is missing/corrupt, since
    /// it ships with the app.
    case none
}

public enum RefreshOutcome: Sendable, Equatable {
    case upToDate(DataVersion)
    case refreshed(DataVersion)
    /// The fetch failed (offline, DNS, timeout, non-2xx, ...). Logged, never
    /// surfaced as an error the app has to turn into a modal — the caller
    /// already has cached or fallback data to keep showing.
    case networkUnavailable
    /// The fetch succeeded but the response didn't parse into usable data.
    case parseFailed
}

/// Ties `SetDataSource` (network), `DataCacheStore` (disk) and
/// `FallbackDataProvider` (bundled resource) together into the "detect the
/// live patch, refresh when it changes, stay usable offline" behavior
/// issues #15/#17/#22 ask for.
///
/// Scheduling a periodic check is deliberately left to the caller (an app
/// layer, on a `Timer`) rather than owned here — this package has no
/// window/host/UI and shouldn't own a run loop concept. `checkAndRefreshIfNeeded()`
/// is cheap to call on launch and again on any interval the caller picks.
public actor TFTDataService {
    private let cache: DataCacheStore
    private let source: SetDataSource
    private let fallback: FallbackDataProvider
    private let logger = Logger(subsystem: "com.tftoverlay.tftdata", category: "ingestion")

    public init(
        cache: DataCacheStore = FileDataCache(),
        source: SetDataSource = CommunityDragonSource(),
        fallback: FallbackDataProvider = BundledFallbackData()
    ) {
        self.cache = cache
        self.source = source
        self.fallback = fallback
    }

    /// Fast, synchronous-feeling (no network) load for app startup: disk
    /// cache if present and valid, else the bundled fallback pack. Never
    /// blocks on the network — call `checkAndRefreshIfNeeded()` separately
    /// to pull anything newer.
    public func loadCurrentStore() -> (store: TFTDataStore, origin: DataOrigin) {
        if let envelope = cache.loadEnvelope() {
            return (makeStore(from: envelope), .diskCache)
        }
        if let envelope = fallback.load() {
            return (makeStore(from: envelope), .bundledFallback)
        }
        logger.error("No disk cache and the bundled fallback pack failed to load; returning an empty store.")
        return (TFTDataStore(), .none)
    }

    /// Checks whether the live content version has moved past what's
    /// cached and, if so, fetches and caches the new set data. Safe to call
    /// on launch and on a timer — a cheap version check is the common case;
    /// the full document is only fetched when the version actually changed.
    @discardableResult
    public func checkAndRefreshIfNeeded() async -> RefreshOutcome {
        let cachedVersion = cache.loadEnvelope()?.dataVersion

        let liveContentVersion: String
        do {
            liveContentVersion = try await source.fetchContentVersion()
        } catch {
            logger
                .notice(
                    "Patch version check failed, staying on cached/fallback data: \(error.localizedDescription, privacy: .public)"
                )
            return .networkUnavailable
        }

        if let cachedVersion, cachedVersion.contentVersion == liveContentVersion {
            return .upToDate(cachedVersion)
        }

        let rawData: Data
        do {
            rawData = try await source.fetchSetData()
        } catch {
            logger
                .notice(
                    "Set data fetch failed, staying on cached/fallback data: \(error.localizedDescription, privacy: .public)"
                )
            return .networkUnavailable
        }

        let parsed: ParsedSetData
        do {
            parsed = try SetDataParser.parse(rawData)
        } catch {
            logger
                .error(
                    "Set data fetched but failed to parse, staying on cached/fallback data: \(error.localizedDescription, privacy: .public)"
                )
            return .parseFailed
        }

        let newVersion = DataVersion(setNumber: parsed.setNumber, contentVersion: liveContentVersion, fetchedAt: Date())
        cache.save(CacheEnvelope(
            schemaVersion: CacheEnvelope.currentSchemaVersion,
            dataVersion: newVersion,
            champions: parsed.champions,
            traits: parsed.traits,
            items: parsed.items,
            augments: parsed.augments
        ))
        return .refreshed(newVersion)
    }

    private func makeStore(from envelope: CacheEnvelope) -> TFTDataStore {
        TFTDataStore(
            champions: envelope.champions,
            traits: envelope.traits,
            items: envelope.items,
            augments: envelope.augments,
            version: envelope.dataVersion
        )
    }
}
