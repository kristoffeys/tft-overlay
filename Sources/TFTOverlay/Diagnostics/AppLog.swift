import OSLog

/// The app shell's own OSLog subsystem, distinct from each package's
/// (e.g. OverlayKit's `dev.tftoverlay.overlaykit`), so diagnostics export
/// and Console.app filtering can tell "app shell" apart from "which package"
/// (#5).
enum AppLog {
    static let settings = Logger(subsystem: "dev.tftoverlay.app", category: "settings")
    static let lifecycle = Logger(subsystem: "dev.tftoverlay.app", category: "lifecycle")
    static let diagnostics = Logger(subsystem: "dev.tftoverlay.app", category: "diagnostics")
}
