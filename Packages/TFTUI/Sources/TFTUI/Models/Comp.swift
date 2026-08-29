import TFTData

/// A hand-authored or machine-derived team composition, decoded verbatim
/// from `docs/schema/comp.schema.json`. See ADR 0002 for provenance.
public struct Comp: Identifiable, Hashable, Sendable, Codable {
    public let schemaVersion: String
    public let id: String
    public let name: String
    public let set: Int
    public let patch: String
    public let source: Source
    public let tier: Tier
    public let playstyle: Playstyle
    public let difficulty: Difficulty
    public let compDescription: String?
    public let units: [CompUnit]
    public let carries: [CompCarry]
    public let boardPositioning: BoardPositioning
    public let augmentPreferences: AugmentPreferences
    public let levelPlan: [LevelPlanEntry]
    public let earlyOpener: String
    public let pivotNotes: String

    public enum Source: String, Codable, Sendable, CaseIterable {
        case handAuthored = "hand-authored"
        case matchDerived = "match-derived"
        case licensedFeed = "licensed-feed"
    }

    public enum Tier: String, Codable, Sendable, CaseIterable, Comparable {
        // Tier letters mirror the schema's "S".."D" values verbatim.
        // swiftlint:disable:next identifier_name
        case s = "S", a = "A", b = "B", c = "C", d = "D"

        private var rank: Int {
            switch self {
            case .s: 0
            case .a: 1
            case .b: 2
            case .c: 3
            case .d: 4
            }
        }

        public static func < (lhs: Tier, rhs: Tier) -> Bool {
            lhs.rank < rhs.rank
        }
    }

    public enum Playstyle: String, Codable, Sendable, CaseIterable {
        case fastEight = "fast_8"
        case slowRoll = "slow_roll"
        case reroll

        public var displayName: String {
            switch self {
            case .fastEight: "Fast 8"
            case .slowRoll: "Slow Roll"
            case .reroll: "Reroll"
            }
        }
    }

    public enum Difficulty: String, Codable, Sendable, CaseIterable, Comparable {
        case easy, medium, hard

        private var rank: Int {
            switch self {
            case .easy: 0
            case .medium: 1
            case .hard: 2
            }
        }

        public static func < (lhs: Difficulty, rhs: Difficulty) -> Bool {
            lhs.rank < rhs.rank
        }
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, name, set, patch, source, tier, playstyle, difficulty
        case compDescription = "description"
        case units, carries, boardPositioning, augmentPreferences, levelPlan, earlyOpener, pivotNotes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(String.self, forKey: .schemaVersion)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        set = try container.decode(Int.self, forKey: .set)
        patch = try container.decode(String.self, forKey: .patch)
        source = try container.decodeIfPresent(Source.self, forKey: .source) ?? .handAuthored
        tier = try container.decode(Tier.self, forKey: .tier)
        playstyle = try container.decode(Playstyle.self, forKey: .playstyle)
        difficulty = try container.decode(Difficulty.self, forKey: .difficulty)
        compDescription = try container.decodeIfPresent(String.self, forKey: .compDescription)
        units = try container.decode([CompUnit].self, forKey: .units)
        carries = try container.decode([CompCarry].self, forKey: .carries)
        boardPositioning = try container.decode(BoardPositioning.self, forKey: .boardPositioning)
        augmentPreferences = try container.decode(AugmentPreferences.self, forKey: .augmentPreferences)
        levelPlan = try container.decode([LevelPlanEntry].self, forKey: .levelPlan)
        earlyOpener = try container.decode(String.self, forKey: .earlyOpener)
        pivotNotes = try container.decode(String.self, forKey: .pivotNotes)
    }
}

public extension Comp {
    /// Carries paired with their full unit entry, dropping any carry whose
    /// `unit` doesn't resolve (which would itself be a data bug).
    var carryUnits: [(carry: CompCarry, unit: CompUnit)] {
        carries.compactMap { carry in
            guard let unit = units.first(where: { $0.name == carry.unit }) else { return nil }
            return (carry, unit)
        }
    }

    /// Lowercased blob of comp name, unit names and trait names, for a
    /// single `contains` search-box check.
    var searchableText: String {
        ([name] + units.map(\.name) + units.flatMap(\.traits))
            .joined(separator: " ")
            .lowercased()
    }
}
