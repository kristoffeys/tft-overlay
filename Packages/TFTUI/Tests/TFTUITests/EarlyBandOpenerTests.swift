@testable import TFTUI
import XCTest

/// What the early band tells the player to buy, and where it comes from (#107).
///
/// Split out of `BuildStagePlanTests` because this is its own contract: the
/// buy-now strip is sourced from the comp's authored `earlyUnits`, so it cannot
/// contradict the `OPEN WITH` prose one card above it, and an opener that never
/// reaches the final board is labelled rather than hidden.
final class EarlyBandOpenerTests: XCTestCase {
    private func plan(_ comp: Comp) -> BuildStagePlan {
        BuildStagePlan(comp: comp)
    }

    /// `solar-riftbeasts` as measured in #107: the authored early roster and
    /// the cheap end of the final board barely overlap, so deriving "buy now"
    /// from the final board made the panel contradict the `OPEN WITH` prose one
    /// card above it.
    private func riftbeastShapedComp() throws -> Comp {
        try CompFixture.make(
            id: "solar-shaped",
            tier: .s,
            units: [
                CompFixture.unit("Akali", cost: 1, role: .carry),
                CompFixture.unit("Leona", cost: 1),
                CompFixture.unit("Gromp", cost: 2),
                CompFixture.unit("Kayle", cost: 2),
                CompFixture.unit("Murkwolf", cost: 2),
                CompFixture.unit("Scuttlecrab", cost: 2),
                CompFixture.unit("Sejuani", cost: 2),
                CompFixture.unit("Shen", cost: 2),
            ],
            carries: [CompCarry(unit: "Akali", itemPriority: ["Infinity Edge"])],
            earlyUnits: ["Cinderling", "Gromp", "Murkwolf", "Scuttlecrab", "Krug"],
            earlyOpener: "Prioritize Cinderling, Gromp, Murkwolf, Scuttlecrab, Krug early."
        )
    }

    func testOpenerStripIsTheAuthoredEarlyRosterInProseOrder() throws {
        let early = try plan(riftbeastShapedComp()).section(for: .early)
        XCTAssertEqual(
            early.openerUnits.map(\.name),
            ["Cinderling", "Gromp", "Murkwolf", "Scuttlecrab", "Krug"],
            "corpus order, so the strip reads in the order the opener prose names them"
        )
        for absent in ["Akali", "Kayle", "Leona", "Sejuani", "Shen"] {
            XCTAssertFalse(
                early.openerUnits.contains { $0.name == absent },
                "\(absent) is a cheap unit in the final board but not something this comp opens on"
            )
        }
    }

    func testEarlyUnitsMissingFromTheFinalBoardAreMarkedTransitionalWithNoInventedCost() throws {
        let early = try plan(riftbeastShapedComp()).section(for: .early)
        let byName = Dictionary(uniqueKeysWithValues: early.openerUnits.map { ($0.name, $0) })

        for transitional in ["Cinderling", "Krug"] {
            let pick = try XCTUnwrap(byName[transitional])
            XCTAssertTrue(pick.isTransitional, "\(transitional) never reaches the final board")
            XCTAssertNil(pick.cost, "cost is single-sourced from units[]; an off-board name has none to state")
        }
        XCTAssertEqual(byName["Gromp"]?.cost, 2, "an opener that is in the build states its cost")
        XCTAssertEqual(byName["Gromp"]?.isTransitional, false)
    }

    /// `OpenerPick.id` is the name, and duplicate identities inside a SwiftUI
    /// `ForEach` are undefined behaviour by SwiftUI's own documentation.
    func testRepeatedEarlyNamesReachTheStripOnce() throws {
        let comp = try CompFixture.make(
            id: "repeated-early",
            tier: .b,
            units: [CompFixture.unit("Gromp", cost: 2)],
            earlyUnits: ["Gromp", "gromp", " Gromp ", ""],
            earlyOpener: "Open Gromp."
        )
        let early = plan(comp).section(for: .early)
        XCTAssertEqual(early.openerUnits.map(\.name), ["Gromp"])
        XCTAssertEqual(Set(early.openerUnits.map(\.id)).count, early.openerUnits.count)
    }

    func testCompWithNoAuthoredEarlyRosterFallsBackToItsCheapUnits() throws {
        let comp = try CompFixture.make(
            id: "no-early-roster",
            tier: .c,
            units: [
                CompFixture.unit("Ashe", cost: 5),
                CompFixture.unit("Vi", cost: 2),
                CompFixture.unit("Karma", cost: 1),
            ],
            earlyOpener: "Play whatever is strongest."
        )
        let early = plan(comp).section(for: .early)
        XCTAssertEqual(early.openerUnits.map(\.name), ["Karma", "Vi"], "cheapest first")
        XCTAssertEqual(early.openerUnits.map(\.cost), [1, 2])
        XCTAssertTrue(
            early.openerUnits.allSatisfy { !$0.isTransitional },
            "a fallback pick comes out of the final board, so none of it is transitional"
        )
    }

    /// The real corpus, not a fixture: the two things the player reads one card
    /// apart have to name the same units.
    func testTheOpenerStripAgreesWithTheOpenerProseAcrossTheRealCorpus() throws {
        let comps = try CompLoader.bundledFixtures()
        XCTAssertEqual(comps.count, 36, "the corpus this measures")
        for comp in comps {
            let early = BuildStagePlan(comp: comp).section(for: .early)
            XCTAssertFalse(comp.earlyUnits.isEmpty, "\(comp.id) carries no early roster to source the strip from")
            XCTAssertEqual(
                early.openerUnits.map(\.name),
                comp.earlyUnits,
                "\(comp.id): the strip is the authored early roster, verbatim"
            )
            let prose = comp.earlyOpener.lowercased()
            for pick in early.openerUnits {
                XCTAssertTrue(
                    prose.contains(pick.name.lowercased()),
                    "\(comp.id): OPEN WITH does not mention \(pick.name), which the strip tells the player to buy"
                )
            }
        }
    }

    /// 29 of the 36 comps open on at least one unit that is not in their final
    /// board, so this is the common case rather than a corner one.
    func testTheRealCorpusMarksItsTransitionalOpeners() throws {
        var marked = 0
        for comp in try CompLoader.bundledFixtures() {
            let early = BuildStagePlan(comp: comp).section(for: .early)
            let board = Set(comp.units.map { $0.name.lowercased() })
            for pick in early.openerUnits {
                XCTAssertEqual(
                    pick.isTransitional,
                    !board.contains(pick.name.lowercased()),
                    "\(comp.id): \(pick.name) is marked transitional \(pick.isTransitional) against the final board"
                )
            }
            marked += early.openerUnits.contains(where: \.isTransitional) ? 1 : 0
        }
        XCTAssertGreaterThanOrEqual(marked, 20, "transitional openers are the corpus norm, not an edge case")
    }
}
