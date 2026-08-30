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
        /// Early-game guidance before a comp has been chosen (#85). A Browse
        /// panel: it answers "what should I play?", from the other end than
        /// the comps list does.
        case openers
        /// The champions the player has, and the comps they are closest to
        /// (#86, #87). Also Browse: its whole output is a shortlist of comps
        /// to pick from.
        case myChampions

        /// The tab label.
        ///
        /// "Mine" rather than "My Champions" because the label has to fit a
        /// five-tab bar down to the 420pt compact width: the long form needs
        /// 410pt of bar and 440pt once the drill-down chevron appears, which
        /// overflows. See `PanelTabBarFitTests`.
        var title: String {
            switch self {
            case .compsList: "Comps"
            case .compDetail: "Detail"
            case .itemCheatSheet: "Items"
            case .reference: "Reference"
            case .focusBuild: "Build"
            case .openers: "Openers"
            case .myChampions: "Mine"
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

        /// Whether this panel only exists to answer "what should I play?",
        /// i.e. belongs to Browse and nowhere else.
        ///
        /// Openers and My Champions are both pre-commit surfaces: one ranks
        /// what to hold before you have chosen, the other ranks what you can
        /// reach from what you already have. Neither has anything to say once
        /// the player has committed, and putting either in Focus would break
        /// the thing Focus is for — one build, no alternatives on screen.
        var isBrowseOnly: Bool {
            self == .openers || self == .myChampions
        }

        /// The tabs the overlay offers in `mode`.
        ///
        /// Both modes lead with the panel that answers the mode's question —
        /// the committed build in `focus`, the list in `browse`. The way *out*
        /// of `focus` is not another tab: it is the tab bar's trailing
        /// accessory, so ⌥C cycling stays inside the mode it started in
        /// instead of walking the user out of Focus by accident and leaving
        /// the build unreachable by hotkey.
        ///
        /// Browse carries five tabs and Focus exactly three. That asymmetry is
        /// the point: Browse is where the player is deciding, so it offers
        /// every route into a decision, while Focus is deliberately narrow.
        static func destinations(in mode: Mode) -> [Panel] {
            switch mode {
            case .browse:
                [.compsList, .openers, .myChampions, .itemCheatSheet, .reference]
            case .focus:
                [.focusBuild, .itemCheatSheet, .reference]
            }
        }

        /// The panel a mode leads with, and the tab a drill-down reports to.
        static func primary(in mode: Mode) -> Panel {
            mode == .focus ? .focusBuild : .compsList
        }

        /// Which tab lights up while this panel is on screen. A drill-down
        /// reports its parent, so the section you are in stays marked; the
        /// two mode-specific panels report whichever of them the current mode
        /// actually shows, so the bar is never left with nothing highlighted.
        ///
        /// The Browse-only panels report themselves in Browse and the mode's
        /// primary in Focus. Navigating to either already forces Browse, so
        /// the Focus branch is unreachable in practice — it exists so the
        /// "every panel highlights a current tab" invariant holds for every
        /// pair, not only the reachable ones.
        func destination(in mode: Mode) -> Panel {
            switch self {
            case .compDetail, .compsList, .focusBuild: Panel.primary(in: mode)
            case .itemCheatSheet, .reference: self
            case .openers, .myChampions: mode == .browse ? self : Panel.primary(in: mode)
            }
        }
    }
}
