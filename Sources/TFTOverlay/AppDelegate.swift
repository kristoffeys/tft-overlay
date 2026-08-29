import AppKit
import OverlayKit
import TFTUI

/// Wires the menu bar shell to OverlayKit, hosting the real TFTUI panels
/// (comps list, comp detail, item cheat sheet) instead of
/// `PlaceholderOverlayContent`. Fully usable standalone: no game, no host,
/// nothing detected. Free-positioned on screen and usable on a bare desktop.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let hotkeyManager = HotkeyManager()
    let appState = OverlayAppState()
    private(set) lazy var overlay = OverlayPanelController(
        content: OverlayContentView(appState: appState),
        configuration: .init(
            // Wide/tall enough that the comps list, detail scroller and
            // item grid all read comfortably — OverlayKit's own default
            // (420x560) is a fine floor, but these panels want a bit more
            // room. Compact hosts CompactItemCheatSheetView, a squarish
            // fixed grid (~262x262 for the standard component set), not a
            // thin strip — OverlayKit's 480x48 default doesn't fit it.
            expandedSize: CGSize(width: 460, height: 640),
            compactSize: CGSize(width: 300, height: 320),
            minSize: CGSize(width: 300, height: 240),
            maxSize: CGSize(width: 900, height: 1200),
            initialLayoutMode: .expanded
        )
    )

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.accessory)
        registerHotkeys()
        overlay.show()
    }

    private func registerHotkeys() {
        // Option+O: toggle interactive (clickable) vs. click-through mode.
        hotkeyManager.register(Hotkey(keyCode: 31, modifierFlags: .option)) { [weak self] in
            self?.overlay.toggleInteractive()
        }
        // Option+L: toggle compact vs. expanded layout.
        hotkeyManager.register(Hotkey(keyCode: 37, modifierFlags: .option)) { [weak self] in
            self?.overlay.toggleLayoutMode()
        }
        // Option+H: show/hide the overlay entirely.
        hotkeyManager.register(Hotkey(keyCode: 4, modifierFlags: .option)) { [weak self] in
            self?.overlay.toggleVisibility()
        }
        // Option+C: cycle comps list -> comp detail -> item cheat sheet.
        hotkeyManager.register(Hotkey(keyCode: 8, modifierFlags: .option)) { [weak self] in
            self?.appState.cycleForward()
        }
        // Option+Shift+C: cycle backward / get back to the previous panel.
        hotkeyManager.register(Hotkey(keyCode: 8, modifierFlags: [.option, .shift])) { [weak self] in
            self?.appState.cycleBackward()
        }
    }

    // MARK: - Menu bar actions

    func toggleOverlayVisibility() {
        overlay.toggleVisibility()
    }

    func cyclePanelForward() {
        appState.cycleForward()
    }

    func showPreferencesPlaceholder() {
        let alert = NSAlert()
        alert.messageText = "Preferences"
        alert.informativeText = "Preferences aren't implemented yet."
        alert.alertStyle = .informational
        alert.runModal()
    }

    func quit() {
        NSApp.terminate(nil)
    }
}
