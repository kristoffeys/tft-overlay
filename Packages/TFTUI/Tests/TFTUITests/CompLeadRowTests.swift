import SwiftUI
@testable import TFTUI
import XCTest

/// The comp-lead capsules in the openers panel (#85): whether the names they
/// draw are actually readable.
///
/// This is the assertion the original suite did not have. It checked only that
/// nothing drew into the panel's right margin — and truncation is precisely
/// the failure that *keeps* content inside the margin, by replacing the tail
/// of a comp name with an ellipsis. On the real corpus at 460pt, three of the
/// six meta-pickup rows truncated (`Coven Spellweav…`, `Elderwood Spellw…`,
/// `Spellweaver Defe…`) and the whole suite stayed green.
///
/// The measurement that catches it: each capsule's *intrinsic* width, read
/// against a deliberately over-wide proposal, summed against the width the row
/// actually has. `measuredSize` does not clamp — a 900pt view measured at a
/// 460pt proposal returns 900 — which is what makes it able to see a capsule
/// that wanted more room than it got.
@MainActor
final class CompLeadRowTests: XCTestCase {
    /// Panel widths this row has to survive: the expanded overlay, the compact
    /// layout, and the narrowest the window can be dragged to
    /// (`AppDelegate`'s `minSize`).
    private let panelWidths: [CGFloat] = [460, 420, 300]

    private let spacing: CGFloat = 4

    /// The width a `CompLeadRow` actually gets inside a `MetaPickupRow`:
    /// panel, less `OpenersView.content`'s 12pt padding each side, less the
    /// row's own 8pt padding each side, less the 34pt portrait and the 10pt
    /// gap after it.
    private func availableWidth(panelWidth: CGFloat) -> CGFloat {
        panelWidth - 12 * 2 - 8 * 2 - (34 + 10)
    }

    private func row(_ leadsTo: [OpenerIndex.CompSummary]) -> CompLeadRow {
        CompLeadRow(leadsTo: leadsTo, onSelectComp: { _ in })
    }

    // MARK: - The real corpus

    /// Every capsule the panel draws, at every panel width, has to fit the
    /// room the row has — measured against the real rendered capsule, not
    /// against `CompLeadLayout`'s own arithmetic.
    ///
    /// This is the regression test for the truncation. Restore the old fixed
    /// limit of three names and the 460pt and 300pt cases both fail here.
    func testEveryShownCompLeadFitsTheRowAtEveryPanelWidth() throws {
        let comps = try CompLoader.bundledFixtures()
        let view = OpenersView(comps: comps)
        let index = OpenerIndex(comps: comps)
        XCTAssertFalse(view.metaPickups.isEmpty, "No meta pickups, so there are no lead rows to check")

        for panelWidth in panelWidths {
            let available = availableWidth(panelWidth: panelWidth)
            for unit in view.metaPickups {
                let leadsTo = index.comps(leadingFrom: unit.name)
                let fit = CompLeadLayout.fit(
                    leadsTo.map(\.name),
                    availableWidth: available,
                    spacing: spacing,
                    maxLines: 1
                )
                let leadRow = row(leadsTo)

                var used: CGFloat = 0
                for (offset, name) in fit.shown.enumerated() {
                    let comp = try XCTUnwrap(leadsTo.first { $0.name == name })
                    // Intrinsic width: what the capsule wants, not what it was
                    // squeezed into. A truncated capsule reports the squeezed
                    // width, which is why the raster assertions missed this.
                    let intrinsic = try ViewSnapshot.measuredSize(
                        of: leadRow.capsule(for: comp),
                        proposedWidth: 2000
                    ).width
                    used += intrinsic + (offset == 0 ? 0 : spacing)
                }
                if fit.overflow > 0 {
                    used += spacing + CompLeadLayout.overflowWidth(fit.overflow)
                }

                XCTAssertLessThanOrEqual(
                    used,
                    available,
                    "\(unit.name)'s leads need \(used)pt of \(available)pt at a \(panelWidth)pt panel, "
                        + "so \(fit.shown.joined(separator: ", ")) cannot all be drawn in full"
                )
            }
        }
    }

    /// A row that shows nothing is not a bridge either. At the expanded width
    /// every unit with leads has to name at least one of them.
    func testEveryUnitWithLeadsNamesAtLeastOneAtTheExpandedWidth() throws {
        let comps = try CompLoader.bundledFixtures()
        let view = OpenersView(comps: comps)
        let index = OpenerIndex(comps: comps)

        for unit in view.metaPickups {
            let leadsTo = index.comps(leadingFrom: unit.name)
            guard !leadsTo.isEmpty else { continue }
            let fit = CompLeadLayout.fit(
                leadsTo.map(\.name),
                availableWidth: availableWidth(panelWidth: 460),
                spacing: spacing,
                maxLines: 1
            )
            XCTAssertGreaterThan(
                fit.shown.count,
                0,
                "\(unit.name) leads into \(leadsTo.count) comps and the row names none of them"
            )
        }
    }

    /// Guards the premise: the corpus really does contain names too wide to
    /// show three of at 460pt.
    ///
    /// Without this the test above could pass because the corpus got tame
    /// rather than because the layout works, and the truncation this all
    /// exists for would be untested again.
    func testTheRealCorpusStillContainsAnUnfittableTripleOfLeads() throws {
        let comps = try CompLoader.bundledFixtures()
        let view = OpenersView(comps: comps)
        let index = OpenerIndex(comps: comps)
        let available = availableWidth(panelWidth: 460)

        let overflowing = view.metaPickups.filter { unit in
            let names = index.comps(leadingFrom: unit.name).map(\.name).prefix(3)
            guard names.count == 3 else { return false }
            let width = names.reduce(0) { $0 + CompLeadLayout.width(of: $1) } + spacing * 2
            return width > available
        }
        XCTAssertFalse(
            overflowing.isEmpty,
            "No unit's three widest leads overflow \(available)pt any more, so the truncation "
                + "regression this suite exists for is no longer reachable from the real corpus"
        )
    }

    // MARK: - Nothing behind hover

    /// The remainder is a drawn counter, so a locked overlay — which receives
    /// no mouse events at all (#83) — still tells the player more comps exist.
    func testTheOverflowCounterIsDrawnWheneverLeadsAreHidden() throws {
        let leadsTo = (1 ... 8).map { number in
            OpenerIndex.CompSummary(
                id: "comp-\(number)",
                name: "Extraordinarily Overlong Comp Name \(number)",
                tier: .s
            )
        }
        let fit = CompLeadLayout.fit(
            leadsTo.map(\.name),
            availableWidth: availableWidth(panelWidth: 300),
            spacing: spacing,
            maxLines: 1
        )
        XCTAssertGreaterThan(fit.overflow, 0, "These names cannot all fit a 300pt panel")
        XCTAssertEqual(
            fit.overflow + fit.shown.count,
            leadsTo.count,
            "The counter has to account for every lead that is not drawn"
        )

        let natural = try ViewSnapshot.measuredSize(
            of: row(leadsTo),
            proposedWidth: availableWidth(panelWidth: 300)
        )
        try assertRendersWithin(
            row(leadsTo),
            size: CGSize(width: availableWidth(panelWidth: 300), height: natural.height),
            rightMargin: 2,
            minimumInk: 0.002
        )
    }

    /// A row too narrow for even one whole name still draws the counter.
    ///
    /// Found by the assertion above during this fix: the counter used to be
    /// attached to the last laid-out line, so when *nothing* fit there was no
    /// line to attach it to and the row rendered completely blank — a unit
    /// that leads into eight comps looking like a unit that leads nowhere.
    func testARowTooNarrowForAnyNameStillDrawsTheCounter() throws {
        let leadsTo = (1 ... 8).map { number in
            OpenerIndex.CompSummary(
                id: "comp-\(number)",
                name: "Extraordinarily Overlong Comp Name \(number)",
                tier: .s
            )
        }
        let narrow: CGFloat = 60
        let fit = CompLeadLayout.fit(
            leadsTo.map(\.name),
            availableWidth: narrow,
            spacing: spacing,
            maxLines: 1
        )
        XCTAssertTrue(fit.lines.isEmpty, "This width is meant to fit no whole name at all")
        XCTAssertEqual(fit.overflow, leadsTo.count)

        let natural = try ViewSnapshot.measuredSize(of: row(leadsTo), proposedWidth: narrow)
        try assertRendersWithin(
            row(leadsTo),
            size: CGSize(width: narrow, height: natural.height),
            rightMargin: 2,
            minimumInk: 0.002
        )
    }

    /// A single comp name wider than the whole row is dropped rather than
    /// drawn as an ellipsis. Half a comp name is not a bridge to anything, and
    /// the counter at least tells the truth about how many there were.
    func testANameWiderThanTheRowIsCountedRatherThanTruncated() {
        let absurd = String(repeating: "Unpronounceable ", count: 12)
        let fit = CompLeadLayout.fit(
            [absurd, "Unrivaled"],
            availableWidth: 100,
            spacing: spacing,
            maxLines: 1
        )
        XCTAssertTrue(fit.shown.isEmpty, "A name that cannot fit should not be drawn truncated")
        XCTAssertEqual(fit.overflow, 2)
    }

    // MARK: - The layout's arithmetic

    /// `CompLeadLayout`'s measurement must never *under*-estimate the real
    /// capsule, or it will hand the row more capsules than fit and truncation
    /// comes straight back.
    func testTheLayoutNeverUnderestimatesTheRenderedCapsule() throws {
        let names = [
            "Vi", "Unrivaled", "Coven Invokers", "Coven Spellweavers",
            "Elderwood Spellweavers", "Spellweaver Defenders", "Blackthorn Sprykin",
        ]
        for name in names {
            let comp = OpenerIndex.CompSummary(id: name, name: name, tier: .s)
            let intrinsic = try ViewSnapshot.measuredSize(
                of: row([comp]).capsule(for: comp),
                proposedWidth: 2000
            ).width
            let computed = CompLeadLayout.width(of: name)
            XCTAssertGreaterThanOrEqual(
                computed,
                intrinsic,
                "The layout budgets \(computed)pt for \"\(name)\" but the capsule renders \(intrinsic)pt, "
                    + "so it will pack in more capsules than actually fit"
            )
            // Not wildly over either, or the row wastes room it could be
            // naming another comp with.
            XCTAssertLessThan(computed - intrinsic, 8, "The budget for \"\(name)\" is needlessly padded")
        }
    }

    /// One line, so the row keeps the height it has inside `MetaPickupRow`.
    func testTheLeadRowIsOneCapsuleTall() {
        XCTAssertEqual(CompLeadLayout.height(maxLines: 1, spacing: spacing), 19)
    }

    /// Nothing to lead into is its own drawn state, not an empty gap.
    func testAUnitWithNoLeadsRendersItsOwnCopy() throws {
        let empty = row([])
        let natural = try ViewSnapshot.measuredSize(of: empty, proposedWidth: 376)
        XCTAssertGreaterThan(natural.height, 0)
        try assertRendersWithin(
            empty,
            size: CGSize(width: 376, height: natural.height),
            rightMargin: 2,
            minimumInk: 0.002
        )
    }
}
