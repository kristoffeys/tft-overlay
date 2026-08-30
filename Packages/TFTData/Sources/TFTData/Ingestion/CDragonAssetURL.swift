import Foundation

/// Turns the Riot-internal texture paths Community Dragon carries in its
/// set-data document into fetchable image URLs.
///
/// The set-data feed (`cdragon/tft/en_us.json`) references art by the path
/// it has *inside the game client's* asset bundle — mixed case, with a
/// `.tex` extension that is a Riot container format no browser or
/// `NSImage` can read. Community Dragon separately republishes every one of
/// those assets, transcoded to PNG, under `/latest/game/<path>`, with the
/// path lowercased and the extension swapped. So the transform is purely
/// mechanical:
///
///     assets/characters/tft18_gromp/tft18_gromp_square.tex
///  -> https://raw.communitydragon.org/latest/game/assets/characters/tft18_gromp/tft18_gromp_square.png
///
/// Verified by hand against the live mirror on 2026-08-29 across a random
/// sample of Set 18 champions, items, traits and augments — all 200 OK,
/// 128x128 for champion/item/augment art and 32x32 for trait icons.
///
/// This is a pure string transform with no networking, so it is directly
/// testable. Nothing here validates that the asset actually exists: a
/// well-formed URL for a missing asset is indistinguishable from a live one
/// until fetched, and the UI already treats "image didn't load" the same as
/// "no URL" (it keeps its text placeholder).
public enum CDragonAssetURL {
    /// Community Dragon's raw game-asset mirror. `latest` tracks the live
    /// patch, matching `CommunityDragonSource`'s use of the same alias for
    /// the set-data document itself.
    public static let assetBaseURL = "https://raw.communitydragon.org/latest/game/"

    /// Extensions the feed uses for texture references. `.tex` is the
    /// overwhelming majority; `.dds` shows up on older, carried-over
    /// assets. Both are republished as `.png`.
    private static let textureExtensions = [".tex", ".dds"]

    /// - Parameter gamePath: A path as it appears in the CDragon set-data
    ///   document, e.g. `assets/characters/tft18_ahri/tft18_ahri_square.tex`.
    /// - Returns: The PNG URL on CDragon's asset mirror, or `nil` when the
    ///   path is missing, empty, or not a recognisable image reference.
    ///   Callers treat `nil` as "no art available" and fall back to a text
    ///   placeholder — this never throws.
    public static func imageURL(forGamePath gamePath: String?) -> URL? {
        guard let gamePath else { return nil }

        var path = gamePath
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !path.isEmpty else { return nil }

        // A few entries carry a leading slash; the base URL already ends
        // in one, and a doubled slash 404s on the mirror.
        while path.hasPrefix("/") {
            path.removeFirst()
        }
        guard !path.isEmpty else { return nil }

        if let textureExtension = textureExtensions.first(where: { path.hasSuffix($0) }) {
            path.removeLast(textureExtension.count)
            path += ".png"
        } else if !path.hasSuffix(".png"), !path.hasSuffix(".jpg") {
            // Not an image reference we know how to resolve. Better to show
            // the text placeholder than to build a URL that will 404 on
            // every launch.
            return nil
        }

        // The feed is not a contract. Refuse anything that could resolve
        // outside the asset base rather than encoding it into a URL: a
        // relative segment or a character outside the plain lowercase-ASCII
        // path alphabet these paths actually use means the entry is not
        // something we know how to serve.
        guard !path.contains(".."), path.unicodeScalars.allSatisfy(CharacterSet.cdragonPathAllowed.contains)
        else { return nil }
        return URL(string: assetBaseURL + path)
    }
}

private extension CharacterSet {
    /// Every character CDragon asset paths actually use, after lowercasing.
    /// Anything else — a space, a scheme's `:`, a query's `?` — means the
    /// string is not one of these paths, and is refused.
    static let cdragonPathAllowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-_./")
}
