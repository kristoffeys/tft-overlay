import CoreGraphics

/// How many fixed-width tiles a `LazyVGrid(.adaptive(minimum:))` fits across a
/// given content width.
///
/// Exists so grid assertions can be **two-sided**. Asserting only that a tile
/// fits `n` to a row (`n * width + (n - 1) * spacing <= contentWidth`) passes
/// for every tile *narrower* than the design too: shrink a 50pt tile to 20pt
/// and it still "fits five across" — while actually fitting fourteen, which is
/// a different layout than the one the tile was designed for. Comparing
/// against the exact column count catches a tile that grew *or* shrank.
enum GridColumns {
    static func count(
        tileWidth: CGFloat,
        contentWidth: CGFloat,
        spacing: CGFloat
    ) -> Int {
        guard tileWidth > 0, contentWidth >= tileWidth else { return 0 }
        // n * tileWidth + (n - 1) * spacing <= contentWidth
        return Int((contentWidth + spacing) / (tileWidth + spacing))
    }
}
