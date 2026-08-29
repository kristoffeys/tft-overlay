import AppKit
import Foundation

/// Decides how many trait tags fit in a given width.
///
/// The overlay is read in peripheral vision in about half a second, so a tag that
/// wraps mid-word ("Execution / er") is worse than a tag that is not shown at all.
/// Rather than letting SwiftUI compress tags until their text wraps, we measure the
/// tags up front and drop the ones that do not fit, surfacing the remainder as a
/// "+N" counter.
public enum TraitTagLayout {
    /// Horizontal padding applied inside `TraitTag`, both sides.
    static let horizontalPadding: CGFloat = 7 * 2

    /// Font metrics must match `TraitTag`'s `.font(.system(size: 11, weight: .bold))`.
    private static let font = NSFont.systemFont(ofSize: 11, weight: .bold)

    /// Small slack so rounding differences between our measurement and SwiftUI's
    /// own layout never push a tag one point over its budget.
    private static let safetyMargin: CGFloat = 2

    /// Rendered width of a single tag, including its capsule padding.
    public static func width(of name: String) -> CGFloat {
        let textWidth = (name as NSString).size(withAttributes: [.font: font]).width
        return ceil(textWidth) + horizontalPadding + safetyMargin
    }

    /// Greatest number of tags that fit in `availableWidth`, plus how many were dropped.
    ///
    /// When anything is dropped, room is reserved for the "+N" overflow tag so the
    /// result still fits. Returns an empty selection rather than a partial tag when
    /// even one tag cannot fit.
    public static func fit(
        _ traits: [String],
        availableWidth: CGFloat,
        spacing: CGFloat = 4
    ) -> (shown: [String], overflow: Int) {
        guard availableWidth > 0, !traits.isEmpty else { return ([], traits.count) }

        var shown: [String] = []
        var used: CGFloat = 0

        for (index, trait) in traits.enumerated() {
            let tagWidth = width(of: trait)
            let gap = shown.isEmpty ? 0 : spacing
            let remaining = traits.count - index - 1

            // If anything would be left over, keep room for the "+N" counter.
            let overflowReserve = remaining > 0
                ? spacing + width(of: overflowLabel(remaining))
                : 0

            if used + gap + tagWidth + overflowReserve <= availableWidth {
                shown.append(trait)
                used += gap + tagWidth
            } else {
                break
            }
        }

        return (shown, traits.count - shown.count)
    }

    /// Label for the overflow counter, e.g. `+2`.
    public static func overflowLabel(_ count: Int) -> String {
        "+\(count)"
    }
}
