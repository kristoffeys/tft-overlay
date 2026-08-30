import SwiftUI
import TFTUI

/// The real panel content hosted inside `OverlayPanelController`, replacing
/// `PlaceholderOverlayContent`. In compact layout mode it shows the pinned
/// build's full roster with items (the thing worth glancing at during a live
/// game); in expanded mode it shows whichever of comps list / comp detail /
/// item cheat sheet `OverlayAppState` currently selects.
struct OverlayContentView: View {
    @ObservedObject var appState: OverlayAppState
    @Environment(\.overlayLayoutMode) private var layoutMode

    var body: some View {
        Group {
            if layoutMode == .compact {
                // The pinned build's roster, so "what do I buy" is answered
                // while collapsed. NSHostingView auto-sizes the panel to its
                // root view's intrinsic content size, so this stays greedily
                // framed to keep the configured compact size rather than
                // shrinking to its content.
                SelectedBuildRosterView(comps: appState.comps, store: appState.pinnedComps) { comp in
                    appState.select(comp)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                expandedContent
            }
        }
        // Starts `.empty` (text placeholders) and swaps in real champion/
        // item/trait art once OverlayAppState finishes its no-network
        // startup load — every icon view already treats that as a normal
        // update, not a special case.
        .tftAssetCatalog(appState.assetCatalog)
    }

    /// The tab bar plus whichever panel is showing. The bar is persistent:
    /// it is the only thing on screen that says how many panels exist and
    /// which one you are on, which ⌥C cycling never did.
    ///
    /// Which tabs it offers depends on the mode: in Focus the committed build
    /// leads and the way back to the list is the trailing accessory, not a
    /// peer tab. That is what makes "no search field and no tier chips
    /// reachable without an explicit trip to Browse" true — the browse chrome
    /// is not one tab-tap away, it is behind a labelled decision.
    private var expandedContent: some View {
        let mode = appState.mode
        return VStack(spacing: 0) {
            PanelTabBar(
                tabs: OverlayAppState.Panel.destinations(in: mode),
                selection: appState.panel.destination(in: mode),
                title: \.title,
                // The drill-down's Back lives *in* the bar rather than on a
                // row of its own, so the detail panel costs no extra height
                // than it did with its own back header.
                onBack: appState.panel.isDestination ? nil : { appState.goBack() },
                accessory: mode == .focus
                    ? .init(title: "Browse", systemImage: "square.grid.2x2") { appState.browse() }
                    : nil,
                onSelect: { appState.show($0) }
            )
            panelContent
        }
        .background(TFTTheme.background)
    }

    @ViewBuilder
    private var panelContent: some View {
        switch appState.panel {
        case .compsList:
            CompsListView(
                comps: appState.comps,
                pinnedStore: appState.pinnedComps,
                onTogglePin: { appState.togglePin($0) },
                onSelect: { appState.select($0) }
            )
        case .focusBuild:
            // A `focusBuild` panel with nothing committed cannot happen
            // through `OverlayAppState`, but rendering the list beats an
            // empty panel if it ever does.
            if let build = appState.committedBuild {
                // The committed build as a stage companion (#84), not the
                // seven-section study document: in game there is one question,
                // and the detail view is one tap down inside this.
                StageCompanionView(
                    comp: build,
                    band: appState.stageBand,
                    advanceHint: appState.stageAdvanceHint,
                    pinnedStore: appState.pinnedComps,
                    onSelectBand: { appState.setStageBand($0) },
                    onTogglePin: { appState.togglePin($0) }
                )
            } else {
                CompsListView(
                    comps: appState.comps,
                    pinnedStore: appState.pinnedComps,
                    onTogglePin: { appState.togglePin($0) },
                    onSelect: { appState.select($0) }
                )
            }
        case .compDetail:
            if let comp = appState.selectedComp {
                CompDetailView(
                    comp: comp,
                    pinnedStore: appState.pinnedComps,
                    onTogglePin: { appState.togglePin($0) }
                )
            } else {
                Spacer()
                Text("No comp selected")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TFTTheme.textSecondary)
                Spacer()
            }
        case .itemCheatSheet:
            ItemCheatSheetView(comps: appState.comps)
        case .reference:
            UnitTraitReferenceView(comps: appState.comps) { comp in
                appState.select(comp)
            }
        }
    }
}
