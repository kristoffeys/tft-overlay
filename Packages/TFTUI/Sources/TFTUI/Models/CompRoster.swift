/// One champion as the roster strip draws it: the unit, plus the items it
/// wants if it is an itemised carry.
///
/// Deliberately a value type derived from a `Comp` rather than a view-local
/// computation, so the ordering rules below are testable without rendering.
public struct CompRosterEntry: Identifiable, Hashable, Sendable {
    /// How many item icons a roster cell draws. TFT units hold three items,
    /// and comps author `itemPriority` as the intended loadout (BiS first),
    /// so three is the full answer to "what do I build on this unit"
    /// virtually always -- see `CompRoster.itemsPerUnit`.
    public static let itemsPerUnit = 3

    public let unit: CompUnit
    /// Up to `itemsPerUnit` items, in the comp's own priority order. Empty
    /// for every unit that is not an itemised carry -- those cells draw the
    /// portrait alone rather than blank item slots.
    public let items: [String]
    /// The comp's full priority list, which can run longer than `items`
    /// when a carry lists alternatives. Kept for tooltips.
    public let allItems: [String]

    public var id: String {
        unit.name
    }

    public var isCarry: Bool {
        items.isEmpty == false
    }

    public init(unit: CompUnit, allItems: [String] = []) {
        self.unit = unit
        self.allItems = allItems
        items = Array(allItems.prefix(Self.itemsPerUnit))
    }
}

/// Turns a comp into the ordered roster a player reads at a glance.
public enum CompRoster {
    /// Itemised carries first, in the comp's own `carries` order (authors
    /// list the primary carry first), then everything else by descending
    /// cost and then name.
    ///
    /// The point is that the two things a player needs mid-game -- what to
    /// buy items for, and which expensive units to look for -- land at the
    /// top-left of the strip, where the eye starts. Roster order as authored
    /// carries no such meaning.
    public static func entries(for comp: Comp) -> [CompRosterEntry] {
        entries(units: comp.units, carries: comp.carries)
    }

    /// The same rules against a comp's parts, which is all this needs and
    /// what makes it checkable without building a whole `Comp`.
    public static func entries(units: [CompUnit], carries: [CompCarry]) -> [CompRosterEntry] {
        let index = CompUnitIndex(units: units, carries: carries)
        let carryRank = carryRanks(for: carries)

        return units
            .map { unit in
                CompRosterEntry(unit: unit, allItems: index.carry(named: unit.name)?.itemPriority ?? [])
            }
            .enumerated()
            .sorted { lhs, rhs in
                let lhsRank = carryRank[lhs.element.unit.name.lowercased()]
                let rhsRank = carryRank[rhs.element.unit.name.lowercased()]
                switch (lhsRank, rhsRank) {
                case let (left?, right?):
                    return left < right
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    break
                }
                if lhs.element.unit.cost != rhs.element.unit.cost {
                    return lhs.element.unit.cost > rhs.element.unit.cost
                }
                if lhs.element.unit.name != rhs.element.unit.name {
                    return lhs.element.unit.name < rhs.element.unit.name
                }
                // Duplicate names would otherwise sort unstably.
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    /// Only carries that actually have items rank ahead of the field: a
    /// `carries` entry with an empty priority list says nothing about what
    /// to buy, so it sorts with the rest of the roster.
    private static func carryRanks(for carries: [CompCarry]) -> [String: Int] {
        var ranks: [String: Int] = [:]
        for (rank, carry) in carries.enumerated() where carry.itemPriority.isEmpty == false {
            let key = carry.unit.lowercased()
            if ranks[key] == nil {
                ranks[key] = rank
            }
        }
        return ranks
    }
}
