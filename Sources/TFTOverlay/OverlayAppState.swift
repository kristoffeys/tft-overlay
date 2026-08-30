import Foundation
import TFTData
import TFTUI

/// Shared state for the panels hosted inside the overlay: which panel is
/// showing, which comp is selected, and the comps loaded from TFTUI's
/// bundled `data/comps/*.json` fixtures. Owned by `AppDelegate` and shared
/// with both the overlay content and the menu bar menu.
@MainActor
final class OverlayAppState: ObservableObject {
    enum Panel: Int, CaseIterable {
        case compsList
        case compDetail
        case itemCheatSheet
        case reference

        var title: String {
            switch self {
            case .compsList: "Comps"
            case .compDetail: "Detail"
            case .itemCheatSheet: "Items"
            case .reference: "Reference"
            }
        }

        /// Whether this panel is a top-level destination, i.e. gets a tab.
        ///
        /// `compDetail` is not: you arrive at it by tapping a comp in the
        /// list, never by picking it cold, and a "Detail" tab that opens on
        /// whatever comp you last looked at (or on "no comp selected") is a
        /// dead end, not a destination. It keeps the Back affordance instead.
        var isDestination: Bool {
            self != .compDetail
        }

        /// The tabs the overlay offers, derived from `allCases` so a fifth
        /// panel appears in the tab bar without touching the tab bar.
        static var destinations: [Panel] {
            allCases.filter(\.isDestination)
        }

        /// Which tab lights up while this panel is on screen. A drill-down
        /// reports its parent, so the section you are in stays marked.
        var destination: Panel {
            isDestination ? self : .compsList
        }
    }

    @Published private(set) var panel: Panel = .compsList
    @Published private(set) var selectedComp: Comp?
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
    let pinnedComps = PinnedCompsStore()

    init() {
        // `CompLoader.bundledFixtures()` reads from TFTUI's own SPM resource
        // bundle (byte-identical copies of `data/comps/*.json`), so this
        // works from a normal app launch regardless of working directory —
        // no path outside the package is touched at runtime.
        comps = (try? CompLoader.bundledFixtures()) ?? []

        // If the player already has a build they're going for, that's the
        // useful thing to land on — not an arbitrary first-alphabetical comp
        // and a blank list. Compact mode has shown the pinned build since
        // the pinning pass; this is the same idea for the expanded view's
        // starting panel.
        if let pinnedID = pinnedComps.currentPinnedID, let pinned = comps.first(where: { $0.id == pinnedID }) {
            selectedComp = pinned
            panel = .compDetail
        } else {
            selectedComp = comps.first
        }

        Task {
            let (store, _) = await TFTDataService().loadCurrentStore()
            assetCatalog = TFTAssetCatalog(store: store)
        }
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
        selectedComp = comp
        panel = .compDetail
    }

    func showList() {
        panel = .compsList
    }

    /// Switches to a panel directly — what the tab bar calls.
    func show(_ panel: Panel) {
        self.panel = panel
    }

    func cycleForward() {
        panel = Self.cycled(from: panel, by: 1)
    }

    func cycleBackward() {
        panel = Self.cycled(from: panel, by: -1)
    }

    /// Cycling walks the *destinations* only, so ⌥C and the tab bar agree on
    /// what "next panel" means. Cycling into `compDetail` used to be possible
    /// and landed on "No comp selected" whenever nothing had been picked.
    private static func cycled(from panel: Panel, by offset: Int) -> Panel {
        let all = Panel.destinations
        guard !all.isEmpty else { return panel }
        let index = all.firstIndex(of: panel.destination) ?? 0
        return all[((index + offset) % all.count + all.count) % all.count]
    }
}
