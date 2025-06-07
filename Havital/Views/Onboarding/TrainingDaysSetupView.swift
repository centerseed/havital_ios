import SwiftUI

@MainActor
class TrainingDaysViewModel: ObservableObject {
    @Published var selectedWeekdays = Set<Int>()
    @Published var selectedLongRunDay: Int = 6 // 預設週六 (1=週一, 7=週日)
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
        // 至少選擇 recommendedMinTrainingDays 且長跑日不在普通訓練日中（如果普通訓練日已選）
        // 或者如果只選了長跑日，也可以
        let hasEnoughDays = selectedWeekdays.count >= recommendedMinTrainingDays
        let isLongRunDayValid = !selectedWeekdays.contains(selectedLongRunDay) || selectedWeekdays.isEmpty 
                                // ^ 如果選了普通訓練日，長跑日不能衝突；如果沒選普通日，長跑日單獨有效

        // 初始按鈕：用於獲取概覽
        // 條件：已選擇足夠的訓練日 (或至少一個長跑日)，且概覽尚未顯示，且最終計畫按鈕也未顯示
        canShowPlanOverviewButton = (hasEnoughDays || selectedWeekdays.count + (selectedLongRunDay > 0 ? 1 : 0) >= 1) && isLongRunDayValid && !showOverview && !canGenerateFinalPlanButton
    }


    func savePreferencesAndGetOverview() async { // 原 savePreferences
        guard !selectedWeekdays.isEmpty || selectedLongRunDay > 0 else {
            error = "請至少選擇一個訓練日或長跑日。"
            return
        }
        if selectedWeekdays.count > 0 && selectedWeekdays.contains(selectedLongRunDay) {
            error = "長跑日不應與普通訓練日重疊。請重新選擇。"
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
        
        do {
            let _ = try await TrainingPlanService.shared.createWeeklyPlan() // API 回傳的 plan 暫存到 weeklyPlan
            // weeklyPlan = plan // 如果需要，可以儲存起來
            
            authService.hasCompletedOnboarding = true // 標記 Onboarding 完成
            // UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding") // authService 內部應處理持久化
            
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
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
    @Environment(\.dismiss) private var dismiss
    
    // For loading animation after final plan generation
    @State private var showLoadingAnimationForFinalPlan = false
    private let loadingMessages = [
        "分析您的訓練偏好...",
        "計算最佳訓練強度...",
        "為您準備專屬課表..."
    ]
    private let loadingDuration: Double = 3 // 調整載入動畫持續時間
    
    var body: some View {
        ScrollViewReader { proxy in
            Form {
                Section(
                    header: Text("選擇您方便的訓練日"),
                    footer: Text("請選擇您一週內通常可以安排跑步訓練的日子。Havital 會根據您的目標和體能狀況，在這些日子裡安排不同類型的跑步課表。建議至少選擇 \(viewModel.recommendedMinTrainingDays) 天。")
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
                    footer: Text("長跑是提升耐力的關鍵。通常建議安排在週末或您有較充裕時間的日子，以便身體有足夠時間恢復。請選擇一天作為您的主要長跑日。")
                ) {
                    Picker("選擇長跑日", selection: $viewModel.selectedLongRunDay) {
                        ForEach(1..<8, id: \.self) { weekday in
                            Text(getWeekdayName(weekday)).tag(weekday)
                        }
                    }
                    .onChange(of: viewModel.selectedLongRunDay) { _ in
                        viewModel.updateButtonStates()
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
                        .padding(.vertical, 5)
                    }
                    .id("overviewSection") // ID for scrolling

                    if viewModel.canGenerateFinalPlanButton {
                        Section {
                            Button(action: {
                                showLoadingAnimationForFinalPlan = true // 觸發全螢幕載入動畫
                                Task {
                                    await viewModel.generateFinalPlanAndCompleteOnboarding()
                                    // 動畫由 loadingAnimation 修飾器自動處理關閉
                                }
                            }) {
                                HStack {
                                    Spacer()
                                    // 這個按鈕的 loading 由全螢幕動畫處理，故此處不放 ProgressView
                                    Text("完成設定並查看第一週課表")
                                    Spacer()
                                }
                            }
                            // 此按鈕的 isLoading 由 showLoadingAnimationForFinalPlan 控制
                            .disabled(showLoadingAnimationForFinalPlan)
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
                    Button("返回") { dismiss() }
                }
            }
            // 全螢幕載入動畫，僅在產生最終計畫時顯示
            .loadingAnimation(
                isLoading: $showLoadingAnimationForFinalPlan,
                messages: loadingMessages,
                totalDuration: loadingDuration
            )
        } // ScrollViewReader End
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
