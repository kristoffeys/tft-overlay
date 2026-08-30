import SwiftUI

/// A champion's cost as a number, for the places that have to state it rather
/// than imply it.
///
/// `UnitPortraitPlaceholder` already tints its border by cost, and between
/// games that cue is enough. It is not enough in the Stage Companion's early
/// band (#107): the point there is to recognise a unit *in the shop*, where the
/// decision is "can I even hit this yet", and a colour the player has to have
/// memorised does not answer that in half a second. A locked panel takes no
/// mouse events (#83), so the number cannot live in a tooltip either.
///
/// Drawn as an overlay on the portrait, so it costs no vertical space.
struct UnitCostBadge: View {
    let cost: Int
    /// The portrait's edge length; the badge scales with it so a 30pt roster
    /// cell and a 40pt opener cell both stay legible.
    let portraitSize: CGFloat

    var body: some View {
        Text("\(cost)")
            .font(.system(size: max(8, (portraitSize * 0.3).rounded()), weight: .heavy, design: .rounded))
            .foregroundStyle(.black.opacity(0.9))
            .padding(.horizontal, 2.5)
            .background(TFTTheme.costColor(cost), in: Capsule())
            .overlay(Capsule().strokeBorder(.black.opacity(0.5), lineWidth: 0.5))
    }
}

#Preview {
    HStack {
        ForEach(1 ... 5, id: \.self) { cost in
            UnitPortraitPlaceholder(name: "Ashe", cost: cost, size: 40)
                .overlay(alignment: .bottomLeading) {
                    UnitCostBadge(cost: cost, portraitSize: 40).padding(1)
                }
        }
    }
    .padding()
    .background(TFTTheme.background)
}
