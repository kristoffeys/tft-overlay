import AppKit

/// Lets a click-through panel be moved by holding a modifier key and
/// dragging anywhere on it, without requiring interactive mode first.
///
/// A click-through panel (`ignoresMouseEvents = true`) never receives its
/// own mouse events — there is no event for a local drag handler to
/// intercept, no matter what modifier is held. A *global* monitor still
/// observes the event stream regardless, without consuming it (unlike a
/// local monitor, a global one can't swallow the event even if it wanted
/// to), so this is the only way to reposition the panel without forcing the
/// user into interactive mode just to drag it. Deliberately independent of
/// interactive mode — Option+drag anywhere on the panel is meant to be one
/// consistent way to move it either way, not one more thing that only
/// works in one mode.
@MainActor
final class OverlayModifierDragController {
    private let panel: OverlayPanel
    private let requiredModifiers: NSEvent.ModifierFlags
    private let onDragStart: () -> Void
    private let onDragEnd: () -> Void

    private var monitor: Any?
    private var startMouseLocation: NSPoint?
    private var startPanelOrigin: NSPoint?

    init(
        panel: OverlayPanel,
        requiredModifiers: NSEvent.ModifierFlags = .option,
        onDragStart: @escaping () -> Void,
        onDragEnd: @escaping () -> Void
    ) {
        self.panel = panel
        self.requiredModifiers = requiredModifiers
        self.onDragStart = onDragStart
        self.onDragEnd = onDragEnd
        monitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            self?.handle(event)
        }
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            let heldFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard heldFlags.contains(requiredModifiers) else { return }
            let location = NSEvent.mouseLocation
            guard panel.frame.contains(location) else { return }
            startMouseLocation = location
            startPanelOrigin = panel.frame.origin
            onDragStart()
        case .leftMouseDragged:
            guard let startMouse = startMouseLocation, let startOrigin = startPanelOrigin else { return }
            let current = NSEvent.mouseLocation
            let proposedOrigin = NSPoint(
                x: startOrigin.x + (current.x - startMouse.x),
                y: startOrigin.y + (current.y - startMouse.y)
            )
            panel.setFrameOrigin(proposedOrigin)
        case .leftMouseUp:
            guard startMouseLocation != nil else { return }
            startMouseLocation = nil
            startPanelOrigin = nil
            onDragEnd()
        default:
            break
        }
    }
}
