/// Decodes a JSON array, skipping elements that fail to decode as `Element`
/// instead of failing the whole array. Community Dragon's feed is not a
/// contract — a single malformed or unexpectedly-shaped entry must not take
/// the rest of the set data down with it.
struct LenientArray<Element: Decodable>: Decodable {
    let elements: [Element]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var result: [Element] = []
        while !container.isAtEnd {
            if let element = try? container.decode(Element.self) {
                result.append(element)
            } else {
                // `decode(Element.self)` failing does not reliably advance
                // `currentIndex` on its own (verified empirically against
                // Foundation's JSONDecoder — a bare `try?` loops forever on
                // a malformed element). Decoding-and-discarding one JSON
                // value of *any* shape forces the cursor forward.
                _ = try? container.decode(DiscardedJSONValue.self)
            }
        }
        elements = result
    }
}

/// Decodes and discards exactly one JSON value of any shape (object, array,
/// or scalar). Used only to advance an unkeyed container's cursor past an
/// element `LenientArray` couldn't decode as its target type.
private struct DiscardedJSONValue: Decodable {
    init(from decoder: Decoder) throws {
        if var unkeyed = try? decoder.unkeyedContainer() {
            while !unkeyed.isAtEnd {
                _ = try? unkeyed.decode(DiscardedJSONValue.self)
            }
        } else if let keyed = try? decoder.container(keyedBy: DynamicKey.self) {
            for key in keyed.allKeys {
                _ = try? keyed.decode(DiscardedJSONValue.self, forKey: key)
            }
        } else {
            let single = try decoder.singleValueContainer()
            _ = try? single.decode(Bool.self)
        }
    }

    private struct DynamicKey: CodingKey {
        var stringValue: String
        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        var intValue: Int? {
            nil
        }

        init?(intValue _: Int) {
            nil
        }
    }
}
