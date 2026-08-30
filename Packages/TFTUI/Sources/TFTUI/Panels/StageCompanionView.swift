import SwiftUI

/// The committed build as a stage companion (#84): what to do *this* round,
/// with the rest of the plan still in view underneath.
///
/// `CompDetailView` answers "tell me about this comp" and stays the right
/// artifact between games — it is one tap away at the bottom. This panel
/// answers the only question a live game asks, and is built to the bar
/// `TFTTheme` sets for itself: readable in peripheral vision, in half a
/// second, over a moving background.
///
/// The stage is set by hand, because there is no board vision yet (#45). That
/// is the risky part, so the layout is built around a player who ignores the
/// control entirely: the current band is default-`early` and unmissable, and
/// every other band stays legible below it rather than hidden. Drifting out of
/// date costs a glance, not the plan.
public struct StageCompanionView: View {
    let comp: Comp
    let band: StageBand
    let advanceHint: String?
    let onSelectBand: (StageBand) -> Void
    let onTogglePin: ((Comp) -> Void)?

    @ObservedObject private var pinnedStoreBox: PinnedCompsStoreBox
    @State private var showsFullDetail = false

    private let plan: BuildStagePlan
    private let unitIndex: CompUnitIndex

    /// - Parameters:
    ///   - band: the stage the player has advanced to. Held by the host, not
    ///     here, so a hotkey and a tap move the same value.
    ///   - advanceHint: the currently-bound advance hotkey, rendered next to
    ///     the stage control. Nil when the host has no binding to name — the
    ///     tap target is the same either way.
    public init(
        comp: Comp,
        band: StageBand,
        advanceHint: String? = nil,
        pinnedStore: PinnedCompsStore? = nil,
        onSelectBand: @escaping (StageBand) -> Void,
        onTogglePin: ((Comp) -> Void)? = nil
    ) {
        self.comp = comp
        self.band = band
        self.advanceHint = advanceHint
        self.onSelectBand = onSelectBand
        self.onTogglePin = onTogglePin
        pinnedStoreBox = PinnedCompsStoreBox(pinnedStore)
        plan = BuildStagePlan(comp: comp)
        unitIndex = CompUnitIndex(comp: comp)
    }

    public var body: some View {
        ScrollView {
            content
        }
        .background(TFTTheme.background)
    }

    /// Padding around `content`'s `VStack`. Named rather than a bare literal
    /// because the top value is also the space between the scroll view's top
    /// edge and `glance` — `StageCompanionSnapshotTests` reads it to compute
    /// how much of the panel `glance` actually gets without scrolling (#110).
    public static let contentPadding: CGFloat = 12

    /// The panel minus its scroll container, for the same reason
    /// `CompDetailView` splits one out: `ImageRenderer` renders a `ScrollView`
    /// as an empty bitmap, so a layout test that wraps one tests nothing.
    var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            glance
            otherBands
            unscheduled
            fullDetailDisclosure
        }
        .padding(Self.contentPadding)
    }

    /// The part that has to answer "what do I do now" with no scrolling, so
    /// it is measured on its own: `StageCompanionSnapshotTests` holds it under
    /// the expanded panel's height for every comp and every band.
    var glance: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            stageControl
            // A hex tooltip on the late band's board can reach past its card.
            StageBandDetail(section: plan.section(for: band), comp: comp, unitIndex: unitIndex)
                .zIndex(1)
        }
    }

    /// Deliberately one line: in Focus the player already knows which build
    /// they committed to, and every point spent restating it is a point not
    /// spent on the stage.
    private var header: some View {
        HStack(spacing: 8) {
            TierBadge(comp.tier)
            Text(comp.name)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(TFTTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            if let store = pinnedStoreBox.store {
                PinToggleButton(isPinned: store.isPinned(comp.id)) {
                    if let onTogglePin {
                        onTogglePin(comp)
                    } else {
                        store.toggle(comp.id)
                    }
                }
            }
        }
    }

    /// The whole point of the panel, and the biggest thing on it.
    ///
    /// Big because staleness has to be self-evident: a player who set Early at
    /// 1-1 and is now at 4-2 must notice without going looking. One tap
    /// advances — the same action the hotkey performs — so the gesture is one
    /// gesture whether or not the panel is unlocked for the mouse.
    private var stageControl: some View {
        Button {
            if let next = band.next {
                onSelectBand(next)
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(band.title.uppercased())
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(TFTTheme.accent)
                Text(band.stageSpan)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(TFTTheme.textSecondary)
                Spacer(minLength: 0)
                trailingStageAffordance
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                TFTTheme.elevatedBackground,
                in: RoundedRectangle(cornerRadius: TFTTheme.cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: TFTTheme.cornerRadius, style: .continuous)
                    .strokeBorder(TFTTheme.accent.opacity(0.55), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(band.next.map { "Advance to \($0.title) stage" } ?? "Last stage")
    }

    private var trailingStageAffordance: some View {
        VStack(alignment: .trailing, spacing: 1) {
            if let target = plan.section(for: band).levelTarget {
                LevelTargetChip(target: target, isProminent: true)
            }
            if let next = band.next {
                Text("Next: \(next.title)\(advanceHint.map { " · \($0)" } ?? "")")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(TFTTheme.textSecondary)
            } else {
                Text("Last stage")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(TFTTheme.textTertiary)
            }
        }
    }

    /// Every band the player is not currently in — all of them, always.
    ///
    /// This is the property the whole feature rests on: the stage is set by
    /// hand, so the realistic worst case is a player who never touches the
    /// control, and for that player these rows are the entire rest of the plan.
    /// Exposed rather than inlined into `otherBands` so
    /// `StageCompanionSnapshotTests` can assert on *which* bands get rendered
    /// instead of only on how tall the result is — a height delta alone cannot
    /// tell "the other bands are below the fold" from "nothing is".
    var otherBandSections: [BuildStagePlan.Section] {
        plan.sections.filter { $0.band != band }
    }

    /// Kept in chronological order rather than "everything after the current
    /// one": a player checking what is coming reads down, and reordering the
    /// list under them every time the stage advances is exactly the kind of
    /// motion a glance layer must not have.
    private var otherBands: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(otherBandSections) { section in
                StageBandSummary(section: section) { onSelectBand(section.band) }
            }
        }
    }

    /// Rows whose stage string the scraper mangled. Shown once, unbanded,
    /// because dropping a row the detail view used to render would make this
    /// panel a downgrade for that comp.
    @ViewBuilder
    private var unscheduled: some View {
        if !plan.unscheduledEntries.isEmpty {
            StageCard("Unplaced plan rows") {
                LevelPlanRows(entries: plan.unscheduledEntries)
            }
        }
    }

    /// Between games the study document is the right artifact, so it is here —
    /// one tap away, and collapsed by default so it costs nothing in game.
    @ViewBuilder
    private var fullDetailDisclosure: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { showsFullDetail.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: showsFullDetail ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(TFTTheme.textTertiary)
                Text(showsFullDetail ? "Hide full build detail" : "Full build detail")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(TFTTheme.textSecondary)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        if showsFullDetail {
            // `content` brings its own 16pt page padding; cancelling this
            // panel's 12pt keeps the study document at the margins it was
            // designed for instead of a 28pt gutter.
            CompDetailView(comp: comp).content
                .padding(.horizontal, -12)
        }
    }
}

#Preview {
    if let comp = try? CompLoader.bundledFixtures().first(where: { $0.id == "blossom-spellweavers" }) {
        StageCompanionView(comp: comp, band: .early, advanceHint: "⌥S", onSelectBand: { _ in })
            .frame(width: 460, height: 640)
    }
}
