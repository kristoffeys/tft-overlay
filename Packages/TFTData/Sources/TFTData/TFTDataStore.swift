/// In-memory lookup over a set's champions, traits, items and augments.
///
/// This package only models the data shape. Loading real set data (from
/// `data/` at the repo root) is wired up by a later phase — see the ADR.
public struct TFTDataStore: Sendable {
    public let champions: [Champion]
    public let traits: [Trait]
    public let items: [Item]
    public let augments: [Augment]

    public init(
        champions: [Champion] = [],
        traits: [Trait] = [],
        items: [Item] = [],
        augments: [Augment] = []
    ) {
        self.champions = champions
        self.traits = traits
        self.items = items
        self.augments = augments
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
}
