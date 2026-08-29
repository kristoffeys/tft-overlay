import Foundation
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

        var title: String {
            switch self {
            case .compsList: "Comps"
            case .compDetail: "Detail"
            case .itemCheatSheet: "Items"
            }
        }
    }

    @Published private(set) var panel: Panel = .compsList
    @Published private(set) var selectedComp: Comp?
    let comps: [Comp]

    init() {
        // `CompLoader.bundledFixtures()` reads from TFTUI's own SPM resource
        // bundle (byte-identical copies of `data/comps/*.json`), so this
        // works from a normal app launch regardless of working directory —
        // no path outside the package is touched at runtime.
        comps = (try? CompLoader.bundledFixtures()) ?? []
        selectedComp = comps.first
    }

    func select(_ comp: Comp) {
        selectedComp = comp
        panel = .compDetail
    }

    func showList() {
        panel = .compsList
    }

    func cycleForward() {
        let all = Panel.allCases
        let index = all.firstIndex(of: panel) ?? 0
        panel = all[(index + 1) % all.count]
    }

    func cycleBackward() {
        let all = Panel.allCases
        let index = all.firstIndex(of: panel) ?? 0
        panel = all[(index - 1 + all.count) % all.count]
    }
}
