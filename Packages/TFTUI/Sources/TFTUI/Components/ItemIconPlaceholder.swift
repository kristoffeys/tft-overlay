import SwiftUI
import TFTData

/// Stand-in for an item icon: initials on a bordered tile. Swap for real
/// art without touching call sites.
public struct ItemIconPlaceholder: View {
    let name: String
    let size: CGFloat

    public init(name: String, size: CGFloat = 32) {
        self.name = name
        self.size = size
    }

    public init(_ item: Item, size: CGFloat = 32) {
        self.init(name: item.name, size: size)
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                .fill(TFTTheme.elevatedBackground)
            RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                .strokeBorder(TFTTheme.accent.opacity(0.55), lineWidth: 1.5)
            Text(abbreviation)
                .font(.system(size: size * 0.3, weight: .heavy, design: .rounded))
                .foregroundStyle(TFTTheme.textPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(2)
        }
        .frame(width: size, height: size)
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
