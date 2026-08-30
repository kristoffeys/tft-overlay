import Foundation

/// A set champion. Pure data — no UI or networking types leak out of this package.
public struct Champion: Identifiable, Hashable, Sendable, Codable {
    public let id: String
    public let name: String
    public let cost: Int
    public let traitIDs: [String]
    /// Square portrait art on Community Dragon's asset mirror, or `nil`
    /// when the feed carried no usable icon path. A `URL` here is a
    /// *claim*, not a guarantee: the UI falls back to its text placeholder
    /// whenever the fetch or decode fails, so images stay a progressive
    /// enhancement rather than a requirement.
    public let imageURL: URL?

    public init(id: String, name: String, cost: Int, traitIDs: [String], imageURL: URL? = nil) {
        self.id = id
        self.name = name
        self.cost = cost
        self.traitIDs = traitIDs
        self.imageURL = imageURL
    }
}
