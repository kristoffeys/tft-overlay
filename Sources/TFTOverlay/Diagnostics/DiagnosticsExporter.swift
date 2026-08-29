import Foundation
import OSLog
import OverlayKit

enum DiagnosticsExportError: Error {
    case zipFailed(status: Int32)
}

/// Gathers a `DiagnosticsReport` and writes it out as a zip (#5). The
/// zip step shells out to `/usr/bin/ditto` — the standard macOS way to
/// create a zip archive (Xcode itself uses it) — rather than adding a
/// third-party archiving dependency for one button in Preferences.
@MainActor
enum DiagnosticsExporter {
    static func makeReport(
        overlayGeometry: OverlayGeometry?,
        activeDataPatch: String,
        recentLogLines: [String]
    ) -> DiagnosticsReport {
        DiagnosticsReport(
            generatedAt: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            activeDataPatch: activeDataPatch,
            overlayGeometryDescription: overlayGeometry.map(describe) ?? "unavailable (overlay not shown)",
            recentLogLines: recentLogLines
        )
    }

    private static func describe(_ geometry: OverlayGeometry) -> String {
        "frame=\(geometry.frame), layoutMode=\(geometry.layoutMode.rawValue), " +
            "opacity=\(geometry.opacity), scale=\(geometry.scale)"
    }

    /// Fetches recent log entries from this process's own OSLog store,
    /// across every `dev.tftoverlay.*` subsystem (app shell + each
    /// package). Never throws to the caller — an empty array means the
    /// store couldn't be opened, not that there were no logs.
    static func fetchRecentLogLines(since: Date = Date().addingTimeInterval(-3600), limit: Int = 500) -> [String] {
        guard let store = try? OSLogStore(scope: .currentProcessIdentifier) else {
            return []
        }
        let position = store.position(date: since)
        guard let entries = try? store.getEntries(at: position) else {
            return []
        }
        let formatter = ISO8601DateFormatter()
        return entries
            .compactMap { $0 as? OSLogEntryLog }
            .filter { $0.subsystem.hasPrefix("dev.tftoverlay.") }
            .suffix(limit)
            .map { "\(formatter.string(from: $0.date)) [\($0.subsystem)/\($0.category)] \($0.composedMessage)" }
    }

    /// Writes `report`'s redacted text into a zip at `destination`.
    static func export(_ report: DiagnosticsReport, to destination: URL) throws {
        let workDir = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workDir) }

        let reportFile = workDir.appendingPathComponent("diagnostics.txt")
        try report.renderedText().write(to: reportFile, atomically: true, encoding: .utf8)

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", workDir.path, destination.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw DiagnosticsExportError.zipFailed(status: process.terminationStatus)
        }
        AppLog.diagnostics.notice("Exported diagnostics to \(destination.lastPathComponent, privacy: .public)")
    }
}
