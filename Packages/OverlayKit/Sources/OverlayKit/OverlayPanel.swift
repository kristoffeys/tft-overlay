import AppKit

/// The bare transparent, click-through-capable panel (#9): borderless,
/// non-activating, floats above normal windows, and survives Space
/// switches. `OverlayPanelController` is the public entry point — this
/// class only owns the raw `NSPanel` configuration.
@MainActor
final class OverlayPanel: NSPanel {
    init(contentRect: CGRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        ignoresMouseEvents = true
        // Without this, AppKit never generates `mouseMoved` events for the
        // panel, so SwiftUI's tracking-area-backed `.onHover` never sees the
        // cursor enter a view and every hover affordance — including the
        // unit/item tooltip — is silently dead (#83). Only matters while
        // `ignoresMouseEvents` is false, so it is safe to set unconditionally.
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
    }

    /// A borderless nonactivating panel can still become key (needed so the
    /// hosted SwiftUI content can receive scroll/click/drag input while
    /// interactive); it must never become main, which would fight with
    /// whatever window/game is actually in front.
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}
