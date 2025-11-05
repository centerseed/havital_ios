import SwiftUI
import HealthKit

struct DataSourceSelectionView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var garminManager = GarminManager.shared
    @StateObject private var stravaManager = StravaManager.shared
    @StateObject private var userPreferenceManager = UserPreferenceManager.shared
    @EnvironmentObject private var featureFlagManager: FeatureFlagManager
    
    @State private var selectedDataSource: DataSourceType?
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var navigateToNextStep = false
    @State private var showGarminAlreadyBoundAlert = false
    @State private var showStravaAlreadyBoundAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        // 標題區塊
                        VStack(spacing: 16) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .foregroundColor(.accentColor)
                            
                            Text(L10n.Onboarding.chooseDataSource.localized)
                                .font(.title2)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                            
                            Text(L10n.Onboarding.selectPlatformDescription.localized)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        
                        // 數據源選項
                        VStack(spacing: 16) {
                            // Apple Health 選項
                            dataSourceCard(
                                type: .appleHealth,
                                icon: "heart.fill",
                                title: "Apple Health",
                                subtitle: L10n.Onboarding.appleHealthSubtitle.localized,
                                description: L10n.Onboarding.appleHealthDescription.localized
                            )

                            // Garmin 選項（總是顯示）
                            dataSourceCard(
                                type: .garmin,
                                icon: "clock.arrow.circlepath",
                                title: "Garmin Connect™",
                                subtitle: L10n.Onboarding.garminSubtitle.localized,
                                description: L10n.Onboarding.garminDescription.localized
                            )

                            // Strava 選項
                            dataSourceCard(
                                type: .strava,
                                icon: "figure.run",
                                title: "Strava",
                                subtitle: L10n.Onboarding.stravaSubtitle.localized,
                                description: L10n.Onboarding.stravaDescription.localized
                            )
                        }
                        .padding(.horizontal)
                        
                        Spacer()
                        
                        // 繼續按鈕
                        Button(action: {
                            handleDataSourceSelection()
                        }) {
                            HStack {
                                if isProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text(isProcessing ? L10n.Onboarding.processing.localized : L10n.Onboarding.continueStep.localized)
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedDataSource != nil ? Color.accentColor : Color.gray)
                            .cornerRadius(10)
                        }
                        .disabled(selectedDataSource == nil || isProcessing)
                        .padding(.horizontal, 40)
                        .padding(.bottom, 30)
                    }
                    .padding()
                }
                
                // 隱藏的 NavigationLink
                NavigationLink(
                    destination: OnboardingView()
                        .navigationBarBackButtonHidden(true),
                    isActive: $navigateToNextStep
                ) {
                    EmptyView()
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
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
        .onAppear {
            // 等待用戶選擇數據源
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
                    // Use official Garmin logo for Garmin option, system icon for others
                    if type == .garmin {
                        Image("Garmin Tag-black-high-res")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 24)
                            .frame(width: 30)
                    } else {
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundColor(selectedDataSource == type ? .accentColor : .secondary)
                            .frame(width: 30)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // 選擇狀態指示器
                    if selectedDataSource == type {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(.title2)
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.secondary)
                            .font(.title2)
                    }
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedDataSource == type ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedDataSource == type ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
            )
        }
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
                    // 不應該到達這裡，因為 UI 中沒有提供 unbound 選項
                    print("DataSourceSelectionView: 意外的 unbound 選擇")
                }
                
                await MainActor.run {
                    isProcessing = false
                    navigateToNextStep = true
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
        
        // 請求 HealthKit 權限
        try await healthKitManager.requestAuthorization()
        
        // 設置數據源偏好
        userPreferenceManager.dataSourcePreference = .appleHealth
        
        // 同步到後端
        try await UserService.shared.updateDataSource(DataSourceType.appleHealth.rawValue)
        
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
        
        // 設置數據源偏好為 Garmin
        userPreferenceManager.dataSourcePreference = .garmin
        
        // 同步到後端
        do {
            try await UserService.shared.updateDataSource(DataSourceType.garmin.rawValue)
        } catch {
            print("同步 Garmin 數據源設定到後端失敗: \(error.localizedDescription)")
        }
        
        // 開始 Garmin OAuth 流程（不等待完成）
        await garminManager.startConnection()
        
        Logger.firebase("Garmin OAuth 流程已啟動", level: .info, labels: [
            "module": "DataSourceSelectionView",
            "action": "garminSelection",
            "result": "oauth_started"
        ])
        
        // 不等待 OAuth 完成，直接繼續到下一步
        // OAuth 流程會在後台進行，用戶可以稍後在設置中完成連接
    }
    
    private func handleStravaSelection() async {
        Logger.firebase("開始 Strava OAuth 流程", level: .info, labels: [
            "module": "DataSourceSelectionView",
            "action": "stravaSelection",
            "step": "start"
        ])
        
        // 設置數據源偏好為 Strava
        userPreferenceManager.dataSourcePreference = .strava
        
        // 同步到後端
        do {
            try await UserService.shared.updateDataSource(DataSourceType.strava.rawValue)
        } catch {
            print("同步 Strava 數據源設定到後端失敗: \(error.localizedDescription)")
        }
        
        // 開始 Strava OAuth 流程（不等待完成）
        await stravaManager.startConnection()
        
        Logger.firebase("Strava OAuth 流程已啟動", level: .info, labels: [
            "module": "DataSourceSelectionView",
            "action": "stravaSelection",
            "result": "oauth_started"
        ])
        
        // 不等待 OAuth 完成，直接繼續到下一步
        // OAuth 流程會在後台進行，用戶可以稍後在設置中完成連接
    }
}

struct DataSourceSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        DataSourceSelectionView()
    }
} 