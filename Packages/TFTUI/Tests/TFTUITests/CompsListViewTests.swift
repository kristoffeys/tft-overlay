@testable import TFTUI
import XCTest

/// How the browse list treats the build the player has committed to.
///
/// The committed build used to be indistinguishable from the rest of the
/// list apart from a 20pt star at the far right of its row — an answer to
/// "which one is mine" that you have to scan fifteen rows to read. It now
/// sorts out of the pack under its own heading, and these pin down that
/// split (the visual treatment is covered by the snapshot tests).
@MainActor
final class CompsListViewTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var comps: [Comp]!

    override func setUpWithError() throws {
        suiteName = "CompsListViewTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        comps = try CompLoader.bundledFixtures()
        try XCTSkipIf(comps.count < 2, "Needs at least two bundled comps")
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func list(pinning id: String? = nil) -> (CompsListView, PinnedCompsStore) {
        let store = PinnedCompsStore(defaults: defaults)
        if let id {
            store.pin(id)
        }
        return (CompsListView(comps: comps, pinnedStore: store), store)
    }

    func testNothingPinnedMeansNoCommittedSection() {
        let (view, _) = list()
        XCTAssertNil(view.committedBuild)
        XCTAssertEqual(view.otherComps.count, comps.count)
    }

    func testTheCurrentPinLeadsTheListAndIsNotRepeatedBelow() throws {
        let pinned = try XCTUnwrap(comps.last)
        let (view, _) = list(pinning: pinned.id)

        XCTAssertEqual(view.committedBuild?.id, pinned.id)
        XCTAssertFalse(
            view.otherComps.contains { $0.id == pinned.id },
            "The committed build is listed twice"
        )
        XCTAssertEqual(view.otherComps.count, comps.count - 1)
    }

    /// Pinning a second comp makes it the current one, so the heading follows
    /// the pin the player last committed to rather than the first one they
    /// ever pinned.
    func testTheHeadedBuildFollowsTheCurrentPinNotThePinOrder() throws {
        let first = try XCTUnwrap(comps.first)
        let second = try XCTUnwrap(comps.last)
        let (view, store) = list(pinning: first.id)
        XCTAssertEqual(view.committedBuild?.id, first.id)

        store.pin(second.id)
        XCTAssertEqual(view.committedBuild?.id, second.id)
    }

    /// Only comps that are still pinned lead the list. A stale id — a comp
    /// dropped from the corpus for a new patch — must not blank the section
    /// or crash it.
    func testAPinnedIDThatIsNotInTheCorpusIsIgnored() {
        let store = PinnedCompsStore(defaults: defaults)
        store.pin("a-comp-that-no-longer-exists")
        let view = CompsListView(comps: comps, pinnedStore: store)

        XCTAssertNil(view.committedBuild)
        XCTAssertEqual(view.otherComps.count, comps.count)
    }
}
