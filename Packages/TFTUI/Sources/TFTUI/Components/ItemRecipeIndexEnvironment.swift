import SwiftUI
import TFTData

private struct ItemRecipeIndexKey: EnvironmentKey {
    /// The bundled set snapshot, not an empty index — see
    /// `ItemRecipeIndex.bundled` for why a recipe is not treated as
    /// optional the way art is.
    static let defaultValue = ItemRecipeIndex.bundled
}

public extension EnvironmentValues {
    var tftItemRecipes: ItemRecipeIndex {
        get { self[ItemRecipeIndexKey.self] }
        set { self[ItemRecipeIndexKey.self] = newValue }
    }
}

public extension View {
    /// Supplies item recipes to every build surface below this view.
    ///
    /// Injected at the root for the same reason as `tftAssetCatalog`: the
    /// views that draw items are several layers deep and only know display
    /// names.
    func tftItemRecipes(_ index: ItemRecipeIndex) -> some View {
        environment(\.tftItemRecipes, index)
    }

    /// Convenience for the common case: recipes from the loaded data store,
    /// so a set rotation reaches the panel through the live feed rather than
    /// waiting for the bundled pack to be recaptured.
    func tftItemRecipes(store: TFTDataStore) -> some View {
        environment(\.tftItemRecipes, ItemRecipeIndex(store: store))
    }
}
