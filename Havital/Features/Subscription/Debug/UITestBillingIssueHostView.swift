#if DEBUG
import SwiftUI
import Combine

// MARK: - UITestBillingIssueHostView
//
// Minimal harness for T-0060: verifies that when a user's subscription has
// billingIssue=true (auto-renewal payment failed), the BillingIssueBanner shows
// the "訂閱續訂失敗 / 更新付款方式" alert — mirrors the condition in
// TrainingPlanV2View.
//
// Accessibility identifiers:
//   "UITest_BillingIssue_HostReady" — view is fully initialized
//
// How to run:
//   -ui_testing_billing_issue launch arg → routes app to this view

struct UITestBillingIssueHostView: View {
    @ObservedObject private var subscriptionState = SubscriptionStateManager.shared

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("BillingIssue Host Ready")
                    .font(AppFont.headline())
                    .accessibilityIdentifier("UITest_BillingIssue_HostReady")

                Text("billingIssue:\(subscriptionState.currentStatus?.billingIssue == true ? "true" : "false")")
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("UITest_BillingIssue_Flag")

                // Mirrors TrainingPlanV2View: banner shown when billingIssue == true.
                if subscriptionState.currentStatus?.billingIssue == true {
                    BillingIssueBanner {}
                        .padding(.horizontal, 16)
                        .transition(.opacity)
                }

                Spacer()
            }
            .padding(.top, 40)
        }
        .onAppear {
            injectBillingIssueStatus()
        }
    }

    /// Injects a subscription status with a billing problem:
    ///   status = .gracePeriod (still has access during Apple billing retry),
    ///   billingIssue = true
    private func injectBillingIssueStatus() {
        let status = SubscriptionStatusEntity(
            status: .gracePeriod,
            planType: "yearly",
            billingIssue: true,
            enforcementEnabled: true
        )
        SubscriptionStateManager.shared.update(status)
    }
}

#endif
