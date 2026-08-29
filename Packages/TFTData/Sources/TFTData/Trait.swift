public struct Trait: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let breakpoints: [Int]

    public init(id: String, name: String, breakpoints: [Int]) {
        self.id = id
        self.name = name
        self.breakpoints = breakpoints
    }
}
