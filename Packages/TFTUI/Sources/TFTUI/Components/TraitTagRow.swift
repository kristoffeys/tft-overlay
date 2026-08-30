import SwiftUI

/// Lays out trait tags across at most `maxLines` lines, with a `+N` counter
/// for anything that still does not fit.
///
/// Measures against the real available width instead of letting SwiftUI
/// compress the tags, which used to wrap their text mid-word in the narrow
/// overlay panel.
///
/// Pass `priority` (see `TraitRelevance`) so the tags that survive a squeeze
/// are the ones worth reading. Without it the row keeps input order, which in
/// the comps list meant alphabetical order — a guarantee that the *least*
/// relevant trait was the one always on screen.
public struct TraitTagRow: View {
    private let traits: [String]
    private let spacing: CGFloat
    private let maxLines: Int
    private let priority: [String: Int]

    public init(
        _ traits: [String],
        spacing: CGFloat = 4,
        maxLines: Int = 1,
        priority: [String: Int] = [:]
    ) {
        self.traits = traits
        self.spacing = spacing
        self.maxLines = max(1, maxLines)
        self.priority = priority
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
            VStack(alignment: .trailing, spacing: spacing) {
                ForEach(Array(layout.lines.enumerated()), id: \.offset) { index, line in
                    HStack(spacing: spacing) {
                        ForEach(line, id: \.self) { TraitTag($0) }
                        if index == layout.lines.count - 1, layout.overflow > 0 {
                            OverflowTraitTag(hidden: layout.hidden)
                        }
                    }
                }
            }
            .frame(width: proxy.size.width, alignment: .trailing)
        }
        .frame(height: TraitTagLayout.height(maxLines: maxLines, spacing: spacing))
    }
}

/// The "+N" counter for traits that did not fit.
///
/// Tinted rather than styled like a real tag, because it is not a trait — it
/// is a note that N *low-relevance* traits were dropped. The tooltip is a
/// convenience for someone already holding a mouse over the row; it is
/// deliberately not the only way to reach the information, which is why the
/// detail panels flow onto a second line and `CompDetailView` carries the
/// complete "traits at full board" breakdown.
struct OverflowTraitTag: View {
    let hidden: [String]

    var body: some View {
        Text(TraitTagLayout.overflowLabel(hidden.count))
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(TFTTheme.textSecondary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(TFTTheme.elevatedBackground.opacity(0.6), in: Capsule())
            .help(hidden.joined(separator: ", "))
            .accessibilityLabel("\(hidden.count) more traits: \(hidden.joined(separator: ", "))")
    }
}

#Preview {
    VStack(alignment: .trailing, spacing: 8) {
        TraitTagRow(["Brawler", "Defender", "Elderwood", "Executioner"])
            .frame(width: 210)
        TraitTagRow(["Brawler", "Defender", "Elderwood", "Executioner"], maxLines: 2)
            .frame(width: 210)
        TraitTagRow(["Brawler", "Defender", "Elderwood", "Executioner"])
            .frame(width: 400)
    }
    .padding()
    .background(TFTTheme.background)
}
