/// A set champion. Pure data — no UI or networking types leak out of this package.
public struct Champion: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let cost: Int
    public let traitIDs: [String]

    public init(id: String, name: String, cost: Int, traitIDs: [String]) {
        self.id = id
        self.name = name
        self.cost = cost
        self.traitIDs = traitIDs
    }
}
