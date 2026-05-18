import SwiftUI

// MARK: - InlineUpsellCardLayout
/// Shared layout for all inline upsell cards (AC-PAYWALL-22/23/24).
/// Layout: lock icon + title + body + primary CTA + secondary CTA.
/// All three inline cards (WeeklyPlan / WeeklyReview / TargetRace) use this layout.
struct InlineUpsellCardLayout: View {
    let titleKey: String
    let bodyKey: String
    let onStartTrial: () -> Void
    let onRestore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header row: lock icon + title
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.orange)
                    .padding(.top, 2)

                Text(NSLocalizedString(titleKey, comment: ""))
                    .font(AppFont.systemScaled(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Body
            Text(NSLocalizedString(bodyKey, comment: ""))
                .font(AppFont.body())
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)

            // Primary CTA: Start 30-day free trial
            Button(action: onStartTrial) {
                Text(NSLocalizedString("paywall.inline.cta.start_trial", comment: ""))
                    .font(AppFont.headline())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("InlineUpsell_StartTrialButton")

            // Secondary CTA: Restore
            Button(action: onRestore) {
                Text(NSLocalizedString("paywall.inline.cta.restore", comment: ""))
                    .font(AppFont.bodySmall())
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("InlineUpsell_RestoreButton")
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.orange.opacity(0.08), radius: 8, x: 0, y: 3)
    }
}
