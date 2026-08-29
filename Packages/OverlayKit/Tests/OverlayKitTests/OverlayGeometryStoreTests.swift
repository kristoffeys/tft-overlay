import CoreGraphics
@testable import OverlayKit
import XCTest

final class OverlayGeometryStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "OverlayGeometryStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testLoadReturnsNilWhenNothingSaved() {
        let store = OverlayGeometryStore(defaults: defaults)
        XCTAssertNil(store.load(for: 1))
    }

    func testSaveThenLoadRoundTrips() {
        let store = OverlayGeometryStore(defaults: defaults)
        let geometry = OverlayGeometry(
            frame: CGRect(x: 10, y: 20, width: 300, height: 400),
            layoutMode: .compact,
            opacity: 0.75,
            scale: 1.5
        )

        store.save(geometry, for: 42)
        let loaded = store.load(for: 42)

        XCTAssertEqual(loaded, geometry)
    }

    func testGeometryIsScopedPerDisplay() {
        let store = OverlayGeometryStore(defaults: defaults)
        let displayOne = OverlayGeometry(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let displayTwo = OverlayGeometry(frame: CGRect(x: 500, y: 500, width: 200, height: 200), layoutMode: .compact)

        store.save(displayOne, for: 1)
        store.save(displayTwo, for: 2)

        XCTAssertEqual(store.load(for: 1), displayOne)
        XCTAssertEqual(store.load(for: 2), displayTwo)
    }

    func testSaveOverwritesPreviousValueForSameDisplay() {
        let store = OverlayGeometryStore(defaults: defaults)
        store.save(OverlayGeometry(frame: CGRect(x: 0, y: 0, width: 100, height: 100)), for: 1)
        let updated = OverlayGeometry(frame: CGRect(x: 1, y: 2, width: 300, height: 400), opacity: 0.5)
        store.save(updated, for: 1)

        XCTAssertEqual(store.load(for: 1), updated)
    }

    func testClearRemovesSavedGeometry() {
        let store = OverlayGeometryStore(defaults: defaults)
        store.save(OverlayGeometry(frame: CGRect(x: 0, y: 0, width: 100, height: 100)), for: 1)
        store.clear(for: 1)

        XCTAssertNil(store.load(for: 1))
    }

    func testDistinctStoresWithDifferentKeyPrefixesDoNotCollide() {
        let storeA = OverlayGeometryStore(defaults: defaults, keyPrefix: "a")
        let storeB = OverlayGeometryStore(defaults: defaults, keyPrefix: "b")
        let geometryA = OverlayGeometry(frame: CGRect(x: 0, y: 0, width: 10, height: 10))

        storeA.save(geometryA, for: 1)

        XCTAssertEqual(storeA.load(for: 1), geometryA)
        XCTAssertNil(storeB.load(for: 1))
    }
}
