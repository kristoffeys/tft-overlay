import TFTData

/// One committed build, sliced into "what do I do right now" per stage band
/// (#84).
///
/// `CompDetailView` renders the same `Comp` as seven stacked sections, which is
/// the right artifact between games and the wrong one during a fight: the level
/// target that applies this round is a row in a list of all of them. This type
/// answers the in-game question instead, and answers it for *every* band at
/// once — the panel shows the current band large and keeps the others
/// de-emphasised below it, because the stage is set by hand and a player who
/// never touches the control must still see the whole plan.
///
/// Everything here comes from the comp the player already pinned. No opponent,
/// lobby, or live-game data feeds it (issue #68), and nothing is scraped at
/// runtime: `levelPlan`, `earlyOpener` and `pivotNotes` are already stage-keyed
/// in the corpus.
public struct BuildStagePlan: Sendable {
    /// Units cheap enough to actually appear in the shop while the opener is
    /// still being built. 3-costs are excluded even though they show up from
    /// 2-1: hitting one early is luck, and listing it as "buy now" turns a
    /// glance-layer into a wishlist.
    public static let buyableEarlyCostLimit = 2

    /// The plan for one band, already reduced to what that band needs.
    ///
    /// Fields that don't apply to a band are empty rather than optional-per-
    /// band-enum: the view renders whatever is non-empty, so a corpus that
    /// grows opener text for late-game pivots later needs no new case here.
    public struct Section: Identifiable, Sendable {
        public var id: StageBand {
            band
        }

        public let band: StageBand
        /// This band's `levelPlan` rows, earliest first. Frequently empty —
        /// most of the real corpus carries only `3-2` and `5-2` — which is
        /// exactly why `levelTarget` exists.
        public let levelPlan: [LevelPlanEntry]
        /// The level to be at, and whether it had to be inherited from an
        /// earlier band because this one has no row of its own.
        public let levelTarget: LevelTarget?
        /// The comp's `earlyOpener`, on the early band only.
        public let opener: String?
        /// This comp's own 1- and 2-cost units: the ones the player can act on
        /// while the shop is still cheap, as opposed to the full roster.
        public let buyableUnits: [CompUnit]
        /// Components worth holding, decomposed from the carries' best-in-slot
        /// items. Names, not `Item`s, so the view stays free to render an icon
        /// or a label without this type knowing which.
        public let componentsToHold: [String]
        /// The carry to build first, and its item priority. Mid-game only —
        /// early there is nothing to itemise yet, late it is already done.
        public let itemisePriority: CompCarry?
        /// The comp's `pivotNotes`, on the late band only.
        public let pivots: String?
        /// Whether this band wants the final board drawn. Late only: before
        /// then the board is aspirational, and it is the single tallest thing
        /// the detail view draws.
        public let showsFinalBoard: Bool

        /// Whether this band has nothing of its own to say. The view still
        /// renders an empty band — collapsed, with its span — rather than
        /// hiding it, so a sparse comp reads as "no extra advice here" instead
        /// of as a band that does not exist.
        public var isEmpty: Bool {
            levelPlan.isEmpty && opener == nil && buyableUnits.isEmpty
                && componentsToHold.isEmpty && itemisePriority == nil && pivots == nil && !showsFinalBoard
        }
    }

    /// A level to play toward. `isCarriedForward` marks a target inherited
    /// from an earlier band because this one has no `levelPlan` row: showing
    /// "Level 6 (from 3-2)" during act 5 is honest about a sparse comp, where
    /// showing a bare "Level 6" would read as a fresh instruction and showing
    /// nothing would leave the band blank for most of the corpus.
    public struct LevelTarget: Hashable, Sendable {
        public let level: Int
        public let stage: GameStage
        public let isCarriedForward: Bool
    }

    /// One section per band, always all three and always in band order.
    public let sections: [Section]

    /// `levelPlan` rows whose `stage` string didn't parse as `act-round`.
    ///
    /// Kept rather than dropped: this panel replaces the detail view's level
    /// plan for the pinned build, and losing a row to a scraper typo would make
    /// it strictly worse than what it replaced. The view shows these once,
    /// unbanded.
    public let unscheduledEntries: [LevelPlanEntry]

    public init(comp: Comp, recipeMatrix: RecipeMatrix = RecipeMatrix()) {
        let (scheduled, unscheduled) = Self.partition(comp.levelPlan)
        unscheduledEntries = unscheduled

        let byBand = Dictionary(grouping: scheduled) { StageBand.containing($0.stage) }
        var carried: (level: Int, stage: GameStage)?
        var built: [Section] = []
        for band in StageBand.allCases {
            let entries = (byBand[band] ?? []).sorted { $0.stage < $1.stage }
            let target = Self.levelTarget(for: entries, carriedForward: carried)
            if let last = entries.last {
                carried = (last.entry.level, last.stage)
            }
            built.append(Self.section(band, comp: comp, entries: entries, target: target, recipeMatrix: recipeMatrix))
        }
        sections = built
    }

    public func section(for band: StageBand) -> Section {
        // `sections` is built from `StageBand.allCases`, so this is total.
        sections.first { $0.band == band } ?? sections[0]
    }

    // MARK: - Construction

    /// A `levelPlan` row with its stage resolved, so the band grouping and the
    /// sort don't each re-parse the string.
    private struct DatedEntry {
        let stage: GameStage
        let entry: LevelPlanEntry
    }

    /// Splits parseable rows from unparseable ones and merges rows that share a
    /// stage into one.
    ///
    /// Duplicates are real and they are not always duplicates:
    /// `riftbeast-summoners` ships two `5-2` rows carrying *different* advice
    /// ("add Ashe, Ivern, Maokai" and "add Alistar, Gnar"). `LevelPlanEntry.id`
    /// is its stage, so both cannot reach a SwiftUI `ForEach` — but keeping the
    /// first and dropping the second is silent data loss, which is exactly what
    /// this type promises not to do. Merging keeps both, one identity.
    private static func partition(_ plan: [LevelPlanEntry]) -> ([DatedEntry], [LevelPlanEntry]) {
        var unscheduled: [LevelPlanEntry] = []
        // First-appearance order, not sorted: the band grouping sorts anyway,
        // and a stable order keeps the merged notes reading in corpus order.
        var order: [GameStage] = []
        var grouped: [GameStage: [LevelPlanEntry]] = [:]
        for entry in plan {
            guard let stage = GameStage(entry.stage) else {
                unscheduled.append(entry)
                continue
            }
            if grouped[stage] == nil {
                order.append(stage)
            }
            grouped[stage, default: []].append(entry)
        }
        let scheduled = order.compactMap { stage -> DatedEntry? in
            guard let rows = grouped[stage], let merged = merged(rows, at: stage) else { return nil }
            return DatedEntry(stage: stage, entry: merged)
        }
        return (scheduled, unscheduled)
    }

    /// One row per stage, carrying every distinct piece of advice the corpus
    /// filed under it.
    ///
    /// Byte-identical notes collapse — that is the genuine duplicate case.
    /// Notes that differ are joined, in corpus order, because a player reading
    /// "5-2" wants both sentences and cannot know a second one existed. A row
    /// naming a *different* level keeps that level inside its own text: the
    /// merged row can only be keyed to one, and the alternative is dropping the
    /// number the advice depends on.
    private static func merged(_ rows: [LevelPlanEntry], at stage: GameStage) -> LevelPlanEntry? {
        guard let first = rows.first else { return nil }
        guard rows.count > 1 else { return canonicalised(first, at: stage) }

        var seen: Set<String> = []
        var advice: [String] = []
        for row in rows {
            let notes = row.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
            let text: String
            if row.level == first.level {
                guard let notes, !notes.isEmpty else { continue }
                text = notes
            } else if let notes, !notes.isEmpty {
                text = "Level \(row.level): \(notes)"
            } else {
                text = "Level \(row.level)"
            }
            guard seen.insert(text).inserted else { continue }
            advice.append(text)
        }
        return LevelPlanEntry(
            stage: stage.label,
            level: first.level,
            notes: advice.isEmpty ? nil : advice.joined(separator: " ")
        )
    }

    /// Re-keys a parsed row to the stage's own notation.
    ///
    /// The raw string is scraper output and reaches the badge in the view
    /// verbatim, so `"1-2\n"` — which now parses rather than being exiled to
    /// the unplaced list — would otherwise draw a line break inside a 38pt
    /// chip. Once a row is parsed, `GameStage.label` is the authority on how
    /// it reads.
    private static func canonicalised(_ entry: LevelPlanEntry, at stage: GameStage) -> LevelPlanEntry {
        guard entry.stage != stage.label else { return entry }
        return LevelPlanEntry(stage: stage.label, level: entry.level, notes: entry.notes)
    }

    private static func levelTarget(
        for entries: [DatedEntry],
        carriedForward: (level: Int, stage: GameStage)?
    ) -> LevelTarget? {
        // The last row in a band is the one still in force when it ends, so
        // that is the level the band is played toward.
        if let last = entries.last {
            return LevelTarget(level: last.entry.level, stage: last.stage, isCarriedForward: false)
        }
        guard let carriedForward else { return nil }
        return LevelTarget(level: carriedForward.level, stage: carriedForward.stage, isCarriedForward: true)
    }

    private static func section(
        _ band: StageBand,
        comp: Comp,
        entries: [DatedEntry],
        target: LevelTarget?,
        recipeMatrix: RecipeMatrix
    ) -> Section {
        let isEarly = band == .early
        return Section(
            band: band,
            levelPlan: entries.map(\.entry),
            levelTarget: target,
            opener: isEarly ? nonEmpty(comp.earlyOpener) : nil,
            buyableUnits: isEarly ? buyableUnits(comp) : [],
            componentsToHold: isEarly ? componentsToHold(comp, recipeMatrix: recipeMatrix) : [],
            // The primary carry is the first one authored; item priority is
            // ordered BiS-first, so "itemise this one first" needs no scoring.
            itemisePriority: band == .mid ? comp.carries.first : nil,
            pivots: band == .late ? nonEmpty(comp.pivotNotes) : nil,
            showsFinalBoard: band == .late
        )
    }

    /// Cheapest first so the list reads in the order the shop makes them
    /// available; name ascending within a cost keeps it stable run to run.
    private static func buyableUnits(_ comp: Comp) -> [CompUnit] {
        comp.units
            .filter { $0.cost <= buyableEarlyCostLimit }
            .sorted { $0.cost != $1.cost ? $0.cost < $1.cost : $0.name < $1.name }
    }

    /// The components behind every carry's best-in-slot item, most-wanted
    /// first. Only the BiS item counts: a held component should serve the item
    /// the player is actually going to build, and folding in every alternate
    /// flattens the ranking until half the component pool ties at one.
    private static func componentsToHold(_ comp: Comp, recipeMatrix: RecipeMatrix) -> [String] {
        let completedByName = Dictionary(
            recipeMatrix.completedItems.map { ($0.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var demand: [String: Int] = [:]
        for carry in comp.carries {
            // An item priority can legitimately name an emblem or artifact,
            // which has no two-component recipe; those contribute nothing
            // rather than aborting the carry.
            guard let bis = carry.itemPriority.first,
                  let completed = completedByName[bis],
                  let recipe = recipeMatrix.recipe(for: completed)
            else { continue }
            demand[recipe.0.name, default: 0] += 1
            demand[recipe.1.name, default: 0] += 1
        }
        return demand
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .map(\.key)
    }

    private static func nonEmpty(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
