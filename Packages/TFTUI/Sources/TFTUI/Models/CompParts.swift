/// A champion entry within a `Comp`'s `units` list.
public struct CompUnit: Identifiable, Hashable, Sendable, Codable {
    public var id: String {
        name
    }

    public let name: String
    public let cost: Int
    public let starTarget: Int
    public let role: Role
    public let traits: [String]
    public let flex: Bool

    public enum Role: String, Codable, Sendable, CaseIterable {
        case carry, frontline, utility, support
    }

    public init(name: String, cost: Int, starTarget: Int, role: Role, traits: [String], flex: Bool = false) {
        self.name = name
        self.cost = cost
        self.starTarget = starTarget
        self.role = role
        self.traits = traits
        self.flex = flex
    }

    private enum CodingKeys: String, CodingKey {
        case name, cost, starTarget, role, traits, flex
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        cost = try container.decode(Int.self, forKey: .cost)
        starTarget = try container.decode(Int.self, forKey: .starTarget)
        role = try container.decode(Role.self, forKey: .role)
        traits = try container.decode([String].self, forKey: .traits)
        flex = try container.decodeIfPresent(Bool.self, forKey: .flex) ?? false
    }
}

/// A carry's item priority within a `Comp`'s `carries` list. `unit` matches
/// a `CompUnit.name` with role `.carry`.
public struct CompCarry: Identifiable, Hashable, Sendable, Codable {
    public var id: String {
        unit
    }

    public let unit: String
    public let itemPriority: [String]
    public let itemNotes: String?

    public init(unit: String, itemPriority: [String], itemNotes: String? = nil) {
        self.unit = unit
        self.itemPriority = itemPriority
        self.itemNotes = itemNotes
    }
}

/// The 4x7 hex final-board layout, row 0 closest to the enemy.
public struct BoardPositioning: Hashable, Sendable, Codable {
    public let grid: [[String?]]
    public let notes: String?

    public init(grid: [[String?]], notes: String? = nil) {
        self.grid = grid
        self.notes = notes
    }
}

/// Preferred augments per tier, most preferred first.
public struct AugmentPreferences: Hashable, Sendable, Codable {
    public let tier1: [String]
    public let tier2: [String]
    public let tier3: [String]

    public init(tier1: [String], tier2: [String], tier3: [String]) {
        self.tier1 = tier1
        self.tier2 = tier2
        self.tier3 = tier3
    }
}

/// One row of a comp's level-by-stage plan.
public struct LevelPlanEntry: Identifiable, Hashable, Sendable, Codable {
    public var id: String {
        stage
    }

    public let stage: String
    public let level: Int
    public let notes: String?

    public init(stage: String, level: Int, notes: String? = nil) {
        self.stage = stage
        self.level = level
        self.notes = notes
    }
}
