import SwiftUI
@testable import TFTUI
import XCTest

/// Whole-panel layout regressions at the sizes the overlay actually ships at.
///
/// `OverlayPanelController.Configuration` uses 460x640 expanded and 300x320
/// compact, so those are the two frames anything here is rendered into. The
/// class of defect this catches is a panel that renders blank at a size, or
/// that pushes text past its own edge — both invisible to the rest of this
/// suite.
///
/// Anything scrollable is rendered as its *content*, never wrapped in the
/// `ScrollView`: see the note in `ViewSnapshot`.
@MainActor
final class PanelSnapshotTests: XCTestCase {
    private let expanded = CGSize(width: 460, height: 640)
    private let compact = CGSize(width: 300, height: 320)

    private func fixtureComp() throws -> Comp {
        try XCTUnwrap(try CompLoader.bundledFixtures().first)
    }

    // MARK: - Tab bar

    func testTabBarRendersWithinBothPanelWidths() throws {
        for size in [expanded, compact] {
            for hasBack in [false, true] {
                try assertRendersWithin(
                    tabBar(selection: "Comps", onBack: hasBack ? {} : nil),
                    size: CGSize(width: size.width, height: PanelTabBar<String>.height),
                    rightMargin: 4,
                    // A 34pt strip carrying three short words is sparse ink.
                    minimumInk: 0.002
                )
            }
        }
    }

    /// The bar is a fixed slice of a very tight panel; if it silently grows it
    /// eats the content it exists to navigate to.
    func testTabBarHeightIsStableAcrossWidthsAndBackAffordance() throws {
        for width in [expanded.width, compact.width, 240.0] {
            for hasBack in [false, true] {
                let bar = tabBar(selection: "Comps", onBack: hasBack ? {} : nil)
                let size = try ViewSnapshot.measuredSize(of: bar, proposedWidth: width)
                XCTAssertEqual(
                    size.height,
                    PanelTabBar<String>.height,
                    accuracy: 1,
                    "Tab bar is \(size.height)pt tall at \(width)pt (back: \(hasBack))"
                )
            }
        }
    }

    /// Three tabs plus the drill-down back button have to fit the narrowest
    /// panel without a label being clipped.
    func testTabLabelsFitTheCompactPanelWidth() {
        let titles = ["Comps", "Items", "Reference"]
        // 11pt heavy text plus 10pt padding each side, 2pt gaps and 2pt
        // capsule inset, a 22pt back button with an 8pt gap, 12pt page
        // margins each side.
        let font = NSFont.systemFont(ofSize: 11, weight: .heavy)
        let labels = titles.reduce(CGFloat.zero) { total, title in
            total + ceil((title as NSString).size(withAttributes: [.font: font]).width) + 20
        }
        let chrome: CGFloat = 2 * 2 + 2 * 2 + 22 + 8 + 12 * 2
        XCTAssertLessThanOrEqual(
            labels + chrome,
            compact.width,
            "Tab labels need \(labels + chrome)pt but the compact panel is \(compact.width)pt"
        )
    }

    // MARK: - Comp detail, the densest panel

    func testCompDetailContentRendersWithinTheExpandedPanelWidth() throws {
        let content = try CompDetailView(comp: fixtureComp()).content
        let natural = try ViewSnapshot.measuredSize(of: content, proposedWidth: expanded.width)

        XCTAssertEqual(natural.width, expanded.width, accuracy: 1)
        XCTAssertGreaterThan(natural.height, expanded.height, "Detail is expected to scroll")

        // Rasterise the whole natural height so nothing is missed below the
        // fold, and require a real margin inside the panel's 16pt padding.
        try assertRendersWithin(
            content,
            size: CGSize(width: expanded.width, height: natural.height),
            rightMargin: 8
        )
    }

    /// The detail panel as the overlay stacks it: tab bar on top (with the
    /// drill-down Back inside it), content underneath.
    func testCompDetailUnderTheTabBarRendersWithinTheExpandedPanel() throws {
        let comp = try fixtureComp()
        let natural = try ViewSnapshot.measuredSize(
            of: CompDetailView(comp: comp).content,
            proposedWidth: expanded.width
        )
        let stacked = VStack(spacing: 0) {
            tabBar(selection: "Comps", onBack: {})
            CompDetailView(comp: comp).content
        }
        .background(TFTTheme.background)

        try assertRendersWithin(
            stacked,
            size: CGSize(width: expanded.width, height: natural.height + PanelTabBar<String>.height),
            rightMargin: 4
        )
    }

    /// Every fixture, not just the first: a long comp name or a wide trait
    /// name is exactly the kind of data that overflows one card and no other.
    func testEveryFixtureCompDetailFitsTheExpandedPanelWidth() throws {
        for comp in try CompLoader.bundledFixtures() {
            let content = CompDetailView(comp: comp).content
            let natural = try ViewSnapshot.measuredSize(of: content, proposedWidth: expanded.width)
            let raster = try ViewSnapshot.render(
                content,
                size: CGSize(width: expanded.width, height: natural.height)
            )
            XCTAssertTrue(
                raster.rightMarginIsClear(inset: 8),
                "\(comp.name) draws inside the panel's right margin at \(expanded.width)pt"
            )
        }
    }

    // MARK: - Panel chrome above the scroll area

    /// The comps list's search field and filter bar are the part that is not
    /// scrollable, and the part that has to survive the 300pt compact width.
    func testCompsListChromeRendersWithinBothPanelSizes() throws {
        let comps = try CompLoader.bundledFixtures()
        for size in [expanded, compact] {
            try assertRendersWithin(CompsListView(comps: comps), size: size, rightMargin: 4)
        }
    }

    func testReferencePanelChromeRendersWithinBothPanelSizes() throws {
        let comps = try CompLoader.bundledFixtures()
        for size in [expanded, compact] {
            try assertRendersWithin(UnitTraitReferenceView(comps: comps), size: size, rightMargin: 4)
        }
    }

    // MARK: - Helper

    private func tabBar(selection: String, onBack: (() -> Void)? = nil) -> some View {
        PanelTabBar(
            tabs: ["Comps", "Items", "Reference"],
            selection: selection,
            title: { $0 },
            onBack: onBack,
            onSelect: { _ in }
        )
    }
}
