import SwiftUI

/// Like `TraitTagRow`, but each shown tag is a button — for the reference
/// panel's cross-links (trait -> units, unit -> traits), where tapping a
/// chip navigates to that trait or unit.
///
/// Reuses `TraitTagLayout.fit` so it never wraps a tag mid-word: the same
/// fix `TraitTagRow` applies for the same reason. Defaults to two lines,
/// because this lives in a drill-down with vertical room to spare and a
/// trait you cannot see is a trait you cannot tap.
public struct TappableTraitTagRow: View {
    private let traits: [String]
    private let spacing: CGFloat
    private let maxLines: Int
    private let priority: [String: Int]
    private let onSelect: (String) -> Void

    public init(
        _ traits: [String],
        spacing: CGFloat = 4,
        maxLines: Int = 2,
        priority: [String: Int] = [:],
        onSelect: @escaping (String) -> Void
    ) {
        self.traits = traits
        self.spacing = spacing
        self.maxLines = max(1, maxLines)
        self.priority = priority
        self.onSelect = onSelect
    }

    public var body: some View {
        GeometryReader { proxy in
            let layout = TraitTagLayout.fit(
                traits,
                availableWidth: proxy.size.width,
                spacing: spacing,
                maxLines: maxLines,
                priority: priority
            )
            VStack(alignment: .leading, spacing: spacing) {
                ForEach(Array(layout.lines.enumerated()), id: \.offset) { index, line in
                    HStack(spacing: spacing) {
                        ForEach(line, id: \.self) { trait in
                            Button {
                                onSelect(trait)
                            } label: {
                                TraitTag(trait)
                            }
                            .buttonStyle(.plain)
                        }
                        if index == layout.lines.count - 1, layout.overflow > 0 {
                            OverflowTraitTag(hidden: layout.hidden)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(width: proxy.size.width, alignment: .leading)
        }
        .frame(height: TraitTagLayout.height(maxLines: maxLines, spacing: spacing))
    }
}

#Preview {
    TappableTraitTagRow(["Brawler", "Defender", "Elderwood", "Executioner"]) { _ in }
        .frame(width: 210)
        .padding()
        .background(TFTTheme.background)
}
