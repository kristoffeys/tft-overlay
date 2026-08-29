import AppKit
import SwiftUI

struct MenuBarContentView: View {
    let appDelegate: AppDelegate

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TFT Overlay").font(.headline)
            Text("Comps loaded: \(appDelegate.appState.comps.count)").font(.caption)
            Divider()
            Button(appDelegate.overlay.isVisible ? "Hide Overlay" : "Show Overlay") {
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
