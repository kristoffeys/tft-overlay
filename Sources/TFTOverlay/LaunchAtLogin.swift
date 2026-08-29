import ServiceManagement

/// Thin wrapper around `SMAppService.mainApp` (#7), off by default.
///
/// `SMAppService.mainApp` identifies the login item by the running
/// executable's containing `.app` bundle. This project's current build
/// (docs/adr/0001) produces a plain SwiftPM executable with an Info.plist
/// embedded via a linker section, not an installed `.app` bundle in
/// `/Applications` — real packaging is Phase 4 work. Until then,
/// registration will throw here; failures are logged rather than fatal, so
/// toggling the setting is harmless (it simply won't take effect) ahead of
/// that packaging work landing.
enum LaunchAtLogin {
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled, SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            } else if !enabled, SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            let action = enabled ? "enable" : "disable"
            AppLog.lifecycle.error(
                "Launch-at-login \(action, privacy: .public) failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}
