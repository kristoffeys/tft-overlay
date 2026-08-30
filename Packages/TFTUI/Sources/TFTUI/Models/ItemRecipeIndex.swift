import TFTData

/// Name-keyed lookup from an item name a comp was authored with ("Infinity
/// Edge") to the two components it is built from (#111).
///
/// The views that show a build hold item *names*, not `Item` values —
/// `CompCarry.itemPriority` is `[String]`, authored by hand against display
/// names — while `RecipeMatrix` answers recipes for `Item`s. This is the
/// bridge, and it exists for the same reason `TFTAssetCatalog` does: so an
/// icon or a recipe can appear without threading a data store through every
/// view signature.
///
/// Recipes are not re-derived here. `RecipeMatrix.recipe(for:)` does that
/// work; this type only resolves a name to the `Item` to ask about, and
/// distinguishes the three answers a view has to draw differently.
public struct ItemRecipeIndex: Sendable {
    /// What the index can say about an item name.
    ///
    /// The distinction between `.notCraftable` and `.unknown` is the whole
    /// point of the enum: Set 18 ships `Rapid Firecannon` and `Statikk Shiv`
    /// as artifacts with no recipe at all, and a player shown two blank
    /// slots for those goes hunting for components that do not exist. An
    /// item this index has simply never heard of is a different situation —
    /// the honest rendering there is nothing, not a claim of uncraftability.
    public enum Recipe: Equatable, Sendable {
        /// Built from these two components, in the set's own order.
        ///
        /// A component here is not necessarily one of the eight standard
        /// ones: `Executioner Emblem` is Frying Pan + Sparring Gloves, and
        /// Frying Pan is not in the standard pool.
        case components(Item, Item)
        /// Known item, no two-component build — an artifact, radiant or
        /// anything else the set hands out whole.
        case notCraftable
        /// Not in this index at all. Say nothing.
        case unknown
    }

    /// The index that knows nothing, so a view hierarchy can opt out of
    /// recipes entirely (previews, tests that measure the pre-#111 layout).
    public static let empty = ItemRecipeIndex(items: [])

    /// The 8 components and 36 completed items of the standard pool.
    ///
    /// Enough for almost every carry item in the corpus, but it has never
    /// heard of an artifact or an emblem, so those come back `.unknown`
    /// rather than labelled.
    public static let standard = ItemRecipeIndex(items: StandardItems.components + StandardItems.completedItems)

    /// Every item in the bundled set snapshot — the environment default.
    ///
    /// Deliberately not `.empty` (which is what `TFTAssetCatalog` defaults
    /// to): art is a genuinely optional enhancement that arrives with a
    /// network fetch, while a recipe is static set data the package already
    /// ships, and the whole point of the bundled pack is that first launch
    /// with no network still shows real data. Defaulting to it also means
    /// the snapshot height guards measure the layout the player actually
    /// gets, instead of a shorter one no build ever renders.
    ///
    /// Falls back to `.standard` if the bundled resource cannot be read, so
    /// the common items keep their recipes even then.
    public static let bundled: ItemRecipeIndex = {
        guard let envelope = BundledFallbackData().load() else { return .standard }
        return ItemRecipeIndex(items: envelope.items)
    }()

    private let matrix: RecipeMatrix
    private let itemsByName: [String: Item]

    /// - Parameter items: every item recipes may be asked about, components
    ///   included. Both roles come from one list because the set data makes
    ///   no structural distinction — Frying Pan is a component of
    ///   `Executioner Emblem` and an item in its own right in the same feed.
    public init(items: [Item]) {
        // `RecipeMatrix` is handed the same list twice on purpose: its
        // `components` argument is what `recipe(for:)` resolves component ids
        // against, and restricting that to the standard eight would drop
        // every recipe naming a non-standard component. The pair index it
        // also builds is unused here.
        matrix = RecipeMatrix(components: items, completedItems: items)
        itemsByName = Self.keyed(items)
    }

    public init(store: TFTDataStore) {
        self.init(items: store.items)
    }

    public func recipe(forItemNamed name: String) -> Recipe {
        guard let item = itemsByName[TFTNameKey.normalize(name)] else { return .unknown }
        guard let pair = matrix.recipe(for: item) else { return .notCraftable }
        return .components(pair.0, pair.1)
    }

    /// Keys on `TFTNameKey` for the reasons documented there — Community
    /// Dragon's punctuation does not match what comps are authored with.
    ///
    /// On a collision the craftable entry wins, then the lowest id: the live
    /// set carries exactly one collision (`Flora Fatalis Emblem` also ships
    /// as an augment-granted copy), and if a future one ever pairs a
    /// craftable item with an uncraftable namesake, the recipe is the more
    /// useful of the two answers.
    private static func keyed(_ items: [Item]) -> [String: Item] {
        items.sorted { $0.id < $1.id }.reduce(into: [:]) { result, item in
            let key = TFTNameKey.normalize(item.name)
            guard let existing = result[key] else {
                result[key] = item
                return
            }
            if existing.componentIDs.count != 2, item.componentIDs.count == 2 {
                result[key] = item
            }
        }
    }
}
