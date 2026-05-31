#if DEBUG
import SwiftUI
import Combine

// MARK: - UITestAC38GraceHostView
//
// Minimal harness for AC-PAYWALL-38/39: verifies that when a user has
// inGracePeriod=true + graceRemainingDays=5, the FreeTierBanner shows
// the "免費體驗中，剩 5 天" text variant, and that hasPremiumAccess=true
// (no inline upsell triggered).
//
// Accessibility identifiers:
//   "UITest_AC38_HostReady"    — view is fully initialized
//   "FreeTierBanner"           — FreeTierBanner component (tagged in FreeTierBanner.swift)
//
// How to run:
//   -ui_testing -ui_testing_ac38 launch arg → routes app to this view

struct UITestAC38GraceHostView: View {
    @ObservedObject private var subscriptionState = SubscriptionStateManager.shared

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Diagnostic label so UITest knows harness is ready
                Text("AC38 Host Ready")
                    .font(AppFont.headline())
                    .accessibilityIdentifier("UITest_AC38_HostReady")

                // Diagnostic: expose hasPremiumAccess value
                Text("hasPremiumAccess:\(subscriptionState.hasPremiumAccess ? "true" : "false")")
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("UITest_AC38_HasPremiumAccess")

                // Diagnostic: expose hasRealSubscription value
                Text("hasRealSubscription:\(subscriptionState.hasRealSubscription ? "true" : "false")")
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("UITest_AC38_HasRealSubscription")

                // Banner shown when !hasRealSubscription — mirrors TrainingPlanV2View logic.
                // A simulated planOverview=true means Week 1 was generated.
                if !subscriptionState.hasRealSubscription {
                    FreeTierBanner(
                        inGracePeriod: subscriptionState.currentStatus?.inGracePeriod == true,
                        graceRemainingDays: subscriptionState.currentStatus?.graceRemainingDays
                    ) {}
                    .padding(.horizontal, 16)
                    .transition(.opacity)
                }

                Spacer()
            }
            .padding(.top, 40)
        }
        .onAppear {
            injectGracePeriodStatus()
        }
    }

    // MARK: - Helpers

    /// Injects a grace period subscription status:
    ///   status = .none (not a real subscriber), inGracePeriod = true, graceRemainingDays = 5
    private func injectGracePeriodStatus() {
        let graceStatus = SubscriptionStatusEntity(
            status: .none,
            enforcementEnabled: true,
            inGracePeriod: true,
            graceRemainingDays: 5
        )
        SubscriptionStateManager.shared.update(graceStatus)
    }
}

#endif
