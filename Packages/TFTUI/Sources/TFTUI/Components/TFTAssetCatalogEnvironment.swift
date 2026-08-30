import SwiftUI
import TFTData

private struct TFTAssetCatalogKey: EnvironmentKey {
    /// No art by default, so any view hierarchy that never injects a
    /// catalog — previews, tests, an app that hasn't loaded its data yet —
    /// renders the text placeholders it always did.
    static let defaultValue = TFTAssetCatalog.empty
}

public extension EnvironmentValues {
    var tftAssetCatalog: TFTAssetCatalog {
        get { self[TFTAssetCatalogKey.self] }
        set { self[TFTAssetCatalogKey.self] = newValue }
    }
}

public extension View {
    /// Supplies champion/item/trait art URLs to every icon below this view.
    ///
    /// Injected at the root rather than passed down because the views that
    /// draw icons are several layers deep and only know display names —
    /// threading a catalog through every panel signature would touch far
    /// more code for no behavioural difference.
    func tftAssetCatalog(_ catalog: TFTAssetCatalog) -> some View {
        environment(\.tftAssetCatalog, catalog)
    }

    /// Convenience for the common case: build the catalog straight from a
    /// loaded data store.
    func tftAssetCatalog(store: TFTDataStore) -> some View {
        environment(\.tftAssetCatalog, TFTAssetCatalog(store: store))
    }
}
