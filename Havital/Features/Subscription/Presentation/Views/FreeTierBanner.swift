import SwiftUI

// MARK: - FreeTierBanner
/// Persistent banner shown at the top of the training plan home when the user is
/// on Free tier (or in launch grace period) AND has already generated Week 1.
///
/// AC-PAYWALL-35:
/// - Visible: subscription_status != premium AND active training plan exists (week >= 1)
/// - Hidden: subscribed / Apple intro trial / no Week 1 yet
///
/// AC-PAYWALL-38: when inGracePeriod=true, shows "免費體驗中，剩 X 天" instead of
/// the default "免費體驗期" title.
///
/// Pure rendering view — zero business logic. All visibility decisions are made by
/// the parent (TrainingPlanV2View) before rendering this component.
struct FreeTierBanner: View {
    /// Whether user is in the IAP launch grace period. Drives title text switching.
    var inGracePeriod: Bool = false
    /// Grace period remaining days. Used only when inGracePeriod = true.
    var graceRemainingDays: Int? = nil
    /// Called when the user taps anywhere on the banner or the CTA button.
    let onTap: () -> Void

    // MARK: - Computed text

    private var titleText: String {
        if inGracePeriod, let days = graceRemainingDays {
            return String(
                format: NSLocalizedString(
                    "paywall.grace_period.banner.title_format",
                    comment: "Free trial, %d days remaining"
                ),
                days
            )
        }
        return NSLocalizedString("paywall.free_tier.banner.title", comment: "Free Preview")
    }

    private var subtitleText: String {
        if inGracePeriod {
            return NSLocalizedString(
                "paywall.grace_period.banner.subtitle",
                comment: "Subscribe to keep AI features"
            )
        }
        return NSLocalizedString(
            "paywall.free_tier.banner.subtitle",
            comment: "Next week's plan requires subscription"
        )
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                // Crown icon
                Image(systemName: "crown.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(titleText)
                        .font(AppFont.systemScaled(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)

                    Text(subtitleText)
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                // Upgrade CTA chip
                Text(NSLocalizedString("paywall.free_tier.banner.cta", comment: "Upgrade"))
                    .font(AppFont.systemScaled(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                    .clipShape(Capsule())
                    .accessibilityIdentifier("FreeTierBanner_UpgradeCTA")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("FreeTierBanner")
    }
}

#Preview {
    VStack(spacing: 16) {
        FreeTierBanner(onTap: {})
            .padding()
        FreeTierBanner(inGracePeriod: true, graceRemainingDays: 5, onTap: {})
            .padding()
    }
    .background(Color(UIColor.systemGroupedBackground))
}
