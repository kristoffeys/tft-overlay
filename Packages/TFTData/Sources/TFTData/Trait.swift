public struct Trait: Identifiable, Hashable, Sendable, Codable {
    /// One activation breakpoint: the unit-count range it covers and the visual
    /// style tier (bronze/silver/gold/etc.) the game assigns it. The raw
    /// integer meaning of `style` is set-defined by Riot and not interpreted
    /// here — this package passes it through as data.
    public struct Level: Hashable, Sendable, Codable {
        public let minUnits: Int
        public let maxUnits: Int
        public let style: Int

        public init(minUnits: Int, maxUnits: Int, style: Int) {
            self.minUnits = minUnits
            self.maxUnits = maxUnits
            self.style = style
        }
    }

    public let id: String
    public let name: String
    public let levels: [Level]

    /// The unit counts at which the trait activates. Derived from `levels`
    /// for callers that only need the breakpoint numbers, not the style tier.
    public var breakpoints: [Int] {
        levels.map(\.minUnits)
    }

    public init(id: String, name: String, levels: [Level]) {
        self.id = id
        self.name = name
        self.levels = levels
    }

    /// Convenience initializer for callers that only have breakpoint counts
    /// (e.g. hand-authored fixtures/tests) and no style-tier data.
    public init(id: String, name: String, breakpoints: [Int]) {
        self.id = id
        self.name = name
        levels = breakpoints.map { Level(minUnits: $0, maxUnits: Int.max, style: 0) }
    }
}
