import SwiftUI

private struct OverlayLayoutModeKey: EnvironmentKey {
    static let defaultValue: OverlayLayoutMode = .expanded
}

private struct OverlayIsInteractiveKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

public extension EnvironmentValues {
    /// Lets hosted content (built by another package) adapt its own layout
    /// to compact vs. expanded (#29) without depending on OverlayKit's
    /// internal state types.
    var overlayLayoutMode: OverlayLayoutMode {
        get { self[OverlayLayoutModeKey.self] }
        set { self[OverlayLayoutModeKey.self] = newValue }
    }

    /// Whether the overlay is currently in interactive (clickable) mode,
    /// so hosted content can e.g. enable scrolling only then.
    var overlayIsInteractive: Bool {
        get { self[OverlayIsInteractiveKey.self] }
        set { self[OverlayIsInteractiveKey.self] = newValue }
    }
}
