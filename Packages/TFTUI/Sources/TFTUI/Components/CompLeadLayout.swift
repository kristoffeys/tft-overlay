import AppKit
import Foundation

/// Decides which comp-lead capsules fit in a given width, and how many are
/// left over.
///
/// The openers panel promises a bridge out of "hold this unit" into "here is
/// what it builds into", and a comp name is only a bridge if you can read it.
/// A fixed count of three could not deliver that: on the real corpus at the
/// 460pt panel the three widest leads need 384pt of a 376pt column, so
/// `Coven Spellweavers` rendered as `Coven Spellweav…`. At the 300pt window
/// minimum it collapsed far enough that `Coven Invokers` and
/// `Coven Spellweavers` both became `Cove…` — two different builds, one
/// indistinguishable label.
///
/// The recovery for that was `.help()`, i.e. hover, which does not fire at all
/// while the overlay is locked for click-through (#83). So the count has to be
/// decided by measurement instead: fit whole names, drop the rest, and draw
/// the remainder as a `+N` that is visible without a mouse.
///
/// Mirrors `TraitTagLayout`, which solved the same problem for trait tags
/// ("Execution / er" wrapping mid-word) and for the same reason. Kept separate
/// rather than generalised: the two carry different capsule geometry and
/// different fonts, and folding them together would mean one set of metrics
/// silently governing two unrelated views.
enum CompLeadLayout {
    /// Horizontal padding inside a lead capsule, both sides.
    private static let horizontalPadding: CGFloat = 6 * 2

    /// The tier dot and the gap between it and the name.
    private static let dotWidth: CGFloat = 5
    private static let dotSpacing: CGFloat = 4

    /// Height of one laid-out row of capsules. Matches the capsule's intrinsic
    /// height: 10pt text plus 3pt vertical padding each side.
    static let lineHeight: CGFloat = 19

    /// Small slack so rounding differences between this measurement and
    /// SwiftUI's own layout never push a capsule one point over its budget.
    private static let safetyMargin: CGFloat = 2

    /// Must match the capsule label's
    /// `.font(.system(size: 10, weight: .bold, design: .rounded))`.
    private static let font: NSFont = {
        let base = NSFont.systemFont(ofSize: 10, weight: .bold)
        guard let rounded = base.fontDescriptor.withDesign(.rounded) else { return base }
        return NSFont(descriptor: rounded, size: 10) ?? base
    }()

    /// Must match the overflow counter's
    /// `.font(.system(size: 10, weight: .heavy, design: .rounded))`.
    private static let overflowFont: NSFont = {
        let base = NSFont.systemFont(ofSize: 10, weight: .heavy)
        guard let rounded = base.fontDescriptor.withDesign(.rounded) else { return base }
        return NSFont(descriptor: rounded, size: 10) ?? base
    }()

    /// The capsules that fit, grouped by line, plus what was left over.
    struct Fit: Equatable {
        let lines: [[String]]
        /// The comp names that did not fit, in the order they were offered.
        let hidden: [String]

        var overflow: Int {
            hidden.count
        }

        /// Every shown name, in layout order.
        var shown: [String] {
            Array(lines.joined())
        }
    }

    /// Rendered width of one lead capsule, including its dot and padding.
    static func width(of name: String) -> CGFloat {
        let textWidth = (name as NSString).size(withAttributes: [.font: font]).width
        return ceil(textWidth) + dotWidth + dotSpacing + horizontalPadding + safetyMargin
    }

    /// Rendered width of the bare `+N` counter, which has no capsule.
    static func overflowWidth(_ count: Int) -> CGFloat {
        let label = overflowLabel(count) as NSString
        return ceil(label.size(withAttributes: [.font: overflowFont]).width) + safetyMargin
    }

    static func overflowLabel(_ count: Int) -> String {
        "+\(count)"
    }

    /// Total height a row needs for `maxLines` lines of capsules.
    static func height(maxLines: Int, spacing: CGFloat = 4) -> CGFloat {
        let lines = max(1, maxLines)
        return CGFloat(lines) * lineHeight + CGFloat(lines - 1) * spacing
    }

    /// The most capsules that fit in `availableWidth` across at most
    /// `maxLines` lines, plus what was dropped.
    ///
    /// `names` is expected to be already ordered best-first — the caller
    /// (`OpenerIndex.comps(leadingFrom:)`) sorts tier-then-name, so the leads
    /// that survive a squeeze are the strongest comps rather than whichever
    /// name sorted first. Room is reserved on the last line for the `+N`
    /// counter whenever anything is dropped, so the result always fits.
    ///
    /// A single name wider than the whole row is dropped rather than shown
    /// truncated: half a comp name is not a bridge to anything, and the `+N`
    /// at least tells the truth about how many there were.
    static func fit(
        _ names: [String],
        availableWidth: CGFloat,
        spacing: CGFloat = 4,
        maxLines: Int = 1
    ) -> Fit {
        guard availableWidth > 0, !names.isEmpty else {
            return Fit(lines: [], hidden: names)
        }

        let lineBudget = max(1, maxLines)
        var lines: [[String]] = []
        var current: [String] = []
        var used: CGFloat = 0
        var index = 0

        while index < names.count {
            let capsuleWidth = width(of: names[index])
            let gap = current.isEmpty ? 0 : spacing
            let isLastLine = lines.count == lineBudget - 1
            let remaining = names.count - index - 1

            // Only the last line has to leave room for the counter; anything
            // that does not fit before then just moves down a line.
            let overflowReserve = isLastLine && remaining > 0
                ? spacing + overflowWidth(remaining)
                : 0

            if used + gap + capsuleWidth + overflowReserve <= availableWidth {
                current.append(names[index])
                used += gap + capsuleWidth
                index += 1
            } else if !isLastLine, !current.isEmpty {
                lines.append(current)
                current = []
                used = 0
            } else {
                // The last line is full, or one name is wider than the row and
                // no amount of wrapping will help.
                break
            }
        }

        if !current.isEmpty {
            lines.append(current)
        }

        let shownCount = lines.reduce(0) { $0 + $1.count }
        return Fit(lines: lines, hidden: Array(names.suffix(names.count - shownCount)))
    }
}
