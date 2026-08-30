import SwiftUI

/// Early-game guidance panel (#85): what to hold and what to slam in stage 1
/// and early stage 2, before a comp has been chosen.
///
/// Four things, in the order a player needs them:
///
/// 1. **Opening plan** — the authored stage-1 → 2-5 rail (`OpeningPlan`).
///    First because it is the only section that answers "what do I do *right
///    now*": at stage 1 the correct action is to spend nothing, and no
///    ranking of pickups can tell you that. Labelled as authored, and shaped
///    unlike the sections below it, because it is the one part of this panel
///    that is not a derivation over the corpus.
/// 2. **Meta pickups** — the openers ranking, from `OpenerIndex.topOpeners`.
/// 3. **Keeps doors open** — the same pool ranked by how many comps it opens
///    at all, any tier. Deliberately a *different* ranking, so the two
///    sections are drawn in two different visual forms: the first is a list
///    with a strength bar, the second a grid of tiles carrying a comp count
///    and a tier spread. Two identically-shaped lists side by side read as
///    one list rendered twice, and the whole point of showing both is that
///    they disagree.
/// 4. **Components** — what to slam versus what to hold.
///
/// The rankings come from `OpenerIndex`, which reads each comp's
/// `earlyUnits` — the board it *opens* on — and never `units`, the final
/// board (see that type's doc, and #99: ranking final boards surfaced six
/// cost-3 units you cannot buy at level 4). Cost is on the face of every
/// entry here for the same reason: the panel had no cost anywhere on it, so
/// nothing about that failure was visible.
///
/// Every unit names the comps it leads into, inline and never behind hover:
/// the panel is only useful if it is a bridge into picking a build rather
/// than a dead end, and hover does not fire at all while the overlay is
/// locked for click-through (#83). How *many* names fit is measured per
/// width rather than fixed — see `CompLeadLayout` — because a name shown
/// truncated is not a name, and hover was the only way back from it.
///
/// **Honesty.** `Comp.tier` is authored metadata copied from a scraped tier
/// list (ADR 0004), not measured placement data — real statistics are #62.
/// Nothing here is rendered as a percentage, a win rate or a confidence, and
/// the basis note at the top of the panel says so in the UI itself rather
/// than only in a doc-comment no player will read.
public struct OpenersView: View {
    private let index: OpenerIndex
    private let onSelectComp: (OpenerIndex.CompSummary) -> Void

    /// How many entries each ranking shows. A stage-1 panel that lists
    /// thirty units is a list, not guidance; the tail of either ranking is
    /// noise you would never act on.
    static let rankingLimit = 6

    /// - Parameter championCosts: champion name -> cost from the live set
    ///   catalog, threaded through to `OpenerIndex`. `Comp.earlyUnits` names
    ///   units without their cost on purpose, and this panel now leads with
    ///   cost, so the number has to come from the catalog that owns it.
    ///   Defaults to empty, which falls back to the corpus's own boards — the
    ///   panel stays correct before the data store has finished loading.
    public init(
        comps: [Comp],
        championCosts: [String: Int] = [:],
        recipeMatrix: RecipeMatrix = RecipeMatrix(),
        onSelectComp: @escaping (OpenerIndex.CompSummary) -> Void = { _ in }
    ) {
        index = OpenerIndex(comps: comps, championCosts: championCosts, recipeMatrix: recipeMatrix)
        self.onSelectComp = onSelectComp
    }

    public var body: some View {
        VStack(spacing: 0) {
            basisNote
            ScrollView {
                content
            }
        }
        .background(TFTTheme.background)
    }

    /// The always-visible statement of what these rankings are and are not.
    ///
    /// Above the scroll view on purpose: a disclaimer you have to scroll to
    /// is a disclaimer that does not exist. Rendered separately from
    /// `content` so a snapshot test can measure both — see `ViewSnapshot`'s
    /// note on `ScrollView` rasterising blank.
    var basisNote: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "info.circle")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(TFTTheme.textTertiary)
            Text("Ranked from this app's comp list — an authored tier list, not measured placements. "
                + "No win rates behind any number here.")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(TFTTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    /// The scroll content, split out so it can be rasterised without a
    /// scrolling host (`ViewSnapshot`).
    var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            OpeningPlanSection()
            metaPickupsSection
            doorsOpenSection
            componentsSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }

    // MARK: - Most present in S/A comps

    var metaPickups: [OpenerIndex.UnitPresence] {
        Array(index.topOpeners.prefix(Self.rankingLimit))
    }

    private var metaPickupsSection: some View {
        section(
            title: "Meta pickups",
            subtitle: "On the opening boards of S and A comps, weighted toward 1-costs. "
                + "The number is how many of those comps open on it."
        ) {
            if metaPickups.isEmpty {
                emptyNote("No S or A comp in this list names an opening board, so there is nothing to weight.")
            } else {
                VStack(spacing: 6) {
                    ForEach(metaPickups) { unit in
                        MetaPickupRow(
                            unit: unit,
                            maximumScore: metaPickups.first?.openerScore ?? 1,
                            leadsTo: index.comps(leadingFrom: unit.name),
                            onSelectComp: onSelectComp
                        )
                    }
                }
            }
        }
    }

    // MARK: - Keeps the most doors open

    var flexibleUnits: [OpenerIndex.UnitPresence] {
        Array(index.mostFlexible.prefix(Self.rankingLimit))
    }

    private var doorsOpenSection: some View {
        section(
            title: "Keeps doors open",
            subtitle: "Opens the most comps, any tier — a different ranking on purpose. "
                + "Letters are the tiers it opens."
        ) {
            if flexibleUnits.isEmpty {
                emptyNote("No comp in this list names an opening board of cheap units.")
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: FlexibleUnitTile.width), spacing: 6, alignment: .top)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(flexibleUnits) { unit in
                        FlexibleUnitTile(unit: unit, leadsTo: index.comps(leadingFrom: unit.name))
                    }
                }
            }
        }
    }

    // MARK: - Components

    /// Components in demand enough to slam on sight, versus the rest.
    ///
    /// The split is `demand >= ceil(topDemand / 2)`: a component wanted by at
    /// least half as many S-tier carry builds as the most-wanted one is one
    /// you will find a home for whatever you end up playing, which is the
    /// only question "slam or hold" is asking. Deliberately relative to the
    /// corpus rather than an absolute count — an absolute threshold would
    /// silently empty one group whenever the comp list grows or shrinks.
    var slamComponents: [OpenerIndex.ComponentDemand] {
        index.componentDemand.filter { $0.demand >= slamThreshold }
    }

    var holdComponents: [OpenerIndex.ComponentDemand] {
        index.componentDemand.filter { $0.demand < slamThreshold }
    }

    private var slamThreshold: Int {
        let top = index.componentDemand.first?.demand ?? 0
        return max(1, Int((Double(top) / 2).rounded(.up)))
    }

    private var componentsSection: some View {
        section(
            title: "Components",
            subtitle: "How many S-tier carry builds want each one"
        ) {
            if index.componentDemand.isEmpty {
                emptyNote("No S-tier comp here names an itemised carry, so there is nothing to rank.")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    componentGroup("Slam", components: slamComponents, tint: TFTTheme.accent)
                    componentGroup("Hold", components: holdComponents, tint: TFTTheme.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private func componentGroup(
        _ label: String,
        components: [OpenerIndex.ComponentDemand],
        tint: Color
    ) -> some View {
        if !components.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(tint)
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: ComponentDemandTile.width), spacing: 6, alignment: .top)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(components) { component in
                        ComponentDemandTile(component: component)
                    }
                }
            }
        }
    }

    // MARK: - Shared chrome

    private func section(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(TFTTheme.accent)
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(TFTTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func emptyNote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(TFTTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    OpenersView(comps: (try? CompLoader.bundledFixtures()) ?? [])
        .frame(width: 460, height: 640)
}
