import CoreGraphics
import Foundation

/// Screen corner an overlay panel is anchored to.
public enum OverlayAnchor: Sendable {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing
}

/// Pure geometry for placing overlay panels. Kept free of AppKit so it is
/// trivially unit-testable without a display.
public enum OverlayPositioning {
    public static func frame(
        for contentSize: CGSize,
        in screenFrame: CGRect,
        anchor: OverlayAnchor,
        padding: CGFloat = 16
    ) -> CGRect {
        let x: CGFloat
        let y: CGFloat

        switch anchor {
        case .topLeading:
            x = screenFrame.minX + padding
            y = screenFrame.maxY - padding - contentSize.height
        case .topTrailing:
            x = screenFrame.maxX - padding - contentSize.width
            y = screenFrame.maxY - padding - contentSize.height
        case .bottomLeading:
            x = screenFrame.minX + padding
            y = screenFrame.minY + padding
        case .bottomTrailing:
            x = screenFrame.maxX - padding - contentSize.width
            y = screenFrame.minY + padding
        }

        return CGRect(origin: CGPoint(x: x, y: y), size: contentSize)
    }

    /// Clamps `size` between `minSize` and `maxSize`, component-wise.
    public static func clamp(_ size: CGSize, min minSize: CGSize, max maxSize: CGSize) -> CGSize {
        CGSize(
            width: Swift.min(Swift.max(size.width, minSize.width), maxSize.width),
            height: Swift.min(Swift.max(size.height, minSize.height), maxSize.height)
        )
    }

    /// Resizes `frame` while keeping its origin fixed (the standard
    /// bottom-left-anchored AppKit resize handle behavior), clamping the
    /// resulting size.
    public static func resized(
        _ frame: CGRect,
        to proposedSize: CGSize,
        min minSize: CGSize,
        max maxSize: CGSize
    ) -> CGRect {
        let size = clamp(proposedSize, min: minSize, max: maxSize)
        return CGRect(origin: frame.origin, size: size)
    }

    /// Frame for one of the fixed edge-snap presets (#14): a full-height
    /// rail on the left/right, or a full-width strip along the bottom.
    public static func frame(
        for preset: OverlaySnapPreset,
        contentSize: CGSize,
        in screenFrame: CGRect,
        padding: CGFloat = 8
    ) -> CGRect {
        switch preset {
        case .leftRail:
            CGRect(
                x: screenFrame.minX + padding,
                y: screenFrame.minY + padding,
                width: contentSize.width,
                height: screenFrame.height - 2 * padding
            )
        case .rightRail:
            CGRect(
                x: screenFrame.maxX - padding - contentSize.width,
                y: screenFrame.minY + padding,
                width: contentSize.width,
                height: screenFrame.height - 2 * padding
            )
        case .bottomStrip:
            CGRect(
                x: screenFrame.minX + padding,
                y: screenFrame.minY + padding,
                width: screenFrame.width - 2 * padding,
                height: contentSize.height
            )
        }
    }

    /// Rounds a rect's origin and size outward to the nearest whole device
    /// pixel for a given backing scale factor, to avoid the half-pixel blur
    /// that comes from a non-integral-pixel frame on Retina/mixed-DPI
    /// displays. Pass `NSScreen.backingScaleFactor` at the call site.
    public static func pixelAligned(_ rect: CGRect, scale: CGFloat) -> CGRect {
        guard scale > 0 else { return rect }
        func align(_ value: CGFloat) -> CGFloat {
            (value * scale).rounded() / scale
        }
        return CGRect(
            x: align(rect.origin.x),
            y: align(rect.origin.y),
            width: align(rect.size.width),
            height: align(rect.size.height)
        )
    }

    /// If `frame` no longer intersects any known screen (e.g. a display was
    /// unplugged since the geometry was persisted), returns a safe fallback
    /// frame fully contained in `fallbackScreenFrame`; otherwise returns
    /// `frame` unchanged.
    public static func validated(
        _ frame: CGRect,
        against knownScreenFrames: [CGRect],
        fallbackScreenFrame: CGRect
    ) -> CGRect {
        let intersectsKnownScreen = knownScreenFrames.contains { $0.intersects(frame) }
        guard !intersectsKnownScreen else { return frame }
        return self.frame(for: frame.size, in: fallbackScreenFrame, anchor: .bottomTrailing)
    }

    /// Pure idle-timeout check: has `idleInterval` elapsed since
    /// `lastActivity` as of `now`? Kept separate from any `Timer` so it is
    /// testable without a run loop.
    public static func shouldAutoRevert(
        lastActivity: TimeInterval,
        now: TimeInterval,
        idleInterval: TimeInterval
    ) -> Bool {
        now - lastActivity >= idleInterval
    }
}
