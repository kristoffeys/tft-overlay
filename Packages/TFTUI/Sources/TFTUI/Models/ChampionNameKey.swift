/// Shared name-normalisation for champion identity, used everywhere a
/// player-entered or comp-authored champion name needs to line up with
/// another one.
///
/// Community Dragon punctuates champion display names inconsistently
/// against the conventional English spellings comps are authored with
/// ("KaiSa" vs "Kai'Sa"), and casing drifts too. Comparing on casing alone
/// risks the same champion silently splitting into two identities — which
/// is exactly the "Warmogs Armor" / "Hand Of Justice" bug `TFTAssetCatalog`
/// already hit for items, fixed the same way: lowercase, then keep only
/// letters and numbers. `OwnedChampionsStore` and `CompSuggestionRanking`
/// both key on this so a name typed once never quietly becomes two.
enum ChampionNameKey {
    static func normalize(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
