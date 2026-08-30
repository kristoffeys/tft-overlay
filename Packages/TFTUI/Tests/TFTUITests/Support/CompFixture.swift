import Foundation
@testable import TFTUI

/// Hand-made `Comp` values for logic tests.
///
/// `Comp` only decodes — ADR 0002's schema is the source of truth, not a
/// memberwise initializer — so fixtures go through the same JSON path the app
/// itself uses, with every field the schema requires but the tests don't care
/// about pinned to a fixed, boring value.
///
/// Shared rather than private to one suite because the comp-suggestion tests
/// are split across files (`CompSuggestionRankingTests` for the scoring
/// contract, `CompSuggestionTierBandTests` for the tier-band ordering
/// contract) and both need the same shapes.
enum CompFixture {
    static func unit(_ name: String, cost: Int, role: CompUnit.Role = .frontline) -> CompUnit {
        CompUnit(name: name, cost: cost, starTarget: 2, role: role, traits: [])
    }

    static func make(
        id: String,
        tier: Comp.Tier,
        units: [CompUnit],
        carries: [CompCarry] = [],
        levelPlan: [LevelPlanEntry] = [],
        earlyOpener: String = "",
        pivotNotes: String = ""
    ) throws -> Comp {
        let unitsJSON = units.map { unit in
            """
            {"name": "\(unit.name)", "cost": \(unit.cost), "starTarget": \(unit.starTarget), \
            "role": "\(unit.role.rawValue)", "traits": []}
            """
        }.joined(separator: ",")
        let carriesJSON = carries.map { carry in
            let items = carry.itemPriority.map { "\"\($0)\"" }.joined(separator: ",")
            return """
            {"unit": "\(carry.unit)", "itemPriority": [\(items)]}
            """
        }.joined(separator: ",")
        let levelPlanJSON = levelPlan.map { entry in
            let notes = entry.notes.map { "\"\($0)\"" } ?? "null"
            return """
            {"stage": "\(entry.stage)", "level": \(entry.level), "notes": \(notes)}
            """
        }.joined(separator: ",")
        let json = """
        {
          "schemaVersion": "1.0.0",
          "id": "\(id)",
          "name": "\(id)",
          "set": 18,
          "patch": "18.1",
          "source": "hand-authored",
          "tier": "\(tier.rawValue)",
          "playstyle": "fast_8",
          "difficulty": "medium",
          "units": [\(unitsJSON)],
          "carries": [\(carriesJSON)],
          "boardPositioning": {"grid": [[]]},
          "augmentPreferences": {"tier1": [], "tier2": [], "tier3": []},
          "levelPlan": [\(levelPlanJSON)],
          "earlyOpener": "\(earlyOpener)",
          "pivotNotes": "\(pivotNotes)"
        }
        """
        return try CompLoader.load(Data(json.utf8))
    }

    /// The shape 33 of the 36 real comps actually have: eight units, costs
    /// 5/4/4/3/2/2/1/1 with the 5-cost as the named carry. `names` must be
    /// eight names in that cost order.
    static func dominantShape(id: String, tier: Comp.Tier, names: [String]) throws -> Comp {
        precondition(names.count == 8, "the dominant real-comp shape is eight units")
        let costs = [5, 4, 4, 3, 2, 2, 1, 1]
        let units = zip(names, costs).enumerated().map { index, pair in
            unit(pair.0, cost: pair.1, role: index == 0 ? .carry : .frontline)
        }
        return try make(id: id, tier: tier, units: units, carries: [CompCarry(unit: names[0], itemPriority: [])])
    }

    /// Total cost/carry weight of `dominantShape`:
    /// `5 * 1.5 + 4 + 4 + 3 + 2 + 2 + 1 + 1`. Spelled out so the expected
    /// scores in the tier-band tests read as arithmetic rather than magic.
    static let dominantShapeTotalWeight = 24.5
}
