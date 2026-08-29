import AppKit
import LCUClient
import SwiftUI

struct MenuBarContentView: View {
    let appDelegate: AppDelegate
    private let lcuClient = LCUClient()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TFT Overlay").font(.headline)
            Text("Comps loaded: \(appDelegate.appState.comps.count)").font(.caption)
            Text("LCU available: \(lcuClient.isAvailable ? "yes" : "no")").font(.caption)
            Divider()
            Button(appDelegate.overlay.isVisible ? "Hide Overlay" : "Show Overlay") {
                appDelegate.toggleOverlayVisibility()
            }
            Button("Switch Panel") {
                appDelegate.cyclePanelForward()
            }
            Button("Preferences…") {
                appDelegate.showPreferencesPlaceholder()
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
