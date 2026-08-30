/// A point in a TFT game in the client's own `act-round` notation (`3-2`).
///
/// Parsing rather than storing the raw string matters because the corpus is
/// scraper output (ADR 0004): `levelPlan` entries arrive in whatever order the
/// source page listed them, so "which entry applies now" cannot be answered by
/// array position, and `"2-5" < "3-1"` only happens to hold lexicographically
/// while both acts are single digits.
public struct GameStage: Hashable, Comparable, Sendable {
    public let act: Int
    public let round: Int

    public init(act: Int, round: Int) {
        self.act = act
        self.round = round
    }

    /// Nil for anything that isn't two non-negative integers around a single
    /// hyphen. A scraped stage string that fails to parse is a data defect, not
    /// a stage — callers surface those separately rather than guessing an act
    /// for them, so nothing the corpus carries is silently dropped.
    ///
    /// Surrounding whitespace *and newlines* are ignored: the corpus is
    /// scraper output (ADR 0004), where a cell copied with its line break
    /// arrives as `"1-2\n"`. Treating that as a data defect would exile a
    /// perfectly good row to "Unplaced plan rows" over a character the player
    /// cannot see.
    public init?(_ raw: String) {
        let parts = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let act = Int(parts[0]), let round = Int(parts[1]),
              act >= 0, round >= 0
        else { return nil }
        self.init(act: act, round: round)
    }

    public var label: String {
        "\(act)-\(round)"
    }

    public static func < (lhs: GameStage, rhs: GameStage) -> Bool {
        lhs.act != rhs.act ? lhs.act < rhs.act : lhs.round < rhs.round
    }
}

/// The three phases of a game a player actually plans in.
///
/// Bands, not stages, because the panel this drives is set by hand mid-game
/// (#84): a stepper with twenty positions would be abandoned by round three,
/// and a three-position one that is one keystroke wide might not be. The
/// boundaries are the ones the game itself uses — carousel-to-carousel — so
/// "am I still in Early" is a question the player can answer by looking at the
/// board rather than by counting rounds.
public enum StageBand: String, CaseIterable, Identifiable, Sendable {
    /// `1-1` through `2-5`: the opener, before any real commitment.
    case early
    /// `3-1` through `4-5`: levelling, rolling, itemising.
    case mid
    /// `5-1` onward: the final board, positioning, and pivots.
    case late

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .early: "Early"
        case .mid: "Mid"
        case .late: "Late"
        }
    }

    /// The band's span, for the header. `late` is open-ended: games run to
    /// `6-x` and beyond, and naming a false upper bound would make a player
    /// past it think the panel had stopped applying.
    public var stageSpan: String {
        switch self {
        case .early: "1-1 – 2-5"
        case .mid: "3-1 – 4-5"
        case .late: "5-1 +"
        }
    }

    /// The band a stage falls in. Total by construction — every act maps
    /// somewhere, including act 0 (which the corpus should never contain) and
    /// acts past 5, so no stage the scraper produces can go unplaced.
    public static func containing(_ stage: GameStage) -> StageBand {
        switch stage.act {
        case ..<3: .early
        case 3, 4: .mid
        default: .late
        }
    }

    /// The band one step later, or nil at `late`.
    ///
    /// Deliberately not wrapping: advancing is the gesture a player makes
    /// under pressure, and a stepper that silently jumps from Late back to
    /// Early on an extra keypress would show act-1 advice during a top-four
    /// fight. Running off the end is the safe failure.
    public var next: StageBand? {
        switch self {
        case .early: .mid
        case .mid: .late
        case .late: nil
        }
    }

    /// Where the panel starts: the earliest band, so a player who never
    /// touches the control still opens on the advice that is correct at the
    /// moment they commit to a build.
    public static let initial: StageBand = .early
}
