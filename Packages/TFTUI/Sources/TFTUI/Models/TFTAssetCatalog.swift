import Foundation
import TFTData

/// Name-keyed lookup from what the overlay's views *have* (a champion,
/// item or trait display name, read out of a hand-authored comp) to the
/// art URL the data layer resolved for it.
///
/// Comps are authored against display names ("Ashe", "Infinity Edge",
/// "Elderwood"), not Riot apiNames, so a name-keyed index is what lets an
/// icon appear without threading a `Champion`/`Item` value through every
/// view that currently takes a `String`.
///
/// Handed to views through the environment rather than passed down, so a
/// panel that doesn't know or care about art needs no changes and an app
/// that has no data store yet keeps today's text-only rendering: `.empty`
/// answers `nil` to everything, and `nil` is exactly the "draw the text
/// placeholder" case.
public struct TFTAssetCatalog: Sendable, Equatable {
    /// The no-art catalog. Also the environment default, so any view
    /// hierarchy that never injects one renders exactly as it did before
    /// images existed.
    public static let empty = TFTAssetCatalog()

    private let championURLsByName: [String: URL]
    private let itemURLsByName: [String: URL]
    private let traitURLsByName: [String: URL]

    public init(
        championURLsByName: [String: URL] = [:],
        itemURLsByName: [String: URL] = [:],
        traitURLsByName: [String: URL] = [:]
    ) {
        self.championURLsByName = Self.keyed(championURLsByName)
        self.itemURLsByName = Self.keyed(itemURLsByName)
        self.traitURLsByName = Self.keyed(traitURLsByName)
    }

    /// Builds the catalog from whatever the data layer loaded — live,
    /// disk-cached or the bundled fallback pack. Entries with no art are
    /// simply absent.
    public init(store: TFTDataStore) {
        self.init(
            championURLsByName: Self.index(store.champions.map { ($0.name, $0.imageURL) }),
            itemURLsByName: Self.index(store.items.map { ($0.name, $0.imageURL) }),
            traitURLsByName: Self.index(store.traits.map { ($0.name, $0.imageURL) })
        )
    }

    public func championImageURL(named name: String) -> URL? {
        championURLsByName[TFTNameKey.normalize(name)]
    }

    public func itemImageURL(named name: String) -> URL? {
        itemURLsByName[TFTNameKey.normalize(name)]
    }

    /// Not consumed by any view yet — `TraitTag` is still text-only — but
    /// resolved here so wiring a trait glyph in later is a one-liner rather
    /// than another pass through the data layer.
    public func traitImageURL(named name: String) -> URL? {
        traitURLsByName[TFTNameKey.normalize(name)]
    }

    private static func index(_ pairs: [(String, URL?)]) -> [String: URL] {
        pairs.reduce(into: [:]) { result, pair in
            guard let url = pair.1 else { return }
            result[pair.0] = url
        }
    }

    /// Normalises the keys via `TFTNameKey`. First entry wins on a
    /// collision, matching `CompUnitIndex`: Set 18 ships several
    /// same-named champion variants (Lux's nine trait forms), and any of
    /// their portraits beats none.
    private static func keyed(_ urls: [String: URL]) -> [String: URL] {
        urls.sorted { $0.key < $1.key }.reduce(into: [:]) { result, pair in
            let key = TFTNameKey.normalize(pair.key)
            if result[key] == nil {
                result[key] = pair.value
            }
        }
    }
}
