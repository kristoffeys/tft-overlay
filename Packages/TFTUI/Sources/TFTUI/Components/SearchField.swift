import SwiftUI

/// The panels' search box: a glyph, a plain text field, and the panel's own
/// inset backing.
///
/// Extracted from `CompsListChrome` and `UnitTraitReferenceView`, which had
/// byte-identical copies of it, so the rasterising seam below exists in one
/// place rather than two.
struct SearchField: View {
    let placeholder: String
    @Binding var text: String

    /// See `EnvironmentValues.rendersTextFieldsAsPlaceholders`.
    @Environment(\.rendersTextFieldsAsPlaceholders) private var rendersPlaceholder

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(TFTTheme.textTertiary)
            field
        }
        .font(.system(size: 13, weight: .medium))
        .padding(9)
        .background(
            TFTTheme.panelBackground,
            in: RoundedRectangle(cornerRadius: TFTTheme.smallCornerRadius, style: .continuous)
        )
    }

    @ViewBuilder
    private var field: some View {
        if rendersPlaceholder, text.isEmpty {
            Text(placeholder)
                .foregroundStyle(TFTTheme.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .foregroundStyle(TFTTheme.textPrimary)
        }
    }
}

/// Draw an empty `TextField` as its own placeholder text instead of as a
/// live field, for the benefit of off-screen rasterisation.
///
/// `ImageRenderer` has no AppKit responder chain, so a `TextField` does not
/// draw its text at all: it rasterises as a saturated solid bar the width of
/// the field. That bar is bright enough to clear an ink-coverage floor by
/// itself, which is exactly how two panel snapshots in issue #95 reported
/// success on a panel that was otherwise entirely black — the search bar was
/// the only thing in the bitmap.
///
/// An empty, unfocused field shows its placeholder in the real app, so
/// substituting `Text(placeholder)` is visually faithful *and* puts real
/// glyphs in the raster: sparse, correctly coloured ink that a blankness
/// assertion can reason about.
///
/// Set by `ViewSnapshot.render` only. `measuredSize` deliberately leaves it
/// off — geometry questions have to be answered by the view that actually
/// ships, and `TextField`'s layout under `ImageRenderer` is accurate even
/// though its drawing is not.
extension EnvironmentValues {
    var rendersTextFieldsAsPlaceholders: Bool {
        get { self[RendersTextFieldsAsPlaceholdersKey.self] }
        set { self[RendersTextFieldsAsPlaceholdersKey.self] = newValue }
    }
}

private struct RendersTextFieldsAsPlaceholdersKey: EnvironmentKey {
    static let defaultValue = false
}
