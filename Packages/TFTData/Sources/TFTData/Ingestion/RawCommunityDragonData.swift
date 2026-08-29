/// Decoding types for Community Dragon's `cdragon/tft/en_us.json` shape.
///
/// Only the fields `SetDataParser` actually consumes are declared — Codable
/// ignores unknown keys, so the rest of that (large) document is simply
/// skipped. Every type here decodes leniently: a champion/trait/item missing
/// a non-essential field falls back to an empty/zero default rather than
/// failing the whole entry, and `RawDocument.sets` values individually
/// missing `champions`/`traits` do the same. Only `apiName`/`name` are load
/// bearing — an entry missing those can't be identified, so it throws and
/// `LenientArray` drops it.
struct RawDocument: Decodable {
    /// Empty when the `items` key is missing/malformed — a partial response
    /// still yields usable champions/traits, just no items or augments.
    let items: [RawItem]
    /// Empty when the `sets` key is missing/malformed — `SetDataParser`
    /// treats that as "no usable data" and throws.
    let sets: [String: RawSet]

    private enum CodingKeys: String, CodingKey {
        case items, sets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? container.decode(LenientArray<RawItem>.self, forKey: .items))?.elements ?? []
        sets = (try? container.decode([String: RawSet].self, forKey: .sets)) ?? [:]
    }
}

struct RawSet: Decodable {
    let champions: [RawChampion]
    let traits: [RawTrait]

    private enum CodingKeys: String, CodingKey {
        case champions, traits
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawChampions = (try? container.decode(LenientArray<RawChampion>.self, forKey: .champions))?.elements ?? []
        let rawTraits = (try? container.decode(LenientArray<RawTrait>.self, forKey: .traits))?.elements ?? []
        champions = rawChampions
        traits = rawTraits
    }
}

struct RawChampion: Decodable {
    let apiName: String
    let name: String
    let cost: Int
    /// Trait *display names* (e.g. "Riftbeast"), not apiNames — CDragon
    /// links champions to traits by name here, unlike everywhere else in
    /// this document. `SetDataParser` resolves these against the set's
    /// trait list to get IDs.
    let traitNames: [String]

    private enum CodingKeys: String, CodingKey {
        case apiName, name, cost, traits
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        apiName = try container.decode(String.self, forKey: .apiName)
        name = try container.decode(String.self, forKey: .name)
        cost = (try? container.decode(Int.self, forKey: .cost)) ?? 0
        traitNames = (try? container.decode([String].self, forKey: .traits)) ?? []
    }
}

struct RawTrait: Decodable {
    let apiName: String
    let name: String
    let effects: [RawTraitEffect]

    private enum CodingKeys: String, CodingKey {
        case apiName, name, effects
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        apiName = try container.decode(String.self, forKey: .apiName)
        name = try container.decode(String.self, forKey: .name)
        effects = (try? container.decode(LenientArray<RawTraitEffect>.self, forKey: .effects))?.elements ?? []
    }
}

struct RawTraitEffect: Decodable {
    let minUnits: Int
    let maxUnits: Int
    let style: Int

    private enum CodingKeys: String, CodingKey {
        case minUnits, maxUnits, style
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        minUnits = try container.decode(Int.self, forKey: .minUnits)
        maxUnits = (try? container.decode(Int.self, forKey: .maxUnits)) ?? Int.max
        style = (try? container.decode(Int.self, forKey: .style)) ?? 0
    }
}

struct RawItem: Decodable {
    let apiName: String
    let name: String
    let composition: [String]
    let isAugment: Bool
    let desc: String?
    /// Asset path. Real equippable items live under an `.../items/...`
    /// directory in this feed; augments, trait-emblem mechanics and unrelated
    /// per-set "mechanic" entries (encounter rewards, portal effects) don't.
    /// See `SetDataParser` for how this is used to filter the flat `items`
    /// array down to real equipment.
    let icon: String?

    private enum CodingKeys: String, CodingKey {
        case apiName, name, composition, isAugment, desc, icon
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        apiName = try container.decode(String.self, forKey: .apiName)
        name = try container.decode(String.self, forKey: .name)
        composition = (try? container.decode([String].self, forKey: .composition)) ?? []
        isAugment = (try? container.decode(Bool.self, forKey: .isAugment)) ?? false
        desc = try? container.decode(String.self, forKey: .desc)
        icon = try? container.decode(String.self, forKey: .icon)
    }
}
