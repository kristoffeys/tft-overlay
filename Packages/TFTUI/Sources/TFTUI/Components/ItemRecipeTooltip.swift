import SwiftUI
import TFTData

/// Hover card for one item: what it is built from, as art *plus names*.
///
/// Names, not just icons, because the initials tile is a supported rendering
/// — it is what shows before any art loads and forever if the asset mirror is
/// unreachable — and "BF" is not a recipe. The inline recipes elsewhere can
/// stay iconic because they sit under the item they belong to; a card that
/// exists only to answer "what is this made of" has room to spell it out.
///
/// Attached to `ItemIconPlaceholder` itself rather than to call sites, so
/// every item icon in the app answers the question and no future one can
/// forget to. That includes the roster grid's 11-20pt icons, which are far
/// too small to carry inline component art — hover is the only form a recipe
/// can take there.
struct ItemRecipeTooltip: View {
    /// Fixed so `FloatingTooltip` can place the card before it is laid out,
    /// and wide enough for the longest component name in the set
    /// ("Needlessly Large Rod") on one line beside its icon.
    static let width: CGFloat = 220

    /// Whether an item with this recipe gets a card at all.
    ///
    /// A named predicate rather than a condition inline in the modifier, so
    /// the "no card for an item we know nothing about" rule is a value a test
    /// can assert on instead of a branch inside a `ViewModifier`.
    static func shows(_ recipe: ItemRecipeIndex.Recipe) -> Bool {
        recipe != .unknown
    }

    let name: String
    let recipe: ItemRecipeIndex.Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ItemIconPlaceholder(name: name, size: 28)
                Text(name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(TFTTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            switch recipe {
            case let .components(first, second):
                Text("Built from".uppercased())
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundStyle(TFTTheme.accent)
                VStack(alignment: .leading, spacing: 5) {
                    componentRow(first)
                    componentRow(second)
                }
            case .notCraftable:
                Text("Artifact — not craftable from components.")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(TFTTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            case .unknown:
                // `itemRecipeTooltipOnHover` never summons a card for this,
                // so it is unreachable in the app — handled rather than
                // crashed on, and covered by a test.
                Text("No recipe known for this item.")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(TFTTheme.textSecondary)
            }
        }
        .padding(10)
        .frame(width: Self.width, alignment: .leading)
        .background(
            TFTTheme.elevatedBackground,
            in: RoundedRectangle(cornerRadius: TFTTheme.smallCornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: TFTTheme.smallCornerRadius, style: .continuous)
                .strokeBorder(TFTTheme.accent.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 8, y: 3)
    }

    private func componentRow(_ component: Item) -> some View {
        HStack(spacing: 6) {
            ItemIconPlaceholder(component, size: 24)
            Text(component.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(TFTTheme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

private struct ItemRecipeTooltipOnHover: ViewModifier {
    let name: String
    let recipe: ItemRecipeIndex.Recipe

    /// See `UnitItemTooltipOnHover`: the owner id is what stops moving
    /// between two adjacent icons from dismissing the card that just
    /// appeared.
    @State private var id = UUID()
    @State private var holder = ScreenFrameHolder()
    /// The card renders in its own window, which starts a fresh environment,
    /// so the art catalog is carried across by hand or every icon in the card
    /// falls back to its text tile.
    @Environment(\.tftAssetCatalog) private var catalog

    func body(content: Content) -> some View {
        content
            .background(ScreenFrameProbe(holder: holder))
            .onHover { hovering in
                guard hovering else {
                    FloatingTooltip.shared.hide(owner: id)
                    return
                }
                guard let anchor = holder.screenFrame else { return }
                FloatingTooltip.shared.show(
                    ItemRecipeTooltip(name: name, recipe: recipe).tftAssetCatalog(catalog),
                    anchor: anchor,
                    owner: id
                )
            }
            .onDisappear { FloatingTooltip.shared.hide(owner: id) }
    }
}

extension View {
    /// Shows a recipe card for `name` on hover, when there is a recipe to
    /// show.
    ///
    /// An item the index has never heard of gets no card at all: a card
    /// saying nothing is worse than no card, and the index not knowing an
    /// item is not evidence about how it is built.
    ///
    /// Nothing essential may live behind this. A locked panel sets
    /// `ignoresMouseEvents` and receives no hover at all (#83), which is
    /// exactly the state the panel is in mid-fight — so the inline recipes
    /// this complements are the ones that have to be readable then.
    func itemRecipeTooltipOnHover(_ name: String, recipe: ItemRecipeIndex.Recipe) -> some View {
        modifier(OptionalItemRecipeTooltipModifier(name: name, recipe: recipe))
    }
}

private struct OptionalItemRecipeTooltipModifier: ViewModifier {
    let name: String
    let recipe: ItemRecipeIndex.Recipe

    func body(content: Content) -> some View {
        if ItemRecipeTooltip.shows(recipe) {
            content.modifier(ItemRecipeTooltipOnHover(name: name, recipe: recipe))
        } else {
            content
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ItemRecipeTooltip(
            name: "Infinity Edge",
            recipe: ItemRecipeIndex.bundled.recipe(forItemNamed: "Infinity Edge")
        )
        ItemRecipeTooltip(
            name: "Rapid Firecannon",
            recipe: ItemRecipeIndex.bundled.recipe(forItemNamed: "Rapid Firecannon")
        )
    }
    .padding()
    .background(TFTTheme.background)
}
