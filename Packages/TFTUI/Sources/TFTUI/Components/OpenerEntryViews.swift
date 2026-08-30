import SwiftUI

// The row and tile views the openers panel (#85) is assembled from.
//
// Split out of `OpenersView` so neither file becomes the kind of
// thousand-line view file nobody can navigate; they are internal rather
// than private for that reason alone and have no other caller.

/// A cost label that says the number out loud, as a pill beside a name.
///
/// The openers panel had no cost anywhere on it, which is how it came to
/// surface six cost-3 units without anyone noticing (#99). The portrait's
/// cost-coloured border is a cue for players who already know the colours;
/// this is the same fact in a form that needs no prior knowledge, because
/// "can I actually buy this at level 4" is the whole question the panel
/// answers.
///
/// Distinct from `UnitCostBadge`, which draws the bare number as an overlay
/// on a portrait for the Stage Companion's roster (#107). That one is a cue
/// next to art the reader is already looking at; this one sits inline in a
/// text row, so it spells out "1-cost" rather than leaving a lone digit to
/// be mistaken for one of the counts elsewhere on the row.
struct UnitCostPill: View {
    let cost: Int

    var body: some View {
        Text("\(cost)-cost")
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .foregroundStyle(.black.opacity(0.85))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(TFTTheme.costColor(cost), in: Capsule())
            .lineLimit(1)
            .fixedSize()
            .accessibilityLabel("Cost \(cost)")
    }
}

/// A meta pickup: portrait, name, its cost, a bar for its opener score, and
/// the comps it leads into.
struct MetaPickupRow: View {
    let unit: OpenerIndex.UnitPresence
    let maximumScore: Int
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
                    UnitCostPill(cost: unit.cost)
                    Spacer(minLength: 6)
                    scoreBar
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

    /// The bar is the ranking. The text beside it is a different, plain fact
    /// — never the other way round (issue #108 review).
    ///
    /// Before this, the bar drew from `openerScore` while the adjacent digit
    /// was `topTierRosterCount`, bold and the same accent colour as the bar
    /// fill. The two numbers order differently — `openerScore` also weights
    /// how much of a comp's early roster a unit *is*, so a unit that is one
    /// comp's entire opening board can outscore one that merely appears on
    /// more boards — and drawing them with equal visual weight, immediately
    /// adjacent, read as "the digit is what the bar measures". It is not,
    /// and a reader has no way to tell that from the two side by side.
    ///
    /// The fix is the pairing, not the ranking: the bar keeps drawing from
    /// `openerScore` (so it falls monotonically down the list — see
    /// `fraction`, pinned by `OpenerEntryViewsTests`), and the text beside it
    /// is now the *share* itself — how many of the comps this unit opens are
    /// S/A tier, out of every comp, any tier, it opens — in small, muted
    /// type that cannot be mistaken for the bar's own value. Shown plainly
    /// rather than behind hover (#83); `.help()` below is a bonus for a
    /// mouse, not the only copy of this fact.
    private var scoreBar: some View {
        HStack(spacing: 6) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(TFTTheme.elevatedBackground)
                    Capsule()
                        .fill(TFTTheme.accent)
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .frame(width: 44, height: 6)
            Text("\(unit.topTierRosterCount) of \(unit.sharedCompCount)")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(TFTTheme.textTertiary)
                .lineLimit(1)
                .fixedSize()
        }
        .help("\(unit.name) — cost \(unit.cost), opens \(unit.topTierRosterCount) S/A comps "
            + "of \(unit.sharedCompCount) it opens at any tier")
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Rank bar. Opens \(unit.topTierRosterCount) of \(unit.sharedCompCount) comps "
                + "it opens as an S or A tier pick"
        )
    }

    /// Fraction of the top opener's own score this bar draws.
    ///
    /// Driven by `openerScore` — the same value `OpenerIndex.topOpeners` is
    /// sorted by — and by nothing else, so a bar in this row can never be
    /// longer than the bar above it. Internal rather than private so
    /// `OpenerEntryViewsTests` can assert that property across a real ranked
    /// list without rendering a single pixel.
    var fraction: CGFloat {
        guard maximumScore > 0 else { return 0 }
        return CGFloat(unit.openerScore) / CGFloat(maximumScore)
    }
}

/// A flexible unit: portrait carrying its cost and its comp count, name
/// below, and the tier spread of the comps it opens.
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
                .overlay(alignment: .topLeading) {
                    Text("\(unit.cost)")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundStyle(.black.opacity(0.85))
                        .padding(.horizontal, 3)
                        .background(TFTTheme.costColor(unit.cost), in: Capsule())
                        .padding(1)
                        .accessibilityLabel("Cost \(unit.cost)")
                }
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
            tierSpread
        }
        .frame(width: Self.width)
        .help("\(unit.name) — cost \(unit.cost), opens: \(leadsTo.map(\.name).joined(separator: ", "))")
    }

    /// The tier spread of the comps this unit opens, as counted tier
    /// letters: `3S 1A`.
    ///
    /// This was a row of small coloured dots (#97). A dot row conveys
    /// nothing without a legend the panel does not have room for, and it
    /// spent one dot per comp on units that open a dozen — eight
    /// indistinguishable pips. Letters carry the same fact in a form that
    /// needs no legend at all, because the tier badges in the comps list and
    /// on every capsule beside them already teach the S/A/B/C/D vocabulary;
    /// counting them collapses twelve marks into two tokens that also say
    /// *how many*, which the dots never did.
    private var tierSpread: some View {
        HStack(spacing: 4) {
            ForEach(tierCounts, id: \.tier) { entry in
                Text("\(entry.count)\(entry.tier.rawValue)")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundStyle(TFTTheme.tierColor(entry.tier))
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(height: 11)
        .accessibilityLabel(
            tierCounts.map { "\($0.count) \($0.tier.rawValue) tier" }.joined(separator: ", ")
        )
    }

    private struct TierCount: Hashable {
        let tier: Comp.Tier
        let count: Int
    }

    /// Best tier first, and only tiers actually present — an empty column
    /// for a tier nothing here uses would be four dead glyphs in a 62pt
    /// tile.
    private var tierCounts: [TierCount] {
        Dictionary(grouping: leadsTo, by: \.tier)
            .map { TierCount(tier: $0.key, count: $0.value.count) }
            .sorted { $0.tier < $1.tier }
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
///
/// How many names are shown is **measured, not fixed**. A fixed three did not
/// fit: on the real corpus at the 460pt panel the widest three leads want
/// 384pt of a 376pt column, so `Coven Spellweavers` rendered as
/// `Coven Spellweav…`, and at the 300pt window minimum `Coven Invokers` and
/// `Coven Spellweavers` both collapsed to `Cove…`. The only recovery was the
/// per-capsule `.help()`, and hover never fires while the overlay is locked
/// for click-through (#83) — so the truncation was, in the mode this panel is
/// actually used in, unrecoverable.
///
/// `CompLeadLayout` now fits whole names to the real available width and the
/// remainder becomes a drawn `+N`. Fewer names at narrower widths, but every
/// name shown is readable without a mouse, which is the only version of this
/// row that does the job it exists for.
struct CompLeadRow: View {
    let leadsTo: [OpenerIndex.CompSummary]
    let onSelectComp: (OpenerIndex.CompSummary) -> Void

    /// One line. The row sits in a list beside a 34pt portrait and a presence
    /// bar; flowing onto a second line fits four to six capsules at 460pt,
    /// which stops reading as "a few builds this leads into" and starts
    /// reading as a wall. Width, not a count, decides how many of those fit.
    private static let maxLines = 1
    private static let spacing: CGFloat = 4

    var body: some View {
        if leadsTo.isEmpty {
            Text("No comp in this list uses it")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(TFTTheme.textTertiary)
        } else {
            GeometryReader { proxy in
                let fit = CompLeadLayout.fit(
                    leadsTo.map(\.name),
                    availableWidth: proxy.size.width,
                    spacing: Self.spacing,
                    maxLines: Self.maxLines
                )
                VStack(alignment: .leading, spacing: Self.spacing) {
                    ForEach(Array(fit.lines.enumerated()), id: \.offset) { index, line in
                        HStack(spacing: Self.spacing) {
                            ForEach(line, id: \.self) { name in
                                if let comp = leadsTo.first(where: { $0.name == name }) {
                                    capsule(for: comp)
                                }
                            }
                            if index == fit.lines.count - 1, fit.overflow > 0 {
                                overflowCounter(fit.hidden)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    // Not a fall-through case: when the row is too narrow for
                    // even one whole comp name there are no lines to hang the
                    // counter off, and without this the row draws literally
                    // nothing while the unit does lead somewhere.
                    if fit.lines.isEmpty, fit.overflow > 0 {
                        HStack(spacing: Self.spacing) {
                            overflowCounter(fit.hidden)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .frame(width: proxy.size.width, alignment: .leading)
            }
            .frame(height: CompLeadLayout.height(maxLines: Self.maxLines, spacing: Self.spacing))
        }
    }

    /// Internal rather than private so a test can measure the real capsule's
    /// intrinsic width instead of reimplementing its geometry — a duplicate
    /// would drift from this one and stop detecting the truncation it exists
    /// to detect.
    func capsule(for comp: OpenerIndex.CompSummary) -> some View {
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
                    // The layout already guaranteed this name fits, so let it
                    // keep its intrinsic width. Without this SwiftUI would
                    // compress it back to an ellipsis if the measurement were
                    // ever a point out — a silent failure. Overflowing instead
                    // is loud, and the right-margin raster assertions see it.
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(TFTTheme.elevatedBackground, in: Capsule())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .accessibilityLabel("Show \(comp.name)")
    }

    /// The count of leads that did not fit.
    ///
    /// Drawn, not hovered: it is the affordance telling the player this unit
    /// opens more than the row had room for. The tooltip listing them is a
    /// convenience for someone already holding a mouse, never the only route —
    /// the full set is in the comps list.
    private func overflowCounter(_ hidden: [String]) -> some View {
        Text(CompLeadLayout.overflowLabel(hidden.count))
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .foregroundStyle(TFTTheme.textSecondary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .help(hidden.joined(separator: ", "))
            .accessibilityLabel("\(hidden.count) more comps: \(hidden.joined(separator: ", "))")
    }
}
