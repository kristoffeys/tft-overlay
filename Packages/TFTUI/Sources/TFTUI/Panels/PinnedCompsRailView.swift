import SwiftUI

/// Pinned-comps rail (#27): a compact strip cycling between the comps a
/// player pinned pre-game, so they don't need to reopen the full comp list
/// mid-round. Persists via `PinnedCompsStore`.
public struct PinnedCompsRailView: View {
    let comps: [Comp]
    @ObservedObject var store: PinnedCompsStore
    let onSelect: (Comp) -> Void

    public init(comps: [Comp], store: PinnedCompsStore, onSelect: @escaping (Comp) -> Void = { _ in }) {
        self.comps = comps
        self.store = store
        self.onSelect = onSelect
    }

    private var pinnedComps: [Comp] {
        store.pinnedIDs.compactMap { id in comps.first { $0.id == id } }
    }

    private var current: Comp? {
        guard let id = store.currentPinnedID, let comp = comps.first(where: { $0.id == id }) else {
            return pinnedComps.first
        }
        return comp
    }

    public var body: some View {
        if pinnedComps.isEmpty {
            emptyState
        } else {
            content
        }
    }

    private var emptyState: some View {
        Text("Pin a comp to cycle it here.")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(TFTTheme.textSecondary)
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(
                TFTTheme.panelBackground,
                in: RoundedRectangle(cornerRadius: TFTTheme.smallCornerRadius, style: .continuous)
            )
    }

    private var content: some View {
        HStack(spacing: 6) {
            cycleButton(systemImage: "chevron.left", action: store.retreat)
            if let current {
                Button {
                    onSelect(current)
                } label: {
                    currentCard(current)
                }
                .buttonStyle(.plain)
            }
            cycleButton(systemImage: "chevron.right", action: store.advance)
        }
        .padding(8)
        .background(
            TFTTheme.panelBackground,
            in: RoundedRectangle(cornerRadius: TFTTheme.cornerRadius, style: .continuous)
        )
    }

    private func currentCard(_ comp: Comp) -> some View {
        HStack(spacing: 8) {
            TierBadge(comp.tier)
            VStack(alignment: .leading, spacing: 2) {
                Text(comp.name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(TFTTheme.textPrimary)
                    .lineLimit(1)
                if pinnedComps.count > 1 {
                    Text("\(displayPosition) / \(pinnedComps.count)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(TFTTheme.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(minWidth: 140, alignment: .leading)
    }

    private var displayPosition: Int {
        (store.cyclePosition(of: current?.id ?? "") ?? 0) + 1
    }

    private func cycleButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(TFTTheme.textPrimary)
                .frame(width: 22, height: 22)
                .background(TFTTheme.elevatedBackground, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(pinnedComps.count <= 1)
    }
}

#Preview {
    let comps = (try? CompLoader.bundledFixtures()) ?? []
    let store = PinnedCompsStore(defaults: UserDefaults(suiteName: "preview")!)
    for comp in comps {
        store.pin(comp.id)
    }
    return PinnedCompsRailView(comps: comps, store: store)
        .padding()
        .background(Color.gray)
}
