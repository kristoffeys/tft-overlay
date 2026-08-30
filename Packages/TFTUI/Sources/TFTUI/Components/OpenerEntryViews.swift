import SwiftUI

// The row and tile views the openers panel (#85) is assembled from.
//
// Split out of `OpenersView` so neither file becomes the kind of
// thousand-line view file nobody can navigate; they are internal rather
// than private for that reason alone and have no other caller.

/// A meta pickup: portrait, name, a bar for its S/A weight, and the comps it
/// leads into.
struct MetaPickupRow: View {
    let unit: OpenerIndex.UnitPresence
    let maximumPresence: Int
    let leadsTo: [OpenerIndex.CompSummary]
    let onSelectComp: (OpenerIndex.CompSummary) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            UnitPortraitPlaceholder(name: unit.name, cost: unit.cost, size: 34)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(unit.name)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(TFTTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 6)
                    presenceBar
                }
                CompLeadRow(leadsTo: leadsTo, onSelectComp: onSelectComp)
            }
        }
        .padding(8)
        .background(
            TFTTheme.panelBackground,
            in: RoundedRectangle(cornerRadius: TFTTheme.smallCornerRadius, style: .continuous)
        )
    }

    /// A bar, not a percentage. The number it draws is a count of weighted
    /// appearances in an authored list; rendering it as "62%" would invent a
    /// precision the corpus does not have.
    private var presenceBar: some View {
        HStack(spacing: 6) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(TFTTheme.elevatedBackground)
                    Capsule()
                        .fill(TFTTheme.accent)
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .frame(width: 56, height: 6)
            Text("\(unit.weightedPresence)")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(TFTTheme.accent)
                .frame(minWidth: 14, alignment: .trailing)
        }
    }

    private var fraction: CGFloat {
        guard maximumPresence > 0 else { return 0 }
        return CGFloat(unit.weightedPresence) / CGFloat(maximumPresence)
    }
}

/// A flexible unit: portrait with its comp count badged onto it, name below.
///
/// A tile rather than a row so this ranking cannot be mistaken for the one
/// above it at a glance.
struct FlexibleUnitTile: View {
    let unit: OpenerIndex.UnitPresence
    let leadsTo: [OpenerIndex.CompSummary]

    /// Six tiles a row at the 460pt panel's content width.
    static let width: CGFloat = 62

    var body: some View {
        VStack(spacing: 3) {
            UnitPortraitPlaceholder(name: unit.name, cost: unit.cost, size: 40)
                .overlay(alignment: .bottomTrailing) {
                    Text("\(unit.sharedCompCount)")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(.black.opacity(0.85))
                        .padding(.horizontal, 4)
                        .background(TFTTheme.accent, in: Capsule())
                        .padding(1)
                }
            Text(unit.name)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(TFTTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: Self.width)
            // The tier spread of the comps it opens, one dot each: three
            // orange dots and one grey says something a bare count cannot.
            tierDots
        }
        .frame(width: Self.width)
        .help(leadsTo.map(\.name).joined(separator: " · "))
    }

    private var tierDots: some View {
        HStack(spacing: 2) {
            ForEach(Array(leadsTo.prefix(8).enumerated()), id: \.offset) { _, comp in
                Circle()
                    .fill(TFTTheme.tierColor(comp.tier))
                    .frame(width: 4, height: 4)
            }
        }
        .frame(height: 4)
    }
}

/// One component and how many S-tier carry builds want it.
///
/// Named, not just iconned. Running with no art at all is a supported way to
/// use this overlay (see `ItemIconPlaceholder`), and in that mode an
/// unlabelled tile is a two-letter abbreviation the player has to decode —
/// which is exactly the half-second this panel does not have.
struct ComponentDemandTile: View {
    let component: OpenerIndex.ComponentDemand

    /// Wide enough for "Recurve Bow" on two 9pt lines; six tiles a row at the
    /// 460pt panel's content width.
    static let width: CGFloat = 66

    var body: some View {
        VStack(spacing: 3) {
            ItemIconPlaceholder(name: component.componentName, size: 32)
                .overlay(alignment: .bottomTrailing) {
                    Text("\(component.demand)")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundStyle(.black.opacity(0.85))
                        .padding(.horizontal, 3)
                        .background(TFTTheme.accent, in: Capsule())
                        .padding(1)
                }
            Text(component.componentName)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(TFTTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .frame(width: Self.width)
        }
        .frame(width: Self.width)
        .help("\(component.componentName) — wanted by \(component.demand) S-tier carry builds")
    }
}

/// The comps an early unit leads into, as tier-coloured capsules.
///
/// Inline and always drawn — this is the bridge out of the panel, and a
/// bridge you have to hover to find is not one (#83).
struct CompLeadRow: View {
    let leadsTo: [OpenerIndex.CompSummary]
    let onSelectComp: (OpenerIndex.CompSummary) -> Void

    /// Three names is what fits the 460pt panel's right column without
    /// truncating any of them; the rest become a count.
    private static let shownLimit = 3

    var body: some View {
        if leadsTo.isEmpty {
            Text("No comp in this list uses it")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(TFTTheme.textTertiary)
        } else {
            HStack(spacing: 4) {
                ForEach(leadsTo.prefix(Self.shownLimit), id: \.id) { comp in
                    Button {
                        onSelectComp(comp)
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(TFTTheme.tierColor(comp.tier))
                                .frame(width: 5, height: 5)
                            Text(comp.name)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(TFTTheme.textPrimary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(TFTTheme.elevatedBackground, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .help(comp.name)
                }
                if leadsTo.count > Self.shownLimit {
                    Text("+\(leadsTo.count - Self.shownLimit)")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(TFTTheme.textSecondary)
                }
                Spacer(minLength: 0)
            }
        }
    }
}
