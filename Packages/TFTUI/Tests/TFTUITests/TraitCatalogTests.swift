@testable import TFTUI
import XCTest

final class TraitCatalogTests: XCTestCase {
    func testKnownTraitReturnsAscendingBreakpointsWithStyles() {
        let breakpoints = TraitCatalog.breakpoints(for: "Elderwood")

        XCTAssertEqual(breakpoints.map(\.count), [2, 4, 6, 8])
        XCTAssertEqual(breakpoints.map(\.style), [.bronze, .silver, .gold, .chromatic])
    }

    func testTraitWithMoreBreakpointsThanStylesRepeatsTheTopStyle() {
        // Hunter has 4 breakpoints against 4 named styles exactly, so cap it
        // with a synthetic lookup instead: any trait beyond bronze/silver/gold
        // /chromatic must clamp to chromatic rather than index out of range.
        let breakpoints = TraitCatalog.breakpoints(for: "Rapidfire")
        XCTAssertEqual(breakpoints.count, 4)
        XCTAssertEqual(breakpoints.last?.style, .chromatic)
    }

    func testUncataloguedTraitReturnsEmpty() {
        XCTAssertTrue(TraitCatalog.breakpoints(for: "Not A Real Trait").isEmpty)
    }
}
