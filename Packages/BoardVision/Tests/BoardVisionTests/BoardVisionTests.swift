@testable import BoardVision
import XCTest

final class BoardVisionTests: XCTestCase {
    func testTargetsPhaseTwo() {
        XCTAssertEqual(BoardVision.targetPhase, 2)
    }
}
