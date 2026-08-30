/// The overlay's navigation taxonomy: every panel it can show, which of them
/// are tabs, and which tab lights up for each.
///
/// Split out of `OverlayAppState` so the state machine and the taxonomy it
/// navigates read separately. Everything here is a pure function of the panel
/// and the mode — no stored state, nothing to observe — which is why it can
/// live in its own file and be reasoned about on its own.
extension OverlayAppState {
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
}
