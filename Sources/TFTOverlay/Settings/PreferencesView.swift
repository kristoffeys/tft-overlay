import AppKit
import OverlayKit
import SwiftUI
import UniformTypeIdentifiers

/// The Preferences window content: General (launch at login, hotkeys),
/// Overlay (opacity, scale, position, idle timeout) and Data (active patch,
/// refresh) sections (#4), plus a diagnostics export action (#5). Every
/// control writes straight into `SettingsStore`, which `AppDelegate`
/// observes to propagate changes live — there is no separate "Apply".
struct PreferencesView: View {
    @ObservedObject var store: SettingsStore
    let hotkeyManager: HotkeyManager
    let overlayGeometryProvider: () -> OverlayGeometry?
    let onRebindHotkey: (AppHotkeyAction, Hotkey) -> Void
    let onLaunchAtLoginChanged: (Bool) -> Void

    var body: some View {
        TabView {
            GeneralSettingsTab(
                store: store,
                hotkeyManager: hotkeyManager,
                overlayGeometryProvider: overlayGeometryProvider,
                onRebindHotkey: onRebindHotkey,
                onLaunchAtLoginChanged: onLaunchAtLoginChanged
            )
            .tabItem { Text("General") }

            OverlaySettingsTab(store: store)
                .tabItem { Text("Overlay") }

            DataSettingsTab(store: store)
                .tabItem { Text("Data") }
        }
        .padding(20)
        .frame(width: 440, height: 360)
    }
}

private struct GeneralSettingsTab: View {
    @ObservedObject var store: SettingsStore
    let hotkeyManager: HotkeyManager
    let overlayGeometryProvider: () -> OverlayGeometry?
    let onRebindHotkey: (AppHotkeyAction, Hotkey) -> Void
    let onLaunchAtLoginChanged: (Bool) -> Void

    @State private var exportStatus: String?

    var body: some View {
        Form {
            Toggle(
                "Launch at login",
                isOn: Binding(
                    get: { store.settings.general.launchAtLogin },
                    set: { newValue in
                        store.settings.general.launchAtLogin = newValue
                        onLaunchAtLoginChanged(newValue)
                    }
                )
            )

            Section("Hotkeys") {
                ForEach(AppHotkeyAction.allCases, id: \.rawValue) { action in
                    HotkeyRecorderRow(
                        action: action,
                        store: store,
                        hotkeyManager: hotkeyManager,
                        onRebind: onRebindHotkey
                    )
                }
            }

            Section("Diagnostics") {
                HStack {
                    Button("Export Diagnostics…") { exportDiagnostics() }
                    if let exportStatus {
                        Text(exportStatus).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    private func exportDiagnostics() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "TFTOverlay-Diagnostics.zip"
        panel.allowedContentTypes = [.zip]
        guard panel.runModal() == .OK, let destination = panel.url else { return }

        let report = DiagnosticsExporter.makeReport(
            overlayGeometry: overlayGeometryProvider(),
            activeDataPatch: store.settings.data.activePatch,
            recentLogLines: DiagnosticsExporter.fetchRecentLogLines()
        )
        do {
            try DiagnosticsExporter.export(report, to: destination)
            exportStatus = "Exported to \(destination.lastPathComponent)"
        } catch {
            exportStatus = "Export failed: \(error.localizedDescription)"
        }
    }
}

private struct OverlaySettingsTab: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        Form {
            Slider(value: $store.settings.overlay.opacity, in: 0.1 ... 1.0) {
                Text("Opacity")
            }
            Slider(value: $store.settings.overlay.scale, in: 0.5 ... 3.0) {
                Text("Scale")
            }
            Picker("Position", selection: $store.settings.overlay.anchor) {
                ForEach(OverlayAnchorPreference.allCases, id: \.rawValue) { anchor in
                    Text(anchor.displayName).tag(anchor)
                }
            }
            Slider(value: $store.settings.overlay.idleTimeoutSeconds, in: 1 ... 60) {
                Text("Idle timeout (seconds)")
            }
        }
        .padding(.top, 8)
    }
}

private struct DataSettingsTab: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        Form {
            TextField("Active patch", text: $store.settings.data.activePatch)
            Toggle("Refresh automatically", isOn: $store.settings.data.autoRefreshEnabled)
        }
        .padding(.top, 8)
    }
}
