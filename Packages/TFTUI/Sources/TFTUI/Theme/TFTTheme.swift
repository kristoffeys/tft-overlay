import SwiftUI

/// Visual tokens for panels meant to be read in peripheral vision, in
/// half a second, over a moving game background: strong contrast, dark
/// backing with enough opacity to separate from the game, no hairlines,
/// bold weights everywhere.
public enum TFTTheme {
    public static let background = Color(red: 0.05, green: 0.06, blue: 0.09).opacity(0.94)
    public static let panelBackground = Color(red: 0.10, green: 0.11, blue: 0.15).opacity(0.92)
    public static let elevatedBackground = Color(red: 0.16, green: 0.17, blue: 0.22).opacity(0.95)
    public static let accent = Color(red: 0.98, green: 0.78, blue: 0.25)

    public static let textPrimary = Color.white

    /// Supporting text that is still *content*: patch labels, item priority
    /// ranks, level-plan notes, positioning notes.
    ///
    /// This was 0.68 and read as a grey mumble at 10–12pt. The panel is three
    /// stacked translucent layers (`background` 0.94 over the game, then
    /// `panelBackground` 0.92 over that), so a mid-brightness game background
    /// still bleeds ~5% through and lifts the effective backing to roughly
    /// sRGB 0.11. At 0.68 white that is ~8.6:1; at 0.82 it is ~11.9:1, which
    /// holds up at 10pt over a moving, bright game UI while staying visibly
    /// subordinate to `textPrimary`.
    public static let textSecondary = Color.white.opacity(0.82)

    /// Decorative chrome only — disclosure chevrons, the search glyph, unfilled
    /// difficulty pips. Deliberately *below* the old secondary value: pushing
    /// content up and ornament down is what restores the hierarchy that
    /// flattening everything to one grey destroyed. Never put words a player
    /// needs to read in this colour.
    public static let textTertiary = Color.white.opacity(0.60)

    public static let cornerRadius: CGFloat = 10
    public static let smallCornerRadius: CGFloat = 6
    public static let spacing: CGFloat = 12

    public static func tierColor(_ tier: Comp.Tier) -> Color {
        switch tier {
        case .s: Color(red: 1.00, green: 0.55, blue: 0.15)
        case .a: Color(red: 0.75, green: 0.42, blue: 1.00)
        case .b: Color(red: 0.32, green: 0.68, blue: 1.00)
        case .c: Color(red: 0.55, green: 0.75, blue: 0.55)
        case .d: Color(red: 0.55, green: 0.55, blue: 0.58)
        }
    }

    public static func costColor(_ cost: Int) -> Color {
        switch cost {
        case 1: Color(red: 0.62, green: 0.65, blue: 0.68)
        case 2: Color(red: 0.32, green: 0.72, blue: 0.42)
        case 3: Color(red: 0.30, green: 0.55, blue: 0.95)
        case 4: Color(red: 0.68, green: 0.36, blue: 0.92)
        default: Color(red: 0.95, green: 0.72, blue: 0.20)
        }
    }
}
