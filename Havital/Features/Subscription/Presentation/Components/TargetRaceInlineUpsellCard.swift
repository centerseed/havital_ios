import SwiftUI

// MARK: - TargetRaceInlineUpsellCard
/// Inline upsell card shown when user tries to create a target race without a subscription.
/// AC-PAYWALL-24: displays in place of the target race creation flow.
struct TargetRaceInlineUpsellCard: View {
    let onStartTrial: () -> Void
    let onRestore: () -> Void

    var body: some View {
        InlineUpsellCardLayout(
            titleKey: "paywall.inline.target_race.title",
            bodyKey: "paywall.inline.target_race.body",
            onStartTrial: onStartTrial,
            onRestore: onRestore
        )
        .accessibilityIdentifier("InlineUpsell_TargetRace")
    }
}
