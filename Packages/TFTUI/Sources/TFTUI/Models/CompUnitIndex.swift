/// What a hover tooltip needs to say about one champion: who it is, and
/// what it wants to hold. Purely derived from a `Comp`, so it is testable
/// without a view.
public struct UnitItemSummary: Hashable, Sendable {
    public let name: String
    public let cost: Int?
    public let role: CompUnit.Role?
    public let starTarget: Int?
    public let itemPriority: [String]
    public let itemNotes: String?

    public init(
        name: String,
        cost: Int? = nil,
        role: CompUnit.Role? = nil,
        starTarget: Int? = nil,
        itemPriority: [String] = [],
        itemNotes: String? = nil
    ) {
        self.name = name
        self.cost = cost
        self.role = role
        self.starTarget = starTarget
        self.itemPriority = itemPriority
        self.itemNotes = itemNotes
    }

    /// False for frontline/utility units that are not itemised carries —
    /// the common case when hovering a board hex.
    public var hasItemPriority: Bool {
        itemPriority.isEmpty == false
    }

    /// Label for the item at `index` in the priority list, matching the
    /// wording of the "Carries & Items" section.
    public static func priorityLabel(_ index: Int) -> String {
        index == 0 ? "BiS" : "Alt \(index)"
    }
}

/// Name-keyed view of a comp's units and carries, so a board hex — which
/// only knows a unit's name — can resolve item priority on hover without
/// rescanning the comp on every mouse move.
public struct CompUnitIndex: Hashable, Sendable {
    public static let empty = CompUnitIndex(units: [], carries: [])

    private let unitsByName: [String: CompUnit]
    private let carriesByName: [String: CompCarry]

    public init(comp: Comp) {
        self.init(units: comp.units, carries: comp.carries)
    }

    public init(units: [CompUnit], carries: [CompCarry]) {
        // Later duplicates lose to the first entry, matching `carryUnits`,
        // which resolves a carry against the first unit of that name.
        unitsByName = Dictionary(units.map { (Self.key($0.name), $0) }, uniquingKeysWith: { first, _ in first })
        carriesByName = Dictionary(carries.map { (Self.key($0.unit), $0) }, uniquingKeysWith: { first, _ in first })
    }

    public func unit(named name: String) -> CompUnit? {
        unitsByName[Self.key(name)]
    }

    public func carry(named name: String) -> CompCarry? {
        carriesByName[Self.key(name)]
    }

    /// Always answers, even for a name this comp doesn't know: an unknown
    /// name still deserves a tooltip with the name in it rather than none.
    public func summary(for name: String) -> UnitItemSummary {
        let unit = unit(named: name)
        let carry = carry(named: name)
        return UnitItemSummary(
            name: unit?.name ?? name,
            cost: unit?.cost,
            role: unit?.role,
            starTarget: unit?.starTarget,
            itemPriority: carry?.itemPriority ?? [],
            itemNotes: carry?.itemNotes
        )
    }

    /// Board grids and carry entries are hand-authored alongside the unit
    /// list, so tolerate a casing slip rather than silently dropping items.
    private static func key(_ name: String) -> String {
        name.lowercased()
    }
}
