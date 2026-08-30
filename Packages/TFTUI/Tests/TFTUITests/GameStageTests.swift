@testable import TFTUI
import XCTest

final class GameStageTests: XCTestCase {
    func testParsesActAndRound() {
        let stage = GameStage("3-2")
        XCTAssertEqual(stage?.act, 3)
        XCTAssertEqual(stage?.round, 2)
        XCTAssertEqual(stage?.label, "3-2")
    }

    func testParsesDoubleDigitActsPastLexicographicOrder() throws {
        // The whole reason stages are parsed rather than compared as strings.
        let ninth = try XCTUnwrap(GameStage("9-1"))
        let tenth = try XCTUnwrap(GameStage("10-1"))
        XCTAssertLessThan(ninth, tenth)
        XCTAssertGreaterThan("9-1", "10-1", "string order disagrees, which is the bug this guards")
    }

    func testRejectsMalformedStageStrings() {
        for raw in ["", "3", "3-", "-2", "three-two", "3-2-1", "-3-2"] {
            XCTAssertNil(GameStage(raw), "\(raw) is not a stage")
        }
    }

    func testOrdersWithinAndAcrossActs() throws {
        let stages = try ["4-1", "2-5", "3-1", "2-1"].map { try XCTUnwrap(GameStage($0)) }
        XCTAssertEqual(stages.sorted().map(\.label), ["2-1", "2-5", "3-1", "4-1"])
    }

    // MARK: - Bands

    func testBandBoundaryBetweenTwoFiveAndThreeOne() throws {
        XCTAssertEqual(try StageBand.containing(XCTUnwrap(GameStage("2-5"))), .early)
        XCTAssertEqual(try StageBand.containing(XCTUnwrap(GameStage("3-1"))), .mid)
    }

    func testBandBoundaryBetweenFourFiveAndFiveOne() throws {
        XCTAssertEqual(try StageBand.containing(XCTUnwrap(GameStage("4-5"))), .mid)
        XCTAssertEqual(try StageBand.containing(XCTUnwrap(GameStage("5-1"))), .late)
    }

    func testLateBandIsOpenEnded() throws {
        for raw in ["5-7", "6-1", "7-4"] {
            XCTAssertEqual(try StageBand.containing(XCTUnwrap(GameStage(raw))), .late, raw)
        }
    }

    func testEveryActPlacesSomewhere() {
        for act in 0 ... 12 {
            _ = StageBand.containing(GameStage(act: act, round: 1))
        }
    }

    func testAdvancingStopsAtLateRatherThanWrapping() {
        XCTAssertEqual(StageBand.early.next, .mid)
        XCTAssertEqual(StageBand.mid.next, .late)
        XCTAssertNil(StageBand.late.next, "wrapping would show act-1 advice during a top-four fight")
    }

    func testDefaultBandIsTheEarliest() {
        XCTAssertEqual(StageBand.initial, .early)
        XCTAssertEqual(StageBand.allCases, [.early, .mid, .late])
    }
}
