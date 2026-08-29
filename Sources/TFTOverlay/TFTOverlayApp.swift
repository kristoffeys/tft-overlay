import SwiftUI

@main
struct TFTOverlayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("TFT Overlay", systemImage: "square.stack.3d.up") {
            MenuBarContentView(appDelegate: appDelegate)
        }
    }
}
