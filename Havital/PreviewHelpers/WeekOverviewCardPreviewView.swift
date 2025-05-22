#if DEBUG
import SwiftUI

struct WeekOverviewCardPreviewView: View {
    let weeklyPlans: [WeeklyPlan]
    let fileNames: [String]
    @State private var selectedIndex = 0
    
    // 建立一個 Preview 專用的 ViewModel
    class PreviewViewModel: TrainingPlanViewModel {
        override init() {
            super.init()
            // 設定一些預覽用的數據
            currentWeekDistance = 25.5
            
            // 設定週摘要預覽數據
            let dateFormatter = ISO8601DateFormatter()
            let today = Date()
            let calendar = Calendar.current
            
            weeklySummaries = [
                WeeklySummaryItem(
                    weekIndex: 1,
                    weekStart: dateFormatter.string(from: calendar.date(byAdding: .day, value: -21, to: today) ?? today),
                    distanceKm: 25.5,
                    weekPlan: "week_1_plan",
                    weekSummary: "week_1_summary",
                    completionPercentage: 75
                ),
                WeeklySummaryItem(
                    weekIndex: 2,
                    weekStart: dateFormatter.string(from: calendar.date(byAdding: .day, value: -14, to: today) ?? today),
                    distanceKm: 30.2,
                    weekPlan: "week_2_plan",
                    weekSummary: "week_2_summary",
                    completionPercentage: 50
                ),
                WeeklySummaryItem(
                    weekIndex: 3,
                    weekStart: dateFormatter.string(from: calendar.date(byAdding: .day, value: -7, to: today) ?? today),
                    distanceKm: 28.7,
                    weekPlan: "week_3_plan",
                    weekSummary: nil,
                    completionPercentage: 25
                )
            ]
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !weeklyPlans.isEmpty {
                    // 顯示當前檔案名稱
                    VStack(spacing: 4) {
                        Text(weeklyPlans[selectedIndex].id ?? "未命名計畫")
                            .font(.headline)
                        
                        if selectedIndex < fileNames.count {
                            Text(fileNames[selectedIndex])
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.bottom, 4)
                        }
                    }
                    .padding(.top)
                    
                    // 使用 Preview 專用的 ViewModel
                    let viewModel = {
                        let vm = PreviewViewModel()
                        vm.weeklyPlan = weeklyPlans[selectedIndex]
                        // 設定訓練計劃概覽（用於計算當前週數）
                        let dateFormatter = ISO8601DateFormatter()
                        let today = Date()
                        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: today) ?? today
                        
                        vm.trainingOverview = TrainingPlanOverview(
                            id: "preview_overview",
                            mainRaceId: "race_123",
                            targetEvaluate: "完成半程馬拉松",
                            totalWeeks: 12,
                            trainingHighlight: "提升耐力與速度",
                            trainingPlanName: "預覽訓練計劃",
                            trainingStageDescription: [
                                TrainingStage(
                                    stageName: "基礎期",
                                    stageId: "base_phase",
                                    stageDescription: "建立有氧基礎",
                                    trainingFocus: "有氧耐力",
                                    weekStart: 1,
                                    weekEnd: 4
                                ),
                                TrainingStage(
                                    stageName: "進階期",
                                    stageId: "build_phase",
                                    stageDescription: "提升速度與肌力",
                                    trainingFocus: "間歇訓練",
                                    weekStart: 5,
                                    weekEnd: 8
                                ),
                                TrainingStage(
                                    stageName: "比賽期",
                                    stageId: "race_phase",
                                    stageDescription: "調整與準備比賽",
                                    trainingFocus: "比賽配速",
                                    weekStart: 9,
                                    weekEnd: 12
                                )
                            ],
                            createdAt: dateFormatter.string(from: twoWeeksAgo)
                        )
                        return vm
                    }()
                    
                    // 顯示 WeekOverviewCard
                    WeekOverviewCard(
                        viewModel: viewModel,
                        plan: weeklyPlans[selectedIndex]
                    )
                    .padding(.horizontal)
                    
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
                    
                    Spacer()
                } else {
                    Text("沒有找到測試資料")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// 預覽提供者
struct WeekOverviewCardPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        // 載入所有測試資料
        let testFilePath = #file
        let testDir = (testFilePath as NSString).deletingLastPathComponent
            .replacingOccurrences(of: "/PreviewHelpers", with: "/../HavitalTests/WeeklyPlanFixtures")
        
        let fileManager = FileManager.default
        let jsonFileNames = (try? fileManager.contentsOfDirectory(atPath: testDir)
            .filter { $0.hasSuffix(".json") }) ?? []
        
        let jsonFiles = jsonFileNames.map { (testDir as NSString).appendingPathComponent($0) }
        
        let decoder = JSONDecoder()
        var plans: [WeeklyPlan] = []
        var validFileNames: [String] = []
        
        for (index, filePath) in jsonFiles.enumerated() {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
                print("無法讀取檔案: \(filePath)")
                continue
            }
            do {
                let plan = try decoder.decode(WeeklyPlan.self, from: data)
                plans.append(plan)
                validFileNames.append(jsonFileNames[index])
            } catch {
                print("解析失敗: \(filePath), 錯誤: \(error)")
            }
        }
        
        return Group {
            // iPhone 14 Pro
            WeekOverviewCardPreviewView(weeklyPlans: plans, fileNames: validFileNames)
                .previewDevice("iPhone 14 Pro")
                .previewDisplayName("iPhone 14 Pro")
            
            // iPhone SE
            WeekOverviewCardPreviewView(weeklyPlans: plans, fileNames: validFileNames)
                .previewDevice("iPhone SE (3rd generation)")
                .previewDisplayName("iPhone SE")
            
            // Dark Mode
            WeekOverviewCardPreviewView(weeklyPlans: plans, fileNames: validFileNames)
                .previewDevice("iPhone 14 Pro")
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}
#endif
