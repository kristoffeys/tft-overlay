import SwiftUI

/// A unit's reference detail: cost, every trait it carries (tap one to jump
/// to that trait's detail), recommended items, and the comps that use it
/// (tap one to open its full comp detail).
struct UnitReferenceDetailView: View {
    let unit: UnitReference
    let onSelectTrait: (String) -> Void
    let onSelectComp: (CompRef) -> Void
    let onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                section("Traits") {
                    TappableTraitTagRow(unit.traits, onSelect: onSelectTrait)
                }
                section("Recommended Items") {
                    if unit.recommendedItems.isEmpty {
                        Text("No item data for this unit yet.")
                            .font(.system(size: 12))
                            .foregroundStyle(TFTTheme.textSecondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(unit.recommendedItems, id: \.self) { name in
                                    VStack(spacing: 3) {
                                        ItemIconPlaceholder(name: name, size: 40)
                                        Text(name)
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundStyle(TFTTheme.textSecondary)
                                            .lineLimit(1)
                                            .frame(maxWidth: 52)
                                    }
                                }
                            }
                        }
                    }
                }
                section("Used In") {
                    if unit.comps.isEmpty {
                        Text("No loaded comp uses this unit.")
                            .font(.system(size: 12))
                            .foregroundStyle(TFTTheme.textSecondary)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(unit.comps) { compRef in
                                Button {
                                    onSelectComp(compRef)
                                } label: {
                                    HStack(spacing: 10) {
                                        TierBadge(compRef.tier)
                                        Text(compRef.name)
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                            .foregroundStyle(TFTTheme.textPrimary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(TFTTheme.textSecondary)
                                    }
                                    .padding(8)
                                    .background(
                                        TFTTheme.elevatedBackground,
                                        in: RoundedRectangle(
                                            cornerRadius: TFTTheme.smallCornerRadius,
                                            style: .continuous
                                        )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            BackButton(action: onBack)
            UnitPortraitPlaceholder(name: unit.name, cost: unit.cost, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(unit.name)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(TFTTheme.textPrimary)
                Text("\(unit.cost)-Cost")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TFTTheme.costColor(unit.cost))
            }
            Spacer()
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

/// A trait's reference detail: breakpoints/style tiers, and every unit
/// across loaded comps that carries it (tap one to jump to its detail).
struct TraitReferenceDetailView: View {
    let trait: TraitReference
    let onSelectUnit: (String) -> Void
    let onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                section("Breakpoints") {
                    BreakpointPills(breakpoints: trait.breakpoints)
                }
                section("Units") {
                    if trait.units.isEmpty {
                        Text("No loaded comp uses this trait.")
                            .font(.system(size: 12))
                            .foregroundStyle(TFTTheme.textSecondary)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(trait.units) { unitRef in
                                Button {
                                    onSelectUnit(unitRef.name)
                                } label: {
                                    HStack(spacing: 10) {
                                        UnitPortraitPlaceholder(name: unitRef.name, cost: unitRef.cost, size: 32)
                                        Text(unitRef.name)
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                            .foregroundStyle(TFTTheme.textPrimary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(TFTTheme.textSecondary)
                                    }
                                    .padding(8)
                                    .background(
                                        TFTTheme.elevatedBackground,
                                        in: RoundedRectangle(
                                            cornerRadius: TFTTheme.smallCornerRadius,
                                            style: .continuous
                                        )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            BackButton(action: onBack)
            Text(trait.name)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(TFTTheme.textPrimary)
            Spacer()
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

private struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(TFTTheme.textPrimary)
                .frame(width: 26, height: 26)
                .background(TFTTheme.elevatedBackground, in: Circle())
        }
        .buttonStyle(.plain)
    }
}
