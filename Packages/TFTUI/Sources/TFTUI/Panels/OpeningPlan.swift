import SwiftUI

/// The beginner opening plan: what to do from stage 1 to 2-5, regardless of
/// which comp you end up playing (#99).
///
/// **Authored general strategy. Nothing here is derived from this app's comp
/// list, and nothing here is measured.** That distinction is load-bearing,
/// which is why it is a stored `attribution` string rendered in the panel
/// rather than a doc-comment: everything else on the Openers panel is a
/// derivation over the corpus, and a reader who cannot tell the two apart
/// has been misled about where the advice comes from. The panel already owes
/// the same honesty about `Comp.tier` being an authored tier list rather than
/// placement data (ADR 0004; real statistics are issue #62) — this is the
/// same rule applied to prose.
///
/// Sourced from established public guidance (BunnyMuffins' opener guide,
/// Mobalytics' economy guide, TFT Ninja's stage-by-stage), not from
/// inference. No percentage, win rate or placement number appears here,
/// because none of those was measured; the gold and interest figures are
/// game rules, and the level timings agree with the corpus's own `levelPlan`
/// (all 36 comps level to 6 at 3-2).
///
/// A pure value type with no view state, so a test can assert on the text
/// without rendering it, and so the wording lives in one place instead of
/// being scattered through a view body.
struct OpeningPlan: Sendable {
    struct Step: Identifiable, Hashable, Sendable {
        var id: String {
            when
        }

        /// When to act, in TFT's own stage-round notation, with the level to
        /// be at by then where there is one. Short enough to read as a
        /// column label — this is the left rail of a four-row plan, not a
        /// sentence.
        let when: String
        let action: String
    }

    /// The one sentence that keeps the section honest. Shown, not buried.
    static let attribution = "Authored general strategy — not derived from this app's comp list, "
        + "and not measured. Applies whichever comp you end up in."

    /// Four rows, one decision each. A stage-1 overlay read in peripheral
    /// vision cannot carry an article; anything that is not a thing to *do*
    /// at a named round is not in here.
    static let steps: [Step] = [
        Step(
            when: "Stage 1",
            action: "Spend nothing — no rolling, no levelling. Take every component, "
                + "and buy pairs of the cheap units above: a 2-star in stage 2 is a big lead."
        ),
        Step(
            when: "2-1 · level 4",
            action: "The fork. Scout the lobby first, then commit: win streak, "
                + "or lose on purpose and bank interest. Drifting between the two loses both."
        ),
        Step(
            when: "2-5 · level 5",
            action: "Slam items that fill a role on a unit you already have. "
                + "Holding components for a perfect best-in-slot costs more than the wrong item does."
        ),
        Step(
            when: "3-2 · level 6",
            action: "Streak settled and components in hand — now pick the comp they left open, "
                + "and roll toward it."
        ),
    ]

    /// The two economy rules every opener decision is measured against.
    /// Game rules, not opinion, and stated as rules rather than dressed up
    /// as a finding.
    static let economyRule = "Gold: 2, 2, 3, 4, then 5 a round. Interest: +1 per 10 held, capped at 50."
}

/// The authored plan, rendered as a labelled four-row rail.
///
/// Visually unlike the ranked sections around it on purpose — no bars, no
/// counts, no portraits — so that "this is advice" and "this is a derivation
/// over the corpus" do not read as the same kind of claim at a glance.
struct OpeningPlanSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            header
            VStack(alignment: .leading, spacing: 5) {
                ForEach(OpeningPlan.steps) { step in
                    stepRow(step)
                }
                economyRow
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Opening plan")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(TFTTheme.accent)
            Text(OpeningPlan.attribution)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(TFTTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The `when` column is a fixed width so the four rounds line up into a
    /// scannable rail; at a ragged left edge the plan reads as four
    /// unrelated sentences.
    private static let whenColumnWidth: CGFloat = 84

    private func stepRow(_ step: OpeningPlan.Step) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(step.when)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(TFTTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: Self.whenColumnWidth, alignment: .leading)
            Text(step.action)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(TFTTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(
            TFTTheme.panelBackground,
            in: RoundedRectangle(cornerRadius: TFTTheme.smallCornerRadius, style: .continuous)
        )
    }

    private var economyRow: some View {
        Text(OpeningPlan.economyRule)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(TFTTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 2)
    }
}

#Preview {
    OpeningPlanSection()
        .padding(12)
        .frame(width: 460)
        .background(TFTTheme.background)
}
