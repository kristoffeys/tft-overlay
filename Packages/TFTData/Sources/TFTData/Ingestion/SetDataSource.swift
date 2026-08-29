import Foundation

/// Fetches the live set-data snapshot and its version tag. Abstracted so
/// tests can inject a fixture-backed fake and never touch the network.
public protocol SetDataSource: Sendable {
    /// A cheap, small poll for "has anything changed" — must not require
    /// downloading the full set-data document.
    func fetchContentVersion() async throws -> String
    /// The full static-data document (`cdragon/tft/en_us.json` shape),
    /// handed to `SetDataParser.parse(_:)` as-is.
    func fetchSetData() async throws -> Data
}
