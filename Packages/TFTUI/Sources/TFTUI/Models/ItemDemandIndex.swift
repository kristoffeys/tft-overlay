/// One comp's carry wanting a given item, at a given priority rank.
public struct ItemDemandEntry: Identifiable, Hashable, Sendable {
    public var id: String {
        "\(compID)-\(unit)"
    }

    public let compID: String
    public let compName: String
    public let unit: String
    /// 1-based position in that carry's `itemPriority`.
    public let priorityRank: Int
}

/// Reverse lookup from a completed item's name to every loaded comp's carry
/// that prioritizes it — the "completed item -> units that want it" side of
/// the cheat sheet (#19).
public struct ItemDemandIndex: Sendable {
    private let entriesByItemName: [String: [ItemDemandEntry]]

    public init(comps: [Comp]) {
        var index: [String: [ItemDemandEntry]] = [:]
        for comp in comps {
            for carry in comp.carries {
                for (offset, itemName) in carry.itemPriority.enumerated() {
                    let entry = ItemDemandEntry(
                        compID: comp.id,
                        compName: comp.name,
                        unit: carry.unit,
                        priorityRank: offset + 1
                    )
                    index[itemName, default: []].append(entry)
                }
            }
        }
        entriesByItemName = index
    }

    public func entries(forItemNamed name: String) -> [ItemDemandEntry] {
        entriesByItemName[name] ?? []
    }
}
