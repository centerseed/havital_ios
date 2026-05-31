import SwiftUI

// MARK: - WeeklyReviewInlineUpsellCard
/// Inline upsell card shown when user triggers AI weekly review without a subscription.
/// AC-PAYWALL-23: displays in place of executing the weekly review.
struct WeeklyReviewInlineUpsellCard: View {
    let onStartTrial: () -> Void
    let onRestore: () -> Void

    var body: some View {
        InlineUpsellCardLayout(
            titleKey: "paywall.inline.weekly_review.title",
            bodyKey: "paywall.inline.weekly_review.body",
            onStartTrial: onStartTrial,
            onRestore: onRestore
        )
        .accessibilityIdentifier("InlineUpsell_WeeklyReview")
    }
}
