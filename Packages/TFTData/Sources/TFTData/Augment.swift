public struct Augment: Identifiable, Hashable, Sendable, Codable {
    /// 1 = Silver, 2 = Gold, 3 = Prismatic.
    public let id: String
    public let name: String
    public let tier: Int
    public let text: String

    public init(id: String, name: String, tier: Int, text: String = "") {
        self.id = id
        self.name = name
        self.tier = tier
        self.text = text
    }
}
