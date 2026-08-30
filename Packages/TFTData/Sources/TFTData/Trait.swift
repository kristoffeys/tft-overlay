import Foundation

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
    /// Trait icon on Community Dragon's asset mirror; see
    /// `Champion.imageURL` for why this is best-effort. These are small
    /// (32x32) greyscale glyphs — the game tints them per activation tier
    /// at render time, so "greyscale" is the asset working as intended,
    /// not a broken download.
    public let imageURL: URL?

    /// The unit counts at which the trait activates. Derived from `levels`
    /// for callers that only need the breakpoint numbers, not the style tier.
    public var breakpoints: [Int] {
        levels.map(\.minUnits)
    }

    public init(id: String, name: String, levels: [Level], imageURL: URL? = nil) {
        self.id = id
        self.name = name
        self.levels = levels
        self.imageURL = imageURL
    }

    /// Convenience initializer for callers that only have breakpoint counts
    /// (e.g. hand-authored fixtures/tests) and no style-tier data.
    public init(id: String, name: String, breakpoints: [Int], imageURL: URL? = nil) {
        self.id = id
        self.name = name
        levels = breakpoints.map { Level(minUnits: $0, maxUnits: Int.max, style: 0) }
        self.imageURL = imageURL
    }
}
