import SwiftUI

/// The geometry half of TFTUI's off-screen snapshot harness, for views the app
/// target composes out of TFTUI parts.
///
/// Deliberately *only* `measuredSize`. TFTUITests has a fuller
/// `ViewSnapshot` with a raster path (`render`, `contentBounds`,
/// `inkCoverage`, `rightMarginIsClear`), but two things argue against reaching
/// for it here even if it were visible across targets:
///
/// - It is not visible. Test support in one package's test target is not
///   importable from another, and exporting a test harness through a product
///   just to share it would put the harness in the shipping build.
/// - The raster half cannot answer the question this target asks. `render()`
///   frames the view to the requested size and clips it, and SwiftUI centres
///   an over-wide child, so over-wide content is cut at *both* ends and no
///   margin check sees it — which is what #95 corrected the harness's own
///   documentation about. `measuredSize` does not clamp, which makes it the
///   sound instrument for "does this fit": a view that needs more width than
///   it is offered reports the larger number.
///
/// So this is a ~15-line re-statement of the one function worth having, not a
/// fork of a harness. If it ever grows a raster path, port TFTUITests'
/// `assertRendersWithin` wholesale — ink floor, vertical-fill distribution and
/// the `TextField` placeholder seam included — rather than reinventing the
/// parts of it that exist because they were once missing.
@MainActor
enum ViewSnapshot {
    /// Backing scale used for rasterisation. 1 keeps the pixel grid equal to
    /// the point grid, which makes measurements read in points.
    static let scale: CGFloat = 1

    /// The size `view` takes when offered `proposedWidth` and unlimited
    /// height, in points.
    ///
    /// Does not clamp: offer less width than the view's content requires and
    /// the returned width is the width it wanted.
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

    static func measuredWidth(
        of view: some View,
        proposedWidth: CGFloat
    ) throws -> CGFloat {
        try measuredSize(of: view, proposedWidth: proposedWidth).width
    }

    enum SnapshotError: Error {
        case renderFailed
    }
}
