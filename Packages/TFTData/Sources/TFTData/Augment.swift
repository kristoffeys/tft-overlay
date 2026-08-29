public struct Augment: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let tier: Int

    public init(id: String, name: String, tier: Int) {
        self.id = id
        self.name = name
        self.tier = tier
    }
}
