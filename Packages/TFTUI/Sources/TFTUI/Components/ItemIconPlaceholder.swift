import SwiftUI
import TFTData

/// An item icon: the real art when it's available, initials on a bordered
/// tile when it isn't.
///
/// See `UnitPortraitPlaceholder` for why the initials tile is a guaranteed
/// rendering rather than a loading state, and why the art URL is resolved
/// from the `tftAssetCatalog` environment by name.
public struct ItemIconPlaceholder: View {
    let name: String
    let size: CGFloat
    let explicitImageURL: URL?

    @Environment(\.tftAssetCatalog) private var catalog
    @Environment(\.tftItemRecipes) private var recipes

    public init(name: String, size: CGFloat = 32, imageURL: URL? = nil) {
        self.name = name
        self.size = size
        explicitImageURL = imageURL
    }

    public init(_ item: Item, size: CGFloat = 32) {
        self.init(name: item.name, size: size, imageURL: item.imageURL)
    }

    public var body: some View {
        ZStack {
            AssetImage(url: explicitImageURL ?? catalog.itemImageURL(named: name), cornerRadius: cornerRadius) {
                abbreviationTile
            }
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(TFTTheme.accent.opacity(0.55), lineWidth: 1.5)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        // Every item icon in the app, rather than the ~14 call sites, so none
        // of them can forget and the 11-20pt roster icons — too small for
        // inline component art — answer the question too (#111).
        .itemRecipeTooltipOnHover(name, recipe: recipes.recipe(forItemNamed: name))
    }

    private var cornerRadius: CGFloat {
        size * 0.16
    }

    private var abbreviationTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(TFTTheme.elevatedBackground)
            Text(abbreviation)
                .font(.system(size: size * 0.3, weight: .heavy, design: .rounded))
                .foregroundStyle(TFTTheme.textPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(2)
        }
    }

    private var abbreviation: String {
        let words = name.split(separator: " ").filter { $0.first?.isLetter == true }
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

#Preview {
    HStack {
        ItemIconPlaceholder(name: "Infinity Edge", size: 44)
        ItemIconPlaceholder(name: "B.F. Sword", size: 44)
    }
    .padding()
    .background(TFTTheme.background)
}
