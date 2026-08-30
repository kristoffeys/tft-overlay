/// On-disk cache file format. `schemaVersion` is the file *shape*, separate
/// from `DataVersion.contentVersion` (which is the game-data patch).
///
/// Migration strategy: bump `currentSchemaVersion` on any shape change and
/// `FileDataCache` treats an on-disk file tagged with an older/other
/// version as a cache miss (discard and re-fetch) rather than attempting a
/// field-by-field migration — safe by construction, since the live network
/// fetch is always available as the source of truth and the bundled
/// fallback pack covers the offline case. Revisit only if that discard cost
/// ever becomes a real problem (e.g. a migration that must preserve
/// something the network/fallback can't reconstruct).
///
/// History:
/// - v1: champions/traits/items/augments as text-only data.
/// - v2: each of those gained an `imageURL`. Codable would happily decode a
///   v1 file (the new field is optional, so it would come back `nil`), but
///   that leaves a user who already has a cache staring at text
///   placeholders until the *next* patch changes the content version —
///   possibly days. Discarding instead drops them onto the bundled pack,
///   which does carry image URLs, and refetches on the next successful
///   network check.
///
/// `public` because it's part of the `DataCacheStore` protocol surface, but
/// `TFTDataService` is the only intended writer/reader of this shape — a
/// custom `DataCacheStore` conformance only needs to round-trip it.
public struct CacheEnvelope: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 2

    public let schemaVersion: Int
    public let dataVersion: DataVersion
    public let champions: [Champion]
    public let traits: [Trait]
    public let items: [Item]
    public let augments: [Augment]

    public init(
        schemaVersion: Int,
        dataVersion: DataVersion,
        champions: [Champion],
        traits: [Trait],
        items: [Item],
        augments: [Augment]
    ) {
        self.schemaVersion = schemaVersion
        self.dataVersion = dataVersion
        self.champions = champions
        self.traits = traits
        self.items = items
        self.augments = augments
    }
}
