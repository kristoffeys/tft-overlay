import SwiftUI

/// Wraps fixed-width children onto as many rows as the proposed width needs,
/// instead of running past it (#100).
///
/// `StageBandDetail`'s unit strip used a plain `HStack`, which has no answer for "more children
/// than fit" except overflowing — invisible to every comp with five or fewer
/// 1-/2-cost units, which is every comp except `solar-riftbeasts`'s eight.
/// `TraitTagLayout` solves the analogous problem for variable-width tags with
/// a measure-and-drop "+N" counter, which is right for a glance layer reading
/// trait chips but wrong here: buyable units are the actual shopping list, so
/// dropping one behind a counter is exactly the silent loss this panel is
/// built not to commit. Wrapping preserves every unit; it costs vertical
/// space instead, which the panel has more of than horizontal.
struct WrapHStack: Layout {
    var horizontalSpacing: CGFloat = 8
    var verticalSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = arrangedRows(subviews: subviews, maxWidth: maxWidth)
        let rowHeights = rows.map { row in row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0 }
        let height = rowHeights.reduce(0, +) + verticalSpacing * CGFloat(max(0, rows.count - 1))
        let width = rows.map { row -> CGFloat in
            let widths = row.map { $0.sizeThatFits(.unspecified).width }
            return widths.reduce(0, +) + horizontalSpacing * CGFloat(max(0, row.count - 1))
        }.max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let rows = arrangedRows(subviews: subviews, maxWidth: bounds.width)
        var y = bounds.minY
        for row in rows {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            var x = bounds.minX
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
                x += size.width + horizontalSpacing
            }
            y += rowHeight + verticalSpacing
        }
    }

    /// Greedy left-to-right, top-down wrapping: a child starts a new row only
    /// when it would not fit on the current one, never earlier.
    private func arrangedRows(subviews: Subviews, maxWidth: CGFloat) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = []
        var current: [LayoutSubview] = []
        var used: CGFloat = 0
        for subview in subviews {
            let width = subview.sizeThatFits(.unspecified).width
            let gap = current.isEmpty ? 0 : horizontalSpacing
            if !current.isEmpty, used + gap + width > maxWidth {
                rows.append(current)
                current = [subview]
                used = width
            } else {
                current.append(subview)
                used += gap + width
            }
        }
        if !current.isEmpty {
            rows.append(current)
        }
        return rows
    }
}
