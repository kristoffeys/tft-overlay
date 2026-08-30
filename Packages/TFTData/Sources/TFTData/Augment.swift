import Foundation

public struct Augment: Identifiable, Hashable, Sendable, Codable {
    /// 1 = Silver, 2 = Gold, 3 = Prismatic.
    public let id: String
    public let name: String
    public let tier: Int
    public let text: String
    /// Augment icon on Community Dragon's asset mirror; see
    /// `Champion.imageURL` for why this is best-effort.
    public let imageURL: URL?

    public init(id: String, name: String, tier: Int, text: String = "", imageURL: URL? = nil) {
        self.id = id
        self.name = name
        self.tier = tier
        self.text = text
        self.imageURL = imageURL
    }
}
