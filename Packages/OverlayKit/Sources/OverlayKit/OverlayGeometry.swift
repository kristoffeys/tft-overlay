import CoreGraphics

/// Which layout a panel is currently drawn in.
///
/// Compact is a thin always-on strip; expanded shows full panels. Persisted
/// per display alongside geometry (#29).
public enum OverlayLayoutMode: String, Sendable, Codable, CaseIterable, Equatable {
    case compact
    case expanded

    public var toggled: OverlayLayoutMode {
        self == .compact ? .expanded : .compact
    }
}

/// Edge-snap presets a panel can be pinned to (#14).
public enum OverlaySnapPreset: String, Sendable, Codable, CaseIterable, Equatable {
    case leftRail
    case rightRail
    case bottomStrip
}

/// Everything about a panel's placement/appearance that should survive a
/// relaunch, scoped to a single display.
public struct OverlayGeometry: Sendable, Codable, Equatable {
    public var frame: CGRect
    public var layoutMode: OverlayLayoutMode
    public var opacity: Double
    public var scale: Double

    public init(
        frame: CGRect,
        layoutMode: OverlayLayoutMode = .expanded,
        opacity: Double = 0.9,
        scale: Double = 1.0
    ) {
        self.frame = frame
        self.layoutMode = layoutMode
        self.opacity = opacity
        self.scale = scale
    }
}

/// Stable-for-a-session identifier for a physical display (backed by
/// `CGDirectDisplayID` at the call site). Kept as a plain integer here so
/// this module has no AppKit dependency.
public typealias OverlayDisplayID = Int
