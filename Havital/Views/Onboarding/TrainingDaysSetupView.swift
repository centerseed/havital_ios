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

    // 導航狀態
    @Published var navigateToPreview = false // 導航到預覽頁面
    @Published var navigateToTrainingOverview = false // 導航到最終訓練總覽頁面

    private let userPreferenceManager = UserPreferenceManager.shared
    private let authService = AuthenticationService.shared
    
    let recommendedMinTrainingDays = 2 // 最小建議訓練天數

    init() {
        // 初始化
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

                let overview = try await TrainingPlanService.shared.postTrainingPlanOverview(startFromStage: selectedStage)
                self.trainingPlanOverview = overview

                TrainingPlanStorage.saveTrainingPlanOverview(overview)

                // 儲存 userPreferenceManager
                let weekdaysDisplay = self.selectedWeekdays.map { self.getWeekdayNameStatic($0) }
                self.userPreferenceManager.preferWeekDays = weekdaysDisplay
                self.userPreferenceManager.preferWeekDaysLongRun = [self.getWeekdayNameStatic(self.selectedLongRunDay)]

                // 導航到預覽頁面
                self.navigateToPreview = true

            } catch {
                self.error = error.localizedDescription
            }
            self.isLoading = false
        }.value
    }
    
    func generateFinalPlanAndCompleteOnboarding() async { // 原 generateWeeklyPlan
        isLoading = true
        error = nil
        var planSuccessfullyCreated = false

        do {
            print("[TrainingDaysViewModel] Attempting to create weekly plan...") // 新增日誌

            // 讀取用戶選擇的起始階段（如果有的話）
            let selectedStage = UserDefaults.standard.string(forKey: "selectedStartStage")
            if let stage = selectedStage {
                print("[TrainingDaysViewModel] Creating plan with start stage: \(stage)")
            }

            let _ = try await TrainingPlanService.shared.createWeeklyPlan(startFromStage: selectedStage)
            print("[TrainingDaysViewModel] Weekly plan created successfully.") // 新增日誌
            planSuccessfullyCreated = true

            // 清除已使用的階段選擇
            UserDefaults.standard.removeObject(forKey: "selectedStartStage")

            print("[TrainingDaysViewModel] 新流程：導航到 TrainingOverviewView")

        } catch {
            // 特別處理任務取消錯誤，但也記錄其他錯誤
            if (error as NSError).code != NSURLErrorCancelled {
                print("[TrainingDaysViewModel] Error generating weekly plan: \(error) - Localized: \(error.localizedDescription)") // 詳細錯誤日誌
                self.error = "產生課表失敗：\(error.localizedDescription)"
            }
        }

        // 確保 isLoading 在所有情況下都會被重置
        isLoading = false

        if planSuccessfullyCreated {
            // 新流程：導航到 TrainingOverviewView 而不是直接完成 onboarding
            print("[TrainingDaysViewModel] 導航到訓練總覽頁面")
            navigateToTrainingOverview = true
        }
    }

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
    @StateObject private var viewModel = TrainingDaysViewModel()
    @Environment(\.dismiss) private var dismiss

    // 檢查是否為新手 5km 計劃
    private var isBeginner5kPlan: Bool {
        UserDefaults.standard.bool(forKey: "onboarding_isBeginner5kPlan")
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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("common.back", comment: "Back")) {
                        dismiss()
                    }
                }
            }
        } // ScrollViewReader End
        .fullScreenCover(isPresented: $viewModel.isLoading) {
            LoadingAnimationView(messages: [
                NSLocalizedString("onboarding.evaluating_goal", comment: "Evaluating Goal"),
                NSLocalizedString("onboarding.calculating_training_intensity", comment: "Calculating Training Intensity"),
                NSLocalizedString("onboarding.generating_overview", comment: "Generating Overview")
            ], totalDuration: previewLoadingDuration)
        }
        .background(
            Group {
                // 導航到預覽頁面
                NavigationLink(
                    destination: TrainingOverviewView(mode: .preview, trainingOverview: viewModel.trainingPlanOverview)
                        .navigationBarBackButtonHidden(true),
                    isActive: $viewModel.navigateToPreview
                ) {
                    EmptyView()
                }

                // 導航到最終訓練總覽頁面
                NavigationLink(
                    destination: TrainingOverviewView(mode: .final)
                        .navigationBarBackButtonHidden(true),
                    isActive: $viewModel.navigateToTrainingOverview
                ) {
                    EmptyView()
                }
            }
        )
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
