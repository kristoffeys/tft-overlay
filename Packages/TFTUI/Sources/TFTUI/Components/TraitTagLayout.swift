import AppKit
import Foundation

/// Decides which trait tags are shown in a given width, and on which line.
///
/// The overlay is read in peripheral vision in about half a second, so a tag
/// that wraps mid-word ("Execution / er") is worse than a tag that is not
/// shown at all. Rather than letting SwiftUI compress tags until their text
/// wraps, we measure the tags up front and drop the ones that do not fit,
/// surfacing the remainder as a "+N" counter.
///
/// Two things decide *which* tags survive:
///
/// 1. `priority` (see `TraitRelevance`) — the highest-weighted traits are
///    laid out first, so the guaranteed-visible tags are the game-relevant
///    ones rather than whichever name sorted first alphabetically.
/// 2. `maxLines` — callers with vertical room (the reference detail panels)
///    flow onto a second line instead of hiding anything, because a "+N"
///    with a hover tooltip is invisible to someone who is glancing, not
///    pointing.
public enum TraitTagLayout {
    /// Horizontal padding applied inside `TraitTag`, both sides.
    static let horizontalPadding: CGFloat = 7 * 2

    /// Height of one laid-out row of tags. Matches `TraitTag`'s intrinsic
    /// height (11pt text plus 3pt vertical padding each side).
    public static let lineHeight: CGFloat = 20

    /// Font metrics must match `TraitTag`'s `.font(.system(size: 11, weight: .bold))`.
    private static let font = NSFont.systemFont(ofSize: 11, weight: .bold)

    /// Small slack so rounding differences between our measurement and SwiftUI's
    /// own layout never push a tag one point over its budget.
    private static let safetyMargin: CGFloat = 2

    /// The tags that fit, grouped by line, plus how many were left over.
    public struct Fit: Equatable {
        public let lines: [[String]]
        /// The traits that did not fit, least relevant last. Never inferred
        /// from the caller's input order — `priority` reorders the tags, so
        /// the dropped ones are the tail of the *ranked* list, not of the
        /// array that was passed in.
        public let hidden: [String]

        public var overflow: Int {
            hidden.count
        }

        /// Every shown tag, in layout order.
        public var shown: [String] {
            Array(lines.joined())
        }

        public init(lines: [[String]], hidden: [String]) {
            self.lines = lines
            self.hidden = hidden
        }
    }

    /// Rendered width of a single tag, including its capsule padding.
    public static func width(of name: String) -> CGFloat {
        let textWidth = (name as NSString).size(withAttributes: [.font: font]).width
        return ceil(textWidth) + horizontalPadding + safetyMargin
    }

    /// Total height a row needs for `maxLines` lines of tags.
    public static func height(maxLines: Int, spacing: CGFloat = 4) -> CGFloat {
        let lines = max(1, maxLines)
        return CGFloat(lines) * lineHeight + CGFloat(lines - 1) * spacing
    }

    /// Ranks `traits` most-relevant-first. Equal weights keep their input
    /// order, so a caller with no signal to give gets its array back untouched.
    public static func prioritized(_ traits: [String], by priority: [String: Int]) -> [String] {
        guard !priority.isEmpty else { return traits }
        return traits.enumerated()
            .sorted { lhs, rhs in
                let lhsWeight = priority[lhs.element] ?? 0
                let rhsWeight = priority[rhs.element] ?? 0
                return lhsWeight == rhsWeight ? lhs.offset < rhs.offset : lhsWeight > rhsWeight
            }
            .map(\.element)
    }

    /// Greatest number of tags that fit in `availableWidth` across at most
    /// `maxLines` lines, plus how many were dropped.
    ///
    /// When anything is dropped, room is reserved on the last line for the
    /// "+N" overflow tag so the result still fits. Returns an empty selection
    /// rather than a partial tag when even one tag cannot fit.
    public static func fit(
        _ traits: [String],
        availableWidth: CGFloat,
        spacing: CGFloat = 4,
        maxLines: Int = 1,
        priority: [String: Int] = [:]
    ) -> Fit {
        guard availableWidth > 0, !traits.isEmpty else {
            return Fit(lines: [], hidden: prioritized(traits, by: priority))
        }

        let ordered = prioritized(traits, by: priority)
        let lineBudget = max(1, maxLines)

        var lines: [[String]] = []
        var current: [String] = []
        var used: CGFloat = 0
        var index = 0

        while index < ordered.count {
            let trait = ordered[index]
            let tagWidth = width(of: trait)
            let gap = current.isEmpty ? 0 : spacing
            let isLastLine = lines.count == lineBudget - 1
            let remaining = ordered.count - index - 1

            // Only the last line has to leave room for the "+N" counter;
            // anything that does not fit before then just moves down a line.
            let overflowReserve = isLastLine && remaining > 0
                ? spacing + width(of: overflowLabel(remaining))
                : 0

            if used + gap + tagWidth + overflowReserve <= availableWidth {
                current.append(trait)
                used += gap + tagWidth
                index += 1
            } else if !isLastLine, !current.isEmpty {
                lines.append(current)
                current = []
                used = 0
            } else {
                // Either the last line is full, or a single tag is wider than
                // the whole row and no amount of wrapping will help.
                break
            }
        }

        if !current.isEmpty {
            lines.append(current)
        }

        let shownCount = lines.reduce(0) { $0 + $1.count }
        return Fit(lines: lines, hidden: Array(ordered.suffix(ordered.count - shownCount)))
    }

    /// Label for the overflow counter, e.g. `+2`.
    public static func overflowLabel(_ count: Int) -> String {
        "+\(count)"
    }
}
