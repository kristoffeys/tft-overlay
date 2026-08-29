import OSLog

/// OverlayKit's own OSLog subsystem, kept separate from the app target's and
/// other packages' so diagnostics can filter/export by subsystem (#5).
public enum OverlayKitLog {
    public static let panel = Logger(subsystem: "dev.tftoverlay.overlaykit", category: "panel")
    public static let hotkeys = Logger(subsystem: "dev.tftoverlay.overlaykit", category: "hotkeys")
}
