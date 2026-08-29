import Foundation

/// Live `SetDataSource` backed by Community Dragon.
///
/// URLs verified by hand against the live site on 2026-08-29, three days
/// into Set 18 "Enchanted Wilds" / patch 18.1:
///
/// - `https://raw.communitydragon.org/latest/content-metadata.json` returns
///   `{"version": "16.17.8104348+branch.releases-16-17.content.release"}` —
///   CDragon's own content build id. It changes on every patch/hotfix and is
///   a ~60-byte response, so it's cheap to poll on a timer without
///   downloading the full set-data document just to check for a change.
/// - `https://raw.communitydragon.org/latest/cdragon/tft/en_us.json` (~24MB)
///   is Riot's static TFT data as CDragon republishes it: per-set
///   champions/traits under a `sets` object keyed by set number as a string
///   (the live set here is `sets["18"]`), plus a flat `items` array — every
///   item and augment CDragon still serves, across every set, disambiguated
///   by an apiName prefix that's each set's internal codename (Set 18's is
///   `DA_`, not `TFT18_` — see `SetDataParser`). There is no versioned path
///   (e.g. `/18.1/...`) for this particular endpoint; `/latest/` always
///   serves the current patch, which is why `content-metadata.json` is the
///   change signal instead.
public struct CommunityDragonSource: SetDataSource {
    private static let contentVersionURL = URL(string: "https://raw.communitydragon.org/latest/content-metadata.json")!
    private static let setDataURL = URL(string: "https://raw.communitydragon.org/latest/cdragon/tft/en_us.json")!

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetchContentVersion() async throws -> String {
        struct ContentMetadata: Decodable { let version: String }
        let (data, _) = try await session.data(from: Self.contentVersionURL)
        return try JSONDecoder().decode(ContentMetadata.self, from: data).version
    }

    public func fetchSetData() async throws -> Data {
        let (data, _) = try await session.data(from: Self.setDataURL)
        return data
    }
}
