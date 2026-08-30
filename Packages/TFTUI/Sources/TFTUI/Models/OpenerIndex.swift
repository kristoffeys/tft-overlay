import TFTData

/// Early-game guidance derived purely from the loaded comp corpus: which
/// cheap units are worth picking up before a comp is chosen, which
/// components to prioritise while holding, and which comps a given early
/// unit can still lead into.
///
/// **This is not statistics.** `Comp.tier` is authored metadata copied from
/// a scraped tier list (ADR 0004), not measured placement data -- there is
/// no win rate or sample size behind any number this type produces, and no
/// confidence figure is invented to paper over that. Real placement
/// statistics are phase 3 (issue #62); a future caller must not present
/// this output as if it were that.
///
/// Reads nothing but the local `[Comp]` corpus passed to `init`. No
/// opponent, lobby, or live-game data of any kind feeds this (issue #68) --
/// there is nothing here to feed it with.
public struct OpenerIndex: Sendable {
    /// Rankings that answer "what should I hold before I've committed" only
    /// make sense for units cheap enough to hold speculatively. A 4- or
    /// 5-cost unit is a commitment by definition: fielding one already
    /// requires the gold and level that comes with having picked a
    /// direction. So the pool is filtered to 1-3 cost units entirely,
    /// rather than merely down-weighted -- a down-weight would still let a
    /// 5-cost that dominates every S-tier comp leak onto an "early pickup"
    /// list on raw presence alone, which is exactly the failure this
    /// exists to avoid.
    public static let openerCostRange: ClosedRange<Int> = 1 ... 3

    /// Editorial weights for `mostPresent`, not derived from any measured
    /// win rate (see the type doc). An S-tier appearance counts double an
    /// A-tier one; B/C/D-tier appearances count for nothing in this
    /// ranking -- they still count in `mostShared`, which is deliberately
    /// tier-blind.
    private static func presenceWeight(for tier: Comp.Tier) -> Int {
        switch tier {
        case .s: 2
        case .a: 1
        case .b, .c, .d: 0
        }
    }

    /// One low-cost unit's two distinct scores: how strongly the current
    /// meta favors it (`weightedPresence`, S/A only) versus how many
    /// separate archetypes it fits into at all (`sharedCompCount`, every
    /// tier). `OpenerIndex.mostPresent` and `.mostShared` are the same
    /// units sorted by different halves of this.
    public struct UnitPresence: Identifiable, Hashable, Sendable {
        public var id: String {
            name
        }

        public let name: String
        public let cost: Int
        /// Tier-weighted occurrence among S/A-tier comps only. Zero means
        /// the unit never appears in an S or A comp, even if it appears
        /// elsewhere in the corpus.
        public let weightedPresence: Int
        /// Distinct comps -- any tier -- this unit appears in. This is the
        /// "keeps the most doors open" number: a unit slotting into four
        /// B-tier archetypes stays flexible even though it never cracks
        /// the meta-weighted ranking above.
        public let sharedCompCount: Int
    }

    /// One standard component's demand across S-tier carries' item
    /// priorities, decomposed via `RecipeMatrix`. A raw count of how many
    /// times the component was a step toward a wanted completed item --
    /// priority rank (BiS vs. an alternate) is not weighted, deliberately:
    /// this ranking answers "what to slam", and an alt item still wants its
    /// components slammed same as a BiS one does.
    public struct ComponentDemand: Identifiable, Hashable, Sendable {
        public var id: String {
            componentName
        }

        public let componentName: String
        public let demand: Int
    }

    /// A comp this index can bridge an early unit into, named without
    /// pulling in the whole `Comp` -- the panel this exists for wants a
    /// name and a tier to show, not the full board layout.
    public struct CompSummary: Hashable, Sendable {
        public let id: String
        public let name: String
        public let tier: Comp.Tier
    }

    /// Low-cost units ranked by tier-weighted presence in S/A comps,
    /// descending; ties break on unit name ascending so the ranking is
    /// deterministic across runs. Units that never appear in an S or A comp
    /// are absent from this list entirely (they may still be in
    /// `mostShared`).
    public let mostPresent: [UnitPresence]

    /// The same units ranked by how many distinct comps -- any tier --
    /// they appear in, descending, ties broken the same way. Deliberately a
    /// different ranking from `mostPresent`: a unit can lead every list
    /// here while scoring zero on the other, and vice versa.
    public let mostShared: [UnitPresence]

    /// Standard components ranked by demand across S-tier carries,
    /// descending, ties broken on component name ascending.
    public let componentDemand: [ComponentDemand]

    private let leadsToByUnit: [String: [CompSummary]]

    /// Per-unit tallies accumulated from a single pass over the corpus,
    /// before either ranking or the leads-to map is derived from them.
    private struct UnitTallies {
        var costByName: [String: Int] = [:]
        var weightedByName: [String: Int] = [:]
        var sharedCountByName: [String: Int] = [:]
        var leadsTo: [String: [CompSummary]] = [:]
    }

    public init(comps: [Comp], recipeMatrix: RecipeMatrix = RecipeMatrix()) {
        let tallies = Self.tally(comps)
        leadsToByUnit = Self.sortedLeadsTo(tallies.leadsTo)
        mostPresent = Self.ranked(tallies, by: \.weightedByName, keepZero: false)
        mostShared = Self.ranked(tallies, by: \.sharedCountByName, keepZero: true)
        componentDemand = Self.componentDemand(comps, recipeMatrix: recipeMatrix)
    }

    private static func tally(_ comps: [Comp]) -> UnitTallies {
        var tallies = UnitTallies()
        for comp in comps {
            let summary = CompSummary(id: comp.id, name: comp.name, tier: comp.tier)
            let weight = presenceWeight(for: comp.tier)
            for unit in comp.units where openerCostRange.contains(unit.cost) {
                // A unit's true cost is fixed per champion, so any spread
                // across comps in the corpus is bad input data, not a real
                // ambiguity. Resolving to the minimum seen keeps the tally
                // order-independent (unlike last-write-wins, which depends
                // on comp iteration order) and is safe for a ranking that
                // filters on cost 1-3: a lower resolved cost can only make a
                // unit MORE eligible for that filter, never less.
                if let existingCost = tallies.costByName[unit.name] {
                    tallies.costByName[unit.name] = Swift.min(existingCost, unit.cost)
                } else {
                    tallies.costByName[unit.name] = unit.cost
                }
                tallies.sharedCountByName[unit.name, default: 0] += 1
                tallies.weightedByName[unit.name, default: 0] += weight
                tallies.leadsTo[unit.name, default: []].append(summary)
            }
        }
        return tallies
    }

    private static func sortedLeadsTo(_ leadsTo: [String: [CompSummary]]) -> [String: [CompSummary]] {
        leadsTo.mapValues { comps in
            comps.sorted { lhs, rhs in
                lhs.tier != rhs.tier ? lhs.tier < rhs.tier : lhs.name < rhs.name
            }
        }
    }

    /// `keepZero` distinguishes `mostPresent` (drops units with zero S/A
    /// weight -- an appearance only in B/C/D tiers says nothing about
    /// current meta strength) from `mostShared` (keeps everything: every
    /// qualifying unit appears in at least one comp by construction, so
    /// there's nothing to drop).
    private static func ranked(
        _ tallies: UnitTallies,
        by score: KeyPath<UnitTallies, [String: Int]>,
        keepZero: Bool
    ) -> [UnitPresence] {
        let scoreByName = tallies[keyPath: score]
        return tallies.costByName.keys
            .map { name in
                UnitPresence(
                    name: name,
                    cost: tallies.costByName[name] ?? 0,
                    weightedPresence: tallies.weightedByName[name] ?? 0,
                    sharedCompCount: tallies.sharedCountByName[name] ?? 0
                )
            }
            .filter { keepZero || (scoreByName[$0.name] ?? 0) > 0 }
            .sorted { lhs, rhs in
                let lhsScore = scoreByName[lhs.name] ?? 0
                let rhsScore = scoreByName[rhs.name] ?? 0
                return lhsScore != rhsScore ? lhsScore > rhsScore : lhs.name < rhs.name
            }
    }

    private static func componentDemand(_ comps: [Comp], recipeMatrix: RecipeMatrix) -> [ComponentDemand] {
        let completedItemsByName = Dictionary(
            uniqueKeysWithValues: recipeMatrix.completedItems.map { ($0.name, $0) }
        )
        var demandByComponent: [String: Int] = [:]
        for comp in comps where comp.tier == .s {
            for carry in comp.carries {
                for itemName in carry.itemPriority {
                    // A carry's item priority can legitimately name a trait
                    // emblem or an artifact -- not every completed item is a
                    // 2-component build. Those (and any name that fails to
                    // resolve at all) simply contribute nothing here rather
                    // than aborting the comp or crashing.
                    guard let completed = completedItemsByName[itemName],
                          let recipe = recipeMatrix.recipe(for: completed)
                    else { continue }
                    demandByComponent[recipe.0.name, default: 0] += 1
                    demandByComponent[recipe.1.name, default: 0] += 1
                }
            }
        }
        return demandByComponent
            .map { ComponentDemand(componentName: $0.key, demand: $0.value) }
            .sorted { lhs, rhs in
                lhs.demand != rhs.demand ? lhs.demand > rhs.demand : lhs.componentName < rhs.componentName
            }
    }

    /// Every comp -- any tier -- that carries `unitName` among its
    /// early-eligible units, tier-then-name ordered. Lets a future panel
    /// bridge from "hold this unit" to "here's what it builds into" instead
    /// of being a dead end. Empty for a unit outside the opener cost range,
    /// or one this corpus never saw.
    public func comps(leadingFrom unitName: String) -> [CompSummary] {
        leadsToByUnit[unitName] ?? []
    }
}
