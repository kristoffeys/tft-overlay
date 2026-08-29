/// In-memory lookup over a set's champions, traits, items and augments.
///
/// Populated either from `TFTDataService` (live-ingested and cached, see
/// `Ingestion/` and `Cache/`) or by hand for tests/previews.
public struct TFTDataStore: Sendable, Codable {
    public let champions: [Champion]
    public let traits: [Trait]
    public let items: [Item]
    public let augments: [Augment]
    /// `nil` for stores built by hand (tests, previews); set for anything
    /// that came from `TFTDataService`.
    public let version: DataVersion?

    public init(
        champions: [Champion] = [],
        traits: [Trait] = [],
        items: [Item] = [],
        augments: [Augment] = [],
        version: DataVersion? = nil
    ) {
        self.champions = champions
        self.traits = traits
        self.items = items
        self.augments = augments
        self.version = version
    }

    public func champion(id: String) -> Champion? {
        champions.first { $0.id == id }
    }

    public func trait(id: String) -> Trait? {
        traits.first { $0.id == id }
    }

    public func item(id: String) -> Item? {
        items.first { $0.id == id }
    }

    public func augment(id: String) -> Augment? {
        augments.first { $0.id == id }
    }
}
