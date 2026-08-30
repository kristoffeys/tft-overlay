import Combine
import Foundation
import TFTData
import TFTUI

/// Shared state for the panels hosted inside the overlay: which panel is
/// showing, which comp is selected, and the comps loaded from TFTUI's
/// bundled `data/comps/*.json` fixtures. Owned by `AppDelegate` and shared
/// with both the overlay content and the menu bar menu.
@MainActor
final class OverlayAppState: ObservableObject {
    /// Which question the overlay is currently answering (#82).
    ///
    /// The overlay has two modes of *intent*, not two sizes:
    ///
    /// - `browse` — "what should I play?" The list, search, tier and style
    ///   filters. Pre-game, or when pivoting.
    /// - `focus` — "what do I do now?" One build. No search, no tier chips,
    ///   no other comps.
    ///
    /// Pinning is the commit gesture, and it has to be visibly consequential
    /// in the same instant: before this, pinning in the expanded view left
    /// the panel byte-identical apart from a star filling in.
    enum Mode {
        case browse
        case focus
    }

    enum Panel: Int, CaseIterable {
        case compsList
        case compDetail
        case itemCheatSheet
        case reference
        /// The committed build, front and centre. Only a tab in `focus` mode —
        /// with nothing pinned there is no build to show.
        case focusBuild

        var title: String {
            switch self {
            case .compsList: "Comps"
            case .compDetail: "Detail"
            case .itemCheatSheet: "Items"
            case .reference: "Reference"
            case .focusBuild: "Build"
            }
        }

        /// Whether this panel is a top-level destination, i.e. can get a tab.
        ///
        /// `compDetail` is not: you arrive at it by tapping a comp in the
        /// list, never by picking it cold, and a "Detail" tab that opens on
        /// whatever comp you last looked at (or on "no comp selected") is a
        /// dead end, not a destination. It keeps the Back affordance instead.
        var isDestination: Bool {
            self != .compDetail
        }

        /// The tabs the overlay offers in `mode`.
        ///
        /// Both modes show three tabs and both lead with the panel that
        /// answers the mode's question — the committed build in `focus`, the
        /// list in `browse`. The way *out* of `focus` is not a fourth tab: it
        /// is the tab bar's trailing accessory, so ⌥C cycling stays inside
        /// the mode it started in instead of walking the user out of Focus by
        /// accident and leaving the build unreachable by hotkey.
        static func destinations(in mode: Mode) -> [Panel] {
            [primary(in: mode), .itemCheatSheet, .reference]
        }

        /// The panel a mode leads with, and the tab a drill-down reports to.
        static func primary(in mode: Mode) -> Panel {
            mode == .focus ? .focusBuild : .compsList
        }

        /// Which tab lights up while this panel is on screen. A drill-down
        /// reports its parent, so the section you are in stays marked; the
        /// two mode-specific panels report whichever of them the current mode
        /// actually shows, so the bar is never left with nothing highlighted.
        func destination(in mode: Mode) -> Panel {
            switch self {
            case .compDetail, .compsList, .focusBuild: Panel.primary(in: mode)
            case .itemCheatSheet, .reference: self
            }
        }
    }

    @Published private(set) var panel: Panel = .compsList
    @Published private(set) var selectedComp: Comp?
    /// The tab `compDetail` was drilled into from, so Back returns there
    /// instead of always landing on the mode's primary tab (#91). Only ever
    /// set to a destination panel — drilling from one detail into another
    /// (were that possible) keeps the original origin rather than pointing
    /// back at the drill-down itself.
    private var drillOrigin: Panel = .compsList
    /// Whether the player explicitly asked to browse.
    ///
    /// `mode` is *derived*, never stored: the committed build lives in
    /// `PinnedCompsStore` and a second copy of "am I in Focus" would drift
    /// from it. This flag is the one bit that genuinely is not derivable —
    /// "I have a build pinned but I want to look at the others right now" —
    /// and it is cleared by committing to a build.
    @Published private(set) var isBrowsingByRequest = false
    /// Which part of the game the Build panel is answering for (#84).
    ///
    /// Session state, not a setting: it means "where I am in *this* game", so
    /// persisting it would restore a stale act-5 stage into a fresh act-1
    /// lobby, which is worse than the default. It resets when the player
    /// commits to a different build, which is the closest thing the overlay
    /// has to a "new game" signal until board vision lands (#45).
    @Published private(set) var stageBand: StageBand = .initial
    /// The advance hotkey as currently bound, for the stage control to name.
    /// Set by `AppDelegate` once the binding is known — the hotkey is
    /// rebindable, so hardcoding a combo here would eventually lie.
    @Published var stageAdvanceHint: String?
    /// Champion/item/trait art URLs, resolved from whatever `TFTDataService`
    /// has on launch (disk cache or the bundled fallback pack — never a
    /// network call). Starts `.empty` (text placeholders only) and updates
    /// once loaded; nothing above this has to know the difference, since
    /// every icon view already treats "no art yet" as its normal fallback.
    @Published private(set) var assetCatalog: TFTAssetCatalog = .empty
    let comps: [Comp]
    /// Which comps the player pinned, and which of them is the build they
    /// are currently going for. Compact mode shows that build's roster, so
    /// this is the app's notion of "selected build" — `selectedComp` is
    /// only which comp the detail panel happens to be looking at.
    let pinnedComps: PinnedCompsStore

    private var pinObserver: AnyCancellable?

    /// - Parameter pinnedComps: injectable so tests get an isolated
    ///   `UserDefaults` suite. Reading the real one made every navigation
    ///   test depend on whatever the developer last pinned in the app.
    init(pinnedComps: PinnedCompsStore = PinnedCompsStore()) {
        // `CompLoader.bundledFixtures()` reads from TFTUI's own SPM resource
        // bundle (byte-identical copies of `data/comps/*.json`), so this
        // works from a normal app launch regardless of working directory —
        // no path outside the package is touched at runtime.
        comps = (try? CompLoader.bundledFixtures()) ?? []
        self.pinnedComps = pinnedComps

        selectedComp = comps.first

        // A player who already committed to a build gets Focus on it, not a
        // list of fifteen alternatives they have already ruled out.
        if pinnedComps.currentPinnedID != nil, comps.contains(where: { $0.id == pinnedComps.currentPinnedID }) {
            panel = .focusBuild
        }

        // `committedBuild` reads through to the pin store, which is a separate
        // ObservableObject — without this, a pin change made anywhere else
        // (the compact rail's chevrons, the menu bar) would leave the
        // expanded panel showing a stale build.
        pinObserver = pinnedComps.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }

        Task {
            let (store, _) = await TFTDataService().loadCurrentStore()
            assetCatalog = TFTAssetCatalog(store: store)
        }
    }

    /// The build the player has committed to: the current pin, resolved
    /// against the loaded corpus. Nil when nothing is pinned, or when the pin
    /// names a comp this corpus no longer carries.
    var committedBuild: Comp? {
        guard let id = pinnedComps.currentPinnedID else { return nil }
        return comps.first { $0.id == id }
    }

    /// Browse whenever there is no build to focus on, or the player asked for
    /// it. Focus otherwise.
    var mode: Mode {
        (committedBuild == nil || isBrowsingByRequest) ? .browse : .focus
    }

    /// Re-checks Community Dragon for a newer patch and, if one exists,
    /// re-fetches and rebuilds the asset catalog. Called by `AppDelegate` on
    /// a timer, gated on Preferences' "Refresh automatically" — a no-op
    /// over the network whenever the cached content version is still
    /// current, per `TFTDataService.checkAndRefreshIfNeeded()`.
    func refreshAssetDataIfNewer() async {
        let service = TFTDataService()
        guard case .refreshed = await service.checkAndRefreshIfNeeded() else { return }
        let (store, _) = await service.loadCurrentStore()
        assetCatalog = TFTAssetCatalog(store: store)
    }

    func select(_ comp: Comp) {
        if panel.isDestination {
            drillOrigin = panel
        }
        selectedComp = comp
        panel = .compDetail
    }

    // MARK: - Committing to a build

    /// What a pin tap means. Pinning commits; unpinning un-commits.
    func togglePin(_ comp: Comp) {
        if pinnedComps.isPinned(comp.id) {
            pinnedComps.unpin(comp.id)
            // Unpinning the last pin leaves nothing to focus on, so Browse
            // takes over — without a relaunch, which is what it used to take.
            // Clearing the request flag too means the next pin lands straight
            // in Focus rather than in a Browse the player asked for ages ago.
            if committedBuild == nil {
                isBrowsingByRequest = false
                if panel == .focusBuild {
                    panel = .compsList
                }
            }
        } else {
            commit(to: comp)
        }
    }

    /// Pins `comp` and takes the overlay into Focus on it, in one gesture.
    ///
    /// `PinnedCompsStore.pin` re-selects an already-pinned comp, so this
    /// doubles as "switch to this build" while already focused on another.
    func commit(to comp: Comp) {
        // Committing to a *different* build is the overlay's best available
        // proxy for "new game": nobody switches lines mid-act-5 and then wants
        // the stage still reading Late from the previous game.
        if pinnedComps.currentPinnedID != comp.id {
            stageBand = .initial
        }
        pinnedComps.pin(comp.id)
        isBrowsingByRequest = false
        panel = .focusBuild
    }

    // MARK: - Stage (#84)

    func setStageBand(_ band: StageBand) {
        stageBand = band
    }

    /// One gesture, bound to both the stage control and a hotkey. Stops at
    /// `late` rather than wrapping: see `StageBand.next` — an extra keypress
    /// must not drop a player in a top-four fight back onto opener advice.
    func advanceStage() {
        guard let next = stageBand.next else { return }
        stageBand = next
    }

    /// The escape hatch: back to the list, keeping the pin.
    ///
    /// "Change build" is not "unpin" — a player pivoting still wants their
    /// current line on screen until they have chosen the next one.
    func browse() {
        isBrowsingByRequest = true
        panel = .compsList
    }

    // MARK: - Navigation

    /// Switches to a panel directly — what the tab bar calls.
    ///
    /// The comps list *is* the browse view, so arriving at it by any route
    /// means Browse; and `focusBuild` with nothing committed has nothing to
    /// draw, so it redirects rather than showing an empty panel.
    func show(_ panel: Panel) {
        switch panel {
        case .compsList:
            browse()
        case .focusBuild:
            guard let committedBuild else { return browse() }
            commit(to: committedBuild)
        default:
            self.panel = panel
        }
    }

    /// Leaves a drill-down for the tab it was entered from — Reference stays
    /// Reference, the comps list stays the list — so backing out of a comp
    /// you were merely comparing never silently drops you onto a different
    /// section, and in particular never drops you out of Focus onto the
    /// build you committed to. `show` already falls back safely if
    /// `drillOrigin` ever named a tab the current mode no longer offers.
    func goBack() {
        show(drillOrigin)
    }

    func cycleForward() {
        show(cycled(by: 1))
    }

    func cycleBackward() {
        show(cycled(by: -1))
    }

    /// Cycling walks the current mode's *destinations* only, so ⌥C and the
    /// tab bar agree on what "next panel" means. Cycling into `compDetail`
    /// used to be possible and landed on "No comp selected" whenever nothing
    /// had been picked.
    private func cycled(by offset: Int) -> Panel {
        let mode = mode
        let all = Panel.destinations(in: mode)
        guard !all.isEmpty else { return panel }
        let index = all.firstIndex(of: panel.destination(in: mode)) ?? 0
        return all[((index + offset) % all.count + all.count) % all.count]
    }
}
