@testable import TFTUI
import XCTest

final class BuildStagePlanTests: XCTestCase {
    // MARK: - Fixtures

    /// The shape most of the real corpus has: cheap units, two carries, and a
    /// level plan with rows only at `3-2` and `5-2`.
    private func denseComp() throws -> Comp {
        try CompFixture.make(
            id: "dense",
            tier: .s,
            units: [
                CompFixture.unit("Karma", cost: 1),
                CompFixture.unit("Yorick", cost: 1),
                CompFixture.unit("Vi", cost: 2),
                CompFixture.unit("Ahri", cost: 4, role: .carry),
                CompFixture.unit("Ashe", cost: 5),
            ],
            carries: [CompCarry(unit: "Ahri", itemPriority: ["Jeweled Gauntlet", "Infinity Edge"])],
            levelPlan: [
                LevelPlanEntry(stage: "2-1", level: 4, notes: "Econ"),
                LevelPlanEntry(stage: "3-2", level: 6, notes: "Roll a little"),
                LevelPlanEntry(stage: "4-5", level: 8, notes: "Roll it down"),
                LevelPlanEntry(stage: "5-2", level: 9, notes: "Add Zyra"),
            ],
            earlyOpener: "Prioritize Karma and Yorick early.",
            pivotNotes: "Gnar to Zyra."
        )
    }

    private func plan(_ comp: Comp) -> BuildStagePlan {
        BuildStagePlan(comp: comp)
    }

    // MARK: - Stage -> content selection

    func testEachBandGetsItsOwnLevelPlanRows() throws {
        let plan = try plan(denseComp())
        XCTAssertEqual(plan.section(for: .early).levelPlan.map(\.stage), ["2-1"])
        XCTAssertEqual(plan.section(for: .mid).levelPlan.map(\.stage), ["3-2", "4-5"])
        XCTAssertEqual(plan.section(for: .late).levelPlan.map(\.stage), ["5-2"])
    }

    func testBoundaryRowsLandInTheBandTheGameSaysTheyDo() throws {
        let comp = try CompFixture.make(
            id: "boundaries",
            tier: .a,
            units: [CompFixture.unit("Karma", cost: 1)],
            levelPlan: [
                LevelPlanEntry(stage: "2-5", level: 5),
                LevelPlanEntry(stage: "3-1", level: 6),
                LevelPlanEntry(stage: "4-5", level: 8),
                LevelPlanEntry(stage: "5-1", level: 9),
            ]
        )
        let plan = plan(comp)
        XCTAssertEqual(plan.section(for: .early).levelPlan.map(\.stage), ["2-5"])
        XCTAssertEqual(plan.section(for: .mid).levelPlan.map(\.stage), ["3-1", "4-5"])
        XCTAssertEqual(plan.section(for: .late).levelPlan.map(\.stage), ["5-1"])
    }

    func testRowsAreOrderedByStageNotByCorpusOrder() throws {
        let comp = try CompFixture.make(
            id: "shuffled",
            tier: .a,
            units: [CompFixture.unit("Karma", cost: 1)],
            levelPlan: [LevelPlanEntry(stage: "4-2", level: 8), LevelPlanEntry(stage: "3-2", level: 6)]
        )
        XCTAssertEqual(plan(comp).section(for: .mid).levelPlan.map(\.stage), ["3-2", "4-2"])
    }

    func testEarlyBandCarriesOpenerCheapUnitsAndComponents() throws {
        let early = try plan(denseComp()).section(for: .early)
        XCTAssertEqual(early.opener, "Prioritize Karma and Yorick early.")
        XCTAssertEqual(
            early.openerUnits.map(\.name),
            ["Karma", "Yorick", "Vi"],
            "no authored early roster, so the cheap fallback applies: cheapest first, name-stable"
        )
        // Jeweled Gauntlet is the BiS; Infinity Edge is an alternate and must
        // not dilute what the player is told to hold.
        XCTAssertEqual(early.componentsToHold.sorted(), ["Needlessly Large Rod", "Sparring Gloves"])
        XCTAssertNil(early.itemisePriority)
        XCTAssertNil(early.pivots)
        XCTAssertFalse(early.showsFinalBoard)
    }

    func testMidBandNamesTheCarryToItemiseFirst() throws {
        let mid = try plan(denseComp()).section(for: .mid)
        XCTAssertEqual(mid.itemisePriority?.unit, "Ahri")
        XCTAssertEqual(mid.itemisePriority?.itemPriority.first, "Jeweled Gauntlet")
        XCTAssertNil(mid.opener, "the opener is over by act 3")
        XCTAssertTrue(mid.openerUnits.isEmpty)
    }

    func testLateBandCarriesPivotsAndTheFinalBoard() throws {
        let late = try plan(denseComp()).section(for: .late)
        XCTAssertEqual(late.pivots, "Gnar to Zyra.")
        XCTAssertTrue(late.showsFinalBoard)
        XCTAssertNil(late.itemisePriority)
    }

    func testSectionsAreAlwaysAllThreeBandsInOrder() throws {
        XCTAssertEqual(try plan(denseComp()).sections.map(\.band), [.early, .mid, .late])
    }

    // MARK: - Sparse corpus data

    func testCompWithOnlyAMidRowStillGivesEveryBandALevelTarget() throws {
        // `apex-predator` and `elderwood-executioners` are exactly this: a
        // single `3-2` row and nothing else.
        let comp = try CompFixture.make(
            id: "apex-shaped",
            tier: .s,
            units: [CompFixture.unit("Karma", cost: 1)],
            carries: [CompCarry(unit: "Karma", itemPriority: ["Jeweled Gauntlet"])],
            levelPlan: [LevelPlanEntry(stage: "3-2", level: 7)],
            earlyOpener: "Open Karma.",
            pivotNotes: "Nothing to pivot into."
        )
        let plan = plan(comp)

        XCTAssertNil(plan.section(for: .early).levelTarget, "nothing precedes act 3 to inherit from")
        XCTAssertEqual(plan.section(for: .mid).levelTarget?.level, 7)
        XCTAssertEqual(plan.section(for: .mid).levelTarget?.isCarriedForward, false)

        let late = plan.section(for: .late)
        XCTAssertTrue(late.levelPlan.isEmpty)
        XCTAssertEqual(late.levelTarget?.level, 7)
        XCTAssertEqual(late.levelTarget?.stage.label, "3-2")
        XCTAssertTrue(late.levelTarget?.isCarriedForward ?? false, "a skipped band inherits rather than going blank")
    }

    func testBandWithNothingToSayIsStillPresentAndReportsItself() throws {
        let comp = try CompFixture.make(
            id: "bare",
            tier: .d,
            units: [CompFixture.unit("Ashe", cost: 5)],
            levelPlan: [LevelPlanEntry(stage: "3-2", level: 6)]
        )
        let plan = plan(comp)
        XCTAssertTrue(plan.section(for: .early).isEmpty, "no opener, nothing cheap to open on, no components, no rows")
        XCTAssertFalse(plan.section(for: .mid).isEmpty)
        XCTAssertFalse(plan.section(for: .late).isEmpty, "the final board always belongs to Late")
        XCTAssertEqual(plan.sections.count, StageBand.allCases.count, "an empty band is never dropped")
    }

    func testLevelTargetIsTheLastRowInTheBandNotTheFirst() throws {
        let plan = try plan(denseComp())
        XCTAssertEqual(plan.section(for: .mid).levelTarget?.level, 8, "4-5 is still in force when act 4 ends")
        XCTAssertEqual(plan.section(for: .mid).levelTarget?.stage.label, "4-5")
    }

    // MARK: - Nothing from the corpus is lost

    func testRowsSharingAStageAreMergedRatherThanDropped() throws {
        // `riftbeast-summoners` ships two `5-2` rows with *different* advice.
        // LevelPlanEntry.id is the stage, so both cannot reach a ForEach — but
        // keeping only the first loses "Alistar, Gnar" from the panel entirely.
        let comp = try CompFixture.make(
            id: "riftbeast-shaped",
            tier: .a,
            units: [CompFixture.unit("Karma", cost: 1)],
            levelPlan: [
                LevelPlanEntry(stage: "5-2", level: 9, notes: "At level 9 you can add: Ashe, Ivern, Maokai."),
                LevelPlanEntry(stage: "5-2", level: 9, notes: "At level 9 you can add: Alistar, Gnar."),
            ]
        )
        let late = plan(comp).section(for: .late)
        XCTAssertEqual(late.levelPlan.count, 1, "one identity per stage")
        let notes = try XCTUnwrap(late.levelPlan.first?.notes)
        XCTAssertTrue(notes.contains("Ashe, Ivern, Maokai"), notes)
        XCTAssertTrue(notes.contains("Alistar, Gnar"), "the second row's advice survived the merge")
    }

    func testByteIdenticalRowsCollapseToOne() throws {
        let comp = try CompFixture.make(
            id: "true-duplicate",
            tier: .a,
            units: [CompFixture.unit("Karma", cost: 1)],
            levelPlan: [
                LevelPlanEntry(stage: "5-2", level: 9, notes: "Add Zyra."),
                LevelPlanEntry(stage: "5-2", level: 9, notes: "Add Zyra."),
            ]
        )
        let late = plan(comp).section(for: .late)
        XCTAssertEqual(late.levelPlan.count, 1)
        XCTAssertEqual(late.levelPlan.first?.notes, "Add Zyra.", "a real duplicate is not repeated at the player")
    }

    /// The merged row can only be keyed to one level, so a second row naming a
    /// different one keeps its number inside its own text rather than losing it.
    func testMergedRowsKeepALevelThatDisagrees() throws {
        let comp = try CompFixture.make(
            id: "disagreeing-levels",
            tier: .a,
            units: [CompFixture.unit("Karma", cost: 1)],
            levelPlan: [
                LevelPlanEntry(stage: "5-2", level: 9, notes: "Add Zyra."),
                LevelPlanEntry(stage: "5-2", level: 10, notes: "Add Ashe."),
                LevelPlanEntry(stage: "5-2", level: 8),
            ]
        )
        let row = try XCTUnwrap(plan(comp).section(for: .late).levelPlan.first)
        XCTAssertEqual(row.level, 9, "the first row keys the merged one")
        let notes = try XCTUnwrap(row.notes)
        XCTAssertTrue(notes.contains("Add Zyra."), notes)
        XCTAssertTrue(notes.contains("Level 10: Add Ashe."), notes)
        XCTAssertTrue(notes.contains("Level 8"), "a bare row with a different level is still a fact")
    }

    /// A trailing newline is scraper noise, not a data defect: the row belongs
    /// in its band, keyed to the stage's own notation rather than to the raw
    /// string the badge would draw a line break inside.
    func testRowsWithScraperNewlinesAreBandedNotUnplaced() throws {
        let comp = try CompFixture.make(
            id: "newline",
            tier: .a,
            units: [CompFixture.unit("Karma", cost: 1)],
            levelPlan: [
                LevelPlanEntry(stage: "1-2\n", level: 3, notes: "Open"),
                LevelPlanEntry(stage: " 3-2 ", level: 6),
            ]
        )
        let plan = plan(comp)
        XCTAssertTrue(plan.unscheduledEntries.isEmpty, "a line break is not a data defect")
        XCTAssertEqual(plan.section(for: .early).levelPlan.map(\.stage), ["1-2"])
        XCTAssertEqual(plan.section(for: .mid).levelPlan.map(\.stage), ["3-2"])
    }

    func testUnparseableStageRowsAreSurfacedRatherThanDropped() throws {
        let comp = try CompFixture.make(
            id: "typo",
            tier: .b,
            units: [CompFixture.unit("Karma", cost: 1)],
            levelPlan: [LevelPlanEntry(stage: "3-2", level: 6), LevelPlanEntry(stage: "stage four", level: 8)]
        )
        let plan = plan(comp)
        XCTAssertEqual(plan.unscheduledEntries.map(\.stage), ["stage four"])
        XCTAssertEqual(plan.sections.flatMap(\.levelPlan).count, 1)
    }

    /// Two rows whose stage strings are equally unparseable are two rows.
    ///
    /// They share `LevelPlanEntry.id`, so this is where a naive `ForEach` drops
    /// one — see `StageCompanionSnapshotTests`, which measures that they both
    /// actually draw. Today's corpus has no unparseable row at all, but it is
    /// scraper output and gets re-run.
    func testTwoRowsWithTheSameUnparseableStageAreBothKept() throws {
        let comp = try CompFixture.make(
            id: "twice-mangled",
            tier: .b,
            units: [CompFixture.unit("Karma", cost: 1)],
            levelPlan: [
                LevelPlanEntry(stage: "bogus", level: 6, notes: "first"),
                LevelPlanEntry(stage: "bogus", level: 8, notes: "second"),
            ]
        )
        let plan = plan(comp)
        XCTAssertEqual(plan.unscheduledEntries.map(\.notes), ["first", "second"])
        XCTAssertTrue(plan.sections.allSatisfy(\.levelPlan.isEmpty), "an unparseable stage is not banded")
    }

    /// The contract in one assertion: every piece of advice the corpus wrote
    /// down is still readable somewhere in the plan.
    ///
    /// Deliberately not a row count. Counting rows against *distinct stages* is
    /// what the previous version of this test did, and it certified the very
    /// bug it was meant to catch: `riftbeast-summoners`' second `5-2` row was
    /// dropped, the count still matched, the test still passed, and "add
    /// Alistar, Gnar" never reached the panel.
    func testNoAdviceIsLostAcrossTheRealCorpus() throws {
        let comps = try CompLoader.bundledFixtures()
        XCTAssertEqual(comps.count, 36, "the corpus this measures")
        for comp in comps {
            let plan = BuildStagePlan(comp: comp)
            let rendered = plan.sections.flatMap(\.levelPlan) + plan.unscheduledEntries
            let renderedNotes = rendered.compactMap(\.notes)

            for notes in Set(comp.levelPlan.compactMap(\.notes)) where !notes.isEmpty {
                XCTAssertTrue(
                    renderedNotes.contains { $0.contains(notes) },
                    "\(comp.id) lost the advice \(notes.debugDescription)"
                )
            }

            // Stages too: advice is optional in the schema, so a row with no
            // notes at all still has to be somewhere.
            let renderedStages = Set(rendered.map(\.stage))
            for stage in Set(comp.levelPlan.map(\.stage)) {
                let expected = GameStage(stage)?.label ?? stage
                XCTAssertTrue(renderedStages.contains(expected), "\(comp.id) lost the stage \(expected)")
            }
        }
    }

    // MARK: - The player who never advances the stage

    func testDefaultBandShowsAdviceAndEveryOtherBandStaysReadable() throws {
        let plan = try plan(denseComp())
        let current = plan.section(for: .initial)
        XCTAssertEqual(current.band, .early)
        XCTAssertFalse(current.isEmpty, "the default band must say something on its own")

        // The no-op path: the player never touches the stepper, so everything
        // the detail view would have shown must still be reachable from the
        // three sections plus the unbanded remainder.
        let comp = try denseComp()
        XCTAssertEqual(plan.sections.flatMap(\.levelPlan).count, comp.levelPlan.count)
        XCTAssertTrue(plan.sections.contains { $0.opener != nil })
        XCTAssertTrue(plan.sections.contains { $0.pivots != nil })
        XCTAssertTrue(plan.sections.contains(where: \.showsFinalBoard))
    }
}
