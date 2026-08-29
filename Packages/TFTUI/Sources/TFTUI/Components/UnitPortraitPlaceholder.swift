import SwiftUI

/// Stand-in for a champion portrait: cost-colored tile with initials.
/// Swap for real art without touching call sites.
public struct UnitPortraitPlaceholder: View {
    let name: String
    let cost: Int
    let size: CGFloat

    public init(name: String, cost: Int, size: CGFloat = 40) {
        self.name = name
        self.cost = cost
        self.size = size
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(TFTTheme.costColor(cost))
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .strokeBorder(Color.black.opacity(0.55), lineWidth: 2)
            Text(initials)
                .font(.system(size: size * 0.34, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
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
