public struct Item: Identifiable, Hashable, Sendable, Codable {
    public let id: String
    public let name: String
    public let componentIDs: [String]

    public init(id: String, name: String, componentIDs: [String] = []) {
        self.id = id
        self.name = name
        self.componentIDs = componentIDs
    }
}
