import AppKit
import SwiftUI
import TFTData

/// Draws game art for a URL, falling back to `placeholder` whenever there
/// is no art to draw — no URL, offline, a 404, or bytes that don't decode.
///
/// The fallback is not an error path, it is *the* guaranteed rendering: the
/// overlay's whole premise is being fully usable with no game running and
/// no network, so art is a progressive enhancement layered on top of a
/// design that already works without it. Nothing here surfaces a failure to
/// the user; a missing icon simply looks like the text tile it looked like
/// before images existed.
///
/// Bytes come from `TFTData.ImageAssetCache` (disk-backed, fetched at most
/// once ever); this view only owns decoding those bytes into an `NSImage`
/// and remembering the result for the session.
struct AssetImage<Placeholder: View>: View {
    let url: URL?
    /// Corner radius of the frame the art is clipped to, so the image
    /// matches the placeholder tile it replaces.
    let cornerRadius: CGFloat
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var image: NSImage?

    init(url: URL?, cornerRadius: CGFloat, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.cornerRadius = cornerRadius
        self.placeholder = placeholder
        // Seed from the decode cache so art that has already been drawn
        // this session appears in the very first frame. Without this, every
        // re-appearance of a row would fade in from the text tile again,
        // and a snapshot of an already-warm hierarchy would show
        // placeholders.
        _image = State(initialValue: AssetImageLoader.cached(url))
    }

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    // Fill, not fit: a handful of feed entries point
                    // at wide splash art instead of a square portrait
                    // (Set 18's Crimson Raptor is the known one). Cropping
                    // to the centre of a wide image still reads as that
                    // champion; squashing it into a square does not.
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    // The image arrives asynchronously; without this the
                    // tile pops from text to art mid-glance, which is
                    // exactly the kind of motion a peripheral-vision
                    // overlay should not have.
                    .transition(.opacity)
            } else {
                placeholder()
            }
        }
        .animation(.easeOut(duration: 0.15), value: image != nil)
        .task(id: url) {
            if let hit = AssetImageLoader.cached(url) {
                image = hit
                return
            }
            image = await AssetImageLoader.load(url)
        }
    }
}

/// Session-lifetime decode cache in front of `ImageAssetCache`.
///
/// The disk cache removes the *network* cost of an icon; this removes the
/// PNG-decode cost, which otherwise repeats every time a panel is shown or
/// a row scrolls back into view. `NSCache` rather than a plain dictionary
/// so it evicts under memory pressure on its own — the overlay is a
/// long-lived background app and must not hold every icon it has ever
/// drawn forever.
/// Public so an app layer can warm art ahead of first display (and so a
/// render harness can produce a screenshot without a view lifecycle);
/// `AssetImage` is the normal way to consume it.
@MainActor
public enum AssetImageLoader {
    private static let decoded: NSCache<NSURL, NSImage> = {
        let cache = NSCache<NSURL, NSImage>()
        cache.countLimit = 400
        return cache
    }()

    /// The already-decoded image, if this URL has been drawn before in
    /// this process. Synchronous, so a view can render art on its first
    /// frame instead of fading it in again.
    public static func cached(_ url: URL?) -> NSImage? {
        guard let url else { return nil }
        return decoded.object(forKey: url as NSURL)
    }

    /// `nil` for every "no art" case. Never throws: the caller's fallback
    /// is the answer to all of them.
    @discardableResult
    public static func load(_ url: URL?) async -> NSImage? {
        guard let url else { return nil }
        if let hit = cached(url) {
            return hit
        }
        guard let data = await ImageAssetCache.shared.imageData(for: url),
              let image = NSImage(data: data)
        else { return nil }
        decoded.setObject(image, forKey: url as NSURL)
        return image
    }
}
