import AppKit

/// Persists panel geometry (frame, layout mode, opacity, scale) per display
/// and restores it on launch, plus observes window move/resize
/// notifications so external repositioning (a drag, an accessibility
/// client) is captured too, not just this controller's own API calls.
@MainActor
final class OverlayGeometryPersistence {
    private let panel: OverlayPanel
    private let geometryStore: OverlayGeometryStore
    private var moveObserver: NSObjectProtocol?
    private var resizeObserver: NSObjectProtocol?

    init(panel: OverlayPanel, geometryStore: OverlayGeometryStore) {
        self.panel = panel
        self.geometryStore = geometryStore
    }

    deinit {
        if let moveObserver {
            NotificationCenter.default.removeObserver(moveObserver)
        }
        if let resizeObserver {
            NotificationCenter.default.removeObserver(resizeObserver)
        }
    }

    /// Saved geometry for the panel's current display, validated against
    /// known screens (a display unplugged since it was saved falls back to
    /// a safe on-screen frame), or `nil` when there's nothing saved.
    func restoreGeometry() -> (frame: CGRect, geometry: OverlayGeometry)? {
        guard let screen = panel.screen ?? NSScreen.main else { return nil }
        guard let saved = geometryStore.load(for: displayID(for: screen)) else { return nil }
        let knownFrames = NSScreen.screens.map(\.visibleFrame)
        let validated = OverlayPositioning.validated(
            saved.frame,
            against: knownFrames,
            fallbackScreenFrame: screen.visibleFrame
        )
        return (validated, saved)
    }

    func persistCurrentGeometry(layoutMode: OverlayLayoutMode, opacity: Double, scale: Double) {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let geometry = OverlayGeometry(frame: panel.frame, layoutMode: layoutMode, opacity: opacity, scale: scale)
        geometryStore.save(geometry, for: displayID(for: screen))
    }

    func observeWindowMoves(onChange: @escaping () -> Void) {
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { _ in
            Task { @MainActor in onChange() }
        }
        // Safety net alongside the resize handle's own `onResizeEnd`, so any
        // resize (ours or external, e.g. an accessibility client) persists.
        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: panel,
            queue: .main
        ) { _ in
            Task { @MainActor in onChange() }
        }
    }

    private func displayID(for screen: NSScreen) -> OverlayDisplayID {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.intValue ?? 0
    }
}
