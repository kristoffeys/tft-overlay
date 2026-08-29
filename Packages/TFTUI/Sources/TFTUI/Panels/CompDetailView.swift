import SwiftUI

/// Comp detail (#24): final board with star targets and items per carry,
/// hex positioning, item priority + alternatives per carry, level-by-stage
/// plan, early opener, pivot notes, preferred augments.
public struct CompDetailView: View {
    let comp: Comp

    public init(comp: Comp) {
        self.comp = comp
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                boardSection
                carriesSection
                levelPlanSection
                openerPivotSection
                augmentsSection
                rosterSection
            }
            .padding(16)
        }
        .background(TFTTheme.background)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                TierBadge(comp.tier)
                Text(comp.name)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(TFTTheme.textPrimary)
                Spacer()
                DifficultyIndicator(comp.difficulty)
            }
            HStack(spacing: 10) {
                Text(comp.playstyle.displayName)
                Text("Set \(comp.set) · Patch \(comp.patch)")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(TFTTheme.textSecondary)
            if let description = comp.compDescription {
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(TFTTheme.textPrimary.opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            TFTTheme.panelBackground,
            in: RoundedRectangle(cornerRadius: TFTTheme.cornerRadius, style: .continuous)
        )
    }

    private var boardSection: some View {
        section("Final Board") {
            VStack(alignment: .leading, spacing: 8) {
                BoardGridView(grid: comp.boardPositioning.grid)
                    .frame(maxWidth: .infinity, alignment: .center)
                if let notes = comp.boardPositioning.notes {
                    Text(notes)
                        .font(.system(size: 12))
                        .foregroundStyle(TFTTheme.textSecondary)
                }
            }
        }
    }

    private var carriesSection: some View {
        section("Carries & Items") {
            VStack(spacing: 10) {
                ForEach(comp.carryUnits, id: \.unit.id) { pair in
                    CarryCard(carry: pair.carry, unit: pair.unit)
                }
            }
        }
    }

    private var levelPlanSection: some View {
        section("Level Plan") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(comp.levelPlan) { entry in
                    HStack(alignment: .top, spacing: 10) {
                        Text(entry.stage)
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(.black.opacity(0.85))
                            .frame(width: 44, height: 22)
                            .background(TFTTheme.accent, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Level \(entry.level)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(TFTTheme.textPrimary)
                            if let notes = entry.notes {
                                Text(notes)
                                    .font(.system(size: 12))
                                    .foregroundStyle(TFTTheme.textSecondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private var openerPivotSection: some View {
        VStack(spacing: 10) {
            section("Early Opener") {
                Text(comp.earlyOpener)
                    .font(.system(size: 13))
                    .foregroundStyle(TFTTheme.textPrimary.opacity(0.92))
            }
            section("Pivot Notes") {
                Text(comp.pivotNotes)
                    .font(.system(size: 13))
                    .foregroundStyle(TFTTheme.textPrimary.opacity(0.92))
            }
        }
    }

    private var augmentsSection: some View {
        section("Preferred Augments") {
            HStack(alignment: .top, spacing: 16) {
                augmentColumn(title: "Silver", names: comp.augmentPreferences.tier1)
                augmentColumn(title: "Gold", names: comp.augmentPreferences.tier2)
                augmentColumn(title: "Prismatic", names: comp.augmentPreferences.tier3)
            }
        }
    }

    private func augmentColumn(title: String, names: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(TFTTheme.textSecondary)
            if names.isEmpty {
                Text("—").font(.system(size: 12)).foregroundStyle(TFTTheme.textSecondary)
            }
            ForEach(names, id: \.self) { name in
                Text(name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TFTTheme.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rosterSection: some View {
        section("Full Roster") {
            VStack(spacing: 6) {
                ForEach(comp.units) { unit in
                    HStack(spacing: 10) {
                        UnitPortraitPlaceholder(name: unit.name, cost: unit.cost, size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(unit.name)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(TFTTheme.textPrimary)
                                Text(String(repeating: "★", count: unit.starTarget))
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(TFTTheme.accent)
                                if unit.flex {
                                    Text("FLEX")
                                        .font(.system(size: 9, weight: .heavy))
                                        .foregroundStyle(TFTTheme.textSecondary)
                                }
                            }
                            HStack(spacing: 4) {
                                ForEach(unit.traits, id: \.self) { TraitTag($0) }
                            }
                        }
                        Spacer()
                        Text(unit.role.rawValue.capitalized)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(TFTTheme.textSecondary)
                    }
                }
            }
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(TFTTheme.accent)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            TFTTheme.panelBackground,
            in: RoundedRectangle(cornerRadius: TFTTheme.cornerRadius, style: .continuous)
        )
    }
}

private struct CarryCard: View {
    let carry: CompCarry
    let unit: CompUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                UnitPortraitPlaceholder(name: unit.name, cost: unit.cost, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(unit.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(TFTTheme.textPrimary)
                    Text(String(repeating: "★", count: unit.starTarget) + " target")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(TFTTheme.accent)
                }
                Spacer()
            }
            HStack(spacing: 6) {
                ForEach(Array(carry.itemPriority.enumerated()), id: \.offset) { index, itemName in
                    VStack(spacing: 3) {
                        ItemIconPlaceholder(name: itemName, size: 36)
                        Text(rank(index))
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(TFTTheme.textSecondary)
                    }
                }
            }
            if let notes = carry.itemNotes {
                Text(notes)
                    .font(.system(size: 12))
                    .foregroundStyle(TFTTheme.textSecondary)
            }
        }
        .padding(10)
        .background(
            TFTTheme.elevatedBackground,
            in: RoundedRectangle(cornerRadius: TFTTheme.smallCornerRadius, style: .continuous)
        )
    }

    private func rank(_ index: Int) -> String {
        switch index {
        case 0: "BiS"
        default: "Alt \(index)"
        }
    }
}

#Preview {
    if let comp = try? CompLoader.bundledFixtures().first(where: { $0.id == "hunters-ashe" }) {
        CompDetailView(comp: comp)
            .frame(width: 460, height: 780)
    }
}
