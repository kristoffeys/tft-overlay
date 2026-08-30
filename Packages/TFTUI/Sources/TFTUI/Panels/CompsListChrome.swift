import SwiftUI

/// The non-scrolling head of the comps list: search, and the tier/style
/// filters behind a disclosure.
///
/// Measured on the real overlay at 460x640, the tab bar, search field, TIER
/// row and STYLE row consumed ~230 of 640 points — 36% of the panel — before
/// a single comp row was visible, leaving room for about three and a half
/// rows. Mid-game none of that chrome is doing anything: the player is not
/// searching and not filtering by playstyle, they are trying to remember what
/// to buy. So the two chip rows start collapsed and the disclosure carries a
/// count of what is active, which is the only thing you need to know about a
/// filter you cannot currently see.
///
/// Search stays on screen: it is one row, it is the filter people actually
/// reach for, and a hidden text field is a search you forget you have.
///
/// Its own view, with its state passed in, so a layout test can measure both
/// states without reaching into `@State`.
struct CompsListChrome: View {
    @Binding var searchText: String
    @Binding var tierFilter: Comp.Tier?
    @Binding var playstyleFilter: Comp.Playstyle?
    @Binding var showsFilters: Bool

    private var activeFilterCount: Int {
        (tierFilter == nil ? 0 : 1) + (playstyleFilter == nil ? 0 : 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                searchField
                filterDisclosure
            }
            if showsFilters {
                filterRows
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(TFTTheme.textTertiary)
            TextField("Search unit, trait, or comp", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundStyle(TFTTheme.textPrimary)
        }
        .font(.system(size: 13, weight: .medium))
        .padding(9)
        .background(
            TFTTheme.panelBackground,
            in: RoundedRectangle(cornerRadius: TFTTheme.smallCornerRadius, style: .continuous)
        )
    }

    private var filterDisclosure: some View {
        Button {
            showsFilters.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 11, weight: .heavy))
                if activeFilterCount > 0 {
                    Text("\(activeFilterCount)")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                }
            }
            .foregroundStyle(isLit ? .black.opacity(0.85) : TFTTheme.textSecondary)
            .frame(minWidth: 20)
            .padding(.horizontal, 8)
            .padding(.vertical, 9)
            .background(
                isLit ? TFTTheme.accent : TFTTheme.panelBackground,
                in: RoundedRectangle(cornerRadius: TFTTheme.smallCornerRadius, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .focusable(false)
        .accessibilityLabel(showsFilters ? "Hide filters" : "Show filters")
        .help(showsFilters ? "Hide filters" : "Show filters")
    }

    /// Lit while the rows are open *or* while a filter is on with the rows
    /// shut — otherwise collapsing the disclosure would hide the fact that
    /// the list is still filtered, which is how you end up convinced a comp
    /// has disappeared from the corpus.
    private var isLit: Bool {
        showsFilters || activeFilterCount > 0
    }

    private var filterRows: some View {
        VStack(alignment: .leading, spacing: 6) {
            filterRow(title: "Tier") {
                FilterChip(label: "All", isSelected: tierFilter == nil) { tierFilter = nil }
                ForEach(Comp.Tier.allCases, id: \.self) { tier in
                    FilterChip(label: tier.rawValue, isSelected: tierFilter == tier, color: TFTTheme.tierColor(tier)) {
                        tierFilter = (tierFilter == tier) ? nil : tier
                    }
                }
            }
            filterRow(title: "Style") {
                FilterChip(label: "All", isSelected: playstyleFilter == nil) { playstyleFilter = nil }
                ForEach(Comp.Playstyle.allCases, id: \.self) { style in
                    FilterChip(label: style.displayName, isSelected: playstyleFilter == style) {
                        playstyleFilter = (playstyleFilter == style) ? nil : style
                    }
                }
            }
        }
    }

    private func filterRow(title: String, @ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(TFTTheme.textSecondary)
                .frame(width: 34, alignment: .leading)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) { content() }
            }
        }
    }
}

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    var color: Color = TFTTheme.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? .black.opacity(0.85) : TFTTheme.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isSelected ? color : TFTTheme.elevatedBackground, in: Capsule())
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
}

#Preview {
    @Previewable @State var search = ""
    @Previewable @State var tier: Comp.Tier?
    @Previewable @State var style: Comp.Playstyle?
    @Previewable @State var shows = false

    return VStack(spacing: 0) {
        CompsListChrome(
            searchText: $search,
            tierFilter: $tier,
            playstyleFilter: $style,
            showsFilters: $shows
        )
        Spacer()
    }
    .frame(width: 460, height: 200)
    .background(TFTTheme.background)
}
