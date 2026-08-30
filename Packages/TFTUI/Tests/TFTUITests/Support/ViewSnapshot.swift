import AppKit
import SwiftUI
@testable import TFTUI
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
/// - `measuredSize(of:proposedWidth:)` — the size a view actually takes at a
///   given proposed width. This is the direct detector for wrapping: a row
///   that is supposed to be one line tall and comes back two lines tall has
///   wrapped. It is *also* the only real detector for horizontal overflow,
///   because it does not clamp: a 900pt-wide child measured at a 460pt
///   proposal comes back 900pt wide.
/// - `render(_:size:)` plus `contentBounds` / `inkCoverage` — where ink
///   actually landed inside a fixed frame, which catches a panel that renders
///   empty at a size, or content pressed flush against an edge with no
///   margin.
///
/// **Known limitation: `ScrollView` rasterises blank.** It needs a real
/// scrolling host that `ImageRenderer` does not provide, so a view whose root
/// is a `ScrollView` comes back as an empty bitmap and any assertion on it is
/// vacuous. Render the scroll *content* instead — `CompDetailView.content` is
/// split out for exactly this.
///
/// **Known limitation: `TextField` rasterises as a solid bar.** There is no
/// AppKit responder chain here, so the field draws no text and comes back as
/// a saturated block. Left alone that block is bright enough to satisfy an
/// ink-coverage floor by itself, which is how two panel snapshots certified
/// an otherwise entirely blank panel (issue #95). `render` therefore sets
/// `EnvironmentValues.rendersTextFieldsAsPlaceholders`, and `SearchField`
/// draws its placeholder text instead. Any new text field has to go through
/// `SearchField`, or opt into the same seam, or this blindness comes back.
///
/// `assertRendersWithin` guards against both by asserting on the
/// *distribution* of ink — `contentBounds` has to cover a stated fraction of
/// the frame's height — and not only on a global coverage floor, which one
/// bright bar can clear on its own.
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

    /// Tolerance on width comparisons, in points.
    ///
    /// `measuredSize` reads its numbers back off an integer pixel grid, so a
    /// view that fits exactly can measure a pixel wider than its proposal
    /// through rounding alone. Anything past this is a real overflow.
    static let widthTolerance: CGFloat = 1
    /// Rasterises `view` clamped to exactly `size`, over an opaque near-black
    /// ground so "did anything draw here" is answerable per pixel.
    ///
    /// **This raster is blind to horizontal overflow, by construction.** The
    /// container below is fixed and clips, and SwiftUI *centres* a child that
    /// is wider than the space it is offered — so an over-wide child is
    /// clipped on *both* edges and never reaches the right margin. Measured:
    /// a 520pt view rendered at 50x60 comes back with bounds `(4, 2, 42, 42)`
    /// and `rightMarginIsClear(inset: 2) == true`. Ask `measuredSize` about
    /// widths instead; `assertRendersWithin` does.
    static func render(_ view: some View, size: CGSize) throws -> Raster {
        let framed = VStack(spacing: 0) {
            view
        }
        .frame(width: size.width, height: size.height)
        .background(Color.black)
        .clipped()
        // See `EnvironmentValues.rendersTextFieldsAsPlaceholders`: a live
        // `TextField` rasterises here as a solid saturated bar, which is ink
        // the real panel does not have.
        .environment(\.rendersTextFieldsAsPlaceholders, true)

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
    /// background.
    ///
    /// What this catches: content *laid out* flush against the right edge —
    /// a row that lost its trailing padding, a label whose container runs to
    /// the frame's edge.
    ///
    /// What it does **not** catch, despite what this harness used to claim: a
    /// child wider than the frame. `render` centres and double-clips such a
    /// child, so it never reaches either margin — see the note on `render`.
    /// Horizontal overflow is a `measuredSize` question.
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

/// Asserts a view fits its frame horizontally, filled it vertically, and left
/// a clear margin down the right edge.
///
/// Three independent questions, in the order they are worth asking:
///
/// 1. **Does it fit?** `measuredSize` at a proposal of `size.width` does not
///    clamp, so a child that wanted more room reports the width it wanted.
///    This is the only assertion here that sees horizontal overflow at all —
///    the raster cannot, because `render` centres and double-clips an
///    over-wide child.
/// 2. **Did it draw, and draw *throughout*?** An ink-coverage floor alone is
///    not enough: one saturated bar clears it while the rest of the frame is
///    black, which is precisely how issue #95's two blank-panel assertions
///    passed. So `contentBounds` must also span `minimumVerticalFill` of the
///    frame's height.
/// 3. **Did it keep its margin?** Content laid out flush to the right edge.
///
/// - Parameter minimumVerticalFill: the fraction of `size.height` that
///   `contentBounds` has to cover. The default suits a view rendered at a
///   height it fills. Lower it only for a frame whose emptiness is real
///   geometry — an empty state with 40pt of top padding, a 34pt bar carrying
///   11pt glyphs — and say what the measured value is, so the floor stays
///   anchored to something. It must stay above zero: that is what makes a
///   blank raster fail.
@MainActor
func assertRendersWithin(
    _ view: some View,
    size: CGSize,
    rightMargin: CGFloat = 2,
    minimumInk: Double = 0.005,
    minimumVerticalFill: Double = 0.5,
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    let intrinsic = try ViewSnapshot.measuredSize(of: view, proposedWidth: size.width)
    XCTAssertLessThanOrEqual(
        intrinsic.width,
        size.width + ViewSnapshot.widthTolerance,
        "View wants \(intrinsic.width)pt of width inside a \(size.width)pt frame — "
            + "it will be centred and clipped on both edges, not laid out",
        file: file,
        line: line
    )

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
    let verticalFill = bounds.height / size.height
    XCTAssertGreaterThanOrEqual(
        verticalFill,
        minimumVerticalFill,
        "Ink covers \(bounds.height)pt of a \(size.height)pt frame (\(verticalFill) of its height, "
            + "bounds \(bounds)) — expected at least \(minimumVerticalFill). "
            + "A frame this empty is a view that rendered nothing, not a view that laid out",
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
