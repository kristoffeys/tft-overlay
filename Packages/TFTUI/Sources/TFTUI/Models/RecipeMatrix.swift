import TFTData

/// A component x component -> completed item lookup, built from
/// `StandardItems` data rather than componentA hand-typed grid. The UI iterates
/// `components` for rows/columns and calls `completedItem(_:_:)` per cell;
/// nobody lays the grid out by hand.
public struct RecipeMatrix: Sendable {
    public let components: [Item]
    public let completedItems: [Item]

    private let itemByComponentPair: [String: Item]
    private let componentByID: [String: Item]

    public init(
        components: [Item] = StandardItems.components,
        completedItems: [Item] = StandardItems.completedItems
    ) {
        self.components = components
        self.completedItems = completedItems

        var pairIndex: [String: Item] = [:]
        for item in completedItems where item.componentIDs.count == 2 {
            pairIndex[Self.pairKey(item.componentIDs[0], item.componentIDs[1])] = item
        }
        itemByComponentPair = pairIndex

        var idIndex: [String: Item] = [:]
        for component in components {
            idIndex[component.id] = component
        }
        componentByID = idIndex
    }

    /// The completed item made from `componentA` + `componentB`, in either order.
    public func completedItem(_ componentA: Item, _ componentB: Item) -> Item? {
        itemByComponentPair[Self.pairKey(componentA.id, componentB.id)]
    }

    /// The two components `completedItem` is built from, if both resolve
    /// against `components`.
    public func recipe(for completedItem: Item) -> (Item, Item)? {
        guard completedItem.componentIDs.count == 2,
              let componentA = componentByID[completedItem.componentIDs[0]],
              let componentB = componentByID[completedItem.componentIDs[1]]
        else { return nil }
        return (componentA, componentB)
    }

    private static func pairKey(_ componentA: String, _ componentB: String) -> String {
        componentA < componentB ? "\(componentA)|\(componentB)" : "\(componentB)|\(componentA)"
    }
}
