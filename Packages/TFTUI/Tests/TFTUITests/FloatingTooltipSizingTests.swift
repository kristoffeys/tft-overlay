import AppKit
import SwiftUI
@testable import TFTUI
import XCTest

/// Regression coverage for #83: hover cards never appeared. Once the panel
/// itself was fixed to actually deliver `.onHover`, the card still rendered
/// as a 0x0 window, because `FloatingTooltip.show` measured the card's
/// `NSHostingView` with `sizingOptions` forced to `[]`. That option disables
/// the intrinsic-size machinery `fittingSize` relies on, so it always came
/// back `.zero` and the tooltip panel was set to an invisible zero-size
/// frame — see the note in `FloatingTooltip.show`.
@MainActor
final class FloatingTooltipSizingTests: XCTestCase {
    private func summary() -> UnitItemSummary {
        UnitItemSummary(
            name: "Yorick",
            cost: 4,
            role: .frontline,
            starTarget: 2
        )
    }

    /// The exact measurement `FloatingTooltip.show` performs: a fresh
    /// `NSHostingView` around the card, read via `fittingSize` before it is
    /// ever added to a window.
    func testCardHostingViewHasNonZeroFittingSize() {
        let hosting = NSHostingView(rootView: AnyView(UnitItemTooltip(summary: summary())))

        let size = hosting.fittingSize

        XCTAssertGreaterThan(size.width, 0, "a 0-width card is an invisible card")
        XCTAssertGreaterThan(size.height, 0, "a 0-height card is an invisible card")
    }

    /// Locks in *why* the above must hold: forcing `sizingOptions` to `[]` —
    /// what regressed here — collapses the measurement back to zero.
    func testEmptySizingOptionsCollapsesFittingSizeToZero() {
        let hosting = NSHostingView(rootView: AnyView(UnitItemTooltip(summary: summary())))
        hosting.sizingOptions = []

        XCTAssertEqual(hosting.fittingSize, .zero)
    }
}
