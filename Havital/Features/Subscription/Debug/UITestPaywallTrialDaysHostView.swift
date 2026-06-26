#if DEBUG
import SwiftUI

// MARK: - UITestPaywallTrialDaysHostView
//
// T-0061 verification harness: renders the real PaywallTrialTimelineView + the
// section-subtitle format strings with injected trial-day counts (14 and 30) to
// prove the copy is data-driven (no hardcoded 30 / 28).
//
// How to run:
//   -ui_testing_paywall_trial_days launch arg → routes app to this view

struct UITestPaywallTrialDaysHostView: View {

    private func subtitle(_ key: String, _ days: Int) -> String {
        String(format: NSLocalizedString(key, comment: ""), days)
    }

    @ViewBuilder
    private func block(_ title: String, _ days: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppFont.headline())
            Text("[default subtitle] " + subtitle("paywall.premium.section.default.subtitle_trial_format", days))
                .font(AppFont.caption())
                .foregroundColor(.secondary)
            Text("[earlybird subtitle] " + subtitle("paywall.premium.section.earlybird.subtitle_trial_format", days))
                .font(AppFont.caption())
                .foregroundColor(.secondary)
            PaywallTrialTimelineView(trialDays: days)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Paywall Trial Days Host Ready")
                    .font(AppFont.headline())
                    .accessibilityIdentifier("UITest_PaywallTrialDays_HostReady")

                // Early-bird 30-day
                block("Early-bird (trialDays = 30)", 30)
                // Standard 14-day (after early-bird window)
                block("Standard / post-early-bird (trialDays = 14)", 14)
            }
            .padding(20)
        }
    }
}

#endif
