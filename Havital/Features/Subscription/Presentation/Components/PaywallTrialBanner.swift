import SwiftUI

// MARK: - PaywallTrialBanner
/// Horizontal banner displayed when the user is currently in an Apple intro offer trial.
/// AC-PAYWALL-18: shown below Hero, replacing Trial Timeline.
struct PaywallTrialBanner: View {
    let daysRemaining: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.fill")
                .font(AppFont.systemScaled(size: 18, weight: .semibold))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(
                    String(
                        format: NSLocalizedString("paywall.premium.trial_banner.format", comment: ""),
                        "\(daysRemaining)"
                    )
                )
                .font(AppFont.subheadline())
                .fontWeight(.semibold)
                .foregroundColor(.orange)

                Text(NSLocalizedString("paywall.premium.trial_banner.subtitle", comment: ""))
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("Paywall_TrialBanner")
    }
}
