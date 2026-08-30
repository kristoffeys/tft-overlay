import SwiftUI

/// The compact overlay's default content: the roster of the build the player
/// is actually going for, items and all.
///
/// Compact mode is what stays on screen during a live game, so it should
/// answer the question the player has in that mode -- "what am I buying" --
/// without a click. A generic item recipe matrix answers a question they
/// mostly have between games instead (`CompactItemCheatSheetView` is still
/// there for that).
///
/// "Selected build" is the current pin. Pinning a comp anywhere in the app
/// makes it the current one (`PinnedCompsStore.pin`), and the chevrons cycle
/// between pins when there is more than one, so a player who pinned two
/// lines pre-game can flip between them without reopening the list.
public struct SelectedBuildRosterView: View {
    let comps: [Comp]
    @ObservedObject var store: PinnedCompsStore
    let portraitSize: CGFloat
    let onOpen: (Comp) -> Void

    public init(
        comps: [Comp],
        store: PinnedCompsStore,
        // Sized against the real 300x320 compact panel: a full 8-9 unit
        // roster still lands in two rows at this size, so the leftover
        // height is better spent on art a player can recognise in
        // peripheral vision than on empty panel.
        portraitSize: CGFloat = 50,
        onOpen: @escaping (Comp) -> Void = { _ in }
    ) {
        self.comps = comps
        self.store = store
        self.portraitSize = portraitSize
        self.onOpen = onOpen
    }

    private var pinnedComps: [Comp] {
        store.pinnedIDs.compactMap { id in comps.first { $0.id == id } }
    }

    /// Falls back to the first pin rather than showing the empty state: a
    /// cycle index that has drifted out of step with the pin list is a bug
    /// worth surviving, not worth blanking the panel over.
    private var current: Comp? {
        guard let id = store.currentPinnedID, let comp = comps.first(where: { $0.id == id }) else {
            return pinnedComps.first
        }
        return comp
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let current {
                header(current)
                // One line, always: compact mode is a glance, so the roster
                // is sized down to fit the width rather than wrapping onto
                // rows that push the panel taller. Names are dropped here —
                // the art plus the item strip is what answers "what am I
                // buying", and every portrait still has its hover card.
                GeometryReader { proxy in
                    CompRosterGrid(
                        comp: current,
                        portraitSize: CompRosterStripFit.portraitSize(
                            availableWidth: proxy.size.width,
                            unitCount: current.units.count,
                            spacing: 3
                        ),
                        spacing: 3,
                        layout: .singleLine
                    )
                }
            } else {
                emptyState
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(TFTTheme.background)
    }

    private func header(_ comp: Comp) -> some View {
        HStack(spacing: 6) {
            TierBadge(comp.tier)
            Button {
                onOpen(comp)
            } label: {
                VStack(alignment: .leading, spacing: 1) {
                    Text(comp.name)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(TFTTheme.textPrimary)
                        .lineLimit(1)
                    if pinnedComps.count > 1 {
                        Text("\(displayPosition) / \(pinnedComps.count) pinned")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(TFTTheme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            if pinnedComps.count > 1 {
                cycleButton(systemImage: "chevron.left", action: store.retreat)
                cycleButton(systemImage: "chevron.right", action: store.advance)
            }
        }
    }

    private var displayPosition: Int {
        (store.cyclePosition(of: current?.id ?? "") ?? 0) + 1
    }

    private func cycleButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(TFTTheme.textPrimary)
                .frame(width: 20, height: 20)
                .background(TFTTheme.elevatedBackground, in: Circle())
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "pin")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(TFTTheme.textSecondary)
            Text("Pin a comp to see its roster here")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(TFTTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    let comps = (try? CompLoader.bundledFixtures()) ?? []
    let store = PinnedCompsStore(defaults: UserDefaults(suiteName: "SelectedBuildRosterPreview") ?? .standard)
    for comp in comps.prefix(2) {
        store.pin(comp.id)
    }
    return SelectedBuildRosterView(comps: comps, store: store)
        .frame(width: 300, height: 320)
}
