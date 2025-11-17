import SwiftUI

@MainActor
class OnboardingViewModel: ObservableObject {
    // ... (ViewModel 內容保持不變) ...
    @Published var raceName = ""
    @Published var raceDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()  // 預設為一個月後
    @Published var selectedDistance = "42.195" // 預設全馬
    @Published var targetHours = 4
    @Published var targetMinutes = 0
    @Published var isLoading = false
    @Published var error: String?
    // @Published var navigateToTrainingDays = false // 這個狀態似乎沒有直接在這個 View 中使用來導航，而是 createTarget 成功後，間接觸發 showPersonalBest

    // 起始階段選擇相關狀態
    @Published var selectedStartStage: TrainingStagePhase? = nil
    @Published var shouldShowStageSelection: Bool = false
    
    var availableDistances: [String: String] {
        [
            "5": NSLocalizedString("distance.5k", comment: "5K"),
            "10": NSLocalizedString("distance.10k", comment: "10K"),
            "21.0975": NSLocalizedString("distance.half_marathon", comment: "Half Marathon"),
            "42.195": NSLocalizedString("distance.full_marathon", comment: "Full Marathon")
        ]
    }
    
    /// 使用「週邊界」演算法計算訓練週數（與後端一致）
    /// 注意：此計算方式與簡單的日期差不同，詳見 Docs/TRAINING_WEEKS_CALCULATION.md
    var trainingWeeks: Int {
        return TrainingWeeksCalculator.calculateTrainingWeeks(
            startDate: Date(),
            raceDate: raceDate
        )
    }

    /// 保留舊的計算方式用於對比（僅供參考）
    var actualWeeksRemaining: Double {
        let (_, weeks) = TrainingWeeksCalculator.calculateActualDateDifference(
            startDate: Date(),
            raceDate: raceDate
        )
        return weeks
    }
    
    var targetPace: String {
        let totalSeconds = (targetHours * 3600 + targetMinutes * 60)
        let distanceKm = Double(selectedDistance) ?? 42.195
        let paceSeconds = Int(Double(totalSeconds) / distanceKm)
        let paceMinutes = paceSeconds / 60
        let paceRemainingSeconds = paceSeconds % 60
        return String(format: "%d:%02d", paceMinutes, paceRemainingSeconds)
    }
    
    @MainActor
    func createTarget() async -> Bool { // 返回 Bool 表示是否成功
        isLoading = true
        error = nil
        
        do {
            let target = Target(
                id: UUID().uuidString,
                type: "race_run", // 或許可以考慮增加 "personal_goal" 類型
                name: raceName.isEmpty ? NSLocalizedString("onboarding.my_training_goal", comment: "My Training Goal") : raceName, // 如果名稱為空，給一個預設值
                distanceKm: Int(Double(selectedDistance) ?? 42.195),
                targetTime: targetHours * 3600 + targetMinutes * 60,
                targetPace: targetPace,
                raceDate: Int(raceDate.timeIntervalSince1970),
                isMainRace: true,
                trainingWeeks: trainingWeeks
                // timezone 會自動使用預設的 "Asia/Taipei"
            )
            
            try await UserService.shared.createTarget(target)
            print(NSLocalizedString("onboarding.target_created", comment: "Training goal created"))
            isLoading = false
            return true
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return false
        }
    }
}

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @EnvironmentObject private var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss
    @State private var showHeartRateSetup = false
    @State private var showPersonalBest = false
    @State private var showStageSelection = false
    @State private var showTimeWarning = false
    @State private var showExitConfirmation = false  // 新增：退出確認對話框

    var body: some View {
        VStack {
            Form {
                Section(header: Text(NSLocalizedString("onboarding.your_running_goal", comment: "Your Running Goal")), footer: Text(NSLocalizedString("onboarding.goal_description", comment: "Goal description"))) {
                    TextField(NSLocalizedString("onboarding.target_race_example", comment: "Target race example"), text: $viewModel.raceName)
                        .textContentType(.name)
                    
                    DatePicker(NSLocalizedString("onboarding.goal_date", comment: "Goal Date"),
                              selection: $viewModel.raceDate,
                              in: Date()...,
                              displayedComponents: .date)
                    
                    Text(String(format: NSLocalizedString("onboarding.weeks_until_race", comment: "Weeks until race"), viewModel.trainingWeeks))
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text(NSLocalizedString("onboarding.race_distance", comment: "Race Distance"))) {
                    Picker(NSLocalizedString("onboarding.select_distance", comment: "Select Distance"), selection: $viewModel.selectedDistance) {
                        ForEach(Array(viewModel.availableDistances.keys.sorted()), id: \.self) { key in
                            Text(viewModel.availableDistances[key] ?? key)
                                .tag(key)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text(NSLocalizedString("onboarding.target_finish_time", comment: "Target Finish Time")), footer: Text(NSLocalizedString("onboarding.target_time_description", comment: "Target time description"))) {
                    HStack {
                        Picker(L10n.Onboarding.hoursLabel.localized, selection: $viewModel.targetHours) {
                            ForEach(0...6, id: \.self) { hour in
                                Text("\(hour)")
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100)
                        
                        Text(NSLocalizedString("onboarding.hours", comment: "hours"))
                        
                        Picker(L10n.Onboarding.minutesLabel.localized, selection: $viewModel.targetMinutes) {
                            ForEach(0..<60, id: \.self) { minute in
                                Text("\(minute)")
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100)
                        
                        Text(NSLocalizedString("onboarding.minutes", comment: "minutes"))
                    }
                    .padding(.vertical, 8)
                    
                    Text(String(format: NSLocalizedString("onboarding.average_pace", comment: "Average pace"), viewModel.targetPace))
                        .foregroundColor(.secondary)
                }
                
                if let error = viewModel.error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            
            // 底部按鈕
            VStack {
                Button(action: {
                    Task {
                        if await viewModel.createTarget() {
                            handleNavigationAfterTargetCreation()
                        }
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(NSLocalizedString("onboarding.next_step", comment: "Next Step"))
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(viewModel.isLoading)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground))
            
            // 導航到心率設定頁面
            NavigationLink(destination: HeartRateZoneInfoView(mode: .onboarding(targetDistance: Double(viewModel.selectedDistance) ?? 42.195))
                .navigationBarBackButtonHidden(true),
                           isActive: $showHeartRateSetup) {
                EmptyView()
            }

            // 導航到起始階段選擇頁面
            NavigationLink(destination: StartStageSelectionView(
                weeksRemaining: viewModel.trainingWeeks,
                targetDistanceKm: Double(viewModel.selectedDistance) ?? 42.195,
                onStageSelected: { stage in
                    viewModel.selectedStartStage = stage
                    // 保存到 UserDefaults 供後續使用
                    if let stage = stage {
                        print("[OnboardingView] 💾 Saving selectedStartStage to UserDefaults: \(stage.apiIdentifier)")
                        UserDefaults.standard.set(stage.apiIdentifier, forKey: "selectedStartStage")
                    } else {
                        print("[OnboardingView] 🗑️ Removing selectedStartStage from UserDefaults")
                        UserDefaults.standard.removeObject(forKey: "selectedStartStage")
                    }
                    showStageSelection = false
                    showHeartRateSetup = true
                }
            ).navigationBarBackButtonHidden(true),
               isActive: $showStageSelection) {
                EmptyView()
            }
        }
        .navigationTitle(NSLocalizedString("onboarding.set_training_goal", comment: "Set Training Goal"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(NSLocalizedString("start_stage.time_too_short_title", comment: "時間較為緊迫"),
               isPresented: $showTimeWarning) {
            Button(NSLocalizedString("common.ok", comment: "確定"), role: .cancel) {
                showTimeWarning = false
            }
        } message: {
            Text(NSLocalizedString("start_stage.time_too_short_message",
                                  comment: "距離賽事不足 2 週，可能無法達到預期的訓練效果。建議選擇更晚的賽事日期。"))
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(authService.isReonboardingMode ? NSLocalizedString("common.cancel", comment: "Cancel") : NSLocalizedString("onboarding.back", comment: "Back")) {
                    if authService.isReonboardingMode {
                        // 如果是重新設定模式，顯示確認對話框
                        showExitConfirmation = true
                    } else {
                        // 正常返回
                        dismiss()
                    }
                }
            }

            // 右上角「下一步」按鈕
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task {
                        if await viewModel.createTarget() {
                            handleNavigationAfterTargetCreation()
                        }
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Text(NSLocalizedString("onboarding.next_step", comment: "Next Step"))
                    }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .confirmationDialog(
            NSLocalizedString("onboarding.exit_setup_title", comment: "Exit Goal Setup?"),
            isPresented: $showExitConfirmation,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("onboarding.exit_setup_confirm", comment: "Exit Setup"), role: .destructive) {
                exitReonboarding()
            }
            Button(NSLocalizedString("common.cancel", comment: "Cancel"), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("onboarding.exit_setup_message", comment: "Are you sure you want to exit the goal setup? Your current training plan will remain unchanged."))
        }
    }

    // MARK: - 導航邏輯處理

    /// 退出重新設定模式，回到主畫面
    private func exitReonboarding() {
        authService.hasCompletedOnboarding = true
        authService.isReonboardingMode = false
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        Logger.firebase(
            "用戶取消重新設定目標",
            level: .info,
            labels: [
                "module": "OnboardingView",
                "action": "exit_reonboarding"
            ]
        )

        // dismiss 會觸發 ContentView 切換回主畫面
        dismiss()
    }

    /// 根據訓練週數判斷導航目標
    private func handleNavigationAfterTargetCreation() {
        let standardWeeks = TrainingPlanCalculator.getStandardTrainingWeeks(
            for: Double(viewModel.selectedDistance) ?? 42.195
        )
        let trainingWeeks = viewModel.trainingWeeks

        print("[OnboardingView] 🧭 Navigation Decision: trainingWeeks=\(trainingWeeks), standardWeeks=\(standardWeeks)")

        if trainingWeeks < 2 {
            // 時間過短（<2週），顯示警告
            print("[OnboardingView] ⚠️ Too short, showing warning")
            showTimeWarning = true
        } else if trainingWeeks >= standardWeeks {
            // 時間充足，直接進入心率設定步驟
            print("[OnboardingView] ✅ Enough time, skipping stage selection (using default base stage)")
            viewModel.selectedStartStage = nil // 使用預設（從基礎期開始）
            UserDefaults.standard.removeObject(forKey: "selectedStartStage") // 清除舊值
            showHeartRateSetup = true
        } else {
            // 時間緊張（2-12週），進入階段選擇頁面
            print("[OnboardingView] 🎯 Time constraint detected, showing stage selection")
            showStageSelection = true
        }
    }

}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        // 若要在預覽中測試，需要包裝在 NavigationView 中
        NavigationView {
            OnboardingView()
        }
    }
}
