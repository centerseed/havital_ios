import SwiftUI
import HealthKit

struct DataSourceSelectionView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var garminManager = GarminManager.shared
    @StateObject private var stravaManager = StravaManager.shared
    @StateObject private var viewModel = UserProfileFeatureViewModel()
    @ObservedObject private var coordinator = OnboardingCoordinator.shared
    @EnvironmentObject private var featureFlagManager: FeatureFlagManager

    @State private var selectedDataSource: DataSourceType?
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showGarminAlreadyBoundAlert = false
    @State private var showStravaAlreadyBoundAlert = false

    var body: some View {
        OnboardingPageTemplate(
            ctaTitle: isProcessing ? L10n.Onboarding.processing.localized : L10n.Onboarding.continueStep.localized,
            ctaEnabled: selectedDataSource != nil && !isProcessing,
            isLoading: isProcessing,
            skipTitle: nil,
            ctaAccessibilityId: "OnboardingContinueButton",
            ctaAction: {
                handleDataSourceSelection()
            },
            skipAction: nil
        ) {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.accentColor)

                    Text(L10n.Onboarding.chooseDataSource.localized)
                        .font(AppFont.title2())
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text(L10n.Onboarding.selectPlatformDescription.localized)
                        .font(AppFont.body())
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                VStack(spacing: 16) {
                    dataSourceCard(
                        type: .appleHealth,
                        icon: "heart.fill",
                        title: "Apple Health",
                        subtitle: L10n.Onboarding.appleHealthSubtitle.localized,
                        description: L10n.Onboarding.appleHealthDescription.localized
                    )

                    dataSourceCard(
                        type: .garmin,
                        icon: "clock.arrow.circlepath",
                        title: "Garmin Connect™",
                        subtitle: L10n.Onboarding.garminSubtitle.localized,
                        description: L10n.Onboarding.garminDescription.localized
                    )

                    dataSourceCard(
                        type: .strava,
                        icon: "figure.run",
                        title: "Strava",
                        subtitle: L10n.Onboarding.stravaSubtitle.localized,
                        description: L10n.Onboarding.stravaDescription.localized
                    )
                }
            }
        }
        .accessibilityIdentifier("DataSource_Screen")
        .navigationTitle(L10n.Onboarding.chooseDataSource.localized)
        .navigationBarTitleDisplayMode(.inline)
        .alert(L10n.Onboarding.garminAlreadyBound.localized, isPresented: $showGarminAlreadyBoundAlert) {
            Button(L10n.Onboarding.iUnderstand.localized, role: .cancel) {
                garminManager.garminAlreadyBoundMessage = nil
            }
        } message: {
            Text(garminManager.garminAlreadyBoundMessage ?? L10n.Onboarding.garminAlreadyBoundMessage.localized)
        }
        .onReceive(garminManager.$garminAlreadyBoundMessage) { msg in
            showGarminAlreadyBoundAlert = (msg != nil)
        }
        .onReceive(stravaManager.$stravaAlreadyBoundMessage) { msg in
            showStravaAlreadyBoundAlert = (msg != nil)
        }
        .alert("Strava Account Already Bound", isPresented: $showStravaAlreadyBoundAlert) {
            Button(L10n.Onboarding.iUnderstand.localized, role: .cancel) {
                stravaManager.stravaAlreadyBoundMessage = nil
            }
        } message: {
            Text(stravaManager.stravaAlreadyBoundMessage ?? "This Strava account is already bound to another Paceriz account. Please first log in with the originally bound Paceriz account and unbind Strava in the profile page, then connect with this account.")
        }
        .alert(L10n.Onboarding.error.localized, isPresented: $showError) {
            Button(L10n.Onboarding.confirm.localized, role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    @ViewBuilder
    private func dataSourceCard(
        type: DataSourceType,
        icon: String,
        title: String,
        subtitle: String,
        description: String
    ) -> some View {
        Button(action: {
            selectedDataSource = type
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    if type == .garmin {
                        Image("Garmin Tag-black-high-res")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 24)
                            .frame(width: 30)
                    } else {
                        Image(systemName: icon)
                            .font(AppFont.title2())
                            .foregroundColor(selectedDataSource == type ? .accentColor : .secondary)
                            .frame(width: 30)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(AppFont.headline())
                            .foregroundColor(.primary)
                        Text(subtitle)
                            .font(AppFont.bodySmall())
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if selectedDataSource == type {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(AppFont.title2())
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.secondary)
                            .font(AppFont.title2())
                    }
                }

                Text(description)
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedDataSource == type ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
                    .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedDataSource == type ? Color.accentColor : Color(.systemGray3), lineWidth: selectedDataSource == type ? 2.5 : 1.5)
            )
        }
        .accessibilityIdentifier("DataSourceOption_\(type)")
        .buttonStyle(PlainButtonStyle())
    }

    private func handleDataSourceSelection() {
        guard let selectedSource = selectedDataSource else { return }

        isProcessing = true

        Task {
            do {
                switch selectedSource {
                case .appleHealth:
                    try await handleAppleHealthSelection()
                case .garmin:
                    await handleGarminSelection()
                case .strava:
                    await handleStravaSelection()
                case .unbound:
                    print("DataSourceSelectionView: 意外的 unbound 選擇")
                }

                await MainActor.run {
                    isProcessing = false
                    coordinator.navigate(to: .heartRateZone)
                }

            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func handleAppleHealthSelection() async throws {
        Logger.firebase("開始 Apple Health 權限請求", level: .info, labels: [
            "module": "DataSourceSelectionView",
            "action": "appleHealthSelection",
            "step": "start"
        ])

        try await healthKitManager.requestAuthorization()
        try await viewModel.updateAndSyncDataSource(.appleHealth)

        Logger.firebase("Apple Health 權限請求成功", level: .info, labels: [
            "module": "DataSourceSelectionView",
            "action": "appleHealthSelection",
            "result": "success"
        ])
    }

    private func handleGarminSelection() async {
        Logger.firebase("開始 Garmin OAuth 流程", level: .info, labels: [
            "module": "DataSourceSelectionView",
            "action": "garminSelection",
            "step": "start"
        ])

        await viewModel.updateDataSource(.garmin)
        await garminManager.startConnection()

        Logger.firebase("Garmin OAuth 流程已啟動", level: .info, labels: [
            "module": "DataSourceSelectionView",
            "action": "garminSelection",
            "result": "oauth_started"
        ])
    }

    private func handleStravaSelection() async {
        Logger.firebase("開始 Strava OAuth 流程", level: .info, labels: [
            "module": "DataSourceSelectionView",
            "action": "stravaSelection",
            "step": "start"
        ])

        await viewModel.updateDataSource(.strava)
        await stravaManager.startConnection()

        Logger.firebase("Strava OAuth 流程已啟動", level: .info, labels: [
            "module": "DataSourceSelectionView",
            "action": "stravaSelection",
            "result": "oauth_started"
        ])
    }
}

struct DataSourceSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            DataSourceSelectionView()
        }
    }
}
