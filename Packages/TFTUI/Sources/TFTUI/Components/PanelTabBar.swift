import SwiftUI

/// A persistent segmented bar naming every panel the overlay can show.
///
/// Before this, the panels were reachable only by cycling ⌥C blindly: there
/// was nothing on screen saying which panel you were on, how many there were,
/// or that any others existed at all. That makes the information architecture
/// unobservable — you cannot navigate a structure you cannot see.
///
/// Deliberately generic over the tab type: TFTUI must not know about the app
/// shell's `Panel` enum (or its hotkeys). The caller supplies the tabs and
/// their titles, so adding a fifth panel needs no change here.
///
/// Real estate is the constraint — the panel is 460x640 and already carries
/// search fields and filter bars — so this is a ~34pt row, not a toolbar, and
/// it absorbs the drill-down "Back" affordance rather than stacking a second
/// bar above it.
public struct PanelTabBar<Tab: Hashable>: View {
    /// Where in the hierarchy a bar sits.
    ///
    /// A panel that switches modes *within* itself (the item sheet's
    /// grid/lookup, the reference panel's units/traits) needs a switch too,
    /// and those used to be `Picker(.segmented)` — which renders in the
    /// system accent, so a blue AppKit control sat directly under this bar's
    /// gold one, on a dark panel, in two different visual languages.
    /// `.secondary` is the same control a step down: same chip vocabulary,
    /// muted fill and accent *text* instead of an accent fill, so it reads
    /// as subordinate to the panel bar above it rather than competing.
    public enum Style {
        case primary
        case secondary
    }

    private let tabs: [Tab]
    private let selection: Tab
    private let title: (Tab) -> String
    private let style: Style
    private let onBack: (() -> Void)?
    private let onSelect: (Tab) -> Void

    /// Total height the primary bar occupies, padding included. Callers
    /// sizing a panel's content area can subtract it without measuring.
    public static var height: CGFloat {
        34
    }

    private var barHeight: CGFloat {
        style == .primary ? PanelTabBar.height : 28
    }

    /// - Parameters:
    ///   - selection: the tab to light up. A drill-down should pass its
    ///     parent destination so the section you are in stays marked.
    ///   - style: `.secondary` for a mode switch inside a panel.
    ///   - onBack: shown as a leading chevron when non-nil, i.e. while a
    ///     drill-down is on screen.
    public init(
        tabs: [Tab],
        selection: Tab,
        title: @escaping (Tab) -> String,
        style: Style = .primary,
        onBack: (() -> Void)? = nil,
        onSelect: @escaping (Tab) -> Void
    ) {
        self.tabs = tabs
        self.selection = selection
        self.title = title
        self.style = style
        self.onBack = onBack
        self.onSelect = onSelect
    }

    public var body: some View {
        HStack(spacing: 8) {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(TFTTheme.textPrimary)
                        .frame(width: 22, height: 22)
                        .background(TFTTheme.elevatedBackground, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                .help("Back")
            }
            HStack(spacing: 2) {
                ForEach(tabs, id: \.self) { tab in
                    segment(tab)
                }
            }
            .padding(2)
            .background(TFTTheme.panelBackground, in: Capsule())
            Spacer(minLength: 0)
        }
        .frame(height: barHeight, alignment: .center)
        .padding(.horizontal, 12)
    }

    private func segment(_ tab: Tab) -> some View {
        let isSelected = tab == selection
        return Button {
            onSelect(tab)
        } label: {
            Text(title(tab))
                // Same chip vocabulary as the comps list filter bar: heavy
                // rounded caps, accent fill and near-black text when active.
                .font(.system(size: style == .primary ? 11 : 10, weight: .heavy, design: .rounded))
                .foregroundStyle(segmentForeground(isSelected: isSelected))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(segmentBackground(isSelected: isSelected), in: Capsule())
        }
        .buttonStyle(.plain)
        // Without this the first tab draws AppKit's blue focus ring while a
        // different tab is the accent-filled selected one — two competing
        // "you are here" marks on a bar whose entire job is to have one.
        .focusable(false)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func segmentForeground(isSelected: Bool) -> Color {
        guard isSelected else { return TFTTheme.textSecondary }
        return style == .primary ? .black.opacity(0.85) : TFTTheme.accent
    }

    private func segmentBackground(isSelected: Bool) -> Color {
        guard isSelected else { return .clear }
        return style == .primary ? TFTTheme.accent : TFTTheme.elevatedBackground
    }
}

#Preview {
    VStack(spacing: 0) {
        PanelTabBar(
            tabs: ["Comps", "Items", "Reference"],
            selection: "Comps",
            title: { $0 },
            onSelect: { _ in }
        )
        PanelTabBar(
            tabs: ["Comps", "Items", "Reference"],
            selection: "Comps",
            title: { $0 },
            onBack: {},
            onSelect: { _ in }
        )
        Spacer()
    }
    .frame(width: 460, height: 120)
    .background(TFTTheme.background)
}
