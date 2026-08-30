import SwiftUI

/// Cell geometry for `CompRosterGrid`, split out so the sizing maths is
/// checkable without rendering: every cell in a grid must be the same width
/// or the columns stagger, and the item strip is wider than the portrait it
/// sits under.
public struct CompRosterMetrics: Hashable, Sendable {
    public let portrait: CGFloat
    public let itemSpacing: CGFloat

    public init(portrait: CGFloat, itemSpacing: CGFloat = 1) {
        self.portrait = portrait
        self.itemSpacing = itemSpacing
    }

    /// Deliberately not `portrait / 3`: at that size the item art is a
    /// smudge. Slightly overrunning the portrait's width buys icons that
    /// actually read, which is the whole point of showing them inline.
    public var itemIcon: CGFloat {
        (portrait * 0.38).rounded()
    }

    public var itemRowWidth: CGFloat {
        itemIcon * CGFloat(CompRosterEntry.itemsPerUnit)
            + itemSpacing * CGFloat(CompRosterEntry.itemsPerUnit - 1)
    }

    public var cellWidth: CGFloat {
        max(portrait, itemRowWidth)
    }

    public var nameFontSize: CGFloat {
        max(9, (portrait * 0.22).rounded())
    }
}

/// Solves the portrait size that lets a whole roster sit on exactly one
/// line, for the compact overlay strip.
///
/// Pure arithmetic so the fit is testable without rendering, same as
/// `RecipeGridMetrics`. Clamped at both ends: below the minimum the art
/// stops being recognisable, above the maximum a short roster would render
/// absurdly large portraits.
public enum CompRosterStripFit {
    public static let minimumPortrait: CGFloat = 22
    public static let maximumPortrait: CGFloat = 52

    public static func portraitSize(
        availableWidth: CGFloat,
        unitCount: Int,
        spacing: CGFloat = 3
    ) -> CGFloat {
        guard unitCount > 0 else { return maximumPortrait }
        let gaps = CGFloat(unitCount - 1) * spacing
        let solved = (availableWidth - gaps) / CGFloat(unitCount)
        // The cell is as wide as its item strip when that is wider than the
        // portrait, so solve against the cell and invert.
        let cellToPortrait = CompRosterMetrics(portrait: 100).cellWidth / 100
        return min(max((solved / cellToPortrait).rounded(.down), minimumPortrait), maximumPortrait)
    }
}

/// A comp's whole roster as champion art, with each itemised carry's items
/// stacked directly under its portrait.
///
/// This is the shape every popular TFT tool converged on, and for a good
/// reason: mid-game the two questions are "what do I buy" and "what do I
/// slam", and both are answered by looking at one strip. Putting items in a
/// separate section (or behind a hover) means the answer is a scroll or a
/// mouse-move away at exactly the moment there is no time for either.
///
/// Wraps rather than scrolls, so a narrowed overlay panel reflows instead of
/// hiding the back half of the roster off the right edge.
public struct CompRosterGrid: View {
    /// How the roster arranges itself.
    public enum Layout {
        /// Wraps onto as many rows as it needs. The expanded panel.
        case wrapping
        /// Exactly one row, never wrapping — the compact strip, where the
        /// whole point is a single glanceable line. Size portraits with
        /// `CompRosterStripFit` so they actually fit.
        case singleLine
    }

    private let entries: [CompRosterEntry]
    private let metrics: CompRosterMetrics
    private let showsNames: Bool
    private let spacing: CGFloat
    private let layout: Layout

    public init(
        comp: Comp,
        portraitSize: CGFloat = 44,
        showsNames: Bool = false,
        spacing: CGFloat = 6,
        layout: Layout = .wrapping
    ) {
        self.init(
            entries: CompRoster.entries(for: comp),
            portraitSize: portraitSize,
            showsNames: showsNames,
            spacing: spacing,
            layout: layout
        )
    }

    public init(
        entries: [CompRosterEntry],
        portraitSize: CGFloat = 44,
        showsNames: Bool = false,
        spacing: CGFloat = 6,
        layout: Layout = .wrapping
    ) {
        self.entries = entries
        metrics = CompRosterMetrics(portrait: portraitSize)
        self.showsNames = showsNames
        self.spacing = spacing
        self.layout = layout
    }

    public var body: some View {
        switch layout {
        case .wrapping: wrappingBody
        case .singleLine: singleLineBody
        }
    }

    private var singleLineBody: some View {
        HStack(alignment: .top, spacing: spacing) {
            ForEach(entries) { entry in
                cell(entry)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cell(_ entry: CompRosterEntry) -> some View {
        RosterCell(
            entry: entry,
            metrics: metrics,
            showsNames: showsNames,
            alignsNamesBelowItems: showsNames && hasAnyItems
        )
    }

    private var wrappingBody: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: metrics.cellWidth), spacing: spacing, alignment: .top)],
            alignment: .leading,
            spacing: spacing + 2
        ) {
            // Only reserves item-row height when something in this roster
            // actually has items; otherwise every cell would carry a strip
            // of dead space for a row that never appears.
            ForEach(entries) { entry in
                cell(entry)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var hasAnyItems: Bool {
        entries.contains(where: \.isCarry)
    }
}

private struct RosterCell: View {
    let entry: CompRosterEntry
    let metrics: CompRosterMetrics
    let showsNames: Bool
    let alignsNamesBelowItems: Bool

    var body: some View {
        VStack(spacing: 3) {
            portrait
            if entry.items.isEmpty == false {
                itemRow
            } else if alignsNamesBelowItems {
                // Empty space, not empty item slots: a non-carry has no
                // items to show, but its name should still sit on the same
                // line as its neighbours'.
                Color.clear.frame(height: metrics.itemIcon)
            }
            if showsNames {
                Text(entry.unit.name)
                    .font(.system(size: metrics.nameFontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(entry.isCarry ? TFTTheme.textPrimary : TFTTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: metrics.cellWidth)
            }
        }
        .frame(width: metrics.cellWidth)
        .contentShape(Rectangle())
        .unitItemTooltipOnHover(summary)
    }

    private var portrait: some View {
        UnitPortraitPlaceholder(name: entry.unit.name, cost: entry.unit.cost, size: metrics.portrait)
            // Drawn outside the portrait's bounds so a carry ring never
            // changes the cell's width and stagger the grid columns.
            .overlay {
                if entry.isCarry {
                    RoundedRectangle(cornerRadius: metrics.portrait * 0.28, style: .continuous)
                        .strokeBorder(TFTTheme.accent, lineWidth: 1.5)
                        .padding(-2.5)
                }
            }
            .overlay(alignment: .topLeading) {
                if entry.unit.flex {
                    Text("F")
                        .font(.system(size: max(8, metrics.portrait * 0.2), weight: .heavy, design: .rounded))
                        .foregroundStyle(TFTTheme.textPrimary)
                        .padding(.horizontal, 2)
                        .background(TFTTheme.elevatedBackground.opacity(0.9), in: Capsule())
                        .padding(1)
                        .help("Flexible slot — swap this unit out freely")
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if let badge = starBadge {
                    Text(badge)
                        .font(.system(size: max(8, metrics.portrait * 0.2), weight: .heavy, design: .rounded))
                        .foregroundStyle(.black.opacity(0.9))
                        .padding(.horizontal, 2)
                        .background(TFTTheme.accent, in: Capsule())
                        .padding(1)
                }
            }
    }

    private var itemRow: some View {
        HStack(spacing: metrics.itemSpacing) {
            ForEach(Array(entry.items.enumerated()), id: \.offset) { _, item in
                ItemIconPlaceholder(name: item, size: metrics.itemIcon)
            }
        }
        .help(entry.allItems.joined(separator: " · "))
    }

    /// Two-star is the default every unit is assumed to reach, so labelling
    /// it adds noise to every cell; one-star (a five-cost you cannot pair)
    /// and three-star (a reroll target) are the ones worth calling out.
    private var starBadge: String? {
        entry.unit.starTarget == 2 ? nil : "\(entry.unit.starTarget)★"
    }

    private var summary: UnitItemSummary {
        UnitItemSummary(
            name: entry.unit.name,
            cost: entry.unit.cost,
            role: entry.unit.role,
            starTarget: entry.unit.starTarget,
            itemPriority: entry.allItems
        )
    }
}

#Preview {
    let comps = (try? CompLoader.bundledFixtures()) ?? []
    return VStack(alignment: .leading, spacing: 20) {
        if let comp = comps.first {
            Text("List row — 34pt, no names")
                .font(.caption).foregroundStyle(TFTTheme.textSecondary)
            CompRosterGrid(comp: comp, portraitSize: 34)
            Text("Compact build — 44pt, names")
                .font(.caption).foregroundStyle(TFTTheme.textSecondary)
            CompRosterGrid(comp: comp, portraitSize: 44, showsNames: true)
            Text("Detail — 56pt, names")
                .font(.caption).foregroundStyle(TFTTheme.textSecondary)
            CompRosterGrid(comp: comp, portraitSize: 56, showsNames: true)
        }
    }
    .padding(16)
    .frame(width: 420)
    .background(TFTTheme.background)
}
