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
    private var expandedContent: some View {
        VStack(spacing: 0) {
            PanelTabBar(
                tabs: OverlayAppState.Panel.destinations,
                selection: appState.panel.destination,
                title: \.title,
                // The drill-down's Back lives *in* the bar rather than on a
                // row of its own, so the detail panel costs no extra height
                // than it did with its own back header.
                onBack: appState.panel.isDestination ? nil : { appState.showList() },
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
            CompsListView(comps: appState.comps, pinnedStore: appState.pinnedComps) { comp in
                appState.select(comp)
            }
        case .compDetail:
            if let comp = appState.selectedComp {
                CompDetailView(comp: comp, pinnedStore: appState.pinnedComps)
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
