import SwiftUI

/// Unit and trait reference panel (#26): units grouped by cost with their
/// traits and recommended items, traits with their breakpoints and style
/// tiers, cross-linked both ways — unit -> comps that use it, trait ->
/// units that carry it. Every unit and trait is reachable in two
/// interactions: open this panel, then tap it in the list.
public struct UnitTraitReferenceView: View {
    private let comps: [Comp]
    private let index: RosterIndex
    private let onSelectComp: (Comp) -> Void

    @State private var mode: Mode = .units
    @State private var searchText = ""
    @State private var selection: Selection = .none

    enum Mode: String, CaseIterable, Identifiable {
        case units = "Units"
        case traits = "Traits"
        var id: String {
            rawValue
        }
    }

    enum Selection {
        case none
        case unit(UnitReference)
        case trait(TraitReference)
    }

    public init(comps: [Comp], onSelectComp: @escaping (Comp) -> Void = { _ in }) {
        self.comps = comps
        index = RosterIndex(comps: comps)
        self.onSelectComp = onSelectComp
    }

    public var body: some View {
        VStack(spacing: 0) {
            switch selection {
            case .none:
                modePicker
                searchField
                listContent
            case let .unit(unit):
                UnitReferenceDetailView(
                    unit: unit,
                    onSelectTrait: { name in
                        if let trait = index.trait(named: name) {
                            selection = .trait(trait)
                        }
                    },
                    onSelectComp: resolveAndSelectComp,
                    onBack: { selection = .none }
                )
            case let .trait(trait):
                TraitReferenceDetailView(
                    trait: trait,
                    onSelectUnit: { name in
                        if let unit = index.unit(named: name) {
                            selection = .unit(unit)
                        }
                    },
                    onBack: { selection = .none }
                )
            }
        }
        .background(TFTTheme.background)
    }

    private func resolveAndSelectComp(_ ref: CompRef) {
        if let comp = comps.first(where: { $0.id == ref.id }) {
            onSelectComp(comp)
        }
    }

    private var modePicker: some View {
        Picker("", selection: $mode) {
            ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(10)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(TFTTheme.textSecondary)
            TextField("Search \(mode == .units ? "unit" : "trait")", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundStyle(TFTTheme.textPrimary)
        }
        .font(.system(size: 13, weight: .medium))
        .padding(9)
        .background(
            TFTTheme.panelBackground,
            in: RoundedRectangle(cornerRadius: TFTTheme.smallCornerRadius, style: .continuous)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var listContent: some View {
        switch mode {
        case .units: unitList
        case .traits: traitList
        }
    }

    private var filteredUnits: [UnitReference] {
        guard !searchText.isEmpty else { return index.units }
        return index.units.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }

    private var filteredTraits: [TraitReference] {
        guard !searchText.isEmpty else { return index.traits }
        return index.traits.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }

    private var unitList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(unitsByCost, id: \.cost) { group in
                    Text("\(group.cost)-Cost".uppercased())
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(TFTTheme.textSecondary)
                    ForEach(group.units) { unit in
                        Button {
                            selection = .unit(unit)
                        } label: {
                            UnitReferenceRow(unit: unit)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if filteredUnits.isEmpty {
                    Text("No units match.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TFTTheme.textSecondary)
                        .padding(.top, 40)
                }
            }
            .padding(12)
        }
    }

    private var unitsByCost: [(cost: Int, units: [UnitReference])] {
        let grouped = Dictionary(grouping: filteredUnits, by: \.cost)
        return grouped.keys.sorted().map { (cost: $0, units: grouped[$0] ?? []) }
    }

    private var traitList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if filteredTraits.isEmpty {
                    Text("No traits match.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TFTTheme.textSecondary)
                        .padding(.top, 40)
                }
                ForEach(filteredTraits) { trait in
                    Button {
                        selection = .trait(trait)
                    } label: {
                        TraitReferenceRow(trait: trait)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
        }
    }
}

private struct UnitReferenceRow: View {
    let unit: UnitReference

    var body: some View {
        HStack(spacing: 10) {
            UnitPortraitPlaceholder(name: unit.name, cost: unit.cost, size: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(unit.name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(TFTTheme.textPrimary)
                TraitTagRow(unit.traits)
            }
            Spacer(minLength: 8)
            if !unit.comps.isEmpty {
                Text("\(unit.comps.count) comp\(unit.comps.count == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(TFTTheme.textSecondary)
            }
        }
        .padding(8)
        .background(
            TFTTheme.panelBackground,
            in: RoundedRectangle(cornerRadius: TFTTheme.smallCornerRadius, style: .continuous)
        )
    }
}

private struct TraitReferenceRow: View {
    let trait: TraitReference

    var body: some View {
        HStack(spacing: 10) {
            Text(trait.name)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(TFTTheme.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 8)
            BreakpointPills(breakpoints: trait.breakpoints, compact: true)
            Text("\(trait.units.count)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(TFTTheme.textSecondary)
        }
        .padding(8)
        .background(
            TFTTheme.panelBackground,
            in: RoundedRectangle(cornerRadius: TFTTheme.smallCornerRadius, style: .continuous)
        )
    }
}

/// Style-colored breakpoint counts, e.g. "2 · 4 · 6 · 8" tinted per tier.
struct BreakpointPills: View {
    let breakpoints: [TraitBreakpoint]
    var compact: Bool = false

    var body: some View {
        if breakpoints.isEmpty {
            Text("No breakpoint data")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(TFTTheme.textSecondary)
        } else {
            HStack(spacing: 6) {
                ForEach(breakpoints) { breakpoint in
                    VStack(spacing: 1) {
                        Text("\(breakpoint.count)")
                            .font(.system(size: compact ? 11 : 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(.black.opacity(0.85))
                            .frame(minWidth: compact ? 18 : 24, minHeight: compact ? 18 : 24)
                            .background(styleColor(breakpoint.style), in: Circle())
                        if !compact {
                            Text(breakpoint.style.rawValue.uppercased())
                                .font(.system(size: 8, weight: .heavy, design: .rounded))
                                .foregroundStyle(TFTTheme.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private func styleColor(_ style: TraitStyle) -> Color {
        switch style {
        case .bronze: Color(red: 0.72, green: 0.48, blue: 0.30)
        case .silver: Color(red: 0.75, green: 0.78, blue: 0.82)
        case .gold: Color(red: 0.95, green: 0.78, blue: 0.25)
        case .chromatic: Color(red: 0.55, green: 0.90, blue: 0.95)
        }
    }
}

#Preview {
    UnitTraitReferenceView(comps: (try? CompLoader.bundledFixtures()) ?? [])
        .frame(width: 380, height: 560)
}
