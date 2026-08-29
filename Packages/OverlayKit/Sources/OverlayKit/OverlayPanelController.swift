import AppKit
import SwiftUI

/// Public entry point for hosting arbitrary SwiftUI content in a
/// transparent, click-through overlay panel.
///
/// This owns everything that isn't panel content: the raw `NSPanel` (#9),
/// interactive-mode toggling with idle auto-revert (#13), drag/resize/
/// opacity/scale/snap chrome (#14), compact/expanded layout (#29), and
/// per-display geometry persistence. Standalone by design — nothing here
/// detects or attaches to any host window; the overlay is free-floating and
/// fully usable with no game running.
@MainActor
public final class OverlayPanelController<Content: View> {
    public struct Configuration: Sendable {
        public var expandedSize: CGSize
        public var compactSize: CGSize
        public var minSize: CGSize
        public var maxSize: CGSize
        public var defaultOpacity: Double
        public var idleRevertInterval: TimeInterval
        public var initialLayoutMode: OverlayLayoutMode
        public var initialAnchor: OverlayAnchor

        public init(
            expandedSize: CGSize = CGSize(width: 420, height: 560),
            compactSize: CGSize = CGSize(width: 480, height: 48),
            minSize: CGSize = CGSize(width: 240, height: 40),
            maxSize: CGSize = CGSize(width: 900, height: 1200),
            defaultOpacity: Double = 0.9,
            idleRevertInterval: TimeInterval = 8,
            initialLayoutMode: OverlayLayoutMode = .expanded,
            initialAnchor: OverlayAnchor = .bottomTrailing
        ) {
            self.expandedSize = expandedSize
            self.compactSize = compactSize
            self.minSize = minSize
            self.maxSize = maxSize
            self.defaultOpacity = defaultOpacity
            self.idleRevertInterval = idleRevertInterval
            self.initialLayoutMode = initialLayoutMode
            self.initialAnchor = initialAnchor
        }
    }

    private let panel: OverlayPanel
    private let geometryStore: OverlayGeometryStore
    private let configuration: Configuration
    private let state = OverlayPanelState()

    private var idleTimer: Timer?
    private var lastActivity: TimeInterval = ProcessInfo.processInfo.systemUptime
    private var moveObserver: NSObjectProtocol?
    private var resizeObserver: NSObjectProtocol?

    public init(
        content: Content,
        configuration: Configuration = .init(),
        geometryStore: OverlayGeometryStore = OverlayGeometryStore()
    ) {
        self.configuration = configuration
        self.geometryStore = geometryStore

        let startingSize = configuration.initialLayoutMode == .compact ? configuration.compactSize : configuration
            .expandedSize
        let screenFrame = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let initialFrame = OverlayPositioning.frame(
            for: startingSize,
            in: screenFrame,
            anchor: configuration.initialAnchor
        )

        panel = OverlayPanel(contentRect: initialFrame)
        state.opacity = configuration.defaultOpacity
        state.layoutMode = configuration.initialLayoutMode

        let chrome = OverlayChromeView(
            content: content,
            state: state,
            onResizeDrag: { [weak self] proposed in self?.applyResize(proposed) },
            onResizeEnd: { [weak self] in self?.persistCurrentGeometry() },
            onActivity: { [weak self] in self?.noteActivity() }
        )
        let hostingView = NSHostingView(rootView: chrome)
        // Without this, NSHostingView auto-sizes the panel to hosted
        // content's intrinsic size on macOS 13+, silently overriding every
        // explicit `setFrame` this controller makes (initial size, resize
        // drag, layout-mode switch, restored geometry) the moment hosted
        // content has a fixed/non-flexible size in either dimension.
        hostingView.sizingOptions = []
        panel.contentView = hostingView

        restoreGeometryForCurrentDisplay()
        observeWindowMoves()
    }

    deinit {
        if let moveObserver {
            NotificationCenter.default.removeObserver(moveObserver)
        }
        if let resizeObserver {
            NotificationCenter.default.removeObserver(resizeObserver)
        }
    }

    // MARK: - Visibility

    public var isVisible: Bool {
        panel.isVisible
    }

    public func show() {
        panel.orderFrontRegardless()
    }

    public func hide() {
        panel.orderOut(nil)
    }

    public func toggleVisibility() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    // MARK: - Interactive mode (#13)

    public var isInteractive: Bool {
        state.isInteractive
    }

    public func setInteractive(_ interactive: Bool) {
        guard state.isInteractive != interactive else { return }
        state.isInteractive = interactive
        panel.ignoresMouseEvents = !interactive
        if interactive {
            noteActivity()
            startIdleTimerIfNeeded()
        } else {
            stopIdleTimer()
            persistCurrentGeometry()
        }
    }

    public func toggleInteractive() {
        setInteractive(!isInteractive)
    }

    // MARK: - Layout mode (#29)

    public var layoutMode: OverlayLayoutMode {
        state.layoutMode
    }

    public func setLayoutMode(_ mode: OverlayLayoutMode) {
        guard state.layoutMode != mode else { return }
        state.layoutMode = mode
        let size = mode == .compact ? configuration.compactSize : configuration.expandedSize
        let current = panel.frame
        // Keep the top-left corner fixed so switching modes doesn't fling
        // the panel to a different part of the screen.
        let newOriginY = current.origin.y + current.height - size.height
        applyFrame(CGRect(x: current.origin.x, y: newOriginY, width: size.width, height: size.height))
        persistCurrentGeometry()
    }

    public func toggleLayoutMode() {
        setLayoutMode(state.layoutMode.toggled)
    }

    // MARK: - Opacity & scale (#14)

    public var opacity: Double {
        state.opacity
    }

    public func setOpacity(_ value: Double) {
        state.opacity = min(max(value, 0.1), 1.0)
        persistCurrentGeometry()
    }

    public var scale: Double {
        state.scale
    }

    public func setScale(_ value: Double) {
        state.scale = min(max(value, 0.5), 3.0)
        persistCurrentGeometry()
    }

    // MARK: - Snap presets (#14)

    public func snap(to preset: OverlaySnapPreset) {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let frame = OverlayPositioning.frame(for: preset, contentSize: panel.frame.size, in: screen.visibleFrame)
        applyFrame(frame)
        persistCurrentGeometry()
    }

    // MARK: - Resize handling

    private func applyResize(_ proposedSize: CGSize) {
        let clamped = OverlayPositioning.clamp(proposedSize, min: configuration.minSize, max: configuration.maxSize)
        let current = panel.frame
        let newOriginY = current.origin.y + current.height - clamped.height
        applyFrame(CGRect(x: current.origin.x, y: newOriginY, width: clamped.width, height: clamped.height))
    }

    private func applyFrame(_ frame: CGRect) {
        let scale = (panel.screen ?? NSScreen.main)?.backingScaleFactor ?? 1
        panel.setFrame(OverlayPositioning.pixelAligned(frame, scale: scale), display: true)
    }

    // MARK: - Idle auto-revert

    private func noteActivity() {
        lastActivity = ProcessInfo.processInfo.systemUptime
    }

    private func startIdleTimerIfNeeded() {
        guard idleTimer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkIdle() }
        }
        RunLoop.main.add(timer, forMode: .common)
        idleTimer = timer
    }

    private func stopIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = nil
    }

    private func checkIdle() {
        let now = ProcessInfo.processInfo.systemUptime
        if OverlayPositioning.shouldAutoRevert(
            lastActivity: lastActivity,
            now: now,
            idleInterval: configuration.idleRevertInterval
        ) {
            setInteractive(false)
        }
    }

    // MARK: - Persistence

    private func displayID(for screen: NSScreen) -> OverlayDisplayID {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.intValue ?? 0
    }

    private func restoreGeometryForCurrentDisplay() {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        guard let saved = geometryStore.load(for: displayID(for: screen)) else { return }

        let knownFrames = NSScreen.screens.map(\.visibleFrame)
        let validated = OverlayPositioning.validated(
            saved.frame,
            against: knownFrames,
            fallbackScreenFrame: screen.visibleFrame
        )
        applyFrame(validated)
        state.layoutMode = saved.layoutMode
        state.opacity = saved.opacity
        state.scale = saved.scale
    }

    private func persistCurrentGeometry() {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let geometry = OverlayGeometry(
            frame: panel.frame,
            layoutMode: state.layoutMode,
            opacity: state.opacity,
            scale: state.scale
        )
        geometryStore.save(geometry, for: displayID(for: screen))
    }

    private func observeWindowMoves() {
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.persistCurrentGeometry() }
        }
        // Safety net alongside the resize handle's own `onResizeEnd`, so any
        // resize (ours or external, e.g. an accessibility client) persists.
        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.persistCurrentGeometry() }
        }
    }
}
