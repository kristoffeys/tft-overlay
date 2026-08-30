import Combine
import Foundation

/// Persists which comps are pinned, in pin order, across app launches (#27).
///
/// Pins are stored by `Comp.id` (the schema's stable kebab-case slug — see
/// `comp.schema.json`), not by name, so a pin survives a comp being
/// re-authored for a new patch under the same id. `cycleIndex` tracks which
/// pinned comp the rail is currently showing; it is deliberately not
/// persisted, since which pin was focused last session isn't worth
/// remembering the way the pin set itself is.
public final class PinnedCompsStore: ObservableObject {
    @Published public private(set) var pinnedIDs: [String]
    @Published public private(set) var cycleIndex: Int = 0

    private let defaults: UserDefaults
    private let storageKey: String

    public init(defaults: UserDefaults = .standard, storageKey: String = "tftoverlay.pinnedComps") {
        self.defaults = defaults
        self.storageKey = storageKey
        pinnedIDs = defaults.stringArray(forKey: storageKey) ?? []
    }

    public func isPinned(_ id: String) -> Bool {
        pinnedIDs.contains(id)
    }

    public func toggle(_ id: String) {
        if pinnedIDs.contains(id) {
            unpin(id)
        } else {
            pin(id)
        }
    }

    /// Pinning also makes the comp the current one.
    ///
    /// Pinning is how a player says "this is the build I'm going for", and
    /// the compact overlay shows the current pin's roster — so a pin that
    /// left the cycle pointed at some earlier comp would answer a question
    /// nobody asked. Pinning an already-pinned comp still re-selects it,
    /// which is what makes it a usable "switch to this build" gesture.
    public func pin(_ id: String) {
        if let existing = pinnedIDs.firstIndex(of: id) {
            cycleIndex = existing
            return
        }
        pinnedIDs.append(id)
        cycleIndex = pinnedIDs.count - 1
        persist()
    }

    public func unpin(_ id: String) {
        pinnedIDs.removeAll { $0 == id }
        clampCycleIndex()
        persist()
    }

    /// This pin's position among the others, for display as "2 / 3".
    public func cyclePosition(of id: String) -> Int? {
        pinnedIDs.firstIndex(of: id)
    }

    public var currentPinnedID: String? {
        guard pinnedIDs.indices.contains(cycleIndex) else { return nil }
        return pinnedIDs[cycleIndex]
    }

    /// Steps the cycle forward, wrapping around at the end.
    public func advance() {
        guard !pinnedIDs.isEmpty else { return }
        cycleIndex = (cycleIndex + 1) % pinnedIDs.count
    }

    /// Steps the cycle backward, wrapping around at the start.
    public func retreat() {
        guard !pinnedIDs.isEmpty else { return }
        cycleIndex = (cycleIndex - 1 + pinnedIDs.count) % pinnedIDs.count
    }

    /// Jumps the cycle directly to `id`, if it is pinned.
    public func selectCycle(id: String) {
        guard let index = pinnedIDs.firstIndex(of: id) else { return }
        cycleIndex = index
    }

    private func clampCycleIndex() {
        guard !pinnedIDs.isEmpty else {
            cycleIndex = 0
            return
        }
        cycleIndex = min(cycleIndex, pinnedIDs.count - 1)
    }

    private func persist() {
        defaults.set(pinnedIDs, forKey: storageKey)
    }
}
