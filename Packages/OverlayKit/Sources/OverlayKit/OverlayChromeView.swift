import AppKit
import SwiftUI

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
            .frame(height: 22)
            .overlay(
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                }
                .padding(.horizontal, 8)
                .allowsHitTesting(false)
            )
            .background(Color.black.opacity(0.28))
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
