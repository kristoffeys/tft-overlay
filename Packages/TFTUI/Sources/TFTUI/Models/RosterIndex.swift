/// Minimal identity of a comp, for cross-link display without holding a
/// full `Comp` around inside `RosterIndex` entries.
public struct CompRef: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let tier: Comp.Tier

    public init(id: String, name: String, tier: Comp.Tier) {
        self.id = id
        self.name = name
        self.tier = tier
    }
}

/// Minimal identity of a unit, for cross-link display inside `TraitReference`.
public struct UnitRef: Identifiable, Hashable, Sendable {
    public var id: String {
        name
    }

    public let name: String
    public let cost: Int

    public init(name: String, cost: Int) {
        self.name = name
        self.cost = cost
    }
}

/// A unit's reference entry (#26): cost, every trait it carries across
/// loaded comps, the items comps recommend for it, and which comps use it.
public struct UnitReference: Identifiable, Hashable, Sendable {
    public var id: String {
        name
    }

    public let name: String
    public let cost: Int
    public let traits: [String]
    public let recommendedItems: [String]
    public let comps: [CompRef]

    public init(name: String, cost: Int, traits: [String], recommendedItems: [String], comps: [CompRef]) {
        self.name = name
        self.cost = cost
        self.traits = traits
        self.recommendedItems = recommendedItems
        self.comps = comps
    }
}

/// A trait's reference entry (#26): its breakpoints/style tiers, and every
/// unit across loaded comps that carries it.
public struct TraitReference: Identifiable, Hashable, Sendable {
    public var id: String {
        name
    }

    public let name: String
    public let breakpoints: [TraitBreakpoint]
    public let units: [UnitRef]

    public init(name: String, breakpoints: [TraitBreakpoint], units: [UnitRef]) {
        self.name = name
        self.breakpoints = breakpoints
        self.units = units
    }
}

/// Cross-linked unit/trait reference built from loaded comps: unit -> comps
/// that use it, and trait -> units that carry it (#26). Built once from the
/// same `[Comp]` the rest of the overlay already loads, so the reference
/// panel needs no separate champion/trait data source.
public struct RosterIndex: Sendable {
    /// Sorted by cost, then name — "units by cost".
    public let units: [UnitReference]
    /// Sorted by name.
    public let traits: [TraitReference]

    private let unitsByName: [String: UnitReference]
    private let traitsByName: [String: TraitReference]

    public init(comps: [Comp]) {
        var costByUnit: [String: Int] = [:]
        var traitsByUnit: [String: Set<String>] = [:]
        var compRefsByUnit: [String: [CompRef]] = [:]
        var unitNamesByTrait: [String: Set<String>] = [:]

        for comp in comps {
            let compRef = CompRef(id: comp.id, name: comp.name, tier: comp.tier)
            for unit in comp.units {
                costByUnit[unit.name] = unit.cost
                traitsByUnit[unit.name, default: []].formUnion(unit.traits)
                compRefsByUnit[unit.name, default: []].append(compRef)
                for trait in unit.traits {
                    unitNamesByTrait[trait, default: []].insert(unit.name)
                }
            }
        }

        var itemsByUnit: [String: [String]] = [:]
        for comp in comps {
            for carry in comp.carries {
                itemsByUnit[carry.unit, default: []].append(contentsOf: carry.itemPriority)
            }
        }
        for (unit, items) in itemsByUnit {
            var seen = Set<String>()
            itemsByUnit[unit] = items.filter { seen.insert($0).inserted }
        }

        let unitEntries = costByUnit.keys.sorted().map { name in
            UnitReference(
                name: name,
                cost: costByUnit[name] ?? 0,
                traits: (traitsByUnit[name] ?? []).sorted(),
                recommendedItems: itemsByUnit[name] ?? [],
                comps: (compRefsByUnit[name] ?? []).sorted { $0.name < $1.name }
            )
        }.sorted { lhs, rhs in
            lhs.cost == rhs.cost ? lhs.name < rhs.name : lhs.cost < rhs.cost
        }

        let traitEntries = unitNamesByTrait.keys.sorted().map { name in
            TraitReference(
                name: name,
                breakpoints: TraitCatalog.breakpoints(for: name),
                units: (unitNamesByTrait[name] ?? [])
                    .sorted()
                    .map { UnitRef(name: $0, cost: costByUnit[$0] ?? 0) }
            )
        }

        units = unitEntries
        traits = traitEntries
        unitsByName = Dictionary(uniqueKeysWithValues: unitEntries.map { ($0.name, $0) })
        traitsByName = Dictionary(uniqueKeysWithValues: traitEntries.map { ($0.name, $0) })
    }

    public func unit(named name: String) -> UnitReference? {
        unitsByName[name]
    }

    public func trait(named name: String) -> TraitReference? {
        traitsByName[name]
    }
}
