import SwiftUI

@MainActor
class TrainingDaysViewModel: ObservableObject {
    @Published var selectedWeekdays = Set<Int>()
    @Published var selectedLongRunDay: Int = 6 // 預設週六
    @Published var isLoading = false
    @Published var error: String?
    @Published var navigateToMainView = false
    @Published var trainingPlanOverview: TrainingPlanOverview?
    @Published var showOverview = false
    @Published var canGenerateWeeklyPlan = false
    @Published var weeklyPlan: WeeklyPlan?
    
    private let userPreferenceManager = UserPreferenceManager.shared
    private let authService = AuthenticationService.shared
    
    // 建議的訓練天數
    let recommendedTrainingDays = 2
    
    func generateWeeklyPlan() async {
        isLoading = true
        error = nil
        
        do {
            print("開始呼叫 API")
            let plan = try await TrainingPlanService.shared.createWeeklyPlan()
            print("成功獲取週計劃")
            weeklyPlan = plan
            
            // 更新登入服務的 onboarding 狀態
            authService.hasCompletedOnboarding = true
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            
            navigateToMainView = true
        } catch {
            print("產生週計劃錯誤: \(error)")
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func savePreferences() async {
        isLoading = true
        error = nil
        
        do {
            // 轉換為 API 格式（星期一為 1，星期日為 7）
            let apiWeekdays = selectedWeekdays.map { $0 }
            
            let apiLongRunDay = selectedLongRunDay
            
            // 更新訓練日
            let preferences = [
                "prefer_week_days": apiWeekdays,
                "prefer_week_days_longrun": [apiLongRunDay]
            ] as [String : Any]
            
            try await UserService.shared.updateUserData(preferences)
            
            // 獲取訓練計畫概覽
            let overview = try await TrainingPlanService.shared.getTrainingPlanOverview()
            trainingPlanOverview = overview
            
            // 儲存概覽
            TrainingPlanStorage.saveTrainingPlanOverview(overview)
            
            // 顯示概覽並啟用生成按鈕
            showOverview = true
            canGenerateWeeklyPlan = true
            
            // 將訓練日轉換為中文儲存
            let weekdays = selectedWeekdays.map { weekday in
                switch weekday {
                case 1: return "週一"
                case 2: return "週二"
                case 3: return "週三"
                case 4: return "週四"
                case 5: return "週五"
                case 6: return "週六"
                case 7: return "週日"
                default: return ""
                }
            }
            
            let longRunDay = switch selectedLongRunDay {
            case 1: "週一"
            case 2: "週二"
            case 3: "週三"
            case 4: "週四"
            case 5: "週五"
            case 6: "週六"
            case 7: "週日"
            default: "週六"
            }
            
            userPreferenceManager.preferWeekDays = weekdays
            userPreferenceManager.preferWeekDaysLongRun = [longRunDay]
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
}

struct TrainingDaysSetupView: View {
    @StateObject private var viewModel = TrainingDaysViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showAlert = false
    @State private var showGenerateButton = false
    
    var body: some View {
        Form {
            Section(header: Text("選擇適合的訓練日")) {
                ForEach(1..<8) { weekday in
                    let isSelected = viewModel.selectedWeekdays.contains(weekday)
                    Button(action: {
                        if isSelected {
                            viewModel.selectedWeekdays.remove(weekday)
                        } else {
                            viewModel.selectedWeekdays.insert(weekday)
                        }
                    }) {
                        HStack {
                            Text(getWeekdayName(weekday))
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            
            Section(header: Text("長跑日（建議安排在週末）").padding(.top, 10)) {
                Text("長跑是訓練中最重要的一天，建議安排在週末，以確保有足夠的休息時間")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 5)
                
                Picker("長跑日", selection: $viewModel.selectedLongRunDay) {
                    ForEach(1..<8) { weekday in
                        Text(getWeekdayName(weekday))
                            .tag(weekday)
                    }
                }
            }
            
            if let error = viewModel.error {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
            
            if viewModel.showOverview, let overview = viewModel.trainingPlanOverview {
                Section(header: Text("訓練計畫概覽").padding(.top, 10)) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("目標評估")
                            .font(.headline)
                        Text(overview.targetEvaluate)
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Text("訓練重點")
                            .font(.headline)
                            .padding(.top, 5)
                        Text(overview.trainingHighlight)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 5)
                    
                    if viewModel.canGenerateWeeklyPlan {
                        Button(action: {
                            Task {
                                print("開始產生週計劃")
                                await viewModel.generateWeeklyPlan()
                            }
                        }) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("產生一週課表")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 10)
                        .disabled(viewModel.isLoading)
                    }
                }
            }
        }
        .navigationTitle("設定訓練日")
        .navigationBarTitleDisplayMode(.inline)
        .alert("提示", isPresented: $showAlert) {
            Button("確定") {}
        } message: {
            Text("請至少選擇 \(viewModel.recommendedTrainingDays) 天訓練日")
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    if viewModel.selectedWeekdays.count >= viewModel.recommendedTrainingDays {
                        Task {
                            await viewModel.savePreferences()
                        }
                    } else {
                        showAlert = true
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Text("完成")
                    }
                }
                .disabled(viewModel.selectedWeekdays.isEmpty || viewModel.isLoading)
            }
        }
        .navigationDestination(isPresented: $viewModel.navigateToMainView) {
            // 這裡會由系統自動導向主畫面，因為我們已經設置了 hasCompletedOnboarding = true
            EmptyView()
        }
    }
    
    private func getWeekdayName(_ weekday: Int) -> String {
        switch weekday {
        case 1: return "週一"
        case 2: return "週二"
        case 3: return "週三"
        case 4: return "週四"
        case 5: return "週五"
        case 6: return "週六"
        case 7: return "週日"
        default: return ""
        }
    }
}
