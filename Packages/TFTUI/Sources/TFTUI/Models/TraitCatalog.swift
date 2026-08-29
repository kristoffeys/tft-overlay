/// Style tier names, in ascending order, that a trait's breakpoints step through.
public enum TraitStyle: String, CaseIterable, Sendable {
    case bronze = "Bronze"
    case silver = "Silver"
    case gold = "Gold"
    case chromatic = "Chromatic"
}

/// One activation count on a trait's breakpoint ladder, e.g. "4 -> Silver".
public struct TraitBreakpoint: Identifiable, Hashable, Sendable {
    public var id: Int {
        count
    }

    public let count: Int
    public let style: TraitStyle

    public init(count: Int, style: TraitStyle) {
        self.count = count
        self.style = style
    }
}

/// Hand-authored trait breakpoints for Set 18, in the same spirit as
/// `data/comps/` (see ADR 0002): there is no API for this data, so it is
/// maintained by hand and re-authored as traits change per set/patch.
///
/// `Comp.units[].traits` only ever carries a trait by name, so this catalog
/// is the one place that name resolves to breakpoints and style tiers for
/// the unit/trait reference panel (#26). A trait used by a loaded comp but
/// missing here (not yet catalogued) resolves to an empty breakpoint list
/// rather than crashing — callers show "no breakpoint data" for it.
public enum TraitCatalog {
    /// Breakpoints in ascending activation-count order.
    private static let breakpointsByTrait: [String: [Int]] = [
        "Elderwood": [2, 4, 6, 8],
        "Defender": [2, 4, 6],
        "Fae": [2, 4, 6],
        "Rapidfire": [1, 2, 3, 4],
        "Brawler": [2, 4, 6],
        "Spellweaver": [2, 4, 6],
        "Vanguard": [2, 4, 6],
        "Executioner": [2, 3, 4],
        "Sprykin": [2, 3, 4],
        "Riftbeast": [2, 4, 6],
        "Hunter": [2, 3, 4, 5],
        "Coven": [2, 4, 6],
        "Primal": [1, 2, 3, 4],
        "Blossom": [1, 2, 3],
        "Apex Predator": [1],
    ]

    /// `traitName`'s breakpoints paired with the style tier each one grants.
    /// A trait with more breakpoints than style names repeats the top style,
    /// mirroring the real game's cap at Chromatic.
    public static func breakpoints(for traitName: String) -> [TraitBreakpoint] {
        guard let counts = breakpointsByTrait[traitName] else { return [] }
        return counts.enumerated().map { index, count in
            let styleIndex = min(index, TraitStyle.allCases.count - 1)
            return TraitBreakpoint(count: count, style: TraitStyle.allCases[styleIndex])
        }
    }
}
