import AppKit
import SwiftUI

/// Presents hover cards in their own window, so they are not clipped by the
/// panel the hovered view lives in.
///
/// A SwiftUI `.overlay` cannot escape its hosting window's bounds. The
/// overlay panel is small — 460x640 expanded, 420x132 compact — so a card
/// anchored to anything near an edge was cut off, and in compact mode there
/// was no room for one at all. Clamping the card inside the panel only trades
/// clipping for covering the very roster it describes.
///
/// A separate borderless panel is how tooltips actually work on macOS, and it
/// is the only way to render outside the source window. This one is
/// non-activating and ignores mouse events, so it can never steal the hover
/// that summoned it or pull focus from the game underneath.
///
/// Lives in TFTUI rather than OverlayKit because the two packages must not
/// depend on each other (see CLAUDE.md) and the card is a view concern. It
/// owns no overlay state — it is told a screen rect and draws next to it.
@MainActor
final class FloatingTooltip {
    static let shared = FloatingTooltip()

    /// Distance between the anchor and the card.
    private static let gap: CGFloat = 8
    /// Kept off the screen edge by at least this much.
    private static let screenInset: CGFloat = 8

    private var panel: NSPanel?
    /// Which view currently owns the card. Moving the pointer between two
    /// hoverable cells delivers the new cell's `true` before the old cell's
    /// `false`, so a blind `hide()` would dismiss the card that just
    /// appeared. Only the owner may dismiss.
    private var ownerID: UUID?

    func show(_ content: some View, anchor: CGRect, owner: UUID) {
        ownerID = owner
        let panel = existingPanel()
        let hosting = NSHostingView(rootView: AnyView(content))
        // Deliberately leaving `sizingOptions` at its default (unlike the
        // overlay panel's own hosting view): `fittingSize` below needs it to
        // measure the card's actual content, and forcing it to `[]` collapses
        // that measurement to zero, so the panel gets set to a 0x0 frame and
        // the card never becomes visible (#83).
        let size = hosting.fittingSize
        hosting.frame = CGRect(origin: .zero, size: size)
        panel.contentView = hosting
        panel.setFrame(CGRect(origin: origin(for: size, anchor: anchor), size: size), display: true)
        panel.orderFront(nil)
    }

    /// Dismisses the card, but only on behalf of whoever currently owns it.
    func hide(owner: UUID) {
        guard ownerID == owner else { return }
        ownerID = nil
        panel?.orderOut(nil)
    }

    private func existingPanel() -> NSPanel {
        if let panel {
            return panel
        }
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // SwiftUI draws the card's own shadow; AppKit's would be a second one
        // around a transparent rectangle.
        panel.hasShadow = false
        // Above the overlay panel's `.floating`, so a card is never painted
        // under the panel that summoned it.
        panel.level = .popUpMenu
        // Never take the pointer: this window sits directly under the cursor
        // that is hovering, and swallowing that event would make the card
        // flicker itself out of existence.
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        self.panel = panel
        return panel
    }

    /// Above the anchor when there is room, below it otherwise, and always
    /// within the screen it is on. Screen coordinates are bottom-left origin.
    private func origin(for size: CGSize, anchor: CGRect) -> CGPoint {
        let screen = NSScreen.screens.first { $0.frame.intersects(anchor) } ?? NSScreen.main
        let bounds = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)

        var y = anchor.maxY + Self.gap
        if y + size.height > bounds.maxY - Self.screenInset {
            y = anchor.minY - size.height - Self.gap
        }
        y = min(max(y, bounds.minY + Self.screenInset), bounds.maxY - size.height - Self.screenInset)

        let centred = anchor.midX - size.width / 2
        let x = min(
            max(centred, bounds.minX + Self.screenInset),
            bounds.maxX - size.width - Self.screenInset
        )
        return CGPoint(x: x, y: y)
    }
}

/// Reports the hosted view's frame in screen coordinates.
///
/// SwiftUI's `GeometryProxy` only reaches window space, and the card needs
/// screen space to place a window. Going through the backing `NSView` is the
/// reliable conversion.
@MainActor
final class ScreenFrameHolder {
    weak var view: NSView?

    var screenFrame: CGRect? {
        guard let view, let window = view.window else { return nil }
        return window.convertToScreen(view.convert(view.bounds, to: nil))
    }
}

struct ScreenFrameProbe: NSViewRepresentable {
    let holder: ScreenFrameHolder

    func makeNSView(context _: Context) -> NSView {
        let view = NSView()
        holder.view = view
        return view
    }

    func updateNSView(_ nsView: NSView, context _: Context) {
        holder.view = nsView
    }
}
