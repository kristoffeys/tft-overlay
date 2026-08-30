import SwiftUI
@testable import TFTUI
import XCTest

/// Tests for the test harness.
///
/// Every assertion in `ViewSnapshot` is a claim about what `ImageRenderer`
/// does, and three of those claims turned out to be false (#95): a blank
/// raster passed, a `bounds.maxX` comparison held by construction, and
/// `rightMarginIsClear` was documented as catching an overflow it cannot see.
/// The harness is the thing every layout test in this package rests on, so its
/// own claims get pinned down here rather than left in a doc comment.
@MainActor
final class ViewSnapshotHarnessTests: XCTestCase {
    private let frame = CGSize(width: 50, height: 60)

    /// A container wider than its frame, with its ink inset from its own
    /// edges — the shape of a real over-wide panel child, which is a stack of
    /// padded rows and not a full-bleed fill.
    private func overWide(_ width: CGFloat) -> some View {
        Color.white
            .frame(width: 42, height: 42)
            .padding(4)
            .frame(width: width)
    }

    // MARK: - What the raster cannot see

    /// The claim `ViewSnapshot.render`'s doc comment used to make — that
    /// over-wide content "lands on the edge, where `rightMarginIsClear` sees
    /// it" — is false, and this is the measurement from #95 that shows it.
    ///
    /// SwiftUI centres a child it cannot fit and `render` clips the container,
    /// so the child loses the same amount off *both* ends. Here that removes
    /// every trace: a 520pt container measures `bounds` of (4, 2, 42, 42) in a
    /// 50pt frame with a clear right margin, the exact numbers from #95.
    ///
    /// A full-bleed fill of the same over-wide container *does* trip the margin
    /// check, so this is unreliability rather than uniform blindness — which is
    /// no better to rest an assertion on. Kept as a test because the fix for
    /// #95 is mostly a set of corrected claims, and a corrected claim in a
    /// comment rots exactly as quietly as the wrong one did.
    func testTheRasterIsBlindToAnOverWideChild() throws {
        let raster = try ViewSnapshot.render(overWide(520), size: frame)
        let bounds = try XCTUnwrap(raster.contentBounds())

        XCTAssertLessThanOrEqual(
            bounds.maxX,
            frame.width,
            "A 520pt child in a 50pt frame is centred and clipped, so its ink cannot reach past the frame"
        )
        XCTAssertTrue(
            raster.rightMarginIsClear(inset: 2),
            "The right margin reads clear despite a 10x over-wide child — this is why "
                + "`assertRendersWithin` asks `measuredSize` about widths instead"
        )
    }

    /// And the corollary: the assertion that was deleted in #95 could not have
    /// failed for any view at all, over-wide or not.
    func testContentBoundsCanNeverExceedTheFrame() throws {
        for width in [10.0, 50.0, 520.0] as [CGFloat] {
            let raster = try ViewSnapshot.render(overWide(width), size: frame)
            let bounds = try XCTUnwrap(raster.contentBounds())
            XCTAssertLessThanOrEqual(bounds.maxX, frame.width)
            XCTAssertLessThanOrEqual(bounds.maxY, frame.height)
        }
    }

    // MARK: - What `measuredSize` can see

    /// The replacement instrument. `measuredSize` does *not* clamp to its
    /// proposal, which is the whole reason it can answer "does this fit".
    ///
    /// The earlier diagnosis of #95 blamed `ImageRenderer` for clamping. It
    /// does not; `render`'s own `.frame().clipped()` does. The distinction is
    /// the difference between a harness with no width detector and a harness
    /// with a sound one.
    func testMeasuredSizeDoesNotClampToItsProposal() throws {
        let measured = try ViewSnapshot.measuredSize(of: overWide(900), proposedWidth: 460)
        XCTAssertEqual(measured.width, 900, accuracy: 1, "measuredSize reported a clamped width")
    }

    // MARK: - Blankness

    /// The defect itself: a view that draws one bright bar in a tall frame.
    ///
    /// `inkCoverage` alone lets it through — 0.02 of the frame is above the
    /// 0.005 floor — so `assertRendersWithin` also requires the ink to be
    /// *distributed*. This is the shape of the raster that certified a black
    /// `CompsListView` twice.
    func testABrightBarInATallFrameFailsTheDistributionCheck() throws {
        let bar = VStack(spacing: 0) {
            Color.white.frame(height: 16)
            Spacer(minLength: 0)
        }
        let size = CGSize(width: 460, height: 640)
        let raster = try ViewSnapshot.render(bar, size: size)
        let bounds = try XCTUnwrap(raster.contentBounds())

        XCTAssertGreaterThan(
            raster.inkCoverage(),
            0.005,
            "This raster is meant to clear the ink floor — that is what made it dangerous"
        )
        XCTAssertLessThan(
            bounds.height / size.height,
            0.5,
            "…while covering \(bounds.height)pt of \(size.height)pt, which is what now fails"
        )
    }

    /// A `TextField` under `ImageRenderer` draws no text and rasterises as a
    /// solid bar. `render` substitutes the placeholder so that bar is not
    /// mistaken for content — see
    /// `EnvironmentValues.rendersTextFieldsAsPlaceholders`.
    ///
    /// Measured at 300x34: the live field covers 0.41 of the frame in ink — a
    /// solid block — and the placeholder 0.075, which is glyphs. If a future
    /// change stops the substitution from reaching the field, this notices.
    func testTheSearchFieldRastersAsGlyphsRatherThanABar() throws {
        let size = CGSize(width: 300, height: 34)
        let field = SearchField(placeholder: "Search unit, trait, or comp", text: .constant(""))

        let seamed = try ViewSnapshot.render(field, size: size).inkCoverage()
        let bar = try ViewSnapshot.render(
            field.environment(\.rendersTextFieldsAsPlaceholders, false),
            size: size
        ).inkCoverage()

        XCTAssertGreaterThan(
            bar,
            0.3,
            "A live TextField is expected to rasterise as a saturated block (measured 0.41)"
        )
        XCTAssertLessThan(
            seamed,
            0.15,
            "The seam is not reaching the search field: it still rasterises as a bar (\(seamed) ink), "
                + "which is enough on its own to satisfy an ink-coverage floor"
        )
        XCTAssertGreaterThan(seamed, 0.01, "The placeholder has to actually draw, or the seam blanks the field")
    }
}
