import SwiftUI

// MARK: - WeeklyPlanInlineUpsellCard
/// Inline upsell card shown when user triggers Week 2+ plan generation without a subscription.
/// AC-PAYWALL-22: displays in place of executing the plan generation.
struct WeeklyPlanInlineUpsellCard: View {
    /// Called when user taps the primary CTA.
    /// `isRegenerate`: true when user is re-generating an existing week (source = weeklyPlanRegenerate),
    /// false when first triggering Week 2 generation (source = weeklyPlanWeek2).
    let isRegenerate: Bool
    let onStartTrial: () -> Void
    let onRestore: () -> Void

    var body: some View {
        InlineUpsellCardLayout(
            titleKey: "paywall.inline.weekly_plan.title",
            bodyKey: "paywall.inline.weekly_plan.body",
            onStartTrial: onStartTrial,
            onRestore: onRestore
        )
        .accessibilityIdentifier("InlineUpsell_WeeklyPlan")
    }
}
