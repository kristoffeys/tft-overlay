/// The 8 standard TFT components and the 36 completed items the current set
/// combines them into.
///
/// **This pool is set-specific, not stable across sets.** It was previously
/// assumed to be a fixture Riot never touches; Set 18 "Enchanted Wilds"
/// disproved that by rotating roughly a third of it — Chalice of Power,
/// Frozen Heart, Guardbreaker, Redemption, Runaan's Hurricane, Zephyr,
/// Zeke's Herald, Shroud of Stillness and Guardian Angel are gone, and
/// Kraken's Fury, Nashor's Tooth, Protector's Vow, Red Buff, Spirit Visage,
/// Steadfast Heart, Striker's Flail, Titan's Resolve, Void Staff,
/// Crownguard, Evenshroud and Thief's Gloves took their slots (Rapid
/// Firecannon, Statikk Shiv and Titanic Hydra survived, but as artifacts
/// rather than component combines).
///
/// So this is a hand-transcribed copy of set data, which ADR 0002/0004
/// otherwise avoids. It exists because the item cheat sheet needs a
/// synchronous, deterministically *ordered* 8x8 grid that works on first
/// launch with no network, and neither of those falls out of the live feed:
/// Community Dragon carries no grid ordering, and the live path is async.
/// The duplication is kept honest by `StandardItemsTests`, which diffs every
/// id, recipe and name here against the bundled Community Dragon snapshot
/// (`Resources/fallback-set-data.json`) and fails the build if the two ever
/// disagree — so a set rotation surfaces as a red test naming the exact
/// items that moved, not as a silently wrong cheat sheet.
///
/// Names use the conventional English spelling ("Warmog's Armor",
/// "Hand of Justice") rather than Community Dragon's inconsistent
/// punctuation ("Warmogs Armor", "Hand Of Justice"), since these are what
/// the UI shows and what `data/comps/` item priorities are written against.
/// The ids are Community Dragon's apiNames verbatim.
///
/// This covers only the 2-component standard pool. Artifacts, radiants and
/// trait emblems are set-specific and come from the live/bundled catalog
/// (`TFTDataService` / `BundledFallbackData`), never from here.
public enum StandardItems {
    public static let bfSword = Item(id: "DA_Component_BFSword", name: "B.F. Sword")
    public static let recurveBow = Item(id: "DA_Component_RecurveBow", name: "Recurve Bow")
    public static let needlesslyLargeRod = Item(id: "DA_Component_NeedlesslyLargeRod", name: "Needlessly Large Rod")
    public static let tearOfTheGoddess = Item(id: "DA_Component_TearOfTheGoddess", name: "Tear of the Goddess")
    public static let chainVest = Item(id: "DA_Component_ChainVest", name: "Chain Vest")
    public static let negatronCloak = Item(id: "DA_Component_NegatronCloak", name: "Negatron Cloak")
    public static let giantsBelt = Item(id: "DA_Component_GiantsBelt", name: "Giant's Belt")
    public static let sparringGloves = Item(id: "DA_Component_SparringGloves", name: "Sparring Gloves")

    /// Ordered the same way every time so UI built on top can use this order
    /// directly for grid rows/columns instead of re-sorting.
    public static let components: [Item] = [
        bfSword, recurveBow, needlesslyLargeRod, tearOfTheGoddess,
        chainVest, negatronCloak, giantsBelt, sparringGloves,
    ]

    public static let completedItems: [Item] = [
        Item(id: "DA_Deathblade", name: "Deathblade", componentIDs: [bfSword.id, bfSword.id]),
        Item(id: "DA_GiantSlayer", name: "Giant Slayer", componentIDs: [bfSword.id, recurveBow.id]),
        Item(id: "DA_HextechGunblade", name: "Hextech Gunblade", componentIDs: [bfSword.id, needlesslyLargeRod.id]),
        Item(id: "DA_SpearOfShojin", name: "Spear of Shojin", componentIDs: [bfSword.id, tearOfTheGoddess.id]),
        Item(id: "DA_EdgeOfNight", name: "Edge of Night", componentIDs: [bfSword.id, chainVest.id]),
        Item(id: "DA_Bloodthirster", name: "Bloodthirster", componentIDs: [bfSword.id, negatronCloak.id]),
        Item(id: "DA_SteraksGage", name: "Sterak's Gage", componentIDs: [bfSword.id, giantsBelt.id]),
        Item(id: "DA_InfinityEdge", name: "Infinity Edge", componentIDs: [bfSword.id, sparringGloves.id]),

        Item(id: "DA_RedBuff", name: "Red Buff", componentIDs: [recurveBow.id, recurveBow.id]),
        Item(
            id: "DA_GuinsoosRageblade",
            name: "Guinsoo's Rageblade",
            componentIDs: [recurveBow.id, needlesslyLargeRod.id]
        ),
        Item(id: "DA_VoidStaff", name: "Void Staff", componentIDs: [recurveBow.id, tearOfTheGoddess.id]),
        Item(id: "DA_TitansResolve", name: "Titan's Resolve", componentIDs: [recurveBow.id, chainVest.id]),
        Item(id: "DA_KrakensFury", name: "Kraken's Fury", componentIDs: [recurveBow.id, negatronCloak.id]),
        Item(id: "DA_NashorsTooth", name: "Nashor's Tooth", componentIDs: [recurveBow.id, giantsBelt.id]),
        Item(id: "DA_LastWhisper", name: "Last Whisper", componentIDs: [recurveBow.id, sparringGloves.id]),

        Item(
            id: "DA_RabadonsDeathcap",
            name: "Rabadon's Deathcap",
            componentIDs: [needlesslyLargeRod.id, needlesslyLargeRod.id]
        ),
        Item(
            id: "DA_ArchangelsStaff",
            name: "Archangel's Staff",
            componentIDs: [needlesslyLargeRod.id, tearOfTheGoddess.id]
        ),
        Item(id: "DA_Crownguard", name: "Crownguard", componentIDs: [needlesslyLargeRod.id, chainVest.id]),
        Item(id: "DA_IonicSpark", name: "Ionic Spark", componentIDs: [needlesslyLargeRod.id, negatronCloak.id]),
        Item(id: "DA_Morellonomicon", name: "Morellonomicon", componentIDs: [needlesslyLargeRod.id, giantsBelt.id]),
        Item(
            id: "DA_JeweledGauntlet",
            name: "Jeweled Gauntlet",
            componentIDs: [needlesslyLargeRod.id, sparringGloves.id]
        ),

        Item(id: "DA_BlueBuff", name: "Blue Buff", componentIDs: [tearOfTheGoddess.id, tearOfTheGoddess.id]),
        Item(id: "DA_ProtectorsVow", name: "Protector's Vow", componentIDs: [tearOfTheGoddess.id, chainVest.id]),
        Item(id: "DA_AdaptiveHelm", name: "Adaptive Helm", componentIDs: [tearOfTheGoddess.id, negatronCloak.id]),
        Item(id: "DA_SpiritVisage", name: "Spirit Visage", componentIDs: [tearOfTheGoddess.id, giantsBelt.id]),
        Item(id: "DA_HandOfJustice", name: "Hand of Justice", componentIDs: [tearOfTheGoddess.id, sparringGloves.id]),

        Item(id: "DA_BrambleVest", name: "Bramble Vest", componentIDs: [chainVest.id, chainVest.id]),
        Item(id: "DA_GargoyleStoneplate", name: "Gargoyle Stoneplate", componentIDs: [chainVest.id, negatronCloak.id]),
        Item(id: "DA_SunfireCape", name: "Sunfire Cape", componentIDs: [chainVest.id, giantsBelt.id]),
        Item(id: "DA_SteadfastHeart", name: "Steadfast Heart", componentIDs: [chainVest.id, sparringGloves.id]),

        Item(id: "DA_DragonsClaw", name: "Dragon's Claw", componentIDs: [negatronCloak.id, negatronCloak.id]),
        Item(id: "DA_Evenshroud", name: "Evenshroud", componentIDs: [negatronCloak.id, giantsBelt.id]),
        Item(id: "DA_Quicksilver", name: "Quicksilver", componentIDs: [negatronCloak.id, sparringGloves.id]),

        Item(id: "DA_WarmogsArmor", name: "Warmog's Armor", componentIDs: [giantsBelt.id, giantsBelt.id]),
        Item(id: "DA_StrikersFlail", name: "Striker's Flail", componentIDs: [giantsBelt.id, sparringGloves.id]),

        Item(id: "DA_ThiefsGloves", name: "Thief's Gloves", componentIDs: [sparringGloves.id, sparringGloves.id]),
    ]
}
