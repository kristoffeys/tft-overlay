import Combine
import Foundation

/// Observable UI state for the chrome SwiftUI draws around hosted content.
/// Kept separate from `OverlayPanelController` so the chrome view can
/// `@ObservedObject` it directly.
@MainActor
public final class OverlayPanelState: ObservableObject {
    @Published public var isInteractive: Bool = false
    @Published public var layoutMode: OverlayLayoutMode = .expanded
    @Published public var opacity: Double = 0.9
    @Published public var scale: Double = 1.0

    public init() {}
}
