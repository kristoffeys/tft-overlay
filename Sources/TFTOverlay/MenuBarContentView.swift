import AppKit
import OverlayKit
import SwiftUI

struct MenuBarContentView: View {
    let appDelegate: AppDelegate
    /// Observed, not read once: the overlay can be hidden by hotkey or by
    /// this menu, and the title has to follow either way.
    @ObservedObject var panelState: OverlayPanelState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TFT Overlay").font(.headline)
            Text("Comps loaded: \(appDelegate.appState.comps.count)").font(.caption)
            Divider()
            Button(panelState.isVisible ? "Hide Overlay" : "Show Overlay") {
                appDelegate.toggleOverlayVisibility()
            }
            Button("Switch Panel") {
                appDelegate.cyclePanelForward()
            }
            Button("Preferences…") {
                appDelegate.showPreferences()
            }
            Divider()
            Button("Quit") {
                appDelegate.quit()
            }
        }
        .padding(8)
        .frame(width: 220)
    }
}
