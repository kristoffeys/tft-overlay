import Foundation

/// Everything an "Export diagnostics" action bundles: recent logs, overlay
/// geometry, the configured data patch, and app/OS versions (#5). Building
/// the report and rendering it to redacted text is pure/testable; actually
/// gathering the pieces (OSLogStore, `Bundle.main`) lives in
/// `DiagnosticsExporter`.
struct DiagnosticsReport: Equatable {
    var generatedAt: Date
    var appVersion: String
    var osVersion: String
    var activeDataPatch: String
    var overlayGeometryDescription: String
    var recentLogLines: [String]

    /// Redacted plain-text rendering, ready to write to a file. Redaction
    /// is applied last, over the fully composed text, so nothing here can
    /// accidentally skip it.
    func renderedText(redact: (String) -> String = { DiagnosticsRedactor.redact($0) }) -> String {
        var lines = [
            "TFT Overlay Diagnostics",
            "Generated: \(ISO8601DateFormatter().string(from: generatedAt))",
            "App version: \(appVersion)",
            "macOS version: \(osVersion)",
            "Active data patch: \(activeDataPatch)",
            "Overlay geometry: \(overlayGeometryDescription)",
            "",
            "Recent logs:",
        ]
        lines.append(contentsOf: recentLogLines)
        return redact(lines.joined(separator: "\n"))
    }
}
