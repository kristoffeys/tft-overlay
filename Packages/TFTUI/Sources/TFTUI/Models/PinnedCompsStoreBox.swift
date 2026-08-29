import Combine

/// Bridges an optional `PinnedCompsStore` into something `@ObservedObject`
/// can wrap, since `@ObservedObject` cannot wrap `Optional` directly.
///
/// Panels that take pinning as an optional feature (`pinnedStore:
/// PinnedCompsStore? = nil`) still need to redraw their own pin toggle the
/// moment it's tapped, not just whenever some ancestor happens to
/// re-render for an unrelated reason — without this, a plain `let
/// pinnedStore: PinnedCompsStore?` field leaves the panel unsubscribed from
/// the store's changes.
final class PinnedCompsStoreBox: ObservableObject {
    let store: PinnedCompsStore?
    private var cancellable: AnyCancellable?

    init(_ store: PinnedCompsStore?) {
        self.store = store
        cancellable = store?.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
}
