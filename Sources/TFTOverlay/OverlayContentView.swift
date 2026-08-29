import SwiftUI
import TFTUI

/// The real panel content hosted inside `OverlayPanelController`, replacing
/// `PlaceholderOverlayContent`. In compact layout mode it always shows the
/// always-visible item cheat sheet (the thing worth glancing at during a
/// live game); in expanded mode it shows whichever of comps list / comp
/// detail / item cheat sheet `OverlayAppState` currently selects.
struct OverlayContentView: View {
    @ObservedObject var appState: OverlayAppState
    @Environment(\.overlayLayoutMode) private var layoutMode

    var body: some View {
        if layoutMode == .compact {
            // NSHostingView auto-sizes the panel to its root view's
            // intrinsic content size; CompactItemCheatSheetView has a
            // fixed grid size with no flexible dimension, so without
            // this it silently overrides whatever compact size the
            // panel was configured with. Matching PlaceholderContent's
            // approach (a Spacer-bearing, greedily-framed root) keeps
            // the panel at the configured compact size instead.
            CompactItemCheatSheetView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            expandedContent
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        switch appState.panel {
        case .compsList:
            CompsListView(comps: appState.comps) { comp in
                appState.select(comp)
            }
        case .compDetail:
            VStack(spacing: 0) {
                backHeader
                if let comp = appState.selectedComp {
                    CompDetailView(comp: comp)
                } else {
                    Spacer()
                    Text("No comp selected")
                        .foregroundStyle(TFTTheme.textSecondary)
                    Spacer()
                }
            }
            .background(TFTTheme.background)
        case .itemCheatSheet:
            ItemCheatSheetView(comps: appState.comps)
        }
    }

    private var backHeader: some View {
        HStack {
            Button {
                appState.showList()
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TFTTheme.textPrimary)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
    }
}
