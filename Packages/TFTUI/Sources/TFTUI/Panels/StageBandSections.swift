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
            if !section.buyableUnits.isEmpty {
                StageCard("Buy now · 1–\(BuildStagePlan.buyableEarlyCostLimit) cost") {
                    unitStrip
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

    private var unitStrip: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(section.buyableUnits) { unit in
                VStack(spacing: 3) {
                    UnitPortraitPlaceholder(name: unit.name, cost: unit.cost, size: 40)
                    Text(unit.name)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(TFTTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: 48)
            }
            Spacer(minLength: 0)
        }
    }

    private var componentStrip: some View {
        HStack(spacing: 8) {
            ForEach(section.componentsToHold, id: \.self) { name in
                ItemIconPlaceholder(name: name, size: 34)
            }
            Spacer(minLength: 0)
        }
    }

    private func itemStrip(_ carry: CompCarry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(Array(carry.itemPriority.enumerated()), id: \.offset) { index, name in
                VStack(spacing: 3) {
                    ItemIconPlaceholder(name: name, size: 34)
                    Text(index == 0 ? "BiS" : "Alt \(index)")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(index == 0 ? TFTTheme.accent : TFTTheme.textSecondary)
                }
            }
            Spacer(minLength: 0)
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
    let entries: [LevelPlanEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(entries) { entry in
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
