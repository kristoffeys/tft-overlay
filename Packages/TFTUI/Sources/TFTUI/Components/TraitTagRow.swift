import SwiftUI

/// Lays out as many trait tags as fit, with a `+N` counter for the rest.
///
/// Measures against the real available width instead of letting SwiftUI compress
/// the tags, which used to wrap their text mid-word in the narrow overlay panel.
public struct TraitTagRow: View {
    private let traits: [String]
    private let spacing: CGFloat

    public init(_ traits: [String], spacing: CGFloat = 4) {
        self.traits = traits
        self.spacing = spacing
    }

    public var body: some View {
        GeometryReader { proxy in
            let layout = TraitTagLayout.fit(traits, availableWidth: proxy.size.width, spacing: spacing)
            HStack(spacing: spacing) {
                ForEach(layout.shown, id: \.self) { TraitTag($0) }
                if layout.overflow > 0 {
                    TraitTag(TraitTagLayout.overflowLabel(layout.overflow))
                        .help(traits.suffix(layout.overflow).joined(separator: ", "))
                }
            }
            .frame(width: proxy.size.width, alignment: .trailing)
        }
        .frame(height: 20)
    }
}

#Preview {
    VStack(alignment: .trailing, spacing: 8) {
        TraitTagRow(["Brawler", "Defender", "Elderwood", "Executioner"])
            .frame(width: 210)
        TraitTagRow(["Brawler", "Defender", "Elderwood", "Executioner"])
            .frame(width: 400)
    }
    .padding()
    .background(TFTTheme.background)
}
