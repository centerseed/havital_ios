#if DEBUG
import SwiftUI

struct UITestPaywallHostView: View {
    @State private var paywallTrigger: PaywallTrigger? = nil
    @ObservedObject private var subscriptionState = SubscriptionStateManager.shared
    private let repositoryTypeName: String = {
        let repository = DependencyContainer.shared.resolve() as SubscriptionRepository
        return String(describing: type(of: repository))
    }()

    var body: some View {
        VStack(spacing: 16) {
            Text("UITest Paywall Host")
                .font(.headline)

            Text("status:\(subscriptionState.currentStatus?.status.rawValue ?? "none")")
                .font(.subheadline)
                .accessibilityIdentifier("UITest_SubscriptionStatus")

            Text("repo:\(repositoryTypeName)")
                .font(.caption)
                .foregroundColor(.secondary)
                .accessibilityIdentifier("UITest_SubscriptionRepositoryType")

            Button("Open Paywall") {
                paywallTrigger = .featureLocked
            }
            .accessibilityIdentifier("UITest_OpenPaywall")
        }
        .padding(24)
        .sheet(item: $paywallTrigger) { trigger in
            PaywallView(trigger: trigger)
        }
    }
}
#endif
