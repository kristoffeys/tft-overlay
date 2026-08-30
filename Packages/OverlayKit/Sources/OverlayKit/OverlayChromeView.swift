import AppKit
import SwiftUI

/// Vertical space OverlayKit's own chrome takes from hosted content, so a
/// package on the other side of the boundary can size itself against the
/// real budget instead of guessing (#110).
///
/// `TFTUI` must not import `OverlayKit` (see `CLAUDE.md`), so it cannot read
/// this constant directly; it keeps a documented literal instead, and
/// `Tests/TFTOverlayTests` — the one place both packages meet — cross-checks
/// that literal against this real value.
public enum OverlayChromeMetrics {
    /// Height of the drag-handle header row, shown only while the panel is
    /// interactive (`OverlayPanelState.isInteractive`). Locked/click-through
    /// panels get this space back, so a caller that wants the worst-case
    /// (smallest) content area — the one a "fits without scrolling" budget
    /// needs — should always subtract it.
    public static let interactiveHeaderHeight: CGFloat = 24
}

/// Wraps arbitrary hosted content with the chrome OverlayKit itself owns
/// (#14): a header drag handle, a resize grip, and the interactive-mode
/// visual affordance (border + opacity bump). The content package (built
/// separately) never needs to know any of this exists.
struct OverlayChromeView<Content: View>: View {
    let content: Content
    @ObservedObject var state: OverlayPanelState
    let onResizeDrag: (CGSize) -> Void
    let onResizeEnd: () -> Void
    let onActivity: () -> Void
    let onLockRequested: () -> Void
    let onToggleLayoutMode: () -> Void

    private var effectiveOpacity: Double {
        state.isInteractive ? max(state.opacity, 0.98) : state.opacity
    }

    var body: some View {
        VStack(spacing: 0) {
            if state.isInteractive {
                header
            }
            content
                .environment(\.overlayLayoutMode, state.layoutMode)
                .environment(\.overlayIsInteractive, state.isInteractive)
        }
        .background(Color.clear)
        .overlay(alignment: .bottomTrailing) {
            if state.isInteractive {
                ResizeHandle(onDrag: onResizeDrag, onEnd: onResizeEnd)
                    .frame(width: 14, height: 14)
                    .padding(2)
            }
        }
        .overlay(alignment: .bottomLeading) {
            // Only the locked state needs a floating badge, because locked
            // means there is no header bar to put it in — and no way to
            // click anything anyway, so it is a label, not a control. The
            // unlocked controls live in the header instead, where they
            // cannot sit on top of the roster they are meant to sit beside.
            if !state.isInteractive, let hint = state.interactiveHintText {
                InteractiveHintBadge(text: hint)
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    state.isInteractive ? Color.accentColor.opacity(0.9) : Color.clear,
                    lineWidth: state.isInteractive ? 1.5 : 0
                )
        )
        .opacity(effectiveOpacity)
        .scaleEffect(state.scale)
        .onHover { _ in onActivity() }
    }

    private var header: some View {
        DragHandle(onActivity: onActivity)
            .frame(height: OverlayChromeMetrics.interactiveHeaderHeight)
            .overlay(alignment: .leading) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.leading, 8)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .trailing) {
                // Hit-testable, unlike the drag affordance beside it: these
                // are the only on-screen way to reach click-through and
                // compact mode, both of which used to be hotkey-only.
                HStack(spacing: 4) {
                    if let hint = state.lockHintText {
                        ChromeButton(icon: "lock.open", text: hint, action: onLockRequested)
                    }
                    if let hint = state.layoutHintText {
                        ChromeButton(
                            icon: state.layoutMode == .compact
                                ? "arrow.up.left.and.arrow.down.right"
                                : "arrow.down.right.and.arrow.up.left",
                            text: hint,
                            action: onToggleLayoutMode
                        )
                    }
                }
                .padding(.trailing, 6)
            }
            .background(Color.black.opacity(0.28))
    }
}

/// A chrome control shown only while interactive, where it can actually be
/// clicked. These exist because the modes they reach — click-through, and
/// compact layout — were previously reachable only by a hotkey nothing on
/// screen named.
private struct ChromeButton: View {
    let icon: String
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                Text(text)
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.7), in: Capsule())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(text)
        .accessibilityLabel(text)
    }
}

/// Small persistent badge telling the user how to make a click-through
/// panel clickable. Deliberately high-contrast, not a faint hint: its only
/// job is being read in the same half-second glance the rest of this
/// package's chrome is designed for, not discovered by squinting.
private struct InteractiveHintBadge: View {
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "cursorarrow.slash")
                .font(.system(size: 9, weight: .bold))
            Text(text)
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.7), in: Capsule())
    }
}

/// A thin NSView whose `mouseDown` hands off to `NSWindow.performDrag`, so
/// dragging the header handle moves the panel like a normal titlebar drag —
/// without giving the whole panel a titlebar.
private struct DragHandle: NSViewRepresentable {
    let onActivity: () -> Void

    func makeNSView(context _: Context) -> DragHandleView {
        let view = DragHandleView()
        view.onActivity = onActivity
        return view
    }

    func updateNSView(_ nsView: DragHandleView, context _: Context) {
        nsView.onActivity = onActivity
    }
}

final class DragHandleView: NSView {
    var onActivity: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onActivity?()
        window?.performDrag(with: event)
    }
}

/// A corner grip that reports proposed sizes while dragged; the controller
/// decides how to clamp/apply the resulting frame.
private struct ResizeHandle: NSViewRepresentable {
    let onDrag: (CGSize) -> Void
    let onEnd: () -> Void

    func makeNSView(context _: Context) -> ResizeHandleView {
        let view = ResizeHandleView()
        view.onDrag = onDrag
        view.onEnd = onEnd
        return view
    }

    func updateNSView(_ nsView: ResizeHandleView, context _: Context) {
        nsView.onDrag = onDrag
        nsView.onEnd = onEnd
    }
}

final class ResizeHandleView: NSView {
    var onDrag: ((CGSize) -> Void)?
    var onEnd: (() -> Void)?

    private var startFrameSize: CGSize = .zero
    private var startLocation: NSPoint = .zero

    override func mouseDown(with _: NSEvent) {
        startFrameSize = window?.frame.size ?? .zero
        startLocation = NSEvent.mouseLocation
    }

    override func mouseDragged(with _: NSEvent) {
        let current = NSEvent.mouseLocation
        let dx = current.x - startLocation.x
        let dy = startLocation.y - current.y
        onDrag?(CGSize(width: startFrameSize.width + dx, height: startFrameSize.height + dy))
    }

    override func mouseUp(with _: NSEvent) {
        onEnd?()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeUpDown)
    }
}
