import SwiftUI

public struct TraitTag: View {
    let name: String

    public init(_ name: String) {
        self.name = name
    }

    public var body: some View {
        Text(name)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(TFTTheme.textPrimary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(TFTTheme.elevatedBackground, in: Capsule())
    }
}

#Preview {
    HStack {
        TraitTag("Hunter")
        TraitTag("Riftbeast")
    }
    .padding()
    .background(TFTTheme.background)
}
