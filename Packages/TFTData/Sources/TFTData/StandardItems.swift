/// The 8 standard TFT components and the 36 completed items they combine into.
///
/// This pool has been kept stable by Riot across many sets (unlike set-specific
/// artifact/radiant items and trait emblems, which rotate every set), so it is
/// hand-authored here the same way `data/comps/` is hand-authored per ADR 0002,
/// rather than sourced from a schema file. `Item.componentIDs` already models
/// exactly this shape.
public enum StandardItems {
    public static let bfSword = Item(id: "TFT_Item_BFSword", name: "B.F. Sword")
    public static let recurveBow = Item(id: "TFT_Item_RecurveBow", name: "Recurve Bow")
    public static let needlesslyLargeRod = Item(id: "TFT_Item_NeedlesslyLargeRod", name: "Needlessly Large Rod")
    public static let tearOfTheGoddess = Item(id: "TFT_Item_TearOfTheGoddess", name: "Tear of the Goddess")
    public static let chainVest = Item(id: "TFT_Item_ChainVest", name: "Chain Vest")
    public static let negatronCloak = Item(id: "TFT_Item_NegatronCloak", name: "Negatron Cloak")
    public static let giantsBelt = Item(id: "TFT_Item_GiantsBelt", name: "Giant's Belt")
    public static let sparringGloves = Item(id: "TFT_Item_SparringGloves", name: "Sparring Gloves")

    /// Ordered the same way every time so UI built on top can use this order
    /// directly for grid rows/columns instead of re-sorting.
    public static let components: [Item] = [
        bfSword, recurveBow, needlesslyLargeRod, tearOfTheGoddess,
        chainVest, negatronCloak, giantsBelt, sparringGloves,
    ]

    public static let completedItems: [Item] = [
        Item(id: "TFT_Item_Deathblade", name: "Deathblade", componentIDs: [bfSword.id, bfSword.id]),
        Item(id: "TFT_Item_GiantSlayer", name: "Giant Slayer", componentIDs: [bfSword.id, recurveBow.id]),
        Item(
            id: "TFT_Item_HextechGunblade",
            name: "Hextech Gunblade",
            componentIDs: [bfSword.id, needlesslyLargeRod.id]
        ),
        Item(id: "TFT_Item_SpearOfShojin", name: "Spear of Shojin", componentIDs: [bfSword.id, tearOfTheGoddess.id]),
        Item(id: "TFT_Item_EdgeOfNight", name: "Edge of Night", componentIDs: [bfSword.id, chainVest.id]),
        Item(id: "TFT_Item_Bloodthirster", name: "Bloodthirster", componentIDs: [bfSword.id, negatronCloak.id]),
        Item(id: "TFT_Item_SteraksGage", name: "Sterak's Gage", componentIDs: [bfSword.id, giantsBelt.id]),
        Item(id: "TFT_Item_InfinityEdge", name: "Infinity Edge", componentIDs: [bfSword.id, sparringGloves.id]),

        Item(id: "TFT_Item_RapidFirecannon", name: "Rapid Firecannon", componentIDs: [recurveBow.id, recurveBow.id]),
        Item(
            id: "TFT_Item_GuinsoosRageblade",
            name: "Guinsoo's Rageblade",
            componentIDs: [recurveBow.id, needlesslyLargeRod.id]
        ),
        Item(id: "TFT_Item_StatikkShiv", name: "Statikk Shiv", componentIDs: [recurveBow.id, tearOfTheGoddess.id]),
        Item(id: "TFT_Item_Guardbreaker", name: "Guardbreaker", componentIDs: [recurveBow.id, chainVest.id]),
        Item(id: "TFT_Item_Quicksilver", name: "Quicksilver", componentIDs: [recurveBow.id, negatronCloak.id]),
        Item(id: "TFT_Item_RunaansHurricane", name: "Runaan's Hurricane", componentIDs: [recurveBow.id, giantsBelt.id]),
        Item(id: "TFT_Item_LastWhisper", name: "Last Whisper", componentIDs: [recurveBow.id, sparringGloves.id]),

        Item(
            id: "TFT_Item_RabadonsDeathcap",
            name: "Rabadon's Deathcap",
            componentIDs: [needlesslyLargeRod.id, needlesslyLargeRod.id]
        ),
        Item(
            id: "TFT_Item_ArchangelsStaff",
            name: "Archangel's Staff",
            componentIDs: [needlesslyLargeRod.id, tearOfTheGoddess.id]
        ),
        Item(id: "TFT_Item_AdaptiveHelm", name: "Adaptive Helm", componentIDs: [needlesslyLargeRod.id, chainVest.id]),
        Item(id: "TFT_Item_IonicSpark", name: "Ionic Spark", componentIDs: [needlesslyLargeRod.id, negatronCloak.id]),
        Item(
            id: "TFT_Item_Morellonomicon",
            name: "Morellonomicon",
            componentIDs: [needlesslyLargeRod.id, giantsBelt.id]
        ),
        Item(
            id: "TFT_Item_JeweledGauntlet",
            name: "Jeweled Gauntlet",
            componentIDs: [needlesslyLargeRod.id, sparringGloves.id]
        ),

        Item(id: "TFT_Item_BlueBuff", name: "Blue Buff", componentIDs: [tearOfTheGoddess.id, tearOfTheGoddess.id]),
        Item(id: "TFT_Item_FrozenHeart", name: "Frozen Heart", componentIDs: [tearOfTheGoddess.id, chainVest.id]),
        Item(
            id: "TFT_Item_HandOfJustice",
            name: "Hand of Justice",
            componentIDs: [tearOfTheGoddess.id, negatronCloak.id]
        ),
        Item(id: "TFT_Item_Redemption", name: "Redemption", componentIDs: [tearOfTheGoddess.id, giantsBelt.id]),
        Item(id: "TFT_Item_ZekesHerald", name: "Zeke's Herald", componentIDs: [tearOfTheGoddess.id, sparringGloves.id]),

        Item(id: "TFT_Item_BrambleVest", name: "Bramble Vest", componentIDs: [chainVest.id, chainVest.id]),
        Item(
            id: "TFT_Item_GargoyleStoneplate",
            name: "Gargoyle Stoneplate",
            componentIDs: [chainVest.id, negatronCloak.id]
        ),
        Item(id: "TFT_Item_SunfireCape", name: "Sunfire Cape", componentIDs: [chainVest.id, giantsBelt.id]),
        Item(id: "TFT_Item_GuardianAngel", name: "Guardian Angel", componentIDs: [chainVest.id, sparringGloves.id]),

        Item(id: "TFT_Item_DragonsClaw", name: "Dragon's Claw", componentIDs: [negatronCloak.id, negatronCloak.id]),
        Item(id: "TFT_Item_Zephyr", name: "Zephyr", componentIDs: [negatronCloak.id, giantsBelt.id]),
        Item(
            id: "TFT_Item_ShroudOfStillness",
            name: "Shroud of Stillness",
            componentIDs: [negatronCloak.id, sparringGloves.id]
        ),

        Item(id: "TFT_Item_WarmogsArmor", name: "Warmog's Armor", componentIDs: [giantsBelt.id, giantsBelt.id]),
        Item(id: "TFT_Item_TitanicHydra", name: "Titanic Hydra", componentIDs: [giantsBelt.id, sparringGloves.id]),

        Item(
            id: "TFT_Item_ChaliceOfPower",
            name: "Chalice of Power",
            componentIDs: [sparringGloves.id, sparringGloves.id]
        ),
    ]
}
