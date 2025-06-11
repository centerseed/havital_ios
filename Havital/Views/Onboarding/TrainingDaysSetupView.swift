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
            error = "請至少選擇一個訓練日。"
            return
        }
        
        // 確保長跑日是選擇的訓練日之一
        if !selectedWeekdays.contains(selectedLongRunDay) {
            error = "長跑日必須是您選擇的訓練日之一。請重新選擇。"
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
            let _ = try await TrainingPlanService.shared.createWeeklyPlan()
            print("[TrainingDaysViewModel] Weekly plan created successfully.") // 新增日誌
            planSuccessfullyCreated = true
            
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
        case 1: return "週一"; case 2: return "週二"; case 3: return "週三";
        case 4: return "週四"; case 5: return "週五"; case 6: return "週六";
        case 7: return "週日"; default: return ""
        }
    }
}

struct TrainingDaysSetupView: View {
    @StateObject private var viewModel = TrainingDaysViewModel()

    
    // For loading animation after final plan generation
    private let loadingMessages = [
        "正在分析您的訓練偏好...",
        "計算最佳訓練強度中...",
        "就要完成了！正在為您準備專屬課表..."
    ]
    private let loadingDuration: Double = 20 // 調整載入動畫持續時間
    
    var body: some View {
        ScrollViewReader { proxy in
            Form {
                Section(
                    header: Text("選擇您方便的訓練日"),
                    footer: Text("請選擇您一週內通常可以安排跑步訓練的日子。Paceriz會根據您的目標和體能狀況，在這些日子裡安排不同類型的跑步課表。建議至少選擇 \(viewModel.recommendedMinTrainingDays) 天。")
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
                    header: Text("設定您的長跑日"),
                    footer: Text("長跑是提升耐力的關鍵。請從您選擇的訓練日中挑選一天作為長跑日。通常建議安排在週末或您有較充裕時間的日子，以便身體有足夠時間恢復。")
                ) {
                    // 只有在有選擇訓練日時，提供長跑日選項
                    let longRunOptions = viewModel.selectedWeekdays.isEmpty ? [6] : Array(viewModel.selectedWeekdays).sorted()
                    Picker("選擇長跑日", selection: $viewModel.selectedLongRunDay) {
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
                        Text("長跑日必須是您選擇的訓練日之一").foregroundColor(.red)
                    } else if !viewModel.selectedWeekdays.contains(6) && !viewModel.showOverview {
                        Text("建議將週六設為長跑日，以便有充分時間進行長距離訓練。").foregroundColor(.orange)
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
                                if viewModel.showOverview { // 滾動到概覽
                                    withAnimation { proxy.scrollTo("overviewSection", anchor: .bottom) }
                                }
                            }
                        }) {
                            HStack {
                                Spacer()
                                if viewModel.isLoading && !viewModel.showOverview { // Loading for overview
                                    ProgressView()
                                } else {
                                    Text("儲存偏好並預覽計畫")
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
                                    Text("完成設定並查看第一週課表")
                                    Spacer()
                                }
                            }
                            .disabled(viewModel.isLoading)
                        }
                    }
                }
            } // Form End
            .onAppear {
                viewModel.updateButtonStates() // 初始檢查按鈕狀態
            }
            .navigationTitle("訓練偏好設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") { }
                }
            }
        } // ScrollViewReader End
        .fullScreenCover(isPresented: Binding(
            get: { viewModel.isLoading && viewModel.showOverview },
            set: { _ in }
        )) {
            LoadingAnimationView(messages: loadingMessages, totalDuration: loadingDuration)
        }
    }
    
    private func getWeekdayName(_ weekday: Int) -> String { // 保持 View 內的 helper
        switch weekday {
        case 1: return "週一"; case 2: return "週二"; case 3: return "週三";
        case 4: return "週四"; case 5: return "週五"; case 6: return "週六";
        case 7: return "週日"; default: return ""
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
