import SwiftUI

@MainActor
class WeeklyDistanceViewModel: ObservableObject {
    @Published var weeklyDistance: Double
    @Published var isLoading = false
    @Published var error: String?
    @Published var navigateToGoalTypeSelection = false  // 導航到目標類型選擇
    @Published var navigateToRaceSetup = false  // 導航到賽事設定

    let targetDistance: Double?
    // 調整預設週跑量的上限
    let defaultMaxWeeklyDistanceCap = 30.0 // 預設週跑量上限調整為30公里
    let minimumWeeklyDistance = 0.0 // 允許使用者選擇0公里
    let maxWeeklyDistance = 180.0 // 最大週跑量上限為180公里

    init(targetDistance: Double?) {
        self.targetDistance = targetDistance
        // 預設週跑量為目標距離的30%，但不超過 defaultMaxWeeklyDistanceCap，最低為0
        // 如果沒有目標距離，預設為10公里
        if let targetDistance = targetDistance {
            let suggestedDistance = targetDistance * 0.3
            self.weeklyDistance = max(minimumWeeklyDistance, min(suggestedDistance, defaultMaxWeeklyDistanceCap))
        } else {
            self.weeklyDistance = 10.0 // 沒有目標時預設為10公里
        }
    }
    
    func saveWeeklyDistance() async {
        isLoading = true
        error = nil

        do {
            // 將週跑量轉換為整數
            let weeklyDistanceInt = Int(weeklyDistance.rounded())
            let userData = [
                "current_week_distance": weeklyDistanceInt
            ] as [String: Any]

            try await UserService.shared.updateUserData(userData)
            print("週跑量數據 (\(weeklyDistanceInt)km) 上傳成功")

            // 判斷導航邏輯
            navigateToNextStep(weeklyDistance: weeklyDistanceInt)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func skipSetup() async {
        isLoading = true
        error = nil

        do {
            // 如果略過，將週跑量設為0（整數）
            let skippedWeeklyDistance = 0
            let userData = [
                "current_week_distance": skippedWeeklyDistance
            ] as [String: Any]

            try await UserService.shared.updateUserData(userData)
            print("Skipped weekly distance setup, set to \(skippedWeeklyDistance) km")

            // 判斷導航邏輯
            navigateToNextStep(weeklyDistance: skippedWeeklyDistance)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    /// 判斷下一步導航目標
    private func navigateToNextStep(weeklyDistance: Int) {
        // 讀取用戶是否設定了最佳成績
        let hasPersonalBest = UserDefaults.standard.bool(forKey: "onboarding_hasPersonalBest")

        // 判斷邏輯：
        // 如果用戶沒有設定最佳成績 AND 沒設定週跑量（0km）：顯示目標類型選擇（包含 5km 選項）
        // 否則：直接進入賽事設定
        if !hasPersonalBest && weeklyDistance == 0 {
            print("用戶沒有 PB 且週跑量為 0，導航到目標類型選擇")
            navigateToGoalTypeSelection = true
        } else {
            print("用戶有 PB 或週跑量 > 0，直接導航到賽事設定")
            navigateToRaceSetup = true
        }
    }
}

struct WeeklyDistanceSetupView: View {
    @StateObject private var viewModel: WeeklyDistanceViewModel
    @Environment(\.dismiss) private var dismiss

    init(targetDistance: Double? = nil) {
        _viewModel = StateObject(wrappedValue: WeeklyDistanceViewModel(targetDistance: targetDistance))
    }
    
    // Slider 的最大值：如果有目標距離則為目標距離的4倍（最少60公里），否則固定180公里
    private var sliderMaxDistance: Double {
        if let targetDistance = viewModel.targetDistance {
            return max(targetDistance * 4, 60.0)
        } else {
            return viewModel.maxWeeklyDistance
        }
    }

    var body: some View {
        Form {
            Section(
                header: Text(NSLocalizedString("onboarding.current_weekly_distance", comment: "Current Weekly Distance")).padding(.top, 10),
                footer: Text(NSLocalizedString("onboarding.weekly_distance_description", comment: "Weekly Distance Description"))
            ) {
                // 只在有目標距離時顯示
                if let targetDistance = viewModel.targetDistance {
                    Text(String(format: NSLocalizedString("onboarding.target_distance_label", comment: "Target Distance Label"), targetDistance))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 5)
                }

                Text(NSLocalizedString("onboarding.adjust_weekly_volume", comment: "Adjust Weekly Volume"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 10)

                VStack(alignment: .leading, spacing: 10) {
                    // 週跑量標籤加上 Stepper 方便微調
                    HStack {
                        Text(String(format: NSLocalizedString("onboarding.weekly_volume_label", comment: "Weekly Volume Label"), viewModel.weeklyDistance))
                            .fontWeight(.medium)
                        Spacer()
                        Stepper("", value: $viewModel.weeklyDistance, in: viewModel.minimumWeeklyDistance...sliderMaxDistance, step: 1)
                            .labelsHidden()
                    }

                    Slider(
                        value: $viewModel.weeklyDistance,
                        in: viewModel.minimumWeeklyDistance...sliderMaxDistance,
                        step: 1
                    )

                    HStack {
                        Text(String(format: NSLocalizedString("onboarding.km_label", comment: "KM Label"), viewModel.minimumWeeklyDistance))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: NSLocalizedString("onboarding.km_label", comment: "KM Label"), sliderMaxDistance))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 5)
            }
            
            if let error = viewModel.error {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle(NSLocalizedString("onboarding.weekly_distance_title", comment: "Weekly Distance Title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { // 修改為明確的返回按鈕
                Button {
                    dismiss()
                } label: {
                    Text(NSLocalizedString("onboarding.back", comment: "Back"))
                }
            }
            
            ToolbarItemGroup(placement: .navigationBarTrailing) { // 將略過和下一步放在一起
                Button(NSLocalizedString("onboarding.skip", comment: "Skip")) {
                    Task {
                        await viewModel.skipSetup()
                    }
                }
                .disabled(viewModel.isLoading) // 略過按鈕在加載時也禁用

                if viewModel.isLoading {
                    ProgressView()
                        .padding(.leading, 5) // 給 ProgressView 一點空間
                } else {
                    Button(action: {
                        Task {
                            await viewModel.saveWeeklyDistance()
                        }
                    }) {
                        Text(NSLocalizedString("onboarding.next_step", comment: "Next Step"))
                    }
                    .disabled(viewModel.isLoading) // 下一步按鈕在加載時也禁用
                }
            }
        }
        // .disabled(viewModel.isLoading) // Form 層級的 disabled 可以移除，因為按鈕已單獨處理
        .background(
            Group {
                // 導航到目標類型選擇頁面（新手）
                NavigationLink(
                    destination: GoalTypeSelectionView().navigationBarBackButtonHidden(true),
                    isActive: $viewModel.navigateToGoalTypeSelection
                ) {
                    EmptyView()
                }

                // 導航到賽事設定頁面（有經驗的跑者）
                NavigationLink(
                    destination: OnboardingView().navigationBarBackButtonHidden(true),
                    isActive: $viewModel.navigateToRaceSetup
                ) {
                    EmptyView()
                }
            }
        )
    }
}

struct WeeklyDistanceSetupView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView { // 使用 NavigationView 預覽
            WeeklyDistanceSetupView(targetDistance: 21.0975) // 半馬
        }
        NavigationView {
            WeeklyDistanceSetupView(targetDistance: 5) // 5K
        }
        NavigationView {
            WeeklyDistanceSetupView(targetDistance: nil) // 無目標（新 onboarding 流程）
        }
    }
}
