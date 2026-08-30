import SwiftUI
@testable import TFTOverlay
import TFTUI
import XCTest

/// The tab bar has to *fit*, at every width the overlay ships at, with the
/// real `Panel` titles in it.
///
/// This is the guard on a specific way of breaking the app: the tab bar is the
/// thing that made this overlay's information architecture legible, and it
/// stops doing that the moment it truncates or scrolls. Browse carries five
/// tabs since #85/#86, which is close enough to the limit that renaming one
/// label could silently push it over — "My Champions" instead of "Mine" does
/// exactly that. So the labels are measured, not eyeballed.
///
/// **Why `measuredSize` and not a raster.** `PanelTabBar`'s segment labels are
/// `.lineLimit(1).fixedSize(horizontal: true)`, so they refuse to compress:
/// an over-wide bar overflows its proposal instead of shrinking, and
/// `ViewSnapshot.measuredSize` does not clamp, so the measured width comes
/// back *larger* than the proposal exactly when the bar does not fit. The
/// pixel path cannot see this at all — `render()` frames the view to the
/// proposal and clips it, and SwiftUI centres the over-wide child so both ends
/// are cut and neither margin reports anything. See #95.
@MainActor
final class PanelTabBarFitTests: XCTestCase {
    /// `OverlayPanelController.Configuration` in `AppDelegate`: 460 expanded,
    /// 420 compact, and 420 as the expanded panel's resize floor.
    private let expandedWidth: CGFloat = 460
    private let narrowestWidth: CGFloat = 420

    /// The width a bar needs before it starts overflowing.
    ///
    /// Measured against a proposal far below the intrinsic width, so the
    /// flexible `Spacer` between the tab group and the accessory contributes
    /// its 0pt minimum and what comes back is the bar's own requirement. At a
    /// proposal it fits, the same call returns the proposal instead — which is
    /// why `fits(...)` compares rather than reading this directly.
    private func intrinsicWidth(
        tabs: [OverlayAppState.Panel],
        hasBack: Bool = false,
        hasAccessory: Bool = false
    ) throws -> CGFloat {
        try ViewSnapshot.measuredWidth(
            of: bar(tabs: tabs, hasBack: hasBack, hasAccessory: hasAccessory),
            proposedWidth: 1
        )
    }

    private func bar(
        tabs: [OverlayAppState.Panel],
        hasBack: Bool,
        hasAccessory: Bool
    ) -> some View {
        PanelTabBar(
            tabs: tabs,
            selection: tabs[0],
            title: \.title,
            onBack: hasBack ? {} : nil,
            accessory: hasAccessory
                ? .init(title: "Browse", systemImage: "square.grid.2x2", action: {})
                : nil,
            onSelect: { _ in }
        )
    }

    // MARK: - The assertion that matters

    /// Every bar the overlay can actually show, at both widths it can show it
    /// at. The Browse bar gets the drill-down chevron too, because tapping a
    /// comp from any of the five tabs puts it there.
    func testEveryBarTheOverlayShowsFitsEveryWidthItShowsItAt() throws {
        let browse = OverlayAppState.Panel.destinations(in: .browse)
        let focus = OverlayAppState.Panel.destinations(in: .focus)
        let cases: [(String, [OverlayAppState.Panel], Bool, Bool)] = [
            ("Browse", browse, false, false),
            ("Browse + Back", browse, true, false),
            ("Focus + Browse accessory", focus, false, true),
            ("Focus + Back + Browse accessory", focus, true, true),
        ]

        for (label, tabs, hasBack, hasAccessory) in cases {
            let needed = try intrinsicWidth(tabs: tabs, hasBack: hasBack, hasAccessory: hasAccessory)
            for width in [expandedWidth, narrowestWidth] {
                XCTAssertLessThanOrEqual(
                    needed,
                    width,
                    "\(label) needs \(needed)pt but the panel is \(width)pt wide. "
                        + "Shorten a tab label — the bar must not truncate or scroll."
                )
            }
        }
    }

    /// The bar must not grow taller either: it is a fixed 34pt slice of a very
    /// tight panel, and a second line would come out of the content it exists
    /// to navigate to. A five-tab bar wrapping is the plausible way this
    /// breaks.
    func testTheBrowseBarStaysOneRowTallAtEveryWidth() throws {
        for width in [expandedWidth, narrowestWidth] {
            for hasBack in [false, true] {
                let size = try ViewSnapshot.measuredSize(
                    of: bar(
                        tabs: OverlayAppState.Panel.destinations(in: .browse),
                        hasBack: hasBack,
                        hasAccessory: false
                    ),
                    proposedWidth: width
                )
                XCTAssertEqual(
                    size.height,
                    PanelTabBar<OverlayAppState.Panel>.height,
                    accuracy: 1,
                    "Browse bar is \(size.height)pt tall at \(width)pt (back: \(hasBack))"
                )
            }
        }
    }

    // MARK: - Guarding the guard

    /// Proves the assertion above can fail, rather than being satisfied by
    /// construction — the failure mode #95 found twice in this repo. A tab set
    /// deliberately too wide to fit must be *reported* as not fitting.
    func testTheFitMeasurementActuallyDetectsAnOverWideBar() throws {
        let overWide = try intrinsicWidth(
            tabs: OverlayAppState.Panel.allCases + OverlayAppState.Panel.allCases
        )
        XCTAssertGreaterThan(
            overWide,
            expandedWidth,
            "Fourteen tabs measured as fitting a 460pt bar, so this measurement proves nothing"
        )
    }

    /// The specific label that does not fit, pinned so the tradeoff behind
    /// "Mine" is documented by a failing alternative rather than a comment.
    func testTheLongMyChampionsLabelIsWhyTheTabIsCalledMine() throws {
        XCTAssertEqual(OverlayAppState.Panel.myChampions.title, "Mine")

        let long = PanelTabBar(
            tabs: ["Comps", "Openers", "My Champions", "Items", "Reference"],
            selection: "Comps",
            title: { $0 },
            onBack: {},
            onSelect: { _ in }
        )
        let needed = try ViewSnapshot.measuredWidth(of: long, proposedWidth: 1)
        XCTAssertGreaterThan(
            needed,
            narrowestWidth,
            "\"My Champions\" now fits the \(narrowestWidth)pt floor at \(needed)pt — "
                + "the long label could be restored"
        )
    }
}
