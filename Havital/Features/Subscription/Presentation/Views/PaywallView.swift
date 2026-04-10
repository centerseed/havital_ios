import SwiftUI

// MARK: - PaywallView

struct PaywallView: View {
    @StateObject private var viewModel: PaywallViewModel
    @ObservedObject private var subscriptionState = SubscriptionStateManager.shared
    @Environment(\.dismiss) private var dismiss

    init(trigger: PaywallTrigger) {
        _viewModel = StateObject(wrappedValue: PaywallViewModel(trigger: trigger))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                headerSection

                if let days = viewModel.trialDaysRemaining {
                    trialBanner(daysRemaining: days)
                }

                offeringsSection

                Spacer()

                Button(NSLocalizedString("paywall.restore_purchases", comment: "Restore Purchases")) {
                    // stub — ADR-002
                }
                .font(.footnote)
                .foregroundColor(.secondary)
            }
            .padding()
            .navigationTitle(NSLocalizedString("paywall.title", comment: "Upgrade"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("common.close", comment: "Close")) {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.loadOfferings()
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "crown.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text(headerTitle)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var headerTitle: String {
        switch viewModel.trigger {
        case .apiGated:
            return NSLocalizedString("paywall.header.api_gated", comment: "需要訂閱才能使用此功能")
        case .trialExpired:
            return NSLocalizedString("paywall.header.trial_expired", comment: "試用期已結束")
        case .featureLocked:
            return NSLocalizedString("paywall.header.feature_locked", comment: "升級以解鎖完整功能")
        }
    }

    @ViewBuilder
    private func trialBanner(daysRemaining: Int) -> some View {
        HStack {
            Image(systemName: "clock.fill")
                .foregroundColor(.orange)
            Text(String(format: NSLocalizedString("paywall.trial_days_remaining", comment: "%d 天試用期剩餘"), daysRemaining))
                .font(.subheadline)
                .foregroundColor(.orange)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
    }

    @ViewBuilder
    private var offeringsSection: some View {
        VStack(spacing: 12) {
            switch viewModel.offerings {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            default:
                Text(NSLocalizedString("paywall.offerings_coming_soon", comment: "付費方案即將推出"))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
    }
}
