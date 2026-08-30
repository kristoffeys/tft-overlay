import Foundation

/// Which trait names matter most, so that when only some of them fit
/// (`TraitTagLayout`) the survivors are the ones a player actually reads a
/// comp or a unit for.
///
/// Before this existed the tag row kept whatever happened to come first in
/// array order — which for the comps list meant *alphabetical* order, so
/// "Brawler" (one unit, incidental) was guaranteed a slot while "Elderwood"
/// (six units, the entire reason the comp exists) got collapsed into "+3".
public enum TraitRelevance {
    /// Weights for a whole comp's traits: how many of the comp's units carry
    /// each one. `Elderwood 6` is the comp's identity; a trait held by a
    /// single unit is incidental and is the right thing to drop first.
    ///
    /// Same ranking `CompDetailView`'s "traits at full board" breakdown
    /// already used — this just makes it available to the collapsed rows too.
    public static func weights(in comp: Comp) -> [String: Int] {
        var counts: [String: Int] = [:]
        for unit in comp.units {
            for trait in unit.traits {
                counts[trait, default: 0] += 1
            }
        }
        return counts
    }

    /// Weights for one unit's traits. Every trait on a unit is carried
    /// exactly once, so count says nothing; what separates them is how
    /// cheaply the trait activates. A trait whose first breakpoint is 1
    /// (Apex Predator, Primal, Rapidfire) is live the moment that unit hits
    /// the board, while one needing 4 more bodies is only a promise.
    ///
    /// Traits missing from `TraitCatalog` weigh 0 and sort last: we know
    /// nothing about them, so they are the safest to hide.
    public static func weightsForUnitTraits(_ traits: [String]) -> [String: Int] {
        var weights: [String: Int] = [:]
        for trait in traits {
            guard let first = TraitCatalog.breakpoints(for: trait).first else {
                weights[trait] = 0
                continue
            }
            weights[trait] = max(1, 10 - first.count)
        }
        return weights
    }
}
