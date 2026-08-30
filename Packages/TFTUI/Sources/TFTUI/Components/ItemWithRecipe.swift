import SwiftUI

/// A completed item and what it is built from (#111).
///
/// The build surfaces used to show only the finished item, which answers
/// "what does this carry want" and not "what do I make with the Bow and the
/// Rod in my bench". The completed item stays the headline — it is the
/// bigger icon and the thing the eye lands on — and the components sit under
/// it as support, at a size that still reads as two distinct items when
/// there is no art and both fall back to initials.
///
/// A single view for every surface so the pairing reads identically in the
/// detail cards, the mid band and the hover card; only the sizes differ.
struct ItemWithRecipe: View {
    let name: String
    /// The completed item's icon size. The surface's existing size — this
    /// view is a drop-in for `ItemIconPlaceholder` at the same size.
    let size: CGFloat
    /// The component icons' size. Smaller than `size` so the completed item
    /// keeps the emphasis, but not so small that the initials tile — the
    /// guaranteed rendering when art hasn't loaded — becomes a smudge.
    let componentSize: CGFloat

    @Environment(\.tftItemRecipes) private var recipes

    var recipe: ItemRecipeIndex.Recipe {
        recipes.recipe(forItemNamed: name)
    }

    var body: some View {
        VStack(spacing: 3) {
            ItemIconPlaceholder(name: name, size: size)
            recipeRow
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    /// Internal rather than private so the layout tests can measure and
    /// rasterise the recipe on its own — the pair has to read as a pair with
    /// no art at all, and that is a question about these pixels, not the
    /// column's.
    @ViewBuilder
    var recipeRow: some View {
        switch recipe {
        case let .components(first, second):
            HStack(spacing: 2) {
                ItemIconPlaceholder(name: first.name, size: componentSize)
                Text("+")
                    .font(.system(size: componentSize * 0.42, weight: .bold, design: .rounded))
                    .foregroundStyle(TFTTheme.textTertiary)
                ItemIconPlaceholder(name: second.name, size: componentSize)
            }
        case .notCraftable:
            // Said out loud rather than left as two empty slots: a blank pair
            // reads as missing data and sends the player hunting for
            // components this item does not have.
            Text("ARTIFACT")
                .font(.system(size: max(7, componentSize * 0.36), weight: .heavy, design: .rounded))
                .foregroundStyle(TFTTheme.textTertiary)
                .lineLimit(1)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(TFTTheme.elevatedBackground, in: Capsule())
        case .unknown:
            // Nothing. The index not knowing an item is not evidence the item
            // cannot be built, so there is nothing honest to draw.
            EmptyView()
        }
    }

    /// The recipe is support, and a screen reader gets it in one utterance
    /// rather than as three unlabelled icons.
    var accessibilityLabel: String {
        switch recipe {
        case let .components(first, second):
            "\(name), built from \(first.name) and \(second.name)"
        case .notCraftable:
            "\(name), an artifact — not craftable from components"
        case .unknown:
            name
        }
    }
}

#Preview {
    HStack(alignment: .top, spacing: 12) {
        ItemWithRecipe(name: "Infinity Edge", size: 36, componentSize: 24)
        ItemWithRecipe(name: "Deathblade", size: 36, componentSize: 24)
        ItemWithRecipe(name: "Rapid Firecannon", size: 36, componentSize: 24)
        ItemWithRecipe(name: "Executioner Emblem", size: 36, componentSize: 24)
    }
    .padding()
    .background(TFTTheme.background)
}
