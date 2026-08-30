/// Shared name-normalisation for identity across champions, items and
/// traits — anywhere a player-entered, comp-authored or Community
/// Dragon-sourced display name needs to line up with another one.
///
/// Punctuation and casing are stripped, not just casing.
///
/// Community Dragon punctuates inconsistently against the conventional
/// English names comps and `StandardItems` are written with — it ships
/// "Warmogs Armor" and "Hand Of Justice" where those say "Warmog's Armor"
/// and "Hand of Justice", and the same slip happens on champions ("KaiSa"
/// vs "Kai'Sa"). Comparing on casing alone risks the same champion, item or
/// trait silently splitting into two identities — matching on casing alone
/// once cost an item its art and left a "WA" text tile in the middle of the
/// cheat sheet. `TFTAssetCatalog` (art lookups), `OwnedChampionsStore`
/// (#86) and `CompSuggestionRanking` (#87) all key on this one
/// implementation so a name typed once never quietly becomes two entries
/// in only some of them. Verified collision-free across the live set: no
/// two champions, items or traits normalise together.
enum TFTNameKey {
    static func normalize(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
