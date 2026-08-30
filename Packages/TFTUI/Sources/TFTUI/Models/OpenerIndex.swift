import TFTData

/// Early-game guidance derived purely from the loaded comp corpus: which
/// cheap units are worth picking up before a comp is chosen, which
/// components to prioritise while holding, and which comps a given early
/// unit can still lead into.
///
/// **Ranked from `Comp.earlyUnits`, never from `Comp.units`.** `units` is the
/// FINAL board, and final-board presence *rises* with cost because cheap
/// openers get sold or benched by stage 4 — measured on this corpus, S/A
/// comps field 32 cost-1 unit-slots against 72 cost-4 ones. A ranking over
/// that input can only ever surface units you cannot buy in the rounds this
/// panel is about, and no weighting repairs it because the input answers a
/// different question (issue #99). `earlyUnits` is the roster the comp
/// actually opens on, so the "no expensive openers" property now falls out
/// of the data — across 171 roster slots the corpus names no cost-4 or
/// cost-5 unit at all — rather than being imposed by a filter that hid the
/// bug it was covering for.
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
    /// The dearest unit that can appear as an opener at all.
    ///
    /// A 3-cost is only ever admitted as a reroll carry (see
    /// `rerollCarryNames`); anything dearer is never an opener, because
    /// fielding it already presupposes the gold and level that come with
    /// having picked a direction. Kept as an explicit ceiling even though
    /// the corpus's early rosters contain nothing above 3 today: the rule is
    /// the contract, and an early roster that one day names a 4-cost is a
    /// data bug this must not silently render.
    public static let maximumOpenerCost = 3

    /// Editorial weights, not derived from any measured win rate (see the
    /// type doc). An S-tier comp's opening roster counts double an A-tier
    /// one's; B/C/D-tier openings count for nothing in `topOpeners` -- they
    /// still count in `mostFlexible`, which is deliberately tier-blind.
    private static func tierWeight(for tier: Comp.Tier) -> Int {
        switch tier {
        case .s: 2
        case .a: 1
        case .b, .c, .d: 0
        }
    }

    /// Cost weighting, and the reason this ranking exists.
    ///
    /// A 1-cost is easiest to *find* (the pool is deepest and the shop odds
    /// at level 4 are heavily 1-cost) and therefore easiest to pair, and a
    /// pair beats a lone stronger unit in stage 2. That is the actual
    /// user-facing complaint behind #99, so it is weighted directly rather
    /// than left to emerge from appearance counts. 3-costs score lowest of
    /// the admitted three: even a genuine reroll carry is a plan you commit
    /// to, not a stage-1 pickup.
    private static func costWeight(for cost: Int) -> Int {
        switch cost {
        case 1: 3
        case 2: 2
        default: 1
        }
    }

    /// Numerator for the per-comp roster share, chosen as `lcm(1...8)` so
    /// `rosterShareScale / rosterCount` is exact for every roster size a
    /// legal opening board can have.
    ///
    /// Early rosters are **not** uniform in size: on this corpus 34 comps
    /// name five early units, `elderwood-bloom` four and `hunters-ashe`
    /// one. Counting appearances flat would hand the five-unit comps five
    /// votes and `hunters-ashe` one, so a unit's rank would move with how
    /// verbose its comps' opening notes happened to be. Instead every comp
    /// casts exactly one tier-weighted vote, split evenly across the units
    /// on its opening board: a unit that *is* a comp's whole opening plan
    /// counts for that comp's entire vote, and one of five counts a fifth.
    /// Integer arithmetic throughout, so the ranking is bit-identical run
    /// to run rather than subject to floating-point tie-breaks.
    private static let rosterShareScale = 840

    /// One eligible opener's scores. `openerScore` is the ranking basis --
    /// tier-weighted, cost-weighted and normalised by roster size -- while
    /// the two counts are plain, explainable integers over the same early
    /// rosters. `OpenerIndex.topOpeners` and `.mostFlexible` sort by
    /// different members of this.
    public struct UnitPresence: Identifiable, Hashable, Sendable {
        public var id: String {
            name
        }

        public let name: String
        public let cost: Int
        /// Editorial opener score in arbitrary units -- a rank basis, not a
        /// quantity. Never render it as a number, a percentage or a win
        /// rate: it is `tierWeight * costWeight * rosterShare` summed over
        /// the corpus, and the only meaningful thing to do with it is
        /// compare two of them.
        public let openerScore: Int
        /// Distinct S/A comps whose *opening roster* names this unit. Zero
        /// means the unit only opens B/C/D comps, even though it may open
        /// several of them.
        public let topTierRosterCount: Int
        /// Distinct comps -- any tier -- whose opening roster names this
        /// unit. This is the "keeps the most doors open" number: a unit
        /// opening four B-tier archetypes stays flexible even though it
        /// never cracks the meta-weighted ranking above.
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

    /// Eligible units ranked by `openerScore`, descending; ties break on
    /// unit name ascending so the ranking is deterministic across runs.
    /// Units that open no S or A comp score zero and are absent from this
    /// list entirely (they may still be in `mostFlexible`).
    public let topOpeners: [UnitPresence]

    /// The same units ranked by how many distinct comps -- any tier -- they
    /// open, descending, ties broken the same way. Deliberately a different
    /// ranking from `topOpeners`, and deliberately *unweighted*: "how many
    /// doors does holding this keep open" is a count of doors, and tilting
    /// it by tier or cost would make it a second opinion on the same
    /// question rather than a different question.
    public let mostFlexible: [UnitPresence]

    /// Standard components ranked by demand across S-tier carries,
    /// descending, ties broken on component name ascending.
    public let componentDemand: [ComponentDemand]

    private let leadsToByUnit: [String: [CompSummary]]

    /// Per-unit tallies accumulated from a single pass over the corpus,
    /// before either ranking or the leads-to map is derived from them.
    private struct UnitTallies {
        var costByName: [String: Int] = [:]
        var scoreByName: [String: Int] = [:]
        var topTierCountByName: [String: Int] = [:]
        var sharedCountByName: [String: Int] = [:]
        var leadsTo: [String: [CompSummary]] = [:]
    }

    /// - Parameter championCosts: authoritative champion name -> cost, as
    ///   loaded from the live set catalog. `Comp.earlyUnits` carries names
    ///   only, on purpose, so cost is not duplicated into the corpus and
    ///   cannot drift; this is where it comes back. Falls back to the cost
    ///   the corpus's own `units` entries give when a name is absent here,
    ///   which covers a caller with no data store loaded yet. A name
    ///   neither source knows is dropped rather than guessed -- an opener
    ///   whose cost is unknown cannot be cost-ranked or cost-labelled, and
    ///   inventing a cost for it would put a wrong number on the one thing
    ///   #99 says the panel must show.
    public init(
        comps: [Comp],
        championCosts: [String: Int] = [:],
        recipeMatrix: RecipeMatrix = RecipeMatrix()
    ) {
        let tallies = Self.tally(comps, championCosts: championCosts)
        leadsToByUnit = Self.sortedLeadsTo(tallies.leadsTo)
        topOpeners = Self.ranked(tallies, by: \.scoreByName, keepZero: false)
        mostFlexible = Self.ranked(tallies, by: \.sharedCountByName, keepZero: true)
        componentDemand = Self.componentDemand(comps, recipeMatrix: recipeMatrix)
    }

    private static func tally(_ comps: [Comp], championCosts: [String: Int]) -> UnitTallies {
        let costs = costLookup(comps, championCosts: championCosts)
        let rerollCarries = rerollCarryNames(comps)
        var tallies = UnitTallies()
        for comp in comps where !comp.earlyUnits.isEmpty {
            let summary = CompSummary(id: comp.id, name: comp.name, tier: comp.tier)
            let share = rosterShareScale / comp.earlyUnits.count
            let weight = tierWeight(for: comp.tier)
            for name in comp.earlyUnits {
                guard let cost = costs[TFTNameKey.normalize(name)],
                      isEligible(cost: cost, name: name, rerollCarries: rerollCarries)
                else { continue }
                tallies.costByName[name] = cost
                tallies.scoreByName[name, default: 0] += weight * costWeight(for: cost) * share
                tallies.topTierCountByName[name, default: 0] += weight > 0 ? 1 : 0
                tallies.sharedCountByName[name, default: 0] += 1
                tallies.leadsTo[name, default: []].append(summary)
            }
        }
        return tallies
    }

    /// A 3-cost earns a place on an opener list in exactly one case: the
    /// corpus plays it as a reroll carry, so buying it early *is* the plan
    /// rather than a stopgap. Everything cheaper is admitted outright;
    /// anything dearer never is.
    ///
    /// The `starTarget == 3` signal lives on `Comp.units`, not on
    /// `earlyUnits` -- the early roster is names only by design -- so this
    /// is a deliberate cross-reference between the two, not an oversight.
    private static func isEligible(cost: Int, name: String, rerollCarries: Set<String>) -> Bool {
        guard (1 ... maximumOpenerCost).contains(cost) else { return false }
        // Only the dearest admitted tier needs the reroll test: a 1- or
        // 2-cost is cheap enough to hold speculatively with no plan at all,
        // which is the whole premise of a stage-1 pickup.
        guard cost == 3 else { return true }
        return rerollCarries.contains(TFTNameKey.normalize(name))
    }

    /// Every champion the corpus rerolls to 3 stars anywhere, normalised.
    /// Corpus-wide rather than per-comp: whether a champion is a reroll
    /// carry is a property of the champion in this patch, and a 3-cost that
    /// one comp rerolls is worth opening on even while reading a different
    /// comp's roster.
    private static func rerollCarryNames(_ comps: [Comp]) -> Set<String> {
        Set(
            comps
                .flatMap(\.units)
                .filter { $0.starTarget == 3 }
                .map { TFTNameKey.normalize($0.name) }
        )
    }

    /// Champion cost by normalised name: the supplied catalog first, then
    /// whatever the corpus's own boards say.
    ///
    /// The corpus fallback resolves conflicts to the minimum seen. A unit's
    /// true cost is fixed per champion, so any spread across comps is bad
    /// input data rather than a real ambiguity; taking the minimum keeps the
    /// lookup order-independent, unlike last-write-wins, which would depend
    /// on comp iteration order.
    private static func costLookup(_ comps: [Comp], championCosts: [String: Int]) -> [String: Int] {
        var costs: [String: Int] = [:]
        for unit in comps.flatMap(\.units) {
            let key = TFTNameKey.normalize(unit.name)
            costs[key] = Swift.min(costs[key] ?? unit.cost, unit.cost)
        }
        for (name, cost) in championCosts {
            costs[TFTNameKey.normalize(name)] = cost
        }
        return costs
    }

    private static func sortedLeadsTo(_ leadsTo: [String: [CompSummary]]) -> [String: [CompSummary]] {
        leadsTo.mapValues { comps in
            comps.sorted { lhs, rhs in
                lhs.tier != rhs.tier ? lhs.tier < rhs.tier : lhs.name < rhs.name
            }
        }
    }

    /// `keepZero` distinguishes `topOpeners` (drops units scoring zero --
    /// opening only B/C/D comps says nothing about current meta strength)
    /// from `mostFlexible` (keeps everything: every eligible unit opens at
    /// least one comp by construction, so there's nothing to drop).
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
                    openerScore: tallies.scoreByName[name] ?? 0,
                    topTierRosterCount: tallies.topTierCountByName[name] ?? 0,
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

    /// Every comp -- any tier -- whose opening roster names `unitName`,
    /// tier-then-name ordered. Lets the panel bridge from "hold this unit"
    /// to "here's what it builds into" instead of being a dead end.
    ///
    /// A **secondary hint, never the ranking basis**: opener value is
    /// largely independent of which comp you finish in (#99's research), so
    /// a unit is ranked on how good an opener it is and only then told you
    /// where it can go. Empty for an ineligible unit, or one no comp in
    /// this corpus opens on.
    public func comps(leadingFrom unitName: String) -> [CompSummary] {
        leadsToByUnit[unitName] ?? []
    }
}
