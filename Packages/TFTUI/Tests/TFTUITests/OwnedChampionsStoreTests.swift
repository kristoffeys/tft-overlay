@testable import TFTUI
import XCTest

final class OwnedChampionsStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        suiteName = "OwnedChampionsStoreTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testStartsEmpty() {
        let store = OwnedChampionsStore(defaults: defaults)
        XCTAssertTrue(store.ownedKeys.isEmpty)
        XCTAssertFalse(store.isOwned("Ashe"))
    }

    func testToggleFlipsOwnership() {
        let store = OwnedChampionsStore(defaults: defaults)
        store.toggle("Ashe")
        XCTAssertTrue(store.isOwned("Ashe"))
        store.toggle("Ashe")
        XCTAssertFalse(store.isOwned("Ashe"))
    }

    func testAddIsIdempotent() {
        let store = OwnedChampionsStore(defaults: defaults)
        store.add("Ashe")
        store.add("Ashe")
        XCTAssertEqual(store.ownedKeys.count, 1)
    }

    /// The whole point of the store: ownership outlives the process.
    func testOwnershipPersistsAcrossStoreInstances() {
        let first = OwnedChampionsStore(defaults: defaults)
        first.add("Ashe")
        first.add("Kindred")

        let second = OwnedChampionsStore(defaults: defaults)
        XCTAssertTrue(second.isOwned("Ashe"))
        XCTAssertTrue(second.isOwned("Kindred"))
        XCTAssertEqual(second.ownedKeys.count, 2)
    }

    /// A stale roster is worse than an empty one, so clearing has to be one
    /// unconditional call.
    func testClearRemovesEverythingAndPersists() {
        let first = OwnedChampionsStore(defaults: defaults)
        first.add("Ashe")
        first.add("Kindred")
        first.clear()
        XCTAssertTrue(first.ownedKeys.isEmpty)

        let second = OwnedChampionsStore(defaults: defaults)
        XCTAssertTrue(second.ownedKeys.isEmpty, "clear must persist, not just clear in-memory state")
    }

    /// Regression: `clear()` used to return early when its own in-memory set
    /// was already empty, which is not the same thing as the defaults being
    /// empty. Two stores can share one defaults suite — a re-created
    /// `@StateObject`, or a preview running beside the app, since `init`
    /// defaults to `.standard` — and the one that was constructed before the
    /// other's write holds an empty snapshot. Clearing from that store has to
    /// wipe the persisted roster anyway; a stale roster is worse than none.
    func testClearWipesPersistedStateEvenWhenThisInstanceLooksEmpty() {
        let writer = OwnedChampionsStore(defaults: defaults)
        let observer = OwnedChampionsStore(defaults: defaults)

        writer.add("Ashe")
        XCTAssertTrue(observer.ownedKeys.isEmpty, "the second store snapshotted before the write")

        observer.clear()

        let fresh = OwnedChampionsStore(defaults: defaults)
        XCTAssertTrue(fresh.ownedKeys.isEmpty, "clear must persist unconditionally, not only when it sees state")
    }

    /// The store is a dumb key/value set: it never validates against a
    /// champion catalog, so a name that matches no known champion is just
    /// as storable as a real one, and querying an unrelated name never
    /// crashes or throws.
    func testUnknownNameIsStorableAndQueryable() {
        let store = OwnedChampionsStore(defaults: defaults)
        store.add("Not A Champion")
        XCTAssertTrue(store.isOwned("Not A Champion"))
        XCTAssertFalse(store.isOwned("Ashe"))
    }

    /// Community Dragon punctuates names inconsistently ("KaiSa" vs
    /// "Kai'Sa"); this store must never let that split one champion into
    /// two entries.
    func testPunctuationAndCasingVariantsCollapseToOneEntry() {
        let store = OwnedChampionsStore(defaults: defaults)
        store.add("Kai'Sa")
        XCTAssertTrue(store.isOwned("KaiSa"))
        XCTAssertTrue(store.isOwned("kai'sa"))
        XCTAssertTrue(store.isOwned("KAISA"))
        XCTAssertEqual(store.ownedKeys.count, 1)

        store.toggle("KaiSa")
        XCTAssertFalse(store.isOwned("Kai'Sa"), "toggling a punctuation variant must affect the same entry")
        XCTAssertTrue(store.ownedKeys.isEmpty)
    }

    func testRemoveOnAnUnownedNameIsANoOp() {
        let store = OwnedChampionsStore(defaults: defaults)
        store.remove("Ashe")
        XCTAssertTrue(store.ownedKeys.isEmpty)
    }
}
