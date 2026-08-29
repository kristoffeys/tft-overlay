@testable import TFTUI
import XCTest

final class PinnedCompsStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        suiteName = "PinnedCompsStoreTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testStartsWithNoPins() {
        let store = PinnedCompsStore(defaults: defaults)
        XCTAssertTrue(store.pinnedIDs.isEmpty)
        XCTAssertFalse(store.isPinned("hunters-ashe"))
    }

    func testPinAddsAndUnpinRemoves() {
        let store = PinnedCompsStore(defaults: defaults)

        store.pin("hunters-ashe")
        XCTAssertTrue(store.isPinned("hunters-ashe"))
        XCTAssertEqual(store.pinnedIDs, ["hunters-ashe"])

        store.unpin("hunters-ashe")
        XCTAssertFalse(store.isPinned("hunters-ashe"))
        XCTAssertTrue(store.pinnedIDs.isEmpty)
    }

    func testPinIsIdempotent() {
        let store = PinnedCompsStore(defaults: defaults)
        store.pin("hunters-ashe")
        store.pin("hunters-ashe")
        XCTAssertEqual(store.pinnedIDs, ["hunters-ashe"])
    }

    func testToggleFlipsPinState() {
        let store = PinnedCompsStore(defaults: defaults)
        store.toggle("hunters-ashe")
        XCTAssertTrue(store.isPinned("hunters-ashe"))
        store.toggle("hunters-ashe")
        XCTAssertFalse(store.isPinned("hunters-ashe"))
    }

    /// The whole point of the store: pins outlive the process.
    func testPinsPersistAcrossStoreInstances() {
        let first = PinnedCompsStore(defaults: defaults)
        first.pin("hunters-ashe")
        first.pin("elderwood-bloom")

        let second = PinnedCompsStore(defaults: defaults)
        XCTAssertEqual(second.pinnedIDs, ["hunters-ashe", "elderwood-bloom"])
    }

    func testCycleAdvanceAndRetreatWrapAround() {
        let store = PinnedCompsStore(defaults: defaults)
        store.pin("a")
        store.pin("b")
        store.pin("c")

        XCTAssertEqual(store.currentPinnedID, "a")
        store.advance()
        XCTAssertEqual(store.currentPinnedID, "b")
        store.advance()
        XCTAssertEqual(store.currentPinnedID, "c")
        store.advance()
        XCTAssertEqual(store.currentPinnedID, "a", "advancing past the last pin should wrap to the first")

        store.retreat()
        XCTAssertEqual(store.currentPinnedID, "c", "retreating past the first pin should wrap to the last")
    }

    func testCycleOnEmptyStoreDoesNothing() {
        let store = PinnedCompsStore(defaults: defaults)
        store.advance()
        store.retreat()
        XCTAssertNil(store.currentPinnedID)
    }

    func testUnpinningTheCurrentCycleTargetClampsIndex() {
        let store = PinnedCompsStore(defaults: defaults)
        store.pin("a")
        store.pin("b")
        store.pin("c")
        store.advance()
        store.advance()
        XCTAssertEqual(store.currentPinnedID, "c")

        store.unpin("c")
        XCTAssertEqual(store.pinnedIDs, ["a", "b"])
        XCTAssertNotNil(store.currentPinnedID, "index must stay in bounds after the current pin is removed")
    }

    func testSelectCycleJumpsToAKnownPin() {
        let store = PinnedCompsStore(defaults: defaults)
        store.pin("a")
        store.pin("b")
        store.pin("c")

        store.selectCycle(id: "c")
        XCTAssertEqual(store.currentPinnedID, "c")
        XCTAssertEqual(store.cyclePosition(of: "c"), 2)
    }

    func testSelectCycleIgnoresUnknownID() {
        let store = PinnedCompsStore(defaults: defaults)
        store.pin("a")
        store.selectCycle(id: "not-pinned")
        XCTAssertEqual(store.currentPinnedID, "a")
    }
}
