@testable import OverlayKit
import XCTest

final class OverlayLayoutModeTests: XCTestCase {
    func testToggledFlipsCompactAndExpanded() {
        XCTAssertEqual(OverlayLayoutMode.compact.toggled, .expanded)
        XCTAssertEqual(OverlayLayoutMode.expanded.toggled, .compact)
    }

    func testCodableRoundTrip() throws {
        let encoded = try JSONEncoder().encode(OverlayLayoutMode.compact)
        let decoded = try JSONDecoder().decode(OverlayLayoutMode.self, from: encoded)
        XCTAssertEqual(decoded, .compact)
    }
}
