import Foundation

public struct Item: Identifiable, Hashable, Sendable, Codable {
    public let id: String
    public let name: String
    public let componentIDs: [String]
    /// Item icon on Community Dragon's asset mirror; see `Champion.imageURL`
    /// for why this is best-effort.
    public let imageURL: URL?

    public init(id: String, name: String, componentIDs: [String] = [], imageURL: URL? = nil) {
        self.id = id
        self.name = name
        self.componentIDs = componentIDs
        self.imageURL = imageURL
    }
}
