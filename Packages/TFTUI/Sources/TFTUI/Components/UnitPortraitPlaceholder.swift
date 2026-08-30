import SwiftUI
import TFTData

/// A champion portrait: the real square art when it's available, and a
/// cost-colored tile with the champion's initials when it isn't.
///
/// The name is historical — this started life as art-free scaffolding — but
/// the contract it kept is the point: callers pass a name and a cost and
/// always get something readable back. The initials tile is not a loading
/// state to be replaced, it is the guaranteed rendering for "no network,
/// no cached art, no data store", which is a first-class supported way to
/// run this overlay.
///
/// The art URL is resolved from the `tftAssetCatalog` environment by name,
/// so no call site has to change to gain images; pass `imageURL` explicitly
/// when a caller already holds a `Champion` and can skip the lookup.
public struct UnitPortraitPlaceholder: View {
    let name: String
    let cost: Int
    let size: CGFloat
    let explicitImageURL: URL?

    @Environment(\.tftAssetCatalog) private var catalog

    public init(name: String, cost: Int, size: CGFloat = 40, imageURL: URL? = nil) {
        self.name = name
        self.cost = cost
        self.size = size
        explicitImageURL = imageURL
    }

    public init(_ champion: Champion, size: CGFloat = 40) {
        self.init(name: champion.name, cost: champion.cost, size: size, imageURL: champion.imageURL)
    }

    public var body: some View {
        ZStack {
            AssetImage(url: explicitImageURL ?? catalog.championImageURL(named: name), cornerRadius: cornerRadius) {
                initialsTile
            }
            // Drawn over the art, not under it: the cost color is how the
            // overlay communicates cost at a glance, and Riot's portraits
            // carry no cost cue of their own.
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(TFTTheme.costColor(cost), lineWidth: 2)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.black.opacity(0.55), lineWidth: 0.5)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var cornerRadius: CGFloat {
        size * 0.22
    }

    private var initialsTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(TFTTheme.costColor(cost))
            Text(initials)
                .font(.system(size: size * 0.34, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return String(letters).uppercased()
    }
}

#Preview {
    HStack {
        ForEach(1 ... 5, id: \.self) { UnitPortraitPlaceholder(name: "Ashe", cost: $0) }
    }
    .padding()
    .background(TFTTheme.background)
}
