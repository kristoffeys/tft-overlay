import AppKit
import Combine
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
    let settingsStore = SettingsStore()
    private let preferencesWindowController = PreferencesWindowController()
    private var settingsCancellable: AnyCancellable?

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
            defaultOpacity: settingsStore.settings.overlay.opacity,
            idleRevertInterval: settingsStore.settings.overlay.idleTimeoutSeconds,
            initialLayoutMode: .expanded
        )
    )

    func applicationDidFinishLaunching(_: Notification) {
        guard SingleInstanceGuard.acquire() else {
            AppLog.lifecycle.notice("Another instance already holds the single-instance lock; terminating")
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.accessory)
        overlay.setScale(settingsStore.settings.overlay.scale)
        overlay.moveToAnchor(settingsStore.settings.overlay.anchor.overlayAnchor)
        registerHotkeys()
        observeSettings()
        overlay.show()
    }

    func applicationWillTerminate(_: Notification) {
        // Clean shutdown (#7): tear down the panel and hotkeys explicitly
        // rather than relying on `deinit`, which process exit doesn't
        // reliably run for an app-lifetime object.
        settingsCancellable?.cancel()
        preferencesWindowController.teardown()
        overlay.teardown()
        hotkeyManager.unregisterAll()
        SingleInstanceGuard.release()
    }

    // MARK: - Hotkeys (#4)

    private func registerHotkeys() {
        for action in AppHotkeyAction.allCases {
            let hotkey = settingsStore.settings.general.hotkeys[action.rawValue] ?? action.defaultHotkey
            registerHotkey(hotkey, for: action)
        }
    }

    private func registerHotkey(_ hotkey: Hotkey, for action: AppHotkeyAction) {
        let result = hotkeyManager.register(hotkey, for: action.action) { [weak self] in
            self?.perform(action)
        }
        if case let .conflict(existing) = result {
            AppLog.lifecycle.error(
                "Hotkey conflict for \(action.rawValue, privacy: .public): already bound to \(existing.id, privacy: .public)"
            )
        }
    }

    private func perform(_ action: AppHotkeyAction) {
        switch action {
        case .toggleInteractive: overlay.toggleInteractive()
        case .toggleLayout: overlay.toggleLayoutMode()
        case .toggleVisibility: overlay.toggleVisibility()
        case .cycleForward: appState.cycleForward()
        case .cycleBackward: appState.cycleBackward()
        }
    }

    /// Rebinds `action` to `hotkey` (invoked from the Preferences hotkey
    /// recorder, which has already checked for conflicts) and persists it.
    private func rebindHotkey(_ action: AppHotkeyAction, to hotkey: Hotkey) {
        registerHotkey(hotkey, for: action)
        settingsStore.settings.general.hotkeys[action.rawValue] = hotkey
    }

    // MARK: - Settings propagation (#4 — live, no restart)

    private func observeSettings() {
        settingsCancellable = settingsStore.$settings
            .removeDuplicates()
            .sink { [weak self] settings in
                self?.applyOverlaySettings(settings.overlay)
            }
        LaunchAtLogin.setEnabled(settingsStore.settings.general.launchAtLogin)
    }

    private func applyOverlaySettings(_ overlaySettings: OverlaySettings) {
        overlay.setOpacity(overlaySettings.opacity)
        overlay.setScale(overlaySettings.scale)
        overlay.setIdleRevertInterval(overlaySettings.idleTimeoutSeconds)
        overlay.moveToAnchor(overlaySettings.anchor.overlayAnchor)
    }

    // MARK: - Menu bar actions

    func toggleOverlayVisibility() {
        overlay.toggleVisibility()
    }

    func cyclePanelForward() {
        appState.cycleForward()
    }

    func showPreferences() {
        preferencesWindowController.show(
            store: settingsStore,
            hotkeyManager: hotkeyManager,
            overlayGeometryProvider: { [weak self] in self?.overlay.currentGeometry },
            onRebindHotkey: { [weak self] action, hotkey in self?.rebindHotkey(action, to: hotkey) },
            onLaunchAtLoginChanged: { enabled in LaunchAtLogin.setEnabled(enabled) }
        )
    }

    func quit() {
        NSApp.terminate(nil)
    }
}
