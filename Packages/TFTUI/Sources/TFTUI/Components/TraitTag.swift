import SwiftUI

public struct TraitTag: View {
    let name: String

    public init(_ name: String) {
        self.name = name
    }

    public var body: some View {
        Text(name)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(TFTTheme.textPrimary)
            // A tag must never wrap mid-word: the overlay is read in peripheral
            // vision, so "Execution / er" is worse than not showing the tag at all.
            // TraitTagRow decides what fits; this just refuses to be compressed.
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(TFTTheme.elevatedBackground, in: Capsule())
    }
}

#Preview {
    HStack {
        TraitTag("Hunter")
        TraitTag("Riftbeast")
    }
    .padding()
    .background(TFTTheme.background)
}
