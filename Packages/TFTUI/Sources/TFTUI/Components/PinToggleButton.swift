import SwiftUI

/// Pin toggle for the build the player is going for (#27).
///
/// A pin, not a star: a star reads as "favourite" — a lasting preference
/// across many comps — whereas this marks the one build you are playing
/// toward right now, which is what compact mode shows and what the app
/// opens on.
struct PinToggleButton: View {
    let isPinned: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isPinned ? "pin.fill" : "pin")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isPinned ? TFTTheme.accent : TFTTheme.textSecondary)
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .help(isPinned ? "Unpin comp" : "Pin comp")
    }
}
