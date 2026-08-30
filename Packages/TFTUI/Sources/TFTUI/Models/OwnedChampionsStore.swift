import Combine
import Foundation

/// Persists which champions the player currently has, across panel toggles
/// and app launches (#86).
///
/// The overlay cannot see the board — vision is Phase 2 (#43) and will not
/// land soon — so this is the manual stand-in: the player taps what they
/// have, which unlocks the most useful question in the game, "given what I
/// have, what should I build?" (`CompSuggestionRanking`, #87). Keyed by
/// champion name rather than any Riot id, matching how the rest of the app
/// already identifies units (`CompUnit.name`,
/// `TFTAssetCatalog.championImageURL(named:)`), and normalised through
/// `TFTNameKey` so punctuation or casing drift can never split one
/// champion into two entries in this store.
///
/// `clear()` is not an afterthought. This roster goes stale every single
/// game — it describes one game's bench, not the player in general — and a
/// stale roster is actively worse than an empty one, since it lies about
/// what's reachable. Wiping it is always exactly one call.
///
/// Follows `PinnedCompsStore`'s shape deliberately: an `ObservedObject`
/// over an injectable `UserDefaults` and storage key, so tests never touch
/// real user state. Built so that when board vision arrives it can call
/// `add`/`remove` on this same store as just another source of truth,
/// rather than needing its own separate state to merge in later.
public final class OwnedChampionsStore: ObservableObject {
    @Published public private(set) var ownedKeys: Set<String>

    private let defaults: UserDefaults
    private let storageKey: String

    public init(defaults: UserDefaults = .standard, storageKey: String = "tftoverlay.ownedChampions") {
        self.defaults = defaults
        self.storageKey = storageKey
        let stored = defaults.stringArray(forKey: storageKey) ?? []
        ownedKeys = Set(stored.map(TFTNameKey.normalize))
    }

    public func isOwned(_ name: String) -> Bool {
        ownedKeys.contains(TFTNameKey.normalize(name))
    }

    public func toggle(_ name: String) {
        if isOwned(name) {
            remove(name)
        } else {
            add(name)
        }
    }

    public func add(_ name: String) {
        guard ownedKeys.insert(TFTNameKey.normalize(name)).inserted else { return }
        persist()
    }

    public func remove(_ name: String) {
        guard ownedKeys.remove(TFTNameKey.normalize(name)) != nil else { return }
        persist()
    }

    /// The whole roster goes stale every game; this is the one-tap reset
    /// that makes "empty" the safe default between games rather than a
    /// leftover roster from the last one.
    public func clear() {
        guard !ownedKeys.isEmpty else { return }
        ownedKeys.removeAll()
        persist()
    }

    private func persist() {
        defaults.set(Array(ownedKeys), forKey: storageKey)
    }
}
