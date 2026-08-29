import Foundation

/// The result of parsing one Community Dragon set-data snapshot: the champions,
/// traits, items and augments for whichever set was live in that snapshot.
public struct ParsedSetData: Sendable, Equatable {
    public let setNumber: Int
    public let champions: [Champion]
    public let traits: [Trait]
    public let items: [Item]
    public let augments: [Augment]
}

public enum SetDataParsingError: Error, Equatable {
    /// The document didn't decode as JSON at all, or had no `sets` entries —
    /// there is nothing usable in it, not even a partial result.
    case noUsableData
}

/// Turns Community Dragon's `cdragon/tft/en_us.json` into `TFTData` domain
/// types. Pure function over `Data` — no networking, no caching, so it's
/// directly testable against pinned fixtures.
public enum SetDataParser {
    public static func parse(_ data: Data) throws -> ParsedSetData {
        let document: RawDocument
        do {
            document = try JSONDecoder().decode(RawDocument.self, from: data)
        } catch {
            throw SetDataParsingError.noUsableData
        }

        // The live set is the highest set number CDragon still serves —
        // read from the data, never hardcoded, so a full set rotation needs
        // no code change (issue #17).
        guard let (setNumber, rawSet) = document.sets
            .compactMap({ key, value -> (Int, RawSet)? in Int(key).map { ($0, value) } })
            .max(by: { $0.0 < $1.0 })
        else {
            throw SetDataParsingError.noUsableData
        }

        let traits = parseTraits(rawSet.traits)
        let champions = parseChampions(rawSet.champions, traits: traits)
        let setItems = itemsBelongingToCurrentSet(document.items, realChampions: champions.raw)

        return ParsedSetData(
            setNumber: setNumber,
            champions: champions.parsed,
            traits: traits,
            items: parseItems(setItems),
            augments: parseAugments(setItems)
        )
    }

    private static func parseTraits(_ rawTraits: [RawTrait]) -> [Trait] {
        rawTraits.map { raw in
            Trait(
                id: raw.apiName,
                name: raw.name,
                levels: raw.effects.map { Trait.Level(minUnits: $0.minUnits, maxUnits: $0.maxUnits, style: $0.style) }
            )
        }
    }

    /// A champion with no traits is a PvE-only encounter unit (jungle
    /// camps, the training dummy, etc.) that never appears in a player's
    /// shop — CDragon carries them in the same array with no separate flag,
    /// so trait-emptiness is the discriminator. Verified against the live
    /// Set 18 payload: every entry with a non-empty trait list is a real,
    /// playable unit (74/74); every empty-trait entry is a known PvE-only
    /// encounter unit. Returns the filtered raw champions alongside the
    /// parsed ones since the item-prefix derivation below needs their
    /// apiNames too.
    private static func parseChampions(
        _ rawChampions: [RawChampion],
        traits: [Trait]
    ) -> (parsed: [Champion], raw: [RawChampion]) {
        let traitIDByName = Dictionary(traits.map { ($0.name, $0.id) }, uniquingKeysWith: { first, _ in first })
        let realChampions = rawChampions.filter { !$0.traitNames.isEmpty }
        let parsed = realChampions.map { raw in
            Champion(
                id: raw.apiName,
                name: raw.name,
                cost: raw.cost,
                traitIDs: raw.traitNames.compactMap { traitIDByName[$0] }
            )
        }
        return (parsed, realChampions)
    }

    /// The flat top-level `items` array spans every set CDragon still
    /// serves, keyed by an apiName prefix that is each set's internal
    /// codename (e.g. "TFT17_" for Set 17) rather than "TFT<setNumber>_".
    /// Set 18 ("Enchanted Wilds") uses "DA_" — a fresh codename tied to the
    /// Unreal engine migration, not derivable from the set number. Derive
    /// it instead from the champions we just resolved: every Set-18
    /// champion apiName's first `_`-delimited token is "DA" (verified:
    /// 74/74 in the live payload), so the majority token across this set's
    /// own champions is that set's item-prefix, no matter what it's called
    /// next set.
    private static func itemsBelongingToCurrentSet(_ items: [RawItem], realChampions: [RawChampion]) -> [RawItem] {
        guard let itemPrefix = dominantAPINamePrefix(of: realChampions.map(\.apiName)) else { return [] }
        return items.filter { $0.apiName.hasPrefix(itemPrefix + "_") }
    }

    /// Real equippable items (base components, completed items, artifacts,
    /// radiants, trait emblems) all have an icon under an `.../items/...`
    /// path in this feed. Per-set "mechanic" entries (encounter rewards,
    /// hero-augment upgrades, portal effects) that also show up in this
    /// flat array with `isAugment == false` use a different icon path
    /// (verified against the live payload: this filter yields exactly the
    /// 9 base components + 55 completed items + artifacts/radiants/emblems
    /// for Set 18, none of the ~380 non-equippable "mechanic" entries).
    private static func parseItems(_ setItems: [RawItem]) -> [Item] {
        setItems
            .filter { !$0.isAugment && ($0.icon?.lowercased().contains("/items/") ?? false) }
            .map { Item(id: $0.apiName, name: $0.name, componentIDs: $0.composition) }
    }

    private static func parseAugments(_ setItems: [RawItem]) -> [Augment] {
        setItems
            .filter(\.isAugment)
            .map { raw in
                Augment(
                    id: raw.apiName,
                    name: raw.name,
                    tier: augmentTier(forName: raw.name),
                    text: sanitizeAugmentText(raw.desc ?? "")
                )
            }
    }

    /// The most common `_`-delimited first token among the given apiNames,
    /// ignoring the universal "TFT" token shared by every set's legacy/
    /// neutral entries. `nil` when there's nothing to derive it from.
    private static func dominantAPINamePrefix(of apiNames: [String]) -> String? {
        var counts: [String: Int] = [:]
        for apiName in apiNames {
            guard let token = apiName.split(separator: "_").first, token != "TFT" else { continue }
            counts[String(token), default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    /// TFT augments follow a set-wide, patch-stable naming convention: the
    /// base name is Silver, `<Name>+` is Gold, `<Name>++` is Prismatic. This
    /// is read off the (human-curated) display name rather than the apiName,
    /// since apiName suffixes are inconsistent ("Plus"/"PlusPlus"/roman
    /// numerals/nothing) while the display name's "+" convention is uniform.
    /// Best-effort: a handful of single-tier Prismatic-only augments have no
    /// "+" and default to Silver here — CDragon's set-data feed does not
    /// expose an explicit tier field to disambiguate that case.
    private static func augmentTier(forName name: String) -> Int {
        let plusCount = name.reversed().prefix(while: { $0 == "+" }).count
        return min(max(plusCount, 0) + 1, 3)
    }

    /// Strips the HTML-ish markup CDragon embeds in augment/ability text
    /// (`<br>`, `<magicDamage>...</magicDamage>`, etc). Leaves `@Var@`
    /// numeric-substitution tokens as-is — resolving those requires
    /// evaluating the accompanying `effects` expression map, which is out of
    /// scope for this pass; the tokens are visible but rare enough not to
    /// block reading the text.
    private static func sanitizeAugmentText(_ raw: String) -> String {
        var result = ""
        var insideTag = false
        for character in raw {
            if character == "<" {
                insideTag = true
            } else if character == ">" {
                insideTag = false
            } else if !insideTag {
                result.append(character)
            }
        }
        return result
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
