import SwiftUI
@testable import TFTUI
import XCTest

/// Rendered-layout regressions for the trait tag row.
///
/// `TraitTagLayoutTests` proves the arithmetic; this proves SwiftUI actually
/// laid the tags out the way the arithmetic said it would. The bug that
/// shipped ("stop trait tags wrapping mid-word in the overlay") lived exactly
/// in the gap between those two statements.
@MainActor
final class TraitTagRowSnapshotTests: XCTestCase {
    /// Traits from the committed Set 18 fixtures. "Executioner" is the one
    /// that wrapped to "Execution / er" in the 460pt overlay panel.
    private let elderwoodTraits = ["Brawler", "Defender", "Elderwood", "Executioner"]

    /// Roughly the width the trait row gets inside a comp row in the shipped
    /// 460pt panel, after the tier badge, roster grid and padding.
    private let overlayRowWidth: CGFloat = 210

    // MARK: - The shipped regression

    /// The negative control: without the fit-and-drop pass, these four tags
    /// at this width do wrap onto a second line. If this ever stops being
    /// true the tests below have stopped proving anything.
    func testUnconstrainedTagsWrapAtTheOverlayWidth() throws {
        let naive = HStack(spacing: 4) {
            ForEach(elderwoodTraits, id: \.self) { trait in
                Text(trait)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(TFTTheme.elevatedBackground, in: Capsule())
            }
        }
        .frame(width: overlayRowWidth)

        let size = try ViewSnapshot.measuredSize(of: naive, proposedWidth: overlayRowWidth)
        XCTAssertGreaterThan(
            size.height,
            TraitTagLayout.lineHeight + 1,
            "Four unconstrained tags should not fit \(overlayRowWidth)pt on one line — "
                + "if they now do, this control no longer reproduces the shipped bug"
        )
    }

    /// The regression itself: `TraitTagRow` must stay exactly one line tall
    /// at the same width, because it drops what does not fit instead of
    /// letting the text wrap.
    func testTraitTagRowStaysOneLineAtTheOverlayWidth() throws {
        let row = TraitTagRow(elderwoodTraits).frame(width: overlayRowWidth)
        let size = try ViewSnapshot.measuredSize(of: row, proposedWidth: overlayRowWidth)

        XCTAssertEqual(
            size.height,
            TraitTagLayout.lineHeight,
            accuracy: 1,
            "Trait row grew to \(size.height)pt — a tag wrapped instead of being dropped"
        )
    }

    /// And nothing it does draw runs past its own frame.
    func testTraitTagRowInkStaysInsideItsFrame() throws {
        // Trailing-aligned by design, so the tags may touch the right edge;
        // what must never happen is ink beyond it.
        try assertRendersWithin(
            TraitTagRow(elderwoodTraits),
            size: CGSize(width: overlayRowWidth, height: TraitTagLayout.lineHeight),
            rightMargin: 0
        )
    }

    /// The narrowest realistic case — the 300pt compact panel — must also not
    /// wrap, however few tags survive.
    func testTraitTagRowStaysOneLineAtCompactWidth() throws {
        for width in [90.0, 120.0, 160.0, 210.0, 260.0] {
            let row = TraitTagRow(elderwoodTraits).frame(width: width)
            let size = try ViewSnapshot.measuredSize(of: row, proposedWidth: width)
            XCTAssertEqual(
                size.height,
                TraitTagLayout.lineHeight,
                accuracy: 1,
                "Trait row wrapped at \(width)pt"
            )
        }
    }

    // MARK: - Two-line drill-down variant

    func testTwoLineRowReservesExactlyTwoLines() throws {
        let row = TraitTagRow(elderwoodTraits, maxLines: 2).frame(width: overlayRowWidth)
        let size = try ViewSnapshot.measuredSize(of: row, proposedWidth: overlayRowWidth)

        XCTAssertEqual(
            size.height,
            TraitTagLayout.height(maxLines: 2),
            accuracy: 1
        )
    }

    /// Two lines is what lets the drill-down show every trait rather than
    /// hiding some behind a "+N" that only a hover can open.
    func testTwoLinesShowEveryFixtureTraitAtTheOverlayWidth() {
        let fit = TraitTagLayout.fit(elderwoodTraits, availableWidth: overlayRowWidth, maxLines: 2)
        XCTAssertEqual(fit.overflow, 0)
        XCTAssertEqual(Set(fit.shown), Set(elderwoodTraits))
        XCTAssertEqual(fit.lines.count, 2)
    }
}
