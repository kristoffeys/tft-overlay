import SwiftUI

/// Hover card for one champion: its item priority in the same visual
/// language as the "Carries & Items" cards, or a plain identity line when
/// the unit isn't an itemised carry.
public struct UnitItemTooltip: View {
    /// Fixed so callers can position the card before it has been laid out.
    static let width: CGFloat = 200

    let summary: UnitItemSummary

    public init(summary: UnitItemSummary) {
        self.summary = summary
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(summary.name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(TFTTheme.textPrimary)
                if let starTarget = summary.starTarget {
                    Text(String(repeating: "★", count: starTarget))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(TFTTheme.accent)
                }
                Spacer(minLength: 0)
                if let role = summary.role {
                    Text(role.rawValue.capitalized)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(TFTTheme.textSecondary)
                }
            }
            if summary.hasItemPriority {
                HStack(alignment: .top, spacing: 6) {
                    ForEach(Array(summary.itemPriority.enumerated()), id: \.offset) { index, itemName in
                        VStack(spacing: 3) {
                            ItemIconPlaceholder(name: itemName, size: 30)
                            Text(UnitItemSummary.priorityLabel(index))
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(TFTTheme.textSecondary)
                        }
                    }
                }
                if let notes = summary.itemNotes {
                    Text(notes)
                        .font(.system(size: 11))
                        .foregroundStyle(TFTTheme.textSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("No item priority set")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(TFTTheme.textSecondary)
            }
        }
        .padding(10)
        .frame(width: Self.width, alignment: .leading)
        .background(
            TFTTheme.elevatedBackground,
            in: RoundedRectangle(cornerRadius: TFTTheme.smallCornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: TFTTheme.smallCornerRadius, style: .continuous)
                .strokeBorder(TFTTheme.accent.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 8, y: 3)
    }
}

private struct UnitItemTooltipOnHover: ViewModifier {
    let summary: UnitItemSummary

    /// Identifies this view as the card's owner, so moving between two
    /// hoverable cells cannot dismiss the card that just appeared.
    @State private var id = UUID()
    @State private var holder = ScreenFrameHolder()
    /// The card renders in its own window, which starts a fresh environment
    /// — so the asset catalog has to be carried across by hand or every item
    /// in the card falls back to its text tile.
    @Environment(\.tftAssetCatalog) private var catalog

    func body(content: Content) -> some View {
        content
            // Reads this view's screen rect, which is what lets the card be
            // placed in its own window rather than clipped inside this one.
            .background(ScreenFrameProbe(holder: holder))
            .onHover { hovering in
                guard hovering else {
                    FloatingTooltip.shared.hide(owner: id)
                    return
                }
                guard let anchor = holder.screenFrame else { return }
                FloatingTooltip.shared.show(
                    UnitItemTooltip(summary: summary).tftAssetCatalog(catalog),
                    anchor: anchor,
                    owner: id
                )
            }
            .onDisappear { FloatingTooltip.shared.hide(owner: id) }
    }
}

extension View {
    /// Shows `summary` in a hover card above this view. Pass `nil` to opt a
    /// view out entirely rather than branching at the call site.
    func unitItemTooltipOnHover(_ summary: UnitItemSummary?) -> some View {
        modifier(OptionalTooltipModifier(summary: summary))
    }
}

private struct OptionalTooltipModifier: ViewModifier {
    let summary: UnitItemSummary?

    func body(content: Content) -> some View {
        if let summary {
            content.modifier(UnitItemTooltipOnHover(summary: summary))
        } else {
            content
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        UnitItemTooltip(summary: UnitItemSummary(
            name: "Ashe",
            cost: 5,
            role: .carry,
            starTarget: 2,
            itemPriority: ["Infinity Edge", "Giant Slayer", "Runaan's Hurricane"],
            itemNotes: "Runaan's first if the lobby is wide."
        ))
        UnitItemTooltip(summary: UnitItemSummary(name: "Ornn", cost: 4, role: .frontline, starTarget: 2))
    }
    .padding()
    .background(TFTTheme.background)
}
