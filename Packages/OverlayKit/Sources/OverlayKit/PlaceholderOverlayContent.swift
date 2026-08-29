import SwiftUI

/// Stand-in panel content until the real comps/items UI (a separate
/// package) is wired in. Exists so `OverlayPanelController` can be
/// exercised end-to-end today.
public struct PlaceholderOverlayContent: View {
    @Environment(\.overlayLayoutMode) private var layoutMode
    @Environment(\.overlayIsInteractive) private var isInteractive

    public init() {}

    public var body: some View {
        Group {
            if layoutMode == .compact {
                HStack {
                    Text("TFT Overlay")
                        .font(.caption.bold())
                    Spacer()
                    Circle()
                        .fill(isInteractive ? Color.green : Color.gray)
                        .frame(width: 6, height: 6)
                }
                .padding(.horizontal, 10)
                .frame(maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TFT Overlay").font(.headline)
                    Text(isInteractive ? "Interactive" : "Click-through")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .foregroundStyle(.white)
        .background(Color.black.opacity(0.55))
    }
}
