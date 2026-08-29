/// Persists one `CacheEnvelope` to disk. Kept synchronous and file-based —
/// no async needed for local I/O — so `TFTDataService` can call it directly
/// from actor-isolated code.
public protocol DataCacheStore: Sendable {
    /// `nil` when there is no cache file, it fails to decode, or its
    /// `schemaVersion` doesn't match `CacheEnvelope.currentSchemaVersion` —
    /// all three are treated the same way: a cache miss, not an error.
    func loadEnvelope() -> CacheEnvelope?
    func save(_ envelope: CacheEnvelope)
    func clear()
}
