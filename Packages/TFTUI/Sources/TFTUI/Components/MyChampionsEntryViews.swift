import SwiftUI

// The tile and row views `MyChampionsView` is assembled from (#86, #87).
//
// Split out of the panel so neither file becomes the kind of thousand-line
// view file nobody can navigate; internal rather than private for that
// reason alone.

/// One champion in the picker grid: tap to toggle whether the player has it.
///
/// Owned is the *lit* state — full-opacity art, an accent ring and a
/// checkmark — and unowned is dimmed. Three cues rather than one, because
/// the panel has to answer "did that tap register" from peripheral vision,
/// and colour alone fails that for anyone who cannot separate the accent
/// from the cost border.
struct ChampionPickerTile: View {
    let name: String
    let cost: Int
    let isOwned: Bool
    let onToggle: () -> Void

    /// Seven columns across the 460pt panel's content width, and exactly
    /// five across the 300pt compact panel — below five the picker stops
    /// reading as a grid and becomes a list you scroll to find a 5-cost in.
    static let width: CGFloat = 50
    private static let portrait: CGFloat = 42

    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 3) {
                UnitPortraitPlaceholder(name: name, cost: cost, size: Self.portrait)
                    .overlay {
                        if isOwned {
                            RoundedRectangle(cornerRadius: Self.portrait * 0.28, style: .continuous)
                                .strokeBorder(TFTTheme.accent, lineWidth: 2)
                                .padding(-2)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if isOwned {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .black))
                                .foregroundStyle(.black.opacity(0.85))
                                .padding(2)
                                .background(TFTTheme.accent, in: Circle())
                                .padding(-1)
                        }
                    }
                    .opacity(isOwned ? 1 : 0.45)
                Text(name)
                    .font(.system(size: 9, weight: isOwned ? .heavy : .semibold, design: .rounded))
                    .foregroundStyle(isOwned ? TFTTheme.textPrimary : TFTTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: Self.width)
            }
            .frame(width: Self.width)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .accessibilityLabel(name)
        .accessibilityValue(isOwned ? "Marked" : "Not marked")
        .accessibilityAddTraits(isOwned ? [.isButton, .isSelected] : .isButton)
        .help(name)
    }
}

/// One ranked comp: how much of it the player already has, what is missing by
/// name, and the commit affordance.
///
/// "7/9 — missing Ashe, Kindred" rather than "78%". The named gap is a shop
/// list; a percentage is a number you cannot act on, and would imply a
/// statistic that the authored tier list behind these comps does not have.
struct CompSuggestionRow: View {
    let suggestion: CompSuggestion
    let onCommit: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            TierBadge(suggestion.comp.tier)
            VStack(alignment: .leading, spacing: 6) {
                header
                missingLine
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            TFTTheme.panelBackground,
            in: RoundedRectangle(cornerRadius: TFTTheme.cornerRadius, style: .continuous)
        )
        // A tap gesture, not an outer Button: the row carries its own commit
        // Button, and a Button nested in another Button's label never
        // receives the click (see CompsListView).
        .contentShape(Rectangle())
        .onTapGesture(perform: onCommit)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(suggestion.comp.name)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(TFTTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 6)
            Text("\(suggestion.matchedCount)/\(suggestion.totalCount)")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(TFTTheme.accent)
            commitButton
        }
    }

    /// The commit affordance is drawn, not implied. Tapping the row commits
    /// too, but a tap target with no visible edge is only discoverable by
    /// hovering it — and the overlay is click-through while locked (#83).
    private var commitButton: some View {
        Button(action: onCommit) {
            Text("Build this")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(TFTTheme.accent)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(TFTTheme.elevatedBackground, in: Capsule())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .accessibilityLabel("Build \(suggestion.comp.name)")
        .help("Commit to \(suggestion.comp.name)")
    }

    @ViewBuilder
    private var missingLine: some View {
        if suggestion.missingUnits.isEmpty {
            Text("You have every unit.")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(TFTTheme.accent)
        } else {
            // Wraps onto as many lines as it needs: a comp you are eight
            // units away from has a long list, and truncating it turns the
            // one actionable thing on the row into an ellipsis.
            (
                Text("Missing ").foregroundStyle(TFTTheme.textSecondary)
                    + Text(suggestion.missingUnits.map(\.name).joined(separator: ", "))
                    .foregroundStyle(TFTTheme.textPrimary)
            )
            .font(.system(size: 12, weight: .semibold))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
