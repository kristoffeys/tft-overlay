/// How close the player's owned champions (`OwnedChampionsStore`, #86)
/// already get them to fielding a given comp — the payoff for the manual
/// input path, and the pivot tool for the mid-game question "what can I
/// actually reach from here" (#87).
///
/// Pure and side-effect-free, in the style of `TraitRelevance` /
/// `ItemDemandIndex` / `CompUnitIndex`: no UI, no network, no I/O. Uses
/// only the player's own champions — never opponent or lobby data, which
/// Riot's third-party rules forbid outright (#68).
///
/// `Comp.tier` here is **authored opinion from a maintainer-run scraped
/// tier list, not measured placement data** (ADR 0004, #85) — real
/// win-rate statistics are Phase 3 (#62). This type never turns that
/// opinion into a percentage or a confidence number, and no caller should
/// present its output as if it had one; the doc-comments on `overlapScore`
/// below spell out exactly what is and isn't being measured.
///
/// Because tier is opinion, it is confined to breaking near-ties and is
/// never mixed into the score itself — see
/// `CompSuggestionRanking.scoreEpsilon` and `rank(owned:comps:)` for the
/// exact guarantee and why the constant is the value it is.
public struct CompSuggestion: Identifiable, Hashable, Sendable {
    public var id: String {
        comp.id
    }

    public let comp: Comp

    /// Units the player already owns, most valuable first — highest
    /// weight (`CompSuggestionRanking`'s cost/carry weighting) first, so the
    /// units that actually matter for this comp lead the list.
    public let matchedUnits: [CompUnit]

    /// Units still needed, most valuable first. This is the actionable
    /// half of a suggestion: "7/9 — missing Ashe, Kindred" tells a player
    /// what to look for in the shop; a bare percentage does not.
    public let missingUnits: [CompUnit]

    /// Cost- and carry-weighted matched fraction of the comp, in `[0, 1]`.
    /// A matched 5-cost carry counts far more than a matched 1-cost
    /// frontline unit, because losing the carry is losing the comp. This
    /// is a *distance* measure over the player's own bench, not a
    /// statistic and not a win probability — see the type's doc-comment.
    public let overlapScore: Double

    /// Convenience counts for a "7/9" style callout.
    public var matchedCount: Int {
        matchedUnits.count
    }

    public var totalCount: Int {
        comp.units.count
    }
}

public enum CompSuggestionRanking {
    /// A matched carry counts for this many times a matched non-carry unit
    /// of the same cost — on top of cost already dominating the weight, so
    /// a matched 5-cost carry outweighs a matched 1-cost frontline unit by
    /// roughly 5x on cost alone, and more once the carry bonus applies.
    private static let carryMultiplier = 1.5

    /// The width of the band inside which two comps count as "about equally
    /// close", and therefore the *only* situation in which authored tier is
    /// allowed to decide the order.
    ///
    /// Chosen against the data, not by feel: across the 36 comps in
    /// `CompLoader.bundledFixtures()`, the cheapest single matched unit is
    /// worth 0.0286 of its comp's total weight (the measured range of that
    /// per-comp minimum is 0.0286...0.0938). 0.02 sits strictly below that
    /// floor, so a band this wide can never span a whole matched unit — which
    /// is exactly the property `rank(owned:comps:)` claims.
    /// `testEveryBundledCompsCheapestUnitOutweighsTheTierBand` pins that
    /// against the live corpus and fails loudly if a re-scrape ever breaks
    /// it, since the guarantee below is only as true as the corpus allows.
    ///
    /// Not `private`: the corpus-guard test reads it, and a constant this
    /// load-bearing should be asserted against real data rather than
    /// duplicated in a test.
    static let scoreEpsilon = 1 / bandsPerUnitScore

    /// `1 / scoreEpsilon`, but stated as the integer it is and used as a
    /// multiplier rather than a divisor. `score / 0.02` is not exact in
    /// binary floating point — `0.5 / 0.02` can land just under 25 and
    /// silently drop a comp a band — whereas `score * 50` is exact wherever
    /// the score itself is.
    private static let bandsPerUnitScore = 50.0

    /// Ranks `comps` by how close `owned` already gets the player to
    /// fielding each one.
    ///
    /// Ordering is `(overlap band descending, tier ascending, comp id
    /// ascending)`, where a comp's band is `floor(overlapScore /
    /// scoreEpsilon)`. Quantising the score first is what makes tier a
    /// genuine near-tie tie-break rather than a nudge that can silently
    /// outrank real overlap, and it does so while staying a plain total
    /// order over three keys — so `sorted(by:)` gets the strict weak
    /// ordering it requires. (Comparing scores with `abs(a - b) <
    /// scoreEpsilon` *inside* the comparator would not: "within epsilon" is
    /// not transitive, and an intransitive predicate makes `sorted(by:)`
    /// undefined.)
    ///
    /// Two exact consequences, both of which are tested:
    ///
    /// - If two comps' `overlapScore` differ by `scoreEpsilon` or more they
    ///   land in different bands, so they are ordered purely on overlap and
    ///   tier plays no part at all. (`a - b >= eps` implies
    ///   `floor(a/eps) > floor(b/eps)`.)
    /// - Tier can therefore only ever decide between comps whose overlap
    ///   differs by *less* than `scoreEpsilon` — which, per the constant's
    ///   doc above, is always less than one matched unit of the comp.
    ///
    /// The converse does not hold, deliberately: a sub-epsilon gap that
    /// happens to straddle a band boundary is still settled on overlap. That
    /// errs towards what is actually on the bench over authored opinion,
    /// which is the safe direction to err in.
    ///
    /// Deterministic: two runs over the same inputs always produce the same
    /// order, so a suggestions list never reshuffles between renders for no
    /// visible reason.
    public static func rank(owned: Set<String>, comps: [Comp]) -> [CompSuggestion] {
        let ownedKeys = Set(owned.map(TFTNameKey.normalize))
        let suggestions = comps.map { suggestion(for: $0, ownedKeys: ownedKeys) }
        return suggestions.sorted { lhs, rhs in
            let lhsBand = overlapBand(lhs.overlapScore)
            let rhsBand = overlapBand(rhs.overlapScore)
            if lhsBand != rhsBand {
                return lhsBand > rhsBand
            }
            // Same band: the player is about equally close to both, so
            // authored tier gets to break it — and only here.
            if lhs.comp.tier != rhs.comp.tier {
                return lhs.comp.tier < rhs.comp.tier
            }
            // Tie-break on the comp's stable id, never on array order, so
            // the result is identical every time it's computed.
            return lhs.comp.id < rhs.comp.id
        }
    }

    /// Which `scoreEpsilon`-wide band an overlap score falls in. Integer, so
    /// band comparison is exact and the resulting order is total.
    static func overlapBand(_ overlapScore: Double) -> Int {
        Int((overlapScore * bandsPerUnitScore).rounded(.down))
    }

    /// A single unit's contribution to its comp's total weight: cost, times
    /// `carryMultiplier` if the comp names it as a carry.
    static func unitWeight(_ unit: CompUnit, carryKeys: Set<String>) -> Double {
        let base = Double(unit.cost)
        return carryKeys.contains(TFTNameKey.normalize(unit.name)) ? base * carryMultiplier : base
    }

    static func carryKeys(of comp: Comp) -> Set<String> {
        Set(comp.carries.map { TFTNameKey.normalize($0.unit) })
    }

    private static func suggestion(for comp: Comp, ownedKeys: Set<String>) -> CompSuggestion {
        let carryKeys = carryKeys(of: comp)

        func weight(_ unit: CompUnit) -> Double {
            unitWeight(unit, carryKeys: carryKeys)
        }

        // Most valuable first, with name as a deterministic tie-break for
        // units of equal weight.
        let byValue = comp.units.sorted { lhs, rhs in
            let lhsWeight = weight(lhs)
            let rhsWeight = weight(rhs)
            if lhsWeight != rhsWeight {
                return lhsWeight > rhsWeight
            }
            return lhs.name < rhs.name
        }

        var matched: [CompUnit] = []
        var missing: [CompUnit] = []
        for unit in byValue {
            if ownedKeys.contains(TFTNameKey.normalize(unit.name)) {
                matched.append(unit)
            } else {
                missing.append(unit)
            }
        }

        let totalWeight = comp.units.reduce(0) { $0 + weight($1) }
        let matchedWeight = matched.reduce(0) { $0 + weight($1) }
        let overlap = totalWeight > 0 ? matchedWeight / totalWeight : 0

        return CompSuggestion(comp: comp, matchedUnits: matched, missingUnits: missing, overlapScore: overlap)
    }
}
