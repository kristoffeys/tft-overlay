import SwiftUI

/// Comp detail (#24): final board with star targets and items per carry,
/// hex positioning, item priority + alternatives per carry, level-by-stage
/// plan, early opener, pivot notes, preferred augments.
public struct CompDetailView: View {
    let comp: Comp
    let onTogglePin: ((Comp) -> Void)?
    @ObservedObject private var pinnedStoreBox: PinnedCompsStoreBox

    /// Built once per comp so hovering a hex or a roster row is a dictionary
    /// hit rather than a scan of `units` and `carries`.
    private let unitIndex: CompUnitIndex

    /// - Parameter onTogglePin: see `CompsListView` — a host that treats
    ///   pinning as a commit gesture owns the transition, so the header's pin
    ///   button reports the tap instead of mutating the store itself.
    public init(comp: Comp, pinnedStore: PinnedCompsStore? = nil, onTogglePin: ((Comp) -> Void)? = nil) {
        self.comp = comp
        pinnedStoreBox = PinnedCompsStoreBox(pinnedStore)
        self.onTogglePin = onTogglePin
        unitIndex = CompUnitIndex(comp: comp)
    }

    private var pinnedStore: PinnedCompsStore? {
        pinnedStoreBox.store
    }

    public var body: some View {
        ScrollView {
            content
        }
        .background(TFTTheme.background)
    }

    /// The panel minus its scroll container.
    ///
    /// Split out so the off-screen snapshot tests can rasterise it:
    /// `ImageRenderer` renders a `ScrollView` as an empty bitmap, so a layout
    /// test that wraps one is silently testing nothing. Everything that can
    /// clip or overflow lives in here anyway.
    var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            // A hex tooltip can reach past the board's own card; without
            // this the sections below it are painted over the tooltip.
            boardSection
                .zIndex(1)
            carriesSection
            levelPlanSection
            openerPivotSection
            // Scraped comps carry no augment picks, which is most of them —
            // rendering the section anyway spent a whole card on three
            // em-dashes and pushed the roster below the fold for nothing.
            if hasAugmentPreferences {
                augmentsSection
            }
            rosterSection
        }
        .padding(16)
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
                if let pinnedStore {
                    PinToggleButton(isPinned: pinnedStore.isPinned(comp.id)) {
                        if let onTogglePin {
                            onTogglePin(comp)
                        } else {
                            pinnedStore.toggle(comp.id)
                        }
                    }
                }
            }
            HStack(spacing: 10) {
                Text(comp.playstyle.displayName)
                Text("Set \(comp.set) · Patch \(comp.patch)")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(TFTTheme.textSecondary)
            if let description = comp.compDescription {
                Text(description)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TFTTheme.textPrimary)
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
                BoardGridView(grid: comp.boardPositioning.grid, unitIndex: unitIndex)
                    .frame(maxWidth: .infinity, alignment: .center)
                if let notes = comp.boardPositioning.notes {
                    Text(notes)
                        .font(.system(size: 12, weight: .medium))
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
                                    .font(.system(size: 12, weight: .medium))
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
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TFTTheme.textPrimary)
            }
            section("Pivot Notes") {
                Text(comp.pivotNotes)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TFTTheme.textPrimary)
            }
        }
    }

    private var hasAugmentPreferences: Bool {
        let preferences = comp.augmentPreferences
        return !(preferences.tier1.isEmpty && preferences.tier2.isEmpty && preferences.tier3.isEmpty)
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
                Text("—").font(.system(size: 12, weight: .medium)).foregroundStyle(TFTTheme.textSecondary)
            }
            ForEach(names, id: \.self) { name in
                Text(name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TFTTheme.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Champion art carrying its own items, rather than the text list this
    /// used to be: the roster is the part of a comp a player recognises
    /// visually, and reading eight rows of names to find out what to buy is
    /// slower than looking at eight portraits.
    ///
    /// Per-unit trait tags moved to the aggregate breakdown below the grid —
    /// repeating "Elderwood" on six rows never said as much as "Elderwood
    /// 6" does, and the per-unit list is still one hover away on any cell.
    private var rosterSection: some View {
        section("Full Roster") {
            VStack(alignment: .leading, spacing: 12) {
                CompRosterGrid(comp: comp, portraitSize: 56, showsNames: true)
                traitBreakdown
            }
        }
    }

    private var traitBreakdown: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TRAITS AT FULL BOARD")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(TFTTheme.textSecondary)
            // An adaptive grid rather than TraitTagRow: this breakdown is
            // the one place every trait must be visible, so it wraps to as
            // many rows as it needs instead of collapsing into "+3".
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 96), spacing: 6, alignment: .leading)],
                alignment: .leading,
                spacing: 6
            ) {
                ForEach(traitCounts, id: \.name) { entry in
                    TraitTag("\(entry.name) \(entry.count)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    /// Highest-count traits first: those are the ones the comp is actually
    /// built around, and a trait held by one unit is usually incidental.
    private var traitCounts: [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for unit in comp.units {
            for trait in unit.traits {
                counts[trait, default: 0] += 1
            }
        }
        return counts
            .map { (name: $0.key, count: $0.value) }
            .sorted { $0.count == $1.count ? $0.name < $1.name : $0.count > $1.count }
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
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(TFTTheme.textPrimary)
                    }
                }
            }
            if let notes = carry.itemNotes {
                Text(notes)
                    .font(.system(size: 12, weight: .medium))
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
