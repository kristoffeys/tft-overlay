import SwiftUI

/// Like `TraitTagRow`, but each shown tag is a button — for the reference
/// panel's cross-links (trait -> units, unit -> traits), where tapping a
/// chip navigates to that trait or unit.
///
/// Reuses `TraitTagLayout.fit` so it never wraps a tag mid-word: the same
/// fix `TraitTagRow` applies for the same reason.
public struct TappableTraitTagRow: View {
    private let traits: [String]
    private let spacing: CGFloat
    private let onSelect: (String) -> Void

    public init(_ traits: [String], spacing: CGFloat = 4, onSelect: @escaping (String) -> Void) {
        self.traits = traits
        self.spacing = spacing
        self.onSelect = onSelect
    }

    public var body: some View {
        GeometryReader { proxy in
            let layout = TraitTagLayout.fit(traits, availableWidth: proxy.size.width, spacing: spacing)
            HStack(spacing: spacing) {
                ForEach(layout.shown, id: \.self) { trait in
                    Button {
                        onSelect(trait)
                    } label: {
                        TraitTag(trait)
                    }
                    .buttonStyle(.plain)
                }
                if layout.overflow > 0 {
                    TraitTag(TraitTagLayout.overflowLabel(layout.overflow))
                        .help(traits.suffix(layout.overflow).joined(separator: ", "))
                }
            }
            .frame(width: proxy.size.width, alignment: .leading)
        }
        .frame(height: 20)
    }
}

#Preview {
    TappableTraitTagRow(["Brawler", "Defender", "Elderwood", "Executioner"]) { _ in }
        .frame(width: 210)
        .padding()
        .background(TFTTheme.background)
}
