import Foundation

/// The last-resort data source: used when there is no disk cache (first
/// launch) and no network (offline). Abstracted so tests can inject a
/// fixture instead of loading the real bundled resource.
public protocol FallbackDataProvider: Sendable {
    func load() -> CacheEnvelope?
}

/// Loads the JSON pack bundled into the package under
/// `Resources/fallback-set-data.json` — a real snapshot of the live set
/// (Set 18 "Enchanted Wilds", CDragon content version
/// `16.17.8104348+branch.releases-16-17.content.release`, captured
/// 2026-08-29 via `SetDataParser` against a live fetch — not synthetic
/// placeholder data), in the same `CacheEnvelope` shape the disk cache
/// uses. This is what makes a first launch with no network still show real
/// comps and an item sheet. It goes stale as the set patches; the live
/// path (`TFTDataService.checkAndRefreshIfNeeded`) is what keeps data
/// current — this pack is only ever a floor, never refreshed in place.
public struct BundledFallbackData: FallbackDataProvider {
    public init() {}

    public func load() -> CacheEnvelope? {
        guard let url = Bundle.module.url(forResource: "fallback-set-data", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode(CacheEnvelope.self, from: data)
    }
}
