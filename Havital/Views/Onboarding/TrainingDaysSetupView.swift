import SwiftUI

@MainActor
class TrainingDaysViewModel: ObservableObject {
    @Published var selectedWeekdays = Set<Int>()
    @Published var selectedLongRunDay: Int = 6 // 預設週六 (1=週一, 7=週日)
    @Published var showLongRunDayAlert = false // 用於控制是否顯示長跑日提示
    @Published var isLoading = false
    @Published var error: String?
    @Published var trainingPlanOverview: TrainingPlanOverview?
    @Published var weeklyPlan: WeeklyPlan? // 儲存產生的週計畫 (目前似乎未直接在 UI 使用)
    @Published var isLoadingUserData = false // 加載用戶數據中

    // 導航狀態
    @Published var navigateToPreview = false // 導航到預覽頁面
    @Published var navigateToTrainingOverview = false // 導航到最終訓練總覽頁面

    private let userPreferenceManager = UserPreferencesManager.shared
    private let authService = AuthenticationService.shared

    let recommendedMinTrainingDays = 2 // 最小建議訓練天數

    // 是否為新手 5km 計劃
    let isBeginner: Bool

    init(isBeginner: Bool = false) {
        self.isBeginner = isBeginner
    }

    /// 從用戶當前設置中加載訓練日偏好
    func loadUserTrainingDayPreferences() async {
        isLoadingUserData = true
        do {
            let user = try await UserService.shared.getUserProfileAsync()

            // 從用戶數據中提取訓練日
            if let weekdayPreferences = user.preferWeekDays, !weekdayPreferences.isEmpty {
                await MainActor.run {
                    self.selectedWeekdays = Set(weekdayPreferences)
                    print("[TrainingDaysViewModel] 成功加載訓練日: \(weekdayPreferences)")
                }
            }

            // 從用戶數據中提取長跑日
            if let longrunDayPreferences = user.preferWeekDaysLongrun,
               let longrunDay = longrunDayPreferences.first {
                await MainActor.run {
                    self.selectedLongRunDay = longrunDay
                    print("[TrainingDaysViewModel] 成功加載長跑日: \(longrunDay)")
                }
            } else if !self.selectedWeekdays.isEmpty {
                // 如果沒有長跑日但有訓練日，預設週六或第一個訓練日
                await MainActor.run {
                    if self.selectedWeekdays.contains(6) {
                        self.selectedLongRunDay = 6
                    } else if let first = self.selectedWeekdays.sorted().first {
                        self.selectedLongRunDay = first
                    }
                }
            }
        } catch {
            print("[TrainingDaysViewModel] 加載用戶訓練日偏好失敗: \(error.localizedDescription)")
            // 失敗時使用預設值，不顯示錯誤
        }
        isLoadingUserData = false
    }

    var canSavePreferences: Bool {
        // 至少選擇 recommendedMinTrainingDays
        let hasEnoughDays = selectedWeekdays.count >= recommendedMinTrainingDays

        // 長跑日必須是選擇的訓練日之一
        let isLongRunDayValid = selectedWeekdays.contains(selectedLongRunDay) || selectedWeekdays.isEmpty

        return hasEnoughDays && isLongRunDayValid
    }


    func savePreferencesAndGetOverview() async { // 原 savePreferences
        guard !selectedWeekdays.isEmpty else {
            error = NSLocalizedString("onboarding.select_at_least_one_day", comment: "Select at least one day")
            return
        }

        // 確保長跑日是選擇的訓練日之一
        if !selectedWeekdays.contains(selectedLongRunDay) {
            error = NSLocalizedString("onboarding.long_run_day_must_be_training_day", comment: "Long run day must be training day")
            return
        }

        isLoading = true
        error = nil

        await TrackedTask("TrainingDaysSetupView: savePreferencesAndGetOverview") {
            do {
                let apiWeekdays = self.selectedWeekdays.map { $0 } // 假設 weekday 1-7 對應 API
                let apiLongRunDay = self.selectedLongRunDay

                let preferences = [
                    "prefer_week_days": apiWeekdays,
                    "prefer_week_days_longrun": [apiLongRunDay] // API 預期是陣列
                ] as [String : Any]

                try await UserService.shared.updateUserData(preferences)

            // 讀取用戶選擇的起始階段（如果有的話）
            let selectedStage = UserDefaults.standard.string(forKey: "selectedStartStage")
            print("[TrainingDaysViewModel] 🔍 selectedStartStage from UserDefaults: \(selectedStage ?? "nil")")
            print("[TrainingDaysViewModel] 🔍 isBeginner: \(self.isBeginner)")

                let overview = try await TrainingPlanService.shared.postTrainingPlanOverview(
                    startFromStage: selectedStage,
                    isBeginner: self.isBeginner
                )
                self.trainingPlanOverview = overview

                // ✅ 方案 1: 同步兩個緩存系統
                // 1. 更新 TrainingPlanStorage (UserDefaults)
                TrainingPlanStorage.saveTrainingPlanOverview(overview)

                // 2. 同步更新 TrainingPlanManager 的緩存
                await TrainingPlanManager.shared.updateTrainingOverviewCache(overview)

                // 儲存 userPreferenceManager
                let weekdaysDisplay = self.selectedWeekdays.map { self.getWeekdayNameStatic($0) }
                self.userPreferenceManager.preferWeekDays = weekdaysDisplay
                self.userPreferenceManager.preferWeekDaysLongRun = [self.getWeekdayNameStatic(self.selectedLongRunDay)]

                // 導航到預覽頁面
                OnboardingCoordinator.shared.trainingPlanOverview = overview
                OnboardingCoordinator.shared.navigate(to: .trainingOverview)

            } catch {
                self.error = error.localizedDescription
            }
            self.isLoading = false
        }.value
    }
    
    // 這個函數已被移除，因為週課表應該在 TrainingOverviewView 中由用戶確認後才產生
    // Overview 已經在 savePreferencesAndGetOverview() 中產生了

    // Helper for init and saving preferences
    private func getWeekdayNameStatic(_ weekday: Int) -> String {
        switch weekday {
        case 1: return NSLocalizedString("onboarding.monday", comment: "Monday")
        case 2: return NSLocalizedString("onboarding.tuesday", comment: "Tuesday") 
        case 3: return NSLocalizedString("onboarding.wednesday", comment: "Wednesday")
        case 4: return NSLocalizedString("onboarding.thursday", comment: "Thursday")
        case 5: return NSLocalizedString("onboarding.friday", comment: "Friday")
        case 6: return NSLocalizedString("onboarding.saturday", comment: "Saturday")
        case 7: return NSLocalizedString("onboarding.sunday", comment: "Sunday")
        default: return ""
        }
    }
}

struct TrainingDaysSetupView: View {
    @StateObject private var viewModel: TrainingDaysViewModel
    @ObservedObject private var authService = AuthenticationService.shared
    @ObservedObject private var coordinator = OnboardingCoordinator.shared

    init(isBeginner: Bool = false) {
        _viewModel = StateObject(wrappedValue: TrainingDaysViewModel(isBeginner: isBeginner))
    }

    // 檢查是否為新手 5km 計劃
    private var isBeginner5kPlan: Bool {
        viewModel.isBeginner
    }

    // For loading animation after final plan generation
    private let loadingMessages = [
        "正在分析您的訓練偏好...",
        "計算最佳訓練強度中...",
        "就要完成了！正在為您準備專屬課表..."
    ]
    private let loadingDuration: Double = 20 // 調整載入動畫持續時間
    
    // 新增：用於預覽計劃的載入消息
    private let previewLoadingMessages = [
        "正在評估您的目標賽事",
        "正在計算訓練強度",
        "產生訓練概覽中"
    ]
    private let previewLoadingDuration: Double = 15 // 預覽載入動畫持續時間
    
    var body: some View {
        ScrollViewReader { proxy in
            Form {
                Section(
                    header: Text(NSLocalizedString("onboarding.select_training_days", comment: "Select Training Days")),
                    footer: Text(String(format: NSLocalizedString("onboarding.training_days_description", comment: "Training Days Description"), viewModel.recommendedMinTrainingDays))
                ) {
                    ForEach(1..<8, id: \.self) { weekday in // 週一到週日
                        Button(action: {
                            if viewModel.selectedWeekdays.contains(weekday) {
                                viewModel.selectedWeekdays.remove(weekday)
                            } else {
                                viewModel.selectedWeekdays.insert(weekday)
                            }
                        }) {
                            HStack {
                                Text(getWeekdayName(weekday))
                                Spacer()
                                if viewModel.selectedWeekdays.contains(weekday) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                
                Section(
                    header: Text(isBeginner5kPlan ? NSLocalizedString("onboarding.setup_long_run_day_beginner", comment: "選擇一個能跑比較多一點點的日期") : NSLocalizedString("onboarding.setup_long_run_day", comment: "選擇一天長跑日")),
                    footer: Text(isBeginner5kPlan ? NSLocalizedString("onboarding.long_run_day_description_beginner", comment: "這天會安排稍微長一點的距離，讓身體慢慢適應") : NSLocalizedString("onboarding.long_run_day_description", comment: "每週會有一天進行長距離訓練"))
                ) {
                    // 只有在有選擇訓練日時，提供長跑日選項
                    let longRunOptions = viewModel.selectedWeekdays.isEmpty ? [6] : Array(viewModel.selectedWeekdays).sorted()
                    Picker(NSLocalizedString("onboarding.select_long_run_day", comment: "Select Long Run Day"), selection: $viewModel.selectedLongRunDay) {
                        ForEach(longRunOptions, id: \.self) { weekday in
                            Text(getWeekdayName(weekday)).tag(weekday)
                        }
                    }
                    .disabled(viewModel.selectedWeekdays.isEmpty) // 尚未選擇訓練日時禁用
                    .onAppear {
                        // 預設選擇週六（6）作為長跑日
                        if viewModel.selectedWeekdays.contains(6) {
                            viewModel.selectedLongRunDay = 6
                        } else if let first = viewModel.selectedWeekdays.sorted().first {
                            viewModel.selectedLongRunDay = first
                        }
                    }
                    .onChange(of: viewModel.selectedWeekdays) { newWeekdays in
                        // 如果週六在選擇的訓練日中，則設為長跑日
                        if newWeekdays.contains(6) {
                            viewModel.selectedLongRunDay = 6
                        } 
                        // 如果當前長跑日不在新選擇的訓練日中，則選擇第一個訓練日
                        else if !newWeekdays.contains(viewModel.selectedLongRunDay), let first = newWeekdays.sorted().first {
                            viewModel.selectedLongRunDay = first
                        }
                    }
                    // 如果長跑日不在已選的訓練日中，顯示提示
                    if !viewModel.selectedWeekdays.contains(viewModel.selectedLongRunDay) {
                        Text(NSLocalizedString("onboarding.long_run_day_must_be_training_day", comment: "Long run day must be training day")).foregroundColor(.red)
                    } else if !viewModel.selectedWeekdays.contains(6) {
                        Text(NSLocalizedString("onboarding.suggest_saturday_long_run", comment: "Suggest Saturday long run")).foregroundColor(.orange)
                    }
                }              
                if let error = viewModel.error {
                    Section {
                        Text(error).foregroundColor(.red)
                    }
                }
                
                // --- 按鈕區域 ---
                Section {
                    Button(action: {
                        Task {
                            await viewModel.savePreferencesAndGetOverview()
                        }
                    }) {
                        HStack {
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text(NSLocalizedString("onboarding.save_preferences_preview", comment: "Save Preferences Preview"))
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isLoading || !viewModel.canSavePreferences)
                    .buttonStyle(PlainButtonStyle())
                }
            } // Form End
            .navigationTitle(NSLocalizedString("onboarding.training_days_title", comment: "Training Days Title"))
            .navigationBarTitleDisplayMode(.inline)
        } // ScrollViewReader End
        .fullScreenCover(isPresented: $viewModel.isLoading) {
            LoadingAnimationView(messages: [
                NSLocalizedString("onboarding.evaluating_goal", comment: "Evaluating Goal"),
                NSLocalizedString("onboarding.calculating_training_intensity", comment: "Calculating Training Intensity"),
                NSLocalizedString("onboarding.generating_overview", comment: "Generating Overview")
            ], totalDuration: previewLoadingDuration)
        }
        .background(EmptyView())
        .task {
            // 在視圖出現時加載用戶已有的訓練日設置
            await viewModel.loadUserTrainingDayPreferences()
        }
        .onChange(of: authService.hasCompletedOnboarding) { oldValue, newValue in
            // 當 onboarding 完成時，自動關閉 NavigationLink
            if newValue {
                viewModel.navigateToPreview = false
                viewModel.navigateToTrainingOverview = false
                print("[TrainingDaysSetupView] 偵測到 onboarding 完成，關閉 NavigationLink")
            }
        }
    }

    private func getWeekdayName(_ weekday: Int) -> String {
        switch weekday {
        case 1: return NSLocalizedString("onboarding.monday", comment: "Monday")
        case 2: return NSLocalizedString("onboarding.tuesday", comment: "Tuesday") 
        case 3: return NSLocalizedString("onboarding.wednesday", comment: "Wednesday")
        case 4: return NSLocalizedString("onboarding.thursday", comment: "Thursday")
        case 5: return NSLocalizedString("onboarding.friday", comment: "Friday")
        case 6: return NSLocalizedString("onboarding.saturday", comment: "Saturday")
        case 7: return NSLocalizedString("onboarding.sunday", comment: "Sunday")
        default: return ""
        }
    }
}

struct TrainingDaysSetupView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TrainingDaysSetupView()
        }
    }
}
