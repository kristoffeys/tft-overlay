import Foundation

/// Identifies which live-data snapshot a `TFTDataStore` was built from, so
/// the UI can show "data from patch X" and the ingestion pipeline can tell
/// whether a newer snapshot is available without re-downloading it.
public struct DataVersion: Hashable, Sendable, Codable {
    /// The TFT set number (e.g. 18), read from the data itself rather than
    /// hardcoded, so set rotation doesn't require a code change.
    public let setNumber: Int
    /// Community Dragon's own content build identifier
    /// (`content-metadata.json`'s `version` field, e.g.
    /// `"16.17.8104348+branch.releases-16-17.content.release"`). Opaque —
    /// only used for equality checks to detect a patch/hotfix.
    public let contentVersion: String
    public let fetchedAt: Date

    public init(setNumber: Int, contentVersion: String, fetchedAt: Date) {
        self.setNumber = setNumber
        self.contentVersion = contentVersion
        self.fetchedAt = fetchedAt
    }
}
