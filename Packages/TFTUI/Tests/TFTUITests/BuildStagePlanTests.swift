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
        XCTAssertEqual(early.buyableUnits.map(\.name), ["Karma", "Yorick", "Vi"], "cheapest first, name-stable")
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
        XCTAssertTrue(mid.buyableUnits.isEmpty)
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
        XCTAssertTrue(plan.section(for: .early).isEmpty, "no opener, no cheap units, no components, no rows")
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

    func testDuplicateStageRowsAreCollapsedKeepingTheFirst() throws {
        // `riftbeast-summoners` ships two `5-2` rows, and LevelPlanEntry.id is
        // the stage: handing both to a ForEach is a duplicate-identity bug.
        let comp = try CompFixture.make(
            id: "riftbeast-shaped",
            tier: .a,
            units: [CompFixture.unit("Karma", cost: 1)],
            levelPlan: [
                LevelPlanEntry(stage: "5-2", level: 9, notes: "first"),
                LevelPlanEntry(stage: "5-2", level: 9, notes: "second"),
            ]
        )
        let late = plan(comp).section(for: .late)
        XCTAssertEqual(late.levelPlan.count, 1)
        XCTAssertEqual(late.levelPlan.first?.notes, "first")
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

    func testNoRowIsLostAcrossTheRealCorpus() throws {
        let comps = try CompLoader.bundledFixtures()
        XCTAssertFalse(comps.isEmpty)
        for comp in comps {
            let plan = BuildStagePlan(comp: comp)
            let placed = plan.sections.flatMap(\.levelPlan).count + plan.unscheduledEntries.count
            let distinctStages = Set(comp.levelPlan.map(\.stage)).count
            XCTAssertEqual(placed, distinctStages, "\(comp.id) lost a level-plan row")
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
