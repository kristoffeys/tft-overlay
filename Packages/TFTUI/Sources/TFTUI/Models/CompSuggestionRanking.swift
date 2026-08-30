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

    /// How much a single tier step (S -> A -> B -> C -> D) can move a
    /// comp's place in the list. Deliberately small: tier is authored
    /// opinion, so it should only decide between comps the player is
    /// *about equally* close to fielding, never overrule a real gap in
    /// what's actually on the bench.
    private static let tierStep = 0.02

    /// Ranks `comps` by how close `owned` already gets the player to
    /// fielding each one. Deterministic: two runs over the same inputs
    /// always produce the same order, so a suggestions list never
    /// reshuffles between renders for no visible reason.
    public static func rank(owned: Set<String>, comps: [Comp]) -> [CompSuggestion] {
        let ownedKeys = Set(owned.map(ChampionNameKey.normalize))
        let suggestions = comps.map { suggestion(for: $0, ownedKeys: ownedKeys) }
        return suggestions.sorted { lhs, rhs in
            let lhsScore = adjustedScore(lhs)
            let rhsScore = adjustedScore(rhs)
            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }
            // Tie-break on the comp's stable id, never on array order, so
            // the result is identical every time it's computed.
            return lhs.comp.id < rhs.comp.id
        }
    }

    private static func suggestion(for comp: Comp, ownedKeys: Set<String>) -> CompSuggestion {
        let carryKeys = Set(comp.carries.map { ChampionNameKey.normalize($0.unit) })

        func weight(_ unit: CompUnit) -> Double {
            let base = Double(unit.cost)
            return carryKeys.contains(ChampionNameKey.normalize(unit.name)) ? base * carryMultiplier : base
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
            if ownedKeys.contains(ChampionNameKey.normalize(unit.name)) {
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

    /// The sort key: real overlap plus a small tier nudge. See `tierStep`
    /// for why the nudge can only matter on a near-tie.
    private static func adjustedScore(_ suggestion: CompSuggestion) -> Double {
        suggestion.overlapScore + tierBonus(suggestion.comp.tier)
    }

    private static func tierBonus(_ tier: Comp.Tier) -> Double {
        guard let index = Comp.Tier.allCases.firstIndex(of: tier) else { return 0 }
        let worstIndex = Comp.Tier.allCases.count - 1
        return Double(worstIndex - index) * tierStep
    }
}
