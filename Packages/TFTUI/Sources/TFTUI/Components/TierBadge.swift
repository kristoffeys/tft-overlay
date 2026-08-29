import SwiftUI

public struct TierBadge: View {
    let tier: Comp.Tier

    public init(_ tier: Comp.Tier) {
        self.tier = tier
    }

    public var body: some View {
        Text(tier.rawValue)
            .font(.system(size: 16, weight: .heavy, design: .rounded))
            .foregroundStyle(.black.opacity(0.85))
            .frame(width: 30, height: 30)
            .background(TFTTheme.tierColor(tier), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

#Preview {
    HStack {
        ForEach(Comp.Tier.allCases, id: \.self) { TierBadge($0) }
    }
    .padding()
    .background(TFTTheme.background)
}
