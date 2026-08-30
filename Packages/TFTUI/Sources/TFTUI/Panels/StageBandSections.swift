import SwiftUI

/// The current band's advice, at full size. One card per kind of thing the
/// band asks the player to do, so nothing needs a hover to be readable —
/// hover only fires on an unlocked panel (#83), and this is the panel meant to
/// be read mid-fight.
struct StageBandDetail: View {
    let section: BuildStagePlan.Section
    let comp: Comp
    let unitIndex: CompUnitIndex

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let opener = section.opener {
                StageCard("Open with") {
                    Text(opener)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(TFTTheme.textPrimary)
                }
            }
            if !section.openerUnits.isEmpty || !section.restOfBuild.isEmpty {
                StageCard("Buy now · open with these") {
                    buyNowCard
                }
            }
            if !section.componentsToHold.isEmpty {
                StageCard("Hold these components") {
                    componentStrip
                }
            }
            if let carry = section.itemisePriority {
                StageCard("Itemise \(carry.unit) first") {
                    itemStrip(carry)
                }
            }
            if !section.levelPlan.isEmpty {
                StageCard("This band's plan") {
                    LevelPlanRows(entries: section.levelPlan)
                }
            }
            if section.showsFinalBoard {
                StageCard("Final board") {
                    BoardGridView(grid: comp.boardPositioning.grid, unitIndex: unitIndex)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            if let pivots = section.pivots {
                StageCard("Pivots") {
                    Text(pivots)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(TFTTheme.textPrimary)
                }
            }
            if section.isEmpty {
                Text("Nothing specific to this band — the plan below still applies.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TFTTheme.textSecondary)
            }
        }
    }

    /// The shopping list, then the rest of the build under it.
    ///
    /// One card, not two, and the openers stay the loud half: the buy-now
    /// answer is what this band exists for, and the roster is there so a
    /// 4-cost rolling through the shop in stage 2 is recognisable (#107).
    ///
    /// Everything here is priced in points, because the band had 65 of them
    /// left before the 594pt above-the-fold budget bit (`elderwood-bloom` at
    /// early measured 529pt of it, with a six-line opener paragraph). What the
    /// whole build would have cost, measured: a second card's chrome 40pt, item
    /// icons under the roster cells 14pt, names under them 10pt, a heading line
    /// above them 13pt. So the roster shares this card; it draws no items — the
    /// components card and the mid band's itemise card already answer that —
    /// and no names, because 30pt art plus a cost number is what recognising a
    /// unit in the shop needs, while the opener half, the half a player acts
    /// on, keeps its names. `elderwood-bloom` lands at 565pt, under the 570pt
    /// its own late band already needed before any of this.
    private var buyNowCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            openerStrip
            if section.openerUnits.contains(where: \.isTransitional) {
                Text("TEMP = an opener that is not in the final build. Buying it is correct; you sell it later.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(TFTTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !section.restOfBuild.isEmpty {
                // The label sits beside the strip rather than above it: a line
                // of its own costs 13pt, and beside it costs none — the roster
                // needs at most six 35pt cells of the 334pt left at the
                // narrowest panel width.
                HStack(alignment: .top, spacing: 6) {
                    Text("REST OF\nTHE BUILD")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundStyle(TFTTheme.textTertiary)
                        .lineSpacing(-1)
                        .frame(width: 56, alignment: .leading)
                    CompRosterGrid(
                        entries: section.restOfBuild,
                        portraitSize: 30,
                        showsNames: false,
                        spacing: 5,
                        showsCosts: true,
                        showsItems: false
                    )
                    // Subordinate to the openers above without hiding anything:
                    // recognition survives a dimmed portrait, and full contrast
                    // on both halves would leave no buy-now answer at all.
                    .opacity(0.75)
                }
            }
        }
    }

    private var openerStrip: some View {
        WrapHStack(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(section.openerUnits) { pick in
                VStack(spacing: 3) {
                    OpenerPortrait(pick: pick, size: 40)
                    Text(pick.name)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(TFTTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if pick.isTransitional {
                        Text("TEMP")
                            .font(.system(size: 8, weight: .heavy, design: .rounded))
                            .foregroundStyle(.black.opacity(0.85))
                            .padding(.horizontal, 3)
                            .background(TFTTheme.accent.opacity(0.8), in: Capsule())
                    }
                }
                .frame(width: 48)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(accessibilityLabel(for: pick))
            }
        }
    }

    private func accessibilityLabel(for pick: BuildStagePlan.OpenerPick) -> String {
        guard let cost = pick.cost else {
            return "\(pick.name), transitional opener, not in the final build"
        }
        return "\(pick.name), \(cost) cost"
    }

    private var componentStrip: some View {
        HStack(spacing: 8) {
            ForEach(section.componentsToHold, id: \.self) { name in
                ItemIconPlaceholder(name: name, size: 34)
            }
            Spacer(minLength: 0)
        }
    }

    /// The itemise card, with each item's components under it (#111).
    ///
    /// This band is height-budgeted — 570pt above the fold, derived in #110 —
    /// so the cost was measured before it was spent: the component row adds
    /// 25pt to this card and nothing to any other, since `itemisePriority` is
    /// only ever set on the mid band. Mid's worst case in the corpus was
    /// 378pt at the narrowest panel width against Late's 570pt, so it can
    /// absorb this and every item keeps its recipe rather than only the BiS
    /// one. `StageCompanionSnapshotTests` holds that.
    ///
    /// Components are 22pt against the item's 34pt: smaller than the detail
    /// panel's 24pt, still large enough for the initials tile that is what
    /// renders before any art loads.
    private func itemStrip(_ carry: CompCarry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(Array(carry.itemPriority.enumerated()), id: \.offset) { index, name in
                VStack(spacing: 3) {
                    ItemWithRecipe(name: name, size: 34, componentSize: 22)
                    Text(index == 0 ? "BiS" : "Alt \(index)")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(index == 0 ? TFTTheme.accent : TFTTheme.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

/// One opener's portrait, with its cost stated when the comp knows it.
///
/// A transitional opener — in `earlyUnits`, in no `units` entry — has no cost
/// here at all, and gets a neutral border instead of one tinted by a cost this
/// comp never authored. `UnitPortraitPlaceholder` takes an `Int`, and every
/// value it could be handed means something: 0 draws the 5-cost gold. So the
/// tint is overdrawn rather than guessed, and the `TEMP` chip under the name
/// carries the meaning.
private struct OpenerPortrait: View {
    let pick: BuildStagePlan.OpenerPick
    let size: CGFloat

    var body: some View {
        UnitPortraitPlaceholder(name: pick.name, cost: pick.cost ?? 0, size: size)
            .overlay {
                if pick.cost == nil {
                    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                        .strokeBorder(TFTTheme.textTertiary, lineWidth: 2)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if let cost = pick.cost {
                    UnitCostBadge(cost: cost, portraitSize: size)
                        .padding(1)
                }
            }
    }
}

/// A band the player is not currently in: still legible, deliberately quieter.
///
/// Not hidden and not collapsed behind a tap. The stage is set by hand, so the
/// realistic worst case is a player who never advances it at all — and for
/// that player this row is the whole rest of the plan. Losing it would make
/// the panel worse than the detail view it replaces, which is the one failure
/// this feature cannot afford.
struct StageBandSummary: View {
    let section: BuildStagePlan.Section
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(section.band.title.uppercased())
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(TFTTheme.textSecondary)
                    Text(section.band.stageSpan)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(TFTTheme.textTertiary)
                    Spacer(minLength: 0)
                    if let target = section.levelTarget {
                        LevelTargetChip(target: target, isProminent: false)
                    }
                }
                if !section.levelPlan.isEmpty {
                    LevelPlanRows(entries: section.levelPlan)
                }
                if let text = section.opener ?? section.pivots {
                    Text(text)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(TFTTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(
                TFTTheme.panelBackground.opacity(0.7),
                in: RoundedRectangle(cornerRadius: TFTTheme.smallCornerRadius, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show \(section.band.title) stage")
    }
}

/// The stage-keyed rows themselves, shared by the expanded band and the
/// de-emphasised ones so a row reads the same wherever it appears.
struct LevelPlanRows: View {
    /// A row paired with the identity the `ForEach` actually uses.
    ///
    /// Position, not `LevelPlanEntry.id`. Banded rows are one per stage and
    /// would be safe either way, but this view also draws the *unplaced* rows —
    /// the ones whose stage string did not parse — and two rows sharing a
    /// mangled string share an id. Duplicate identity inside a `ForEach` is
    /// undefined behaviour by SwiftUI's own documentation: today's macOS
    /// happens to lay both rows out and log a warning, which is precisely why
    /// this cannot be left to be caught by a screenshot later.
    ///
    /// Split out as a named type so the identity is a value a test can assert
    /// on, rather than an expression buried in a view builder.
    struct IdentifiedRow: Identifiable {
        let id: Int
        let entry: LevelPlanEntry
    }

    let entries: [LevelPlanEntry]

    var identifiedRows: [IdentifiedRow] {
        entries.enumerated().map { IdentifiedRow(id: $0.offset, entry: $0.element) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(identifiedRows) { row in
                let entry = row.entry
                HStack(alignment: .top, spacing: 8) {
                    Text(entry.stage)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(.black.opacity(0.85))
                        .frame(width: 38, height: 19)
                        .background(TFTTheme.accent, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Level \(entry.level)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(TFTTheme.textPrimary)
                        if let notes = entry.notes {
                            Text(notes)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(TFTTheme.textSecondary)
                                // Wrap, don't truncate. The row lives in an
                                // `HStack` with a `Spacer`, which offers the
                                // text its one-line ideal width and then
                                // ellipsises whatever did not fit — silently
                                // dropping advice, which is the whole thing
                                // this panel is not allowed to do.
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

/// "Level 8", or "Level 6 from 3-2" when the band inherited it.
///
/// The provenance is not decoration: two thirds of the corpus carries no
/// late-game row at all, so without it the Late band would either read as a
/// fresh instruction it isn't, or go blank.
struct LevelTargetChip: View {
    let target: BuildStagePlan.LevelTarget
    let isProminent: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text("Lv \(target.level)")
                .font(.system(size: isProminent ? 15 : 11, weight: .heavy, design: .rounded))
                .foregroundStyle(isProminent ? .black.opacity(0.85) : TFTTheme.accent)
            if target.isCarriedForward {
                Text("from \(target.stage.label)")
                    .font(.system(size: isProminent ? 10 : 9, weight: .bold))
                    .foregroundStyle(isProminent ? .black.opacity(0.6) : TFTTheme.textTertiary)
            }
        }
        .padding(.horizontal, isProminent ? 8 : 6)
        .padding(.vertical, isProminent ? 4 : 2)
        .background(
            isProminent ? AnyShapeStyle(TFTTheme.accent) : AnyShapeStyle(TFTTheme.accent.opacity(0.16)),
            in: RoundedRectangle(cornerRadius: 5, style: .continuous)
        )
    }
}

/// The section chrome the expanded band uses, matching `CompDetailView`'s
/// cards so switching between the two panels doesn't feel like two apps.
struct StageCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(TFTTheme.accent)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            TFTTheme.panelBackground,
            in: RoundedRectangle(cornerRadius: TFTTheme.cornerRadius, style: .continuous)
        )
    }
}
