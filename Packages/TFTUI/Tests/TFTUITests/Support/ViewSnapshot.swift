import AppKit
import SwiftUI
import XCTest

/// Off-screen rendering harness for layout regressions.
///
/// `swift test` passing has never been evidence the UI works: text wrapping,
/// clipping and overflow are invisible to a unit test and have shipped past
/// this suite before (see `TraitTagLayoutTests` and the "trait tags wrapping
/// mid-word" fix). Screenshotting the running app catches those, but needs a
/// WindowServer surface and Screen Recording permission, neither of which is
/// reliably available to CI or to an agent session.
///
/// `ImageRenderer` (macOS 13+) rasterises a SwiftUI view with no window, no
/// screen capture and no permission prompt, which makes it usable from plain
/// `swift test`. Two things it gives us are worth asserting on:
///
/// - `measuredSize(of:proposedWidth:)` — the height a view actually takes at
///   a given width. This is the direct detector for wrapping: a row that is
///   supposed to be one line tall and comes back two lines tall has wrapped.
/// - `render(_:size:)` plus `contentBounds` / `inkCoverage` — where ink
///   actually landed inside a fixed frame, which catches a panel that renders
///   empty at a size, or content pressed against an edge with no margin.
///
/// **Known limitation: `ScrollView` rasterises blank.** It needs a real
/// scrolling host that `ImageRenderer` does not provide, so a view whose root
/// is a `ScrollView` comes back as an empty bitmap and any assertion on it is
/// vacuous. Render the scroll *content* instead — `CompDetailView.content` is
/// split out for exactly this. `assertRendersWithin` fails on a blank raster
/// specifically so this cannot pass silently.
///
/// Extending this: add a case to an existing `*SnapshotTests` file, or a new
/// one, and reach for `measuredSize` first — it is cheaper, deterministic and
/// says *why* it failed. Fall back to pixels only for questions geometry
/// cannot answer.
@MainActor
enum ViewSnapshot {
    /// Backing scale used for rasterisation. 1 keeps the pixel grid equal to
    /// the point grid, which makes bounds assertions read in points.
    static let scale: CGFloat = 1

    /// The size `view` takes when offered `proposedWidth` and unlimited height.
    ///
    /// Returns points, not pixels.
    static func measuredSize(
        of view: some View,
        proposedWidth: CGFloat
    ) throws -> CGSize {
        let renderer = ImageRenderer(content: AnyView(view))
        renderer.proposedSize = ProposedViewSize(width: proposedWidth, height: nil)
        renderer.scale = scale
        guard let image = renderer.cgImage else {
            throw SnapshotError.renderFailed
        }
        return CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
    }

    /// Rasterises `view` clamped to exactly `size`, over an opaque near-black
    /// ground so "did anything draw here" is answerable per pixel.
    static func render(_ view: some View, size: CGSize) throws -> Raster {
        // Deliberately no frame on `view` itself — clamping it would hide the
        // very overflow these assertions exist to catch. The container is
        // fixed and clips, so anything that draws wider than `size` lands on
        // the edge, where `rightMarginIsClear` sees it.
        let framed = VStack(spacing: 0) {
            view
        }
        .frame(width: size.width, height: size.height)
        .background(Color.black)
        .clipped()

        let renderer = ImageRenderer(content: AnyView(framed))
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = scale
        renderer.isOpaque = true
        guard let image = renderer.cgImage else {
            throw SnapshotError.renderFailed
        }
        return try Raster(image: image, scale: scale)
    }

    enum SnapshotError: Error {
        case renderFailed
        case unreadablePixels
    }
}

/// A rendered view's pixels, with the few queries layout regressions need.
struct Raster {
    let width: Int
    let height: Int
    let scale: CGFloat
    private let pixels: [UInt8]
    private let bytesPerRow: Int

    init(image: CGImage, scale: CGFloat) throws {
        width = image.width
        height = image.height
        self.scale = scale
        bytesPerRow = width * 4

        var buffer = [UInt8](repeating: 0, count: bytesPerRow * height)
        guard let context = CGContext(
            data: &buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ViewSnapshot.SnapshotError.unreadablePixels
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        pixels = buffer
    }

    /// Threshold above which a pixel counts as *text*, not backing.
    ///
    /// The panel's own fills land well below this (`panelBackground` reads
    /// ~0.10, a `TraitTag` capsule ~0.17 over black), so everything the
    /// queries below report on is glyphs and accent marks — which is what
    /// clipping and overflow questions are actually about.
    static let inkThreshold: Double = 0.25

    /// Perceived brightness 0...1 of the pixel at (x, y), origin top-left.
    func luminance(x: Int, y: Int) -> Double {
        let offset = y * bytesPerRow + x * 4
        let red = Double(pixels[offset]) / 255
        let green = Double(pixels[offset + 1]) / 255
        let blue = Double(pixels[offset + 2]) / 255
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    /// Fraction of pixels brighter than `threshold` — a cheap "is anything
    /// actually drawn here" measure.
    func inkCoverage(threshold: Double = Raster.inkThreshold) -> Double {
        var lit = 0
        for y in 0 ..< height {
            for x in 0 ..< width where luminance(x: x, y: y) > threshold {
                lit += 1
            }
        }
        return Double(lit) / Double(max(1, width * height))
    }

    /// Bounding box (in points) of everything brighter than `threshold`.
    /// `nil` when the raster is blank.
    func contentBounds(threshold: Double = Raster.inkThreshold) -> CGRect? {
        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1
        for y in 0 ..< height {
            for x in 0 ..< width where luminance(x: x, y: y) > threshold {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
        guard maxX >= 0 else { return nil }
        return CGRect(
            x: CGFloat(minX) / scale,
            y: CGFloat(minY) / scale,
            width: CGFloat(maxX - minX + 1) / scale,
            height: CGFloat(maxY - minY + 1) / scale
        )
    }

    /// Whether every pixel in the `inset`-wide strip down the right edge is
    /// background. Content bleeding into it means something overflowed or was
    /// clipped by the frame rather than laid out inside it.
    func rightMarginIsClear(inset: CGFloat, threshold: Double = Raster.inkThreshold) -> Bool {
        let columns = Int(inset * scale)
        guard columns > 0, columns < width else { return true }
        for x in (width - columns) ..< width {
            for y in 0 ..< height where luminance(x: x, y: y) > threshold {
                return false
            }
        }
        return true
    }
}

/// Asserts a view drew something and stayed inside its frame, with a clear
/// margin down the right edge.
@MainActor
func assertRendersWithin(
    _ view: some View,
    size: CGSize,
    rightMargin: CGFloat = 2,
    minimumInk: Double = 0.005,
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    let raster = try ViewSnapshot.render(view, size: size)
    let ink = raster.inkCoverage()
    XCTAssertGreaterThan(
        ink,
        minimumInk,
        "View rendered essentially blank at \(size.width)x\(size.height) (ink coverage \(ink))",
        file: file,
        line: line
    )
    guard let bounds = raster.contentBounds() else {
        return XCTFail("No content rendered at \(size.width)x\(size.height)", file: file, line: line)
    }
    XCTAssertLessThanOrEqual(
        bounds.maxX,
        size.width,
        "Content extends past the right edge of the frame",
        file: file,
        line: line
    )
    XCTAssertTrue(
        raster.rightMarginIsClear(inset: rightMargin),
        "Content is pressed against the right edge — expected \(rightMargin)pt of clear margin",
        file: file,
        line: line
    )
}
