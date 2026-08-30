import SwiftUI

public struct DifficultyIndicator: View {
    let difficulty: Comp.Difficulty

    public init(_ difficulty: Comp.Difficulty) {
        self.difficulty = difficulty
    }

    private var filled: Int {
        switch difficulty {
        case .easy: 1
        case .medium: 2
        case .hard: 3
        }
    }

    public var body: some View {
        HStack(spacing: 3) {
            ForEach(0 ..< 3, id: \.self) { index in
                Circle()
                    .fill(index < filled ? TFTTheme.accent : TFTTheme.textTertiary.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading) {
        ForEach(Comp.Difficulty.allCases, id: \.self) { DifficultyIndicator($0) }
    }
    .padding()
    .background(TFTTheme.background)
}
