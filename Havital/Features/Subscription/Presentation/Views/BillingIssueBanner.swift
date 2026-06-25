import SwiftUI

// MARK: - BillingIssueBanner
/// Persistent warning banner shown at the top of the training plan home when the
/// user's subscription has a billing problem (auto-renewal payment failed).
///
/// T-0060: Distinct from `FreeTierBanner` (which is a promo / launch-grace upsell).
/// This banner is an *involuntary churn* alert — the user WAS paying, the renewal
/// charge failed, and Apple is retrying during the billing grace period. We must
/// tell them explicitly to update their payment method before access is cut off.
///
/// Driven by `SubscriptionStatusEntity.billingIssue == true`.
///
/// Pure rendering view — zero business logic. Visibility is decided by the parent
/// (TrainingPlanV2View) before rendering this component.
struct BillingIssueBanner: View {
    /// Called when the user taps anywhere on the banner or the CTA button.
    /// Parent opens the App Store subscription-management page.
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.red)

                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString(
                        "paywall.billing_issue.banner.title",
                        comment: "Subscription renewal failed"
                    ))
                    .font(AppFont.systemScaled(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)

                    Text(NSLocalizedString(
                        "paywall.billing_issue.banner.subtitle",
                        comment: "Update payment method to avoid interruption"
                    ))
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text(NSLocalizedString(
                    "paywall.billing_issue.banner.cta",
                    comment: "Update Payment"
                ))
                .font(AppFont.systemScaled(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(Color.red)
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.red.opacity(0.30), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 16) {
        BillingIssueBanner(onTap: {})
    }
    .padding()
}
