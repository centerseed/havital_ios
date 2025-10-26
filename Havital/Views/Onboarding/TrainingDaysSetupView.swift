import SwiftUI

@MainActor
class TrainingDaysViewModel: ObservableObject {
    @Published var selectedWeekdays = Set<Int>()
    @Published var selectedLongRunDay: Int = 6 // 預設週六 (1=週一, 7=週日)
    @Published var showLongRunDayAlert = false // 用於控制是否顯示長跑日提示
    @Published var isLoading = false
    @Published var error: String?
    @Published var trainingPlanOverview: TrainingPlanOverview?
    @Published var showOverview = false // 是否顯示計畫概覽
    @Published var weeklyPlan: WeeklyPlan? // 儲存產生的週計畫 (目前似乎未直接在 UI 使用)
    
    // 控制按鈕顯示的狀態
    @Published var canShowPlanOverviewButton = false // 是否可以顯示「儲存偏好並預覽計畫」按鈕
    @Published var canGenerateFinalPlanButton = false // 是否可以顯示「完成並查看第一週課表」按鈕

    private let userPreferenceManager = UserPreferenceManager.shared
    private let authService = AuthenticationService.shared
    
    let recommendedMinTrainingDays = 2 // 最小建議訓練天數

    init() {
        // 當 selectedWeekdays 或 selectedLongRunDay 改變時，更新按鈕狀態
        // 這裡使用 combine 會更優雅，但為了簡化，我們先在 action 中手動更新
        // 或者在 onAppear 和按鈕 action 中檢查
        updateButtonStates()
    }

    func updateButtonStates() {
        // 至少選擇 recommendedMinTrainingDays
        let hasEnoughDays = selectedWeekdays.count >= recommendedMinTrainingDays
        
        // 長跑日必須是選擇的訓練日之一
        let isLongRunDayValid = selectedWeekdays.contains(selectedLongRunDay) || selectedWeekdays.isEmpty
        
        // 初始按鈕：用於獲取概覽
        // 條件：已選擇足夠的訓練日，且長跑日是訓練日之一，且概覽尚未顯示，且最終計畫按鈕也未顯示
        canShowPlanOverviewButton = hasEnoughDays && isLongRunDayValid && !showOverview && !canGenerateFinalPlanButton
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
        
        do {
            let apiWeekdays = selectedWeekdays.map { $0 } // 假設 weekday 1-7 對應 API
            let apiLongRunDay = selectedLongRunDay
            
            let preferences = [
                "prefer_week_days": apiWeekdays,
                "prefer_week_days_longrun": [apiLongRunDay] // API 預期是陣列
            ] as [String : Any]
            
            try await UserService.shared.updateUserData(preferences)
            
            let overview = try await TrainingPlanService.shared.postTrainingPlanOverview()
            trainingPlanOverview = overview
            
            TrainingPlanStorage.saveTrainingPlanOverview(overview)
            
            showOverview = true // 顯示概覽
            canShowPlanOverviewButton = false // 隱藏「預覽」按鈕
            canGenerateFinalPlanButton = true // 顯示「產生最終計畫」按鈕
            
            // ... (儲存 userPreferenceManager 部分不變)
            let weekdaysDisplay = selectedWeekdays.map { getWeekdayNameStatic($0) }
            userPreferenceManager.preferWeekDays = weekdaysDisplay
            userPreferenceManager.preferWeekDaysLongRun = [getWeekdayNameStatic(selectedLongRunDay)]

        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
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
            
            // 直接更新 UserDefaults 中的 hasCompletedOnboarding 值
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            print("[TrainingDaysViewModel] Updated hasCompletedOnboarding in UserDefaults to true")
            
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
            // 只有成功才標記完成並觸發導航
            print("[TrainingDaysViewModel] Setting hasCompletedOnboarding to true.")
            authService.hasCompletedOnboarding = true
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
                            viewModel.updateButtonStates() // 更新按鈕狀態
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
                    header: Text(NSLocalizedString("onboarding.setup_long_run_day", comment: "Setup Long Run Day")),
                    footer: Text(NSLocalizedString("onboarding.long_run_day_description", comment: "Long Run Day Description"))
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
                        viewModel.updateButtonStates()
                    }
                    .onChange(of: viewModel.selectedLongRunDay) { _ in
                        viewModel.updateButtonStates()
                    }
                    // 如果長跑日不在已選的訓練日中，顯示提示
                    if !viewModel.selectedWeekdays.contains(viewModel.selectedLongRunDay) {
                        Text(NSLocalizedString("onboarding.long_run_day_must_be_training_day", comment: "Long run day must be training day")).foregroundColor(.red)
                    } else if !viewModel.selectedWeekdays.contains(6) && !viewModel.showOverview {
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
                    if viewModel.canShowPlanOverviewButton {
                        Button(action: {
                            Task {
                                await viewModel.savePreferencesAndGetOverview()
                            }
                        }) {
                            HStack {
                                Spacer()
                                if viewModel.isLoading && !viewModel.showOverview { // Loading for overview
                                    ProgressView()
                                } else {
                                    Text(NSLocalizedString("onboarding.save_preferences_preview", comment: "Save Preferences Preview"))
                                }
                                Spacer()
                            }
                        }
                        .disabled(viewModel.isLoading && !viewModel.showOverview)
                    }
                }

                if viewModel.showOverview, let overview = viewModel.trainingPlanOverview {
                    Section(header: Text("您的訓練計畫預覽").padding(.top, 10)) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("目標評估").font(.headline)
                            Text(overview.targetEvaluate).font(.body).foregroundColor(.secondary)

                            Text("訓練重點").font(.headline).padding(.top, 5)
                            Text(overview.trainingHighlight).font(.body).foregroundColor(.secondary)
                        }
                        if viewModel.canGenerateFinalPlanButton {
                            Button(action: {
                                Task {
                                    await viewModel.generateFinalPlanAndCompleteOnboarding()
                                }
                            }) {
                                HStack {
                                    Spacer()
                                    Text(NSLocalizedString("onboarding.complete_setup_view_schedule", comment: "Complete Setup View Schedule"))
                                    Spacer()
                                }
                            }
                            .disabled(viewModel.isLoading)
                            .id("finalPlanButton")
                        }
                    }
                    .id("overviewSection")
                }
            } // Form End
            .onAppear {
                viewModel.updateButtonStates() // 初始檢查按鈕狀態
            }
            .onChange(of: viewModel.showOverview) { showOverview in
                if showOverview {
                    // 延遲一點點時間，確保 UI 已經渲染完成
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            proxy.scrollTo("finalPlanButton", anchor: .center)
                        }
                    }
                }
            }
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
        .fullScreenCover(isPresented: Binding(
            get: { viewModel.isLoading && !viewModel.showOverview },
            set: { _ in }
        )) {
            LoadingAnimationView(messages: [
                NSLocalizedString("onboarding.evaluating_goal", comment: "Evaluating Goal"),
                NSLocalizedString("onboarding.calculating_training_intensity", comment: "Calculating Training Intensity"),
                NSLocalizedString("onboarding.generating_overview", comment: "Generating Overview")
            ], totalDuration: previewLoadingDuration)
        }
        .fullScreenCover(isPresented: Binding(
            get: { viewModel.isLoading && viewModel.showOverview },
            set: { _ in }
        )) {
            LoadingAnimationView(messages: [
                NSLocalizedString("onboarding.analyzing_preferences", comment: "Analyzing Preferences"),
                NSLocalizedString("onboarding.calculating_intensity", comment: "Calculating Intensity"),
                NSLocalizedString("onboarding.almost_ready", comment: "Almost Ready")
            ], totalDuration: loadingDuration)
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
