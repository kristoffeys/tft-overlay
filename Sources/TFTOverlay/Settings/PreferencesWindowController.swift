import AppKit
import OverlayKit
import SwiftUI

/// Owns the single Preferences window (#4), created lazily on first
/// "Preferences…" invocation and reused afterwards rather than creating a
/// new one each time. Plain `NSWindow` + `NSHostingController` rather than
/// SwiftUI's `Settings` scene: this app has `LSUIElement` set and no main
/// menu (docs/adr/0001), and the `Settings` scene's automatic wiring
/// assumes a standard menu-bar app with a Preferences menu command.
@MainActor
final class PreferencesWindowController {
    private var window: NSWindow?

    func show(
        store: SettingsStore,
        hotkeyManager: HotkeyManager,
        overlayGeometryProvider: @escaping () -> OverlayGeometry?,
        onRebindHotkey: @escaping (AppHotkeyAction, Hotkey) -> Void,
        onLaunchAtLoginChanged: @escaping (Bool) -> Void
    ) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let content = PreferencesView(
            store: store,
            hotkeyManager: hotkeyManager,
            overlayGeometryProvider: overlayGeometryProvider,
            onRebindHotkey: onRebindHotkey,
            onLaunchAtLoginChanged: onLaunchAtLoginChanged
        )
        let hostingController = NSHostingController(rootView: content)
        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.title = "Preferences"
        newWindow.styleMask = [.titled, .closable]
        newWindow.isReleasedWhenClosed = false
        newWindow.center()
        window = newWindow

        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Part of clean shutdown (#7): closes the window if it's open so
    /// nothing is left dangling when the app quits.
    func teardown() {
        window?.close()
        window = nil
    }
}
