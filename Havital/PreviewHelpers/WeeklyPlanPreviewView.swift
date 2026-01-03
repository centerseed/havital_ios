#if DEBUG
import SwiftUI

struct WeeklyPlanPreviewView: View {
    let weeklyPlans: [WeeklyPlan]
    @State private var selectedIndex = 0
    
    // 建立一個 Preview 專用的 ViewModel（使用便利初始化器）
    class PreviewViewModel: TrainingPlanViewModel {
        override init(
            repository: TrainingPlanRepository,
            loadWeeklyWorkoutsUseCase: LoadWeeklyWorkoutsUseCase,
            aggregateWorkoutMetricsUseCase: AggregateWorkoutMetricsUseCase,
            weeklyPlanVM: WeeklyPlanViewModel? = nil,
            summaryVM: WeeklySummaryViewModel? = nil
        ) {
            super.init(
                repository: repository,
                loadWeeklyWorkoutsUseCase: loadWeeklyWorkoutsUseCase,
                aggregateWorkoutMetricsUseCase: aggregateWorkoutMetricsUseCase,
                weeklyPlanVM: weeklyPlanVM,
                summaryVM: summaryVM
            )
        }

        convenience init() {
            let container = DependencyContainer.shared
            if !container.isRegistered(TrainingPlanRepository.self) {
                container.registerTrainingPlanModule()
            }
            if !container.isRegistered(WorkoutRepository.self) {
                container.registerWorkoutModule()
            }
            let repository: TrainingPlanRepository = container.resolve()
            let loadUseCase = container.makeLoadWeeklyWorkoutsUseCase()
            let aggregateUseCase = container.makeAggregateWorkoutMetricsUseCase()
            self.init(
                repository: repository,
                loadWeeklyWorkoutsUseCase: loadUseCase,
                aggregateWorkoutMetricsUseCase: aggregateUseCase
            )
        }
    }
    
    var body: some View {
        VStack {
            if !weeklyPlans.isEmpty {
                // 顯示當前檔案名稱
                Text(weeklyPlans[selectedIndex].id ?? "未命名計畫")
                    .font(.headline)
                    .padding()
                
                // 使用 Preview 專用的 ViewModel
                let viewModel = {
                    let vm = PreviewViewModel()
                    vm.weeklyPlanVM.state = .loaded(weeklyPlans[selectedIndex])
                    return vm
                }()
                
                
                
                // 切換按鈕
                HStack {
                    Button("上一個") {
                        selectedIndex = (selectedIndex - 1 + weeklyPlans.count) % weeklyPlans.count
                    }
                    .disabled(weeklyPlans.count <= 1)
                    
                    Text("\(selectedIndex + 1)/\(weeklyPlans.count)")
                        .frame(width: 80)
                    
                    Button("下一個") {
                        selectedIndex = (selectedIndex + 1) % weeklyPlans.count
                    }
                    .disabled(weeklyPlans.count <= 1)
                }
                .padding()

                // 顯示 WeekTimelineView
                WeekTimelineView(
                    viewModel: viewModel,
                    plan: weeklyPlans[selectedIndex]
                )
            } else {
                Text("沒有找到測試資料")
                    .foregroundColor(.secondary)
            }
        }
    }
}

// 預覽提供者
struct WeeklyPlanPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        // 載入所有測試資料
        let testFilePath = #file
        let testDir = (testFilePath as NSString).deletingLastPathComponent
            .replacingOccurrences(of: "/PreviewHelpers", with: "/../HavitalTests/WeeklyPlanFixtures")
        
        let fileManager = FileManager.default
        let jsonFiles = (try? fileManager.contentsOfDirectory(atPath: testDir)
            .filter { $0.hasSuffix(".json") }
            .map { (testDir as NSString).appendingPathComponent($0) }) ?? []
        
        let decoder = JSONDecoder()
        let plans = jsonFiles.compactMap { filePath -> WeeklyPlan? in
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
                print("無法讀取檔案: \(filePath)")
                return nil
            }
            do {
                return try decoder.decode(WeeklyPlan.self, from: data)
            } catch {
                print("解析失敗: \(filePath), 錯誤: \(error)")
                return nil
            }
        }
        
        return Group {
            // iPhone 14 Pro
            WeeklyPlanPreviewView(weeklyPlans: plans)
                .previewDevice("iPhone 14 Pro")
                .previewDisplayName("iPhone 14 Pro")
            
            // iPhone SE
            WeeklyPlanPreviewView(weeklyPlans: plans)
                .previewDevice("iPhone SE (3rd generation)")
                .previewDisplayName("iPhone SE")
        }
    }
}
#endif
