import Combine
import Foundation

/// Observable UI state for the chrome SwiftUI draws around hosted content.
/// Kept separate from `OverlayPanelController` so the chrome view can
/// `@ObservedObject` it directly.
@MainActor
public final class OverlayPanelState: ObservableObject {
    /// Whether the panel is on screen. Published so an app layer can drive
    /// UI from it — a menu item that says "Hide" vs "Show", for instance.
    /// Reading `NSWindow.isVisible` directly is a snapshot that never
    /// notifies, so anything rendered from it silently goes stale.
    @Published public var isVisible: Bool = false
    @Published public var isInteractive: Bool = false
    @Published public var layoutMode: OverlayLayoutMode = .expanded
    @Published public var opacity: Double = 0.9
    @Published public var scale: Double = 1.0
    /// Shown as a small persistent badge while click-through, so the panel
    /// itself says how to unlock it instead of that living only in a menu
    /// the user has no reason to open. `nil` shows nothing (e.g. before the
    /// app layer has resolved the actual bound hotkey). Not shown at all
    /// once interactive — the badge's only job is answering "how do I
    /// click this", which stops being a question once you can.
    @Published public var interactiveHintText: String?

    /// Tooltip for the lock control shown while interactive. The panel is
    /// clickable in that state, so unlike `interactiveHintText` this can be
    /// a real button rather than a label the user has to read a hotkey off.
    @Published public var lockHintText: String?

    /// Tooltip for the compact/expand control shown while interactive.
    @Published public var layoutHintText: String?

    public init() {}
}
