@testable import TFTOverlay
import TFTUI
import XCTest

/// Focus mode (#82): pinning a build takes the overlay over.
///
/// Before this, pinning set `PinnedCompsStore.currentPinnedID` and the
/// expanded panel looked byte-identical afterwards — the only feedback was a
/// 20pt star at the far right of one row filling in. These cases pin down the
/// gesture actually having a consequence, and the escape hatches out of it.
@MainActor
final class OverlayModeTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        suiteName = "OverlayModeTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func state() -> OverlayAppState {
        OverlayAppState(
            pinnedComps: PinnedCompsStore(defaults: defaults),
            ownedChampions: OwnedChampionsStore(defaults: defaults)
        )
    }

    private func twoComps(_ state: OverlayAppState) throws -> (Comp, Comp) {
        try XCTSkipIf(state.comps.count < 2, "Needs at least two bundled comps")
        return (state.comps[0], state.comps[1])
    }

    // MARK: - Landing state

    func testNothingPinnedLandsInBrowse() {
        let state = state()
        XCTAssertNil(state.committedBuild)
        XCTAssertEqual(state.mode, .browse)
        XCTAssertEqual(state.panel, .compsList)
    }

    /// A pin persists across launches, so a relaunch has to land in Focus on
    /// it rather than on a list of alternatives the player already ruled out.
    func testAPersistedPinLandsInFocusOnLaunch() throws {
        let seed = state()
        let (first, _) = try twoComps(seed)
        seed.commit(to: first)

        let relaunched = state()
        XCTAssertEqual(relaunched.committedBuild?.id, first.id)
        XCTAssertEqual(relaunched.mode, .focus)
        XCTAssertEqual(relaunched.panel, .focusBuild)
    }

    /// A pin naming a comp this corpus no longer carries is not a build.
    func testAStalePinDoesNotFakeAFocusedBuild() {
        let store = PinnedCompsStore(defaults: defaults)
        store.pin("a-comp-that-no-longer-exists")
        let state = OverlayAppState(pinnedComps: store)

        XCTAssertNil(state.committedBuild)
        XCTAssertEqual(state.mode, .browse)
        XCTAssertEqual(state.panel, .compsList)
    }

    // MARK: - Pinning is the commit gesture

    func testPinningFromTheListSwitchesIntoFocusOnThatBuild() throws {
        let state = state()
        let (first, _) = try twoComps(state)

        state.togglePin(first)

        XCTAssertTrue(state.pinnedComps.isPinned(first.id))
        XCTAssertEqual(state.committedBuild?.id, first.id)
        XCTAssertEqual(state.mode, .focus)
        XCTAssertEqual(state.panel, .focusBuild)
    }

    func testPinningWhileAlreadyFocusedSwitchesTheBuild() throws {
        let state = state()
        let (first, second) = try twoComps(state)
        state.togglePin(first)

        state.togglePin(second)

        XCTAssertEqual(state.committedBuild?.id, second.id)
        XCTAssertEqual(state.mode, .focus)
        XCTAssertEqual(state.panel, .focusBuild)
        XCTAssertTrue(state.pinnedComps.isPinned(first.id), "Switching builds should not unpin the old one")
    }

    /// Re-pinning an already-pinned comp is how a player who keeps two lines
    /// pinned says "this is the one I'm on now".
    func testCommittingToAnAlreadyPinnedBuildRefocusesIt() throws {
        let state = state()
        let (first, second) = try twoComps(state)
        state.togglePin(first)
        state.togglePin(second)
        state.browse()

        state.commit(to: first)

        XCTAssertEqual(state.committedBuild?.id, first.id)
        XCTAssertEqual(state.mode, .focus)
        XCTAssertEqual(state.panel, .focusBuild)
    }

    /// The #87 payoff: tapping a suggestion in My Champions is the same commit
    /// gesture as pinning from the list, and it has to land the player in Focus
    /// on that build rather than merely pinning it in the background.
    ///
    /// `MyChampionsView.onCommitBuild` is wired straight to `commit(to:)` in
    /// `OverlayContentView`, so this covers the transition that wiring depends
    /// on: from a Browse-only panel, which also has to stop being the panel on
    /// screen.
    func testCommittingFromMyChampionsLandsInFocusOnThatBuild() throws {
        let state = state()
        let (_, second) = try twoComps(state)
        state.show(.myChampions)
        XCTAssertEqual(state.panel, .myChampions)
        XCTAssertEqual(state.mode, .browse)

        state.commit(to: second)

        XCTAssertEqual(state.committedBuild?.id, second.id)
        XCTAssertEqual(state.mode, .focus)
        XCTAssertEqual(state.panel, .focusBuild)
        XCTAssertTrue(state.pinnedComps.isPinned(second.id))
    }

    /// Committing from a suggestion while already focused on something else is
    /// the pivot case — mid-game, "what can I reach from here" is exactly the
    /// question that produces a build switch — and it must reset the stage the
    /// same way pinning does.
    func testCommittingFromMyChampionsWhileFocusedSwitchesTheBuildAndResetsTheStage() throws {
        let state = state()
        let (first, second) = try twoComps(state)
        state.commit(to: first)
        state.advanceStage()
        try XCTSkipIf(state.stageBand == .initial, "Needs a stage band past the first")
        state.browse(to: .myChampions)

        state.commit(to: second)

        XCTAssertEqual(state.committedBuild?.id, second.id)
        XCTAssertEqual(state.mode, .focus)
        XCTAssertEqual(state.panel, .focusBuild)
        XCTAssertEqual(state.stageBand, .initial, "A new build is the overlay's best proxy for a new game")
    }

    /// One store, held by the app state, for the reason
    /// `OwnedChampionsStore.clear()` documents: in-memory state is a snapshot
    /// taken at `init`, so a second store over the same defaults can hold a
    /// stale roster and write it back over a fresh one. `MyChampionsView` is
    /// handed this instance rather than creating its own.
    func testTheOwnedChampionsStoreIsHeldByTheAppStateAndReadsThrough() {
        let state = state()
        XCTAssertTrue(state.ownedChampions.ownedKeys.isEmpty)

        state.ownedChampions.toggle("Ashe")
        XCTAssertTrue(state.ownedChampions.isOwned("Ashe"))

        state.ownedChampions.clear()
        XCTAssertTrue(state.ownedChampions.ownedKeys.isEmpty)
    }

    /// The roster is persisted, so it survives a panel toggle and a relaunch —
    /// and the state that reads it on relaunch has to be the one that was
    /// written to.
    func testTheOwnedRosterSurvivesARelaunch() {
        let seed = state()
        seed.ownedChampions.add("Ashe")

        let relaunched = state()
        XCTAssertTrue(relaunched.ownedChampions.isOwned("Ashe"))
    }

    // MARK: - Getting back out

    /// "Change build" is not "unpin": a player pivoting still wants their
    /// current line on screen until they have chosen the next one.
    func testBrowsingWhilePinnedReturnsToTheListWithoutUnpinning() throws {
        let state = state()
        let (first, _) = try twoComps(state)
        state.togglePin(first)

        state.browse()

        XCTAssertEqual(state.mode, .browse)
        XCTAssertEqual(state.panel, .compsList)
        XCTAssertTrue(state.pinnedComps.isPinned(first.id))
        XCTAssertEqual(state.committedBuild?.id, first.id, "The build is still committed, just not on screen")
    }

    /// Used to need a relaunch: the landing panel was the only thing that
    /// read the pin.
    func testUnpinningTheLastBuildFallsBackToBrowse() throws {
        let state = state()
        let (first, _) = try twoComps(state)
        state.togglePin(first)
        XCTAssertEqual(state.panel, .focusBuild)

        state.togglePin(first)

        XCTAssertFalse(state.pinnedComps.isPinned(first.id))
        XCTAssertNil(state.committedBuild)
        XCTAssertEqual(state.mode, .browse)
        XCTAssertEqual(state.panel, .compsList)
    }

    /// With another pin left there is still a build to be going for, so Focus
    /// holds and hands over to it rather than dumping the player in the list.
    func testUnpinningWithAnotherPinLeftStaysInFocusOnIt() throws {
        let state = state()
        let (first, second) = try twoComps(state)
        state.togglePin(first)
        state.togglePin(second)

        state.togglePin(second)

        XCTAssertEqual(state.committedBuild?.id, first.id)
        XCTAssertEqual(state.mode, .focus)
        XCTAssertEqual(state.panel, .focusBuild)
    }

    /// The next pin after clearing the board goes straight to Focus — a
    /// Browse the player asked for three games ago must not outlive the build
    /// it was about.
    func testPinningAgainAfterUnpinningTheLastBuildReturnsToFocus() throws {
        let state = state()
        let (first, second) = try twoComps(state)
        state.togglePin(first)
        state.browse()
        state.togglePin(first)
        XCTAssertEqual(state.mode, .browse)

        state.togglePin(second)

        XCTAssertEqual(state.mode, .focus)
        XCTAssertEqual(state.panel, .focusBuild)
    }

    /// Leaving a comp you were merely looking at must not also drop you out
    /// of Focus on the build you committed to.
    func testBackingOutOfADrillDownWhileFocusedReturnsToTheBuild() throws {
        let state = state()
        let (first, second) = try twoComps(state)
        state.togglePin(first)

        state.select(second)
        XCTAssertEqual(state.panel, .compDetail)
        XCTAssertEqual(state.mode, .focus, "Looking at another comp is not committing to it")

        state.goBack()

        XCTAssertEqual(state.panel, .focusBuild)
        XCTAssertEqual(state.committedBuild?.id, first.id)
    }

    func testBackingOutOfADrillDownWhileBrowsingReturnsToTheList() throws {
        let state = state()
        let (_, second) = try twoComps(state)

        state.select(second)
        state.goBack()

        XCTAssertEqual(state.panel, .compsList)
        XCTAssertEqual(state.mode, .browse)
    }

    // MARK: - The invariant the whole thing rests on

    /// `mode` is derived from `PinnedCompsStore`, never stored alongside it,
    /// so the two cannot drift. Whatever route the state took, a committed
    /// build plus no browse request means Focus, and Focus means the build
    /// panel is the one the tab bar leads with.
    func testModeNeverContradictsTheCommittedBuild() throws {
        let state = state()
        let (first, second) = try twoComps(state)
        let routes: [(String, () -> Void)] = [
            ("pin first", { state.togglePin(first) }),
            ("browse", { state.browse() }),
            ("pin second", { state.togglePin(second) }),
            ("items", { state.show(.itemCheatSheet) }),
            ("openers", { state.show(.openers) }),
            ("drill in from openers", { state.select(compID: second.id) }),
            ("back to openers", { state.goBack() }),
            ("my champions", { state.show(.myChampions) }),
            ("commit from a suggestion", { state.commit(to: first) }),
            ("my champions again", { state.show(.myChampions) }),
            ("drill into first", { state.select(first) }),
            ("back", { state.goBack() }),
            ("unpin second", { state.togglePin(second) }),
            ("unpin first", { state.togglePin(first) }),
            ("build tab", { state.show(.focusBuild) }),
            ("cycle", { state.cycleForward() }),
        ]

        for (label, step) in routes {
            step()
            if state.committedBuild == nil {
                XCTAssertEqual(state.mode, .browse, "after \(label)")
                XCTAssertNotEqual(state.panel, .focusBuild, "after \(label)")
            }
            XCTAssertEqual(
                state.mode == .focus,
                state.committedBuild != nil && !state.isBrowsingByRequest,
                "after \(label)"
            )
            if state.panel == .focusBuild {
                XCTAssertEqual(state.mode, .focus, "after \(label)")
            }
        }
    }
}
