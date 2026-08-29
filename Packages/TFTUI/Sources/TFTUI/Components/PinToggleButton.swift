import SwiftUI

/// Star toggle for pinning a comp to the pinned-comps rail (#27).
struct PinToggleButton: View {
    let isPinned: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isPinned ? "star.fill" : "star")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isPinned ? TFTTheme.accent : TFTTheme.textSecondary)
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .help(isPinned ? "Unpin comp" : "Pin comp")
    }
}
