import SwiftUI

struct TrainingProgressView: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStageIndex: Int? = nil
    @State private var isLoadingWeeklySummaries = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 當前訓練進度概覽
                    currentTrainingStatusCard

                    // 目標賽事資訊
                    if let overview = viewModel.trainingOverview {
                        targetRaceCard(overview: overview)
                    }

                    // 各階段訓練進度
                    trainingStagesSection
                }
                .padding()
            }
            .navigationTitle(L10n.Training.progress.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.Common.done.localized) {
                        dismiss()
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
        }
        .task {
            await TrackedTask("TrainingProgressView: loadWeeklySummaries") {
                // 初始載入週次數據，使用雙軌模式
                await loadWeeklySummariesWithDualTrack()
            }.value
        }
        .onAppear {
            // 自動展開當前週期對應的階段
            expandCurrentStage()
        }
    }
    
    // 當前訓練進度卡片
    private var currentTrainingStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let plan = viewModel.weeklyPlan {
                let currentWeek = viewModel.calculateCurrentTrainingWeek()
                HStack {
                    Text(L10n.Training.currentProgress.localized)
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(L10n.Training.currentWeekOfTotal.localized(with: currentWeek, viewModel.trainingOverview?.totalWeeks ?? plan.totalWeeks))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // 進度條
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 背景進度條
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 12)
                        
                        // 完成進度
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [.blue, .cyan]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(geometry.size.width * CGFloat(Double(currentWeek) / Double(viewModel.trainingOverview?.totalWeeks ?? plan.totalWeeks)), 0), height: 12)
                    }
                }
                .frame(height: 12)
                
                // 目前訓練階段
                if let overview = viewModel.trainingOverview,
                   let currentStage = getCurrentStage(from: overview, currentWeek: currentWeek) {
                    HStack(alignment: .center, spacing: 12) {
                        Circle()
                            .fill(getStageColor(stageIndex: currentStage.index))
                            .frame(width: 12, height: 12)
                        
                        Text(L10n.Training.currentStage.localized(with: currentStage.stageName))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(L10n.Training.weekRange.localized(with: currentStage.weekStart, currentStage.weekEnd))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text(L10n.Training.cannotGetProgress.localized)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }
    
    // 目標賽事卡片
    private func targetRaceCard(overview: TrainingPlanOverview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Training.targetRace.localized)
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(overview.trainingPlanName)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                // 分隔線
                Divider()
                
                Text(L10n.Training.raceAssessment.localized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.top, 4)
                
                Text(overview.targetEvaluate)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }
    
    // 訓練階段區塊
    private var trainingStagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Training.trainingStages.localized)
                .font(.headline)
            
            if let overview = viewModel.trainingOverview {
                let currentWeek = viewModel.calculateCurrentTrainingWeek()
                ForEach(overview.trainingStageDescription.indices, id: \.self) { index in
                    let stage = overview.trainingStageDescription[index]
                    let isCurrentStage = currentWeek >= stage.weekStart && currentWeek <= (stage.weekEnd ?? stage.weekStart)
                    
                    stageSection(stage: stage, index: index, isCurrentStage: isCurrentStage)
                }
            } else {
                Text(L10n.Training.cannotGetStages.localized)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // 訓練階段區塊
    private func stageSection(stage: TrainingStage, index: Int, isCurrentStage: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 階段標題按鈕
            Button {
                if selectedStageIndex == index {
                    selectedStageIndex = nil
                } else {
                    selectedStageIndex = index
                }
            } label: {
                HStack {
                    Circle()
                        .fill(getStageColor(stageIndex: index))
                        .frame(width: 16, height: 16)
                    
                    Text(stage.stageName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(isCurrentStage ? .primary : .secondary)
                    
                    Spacer()
                    
                    Text(L10n.Training.weekRange.localized(with: stage.weekStart, stage.weekEnd ?? stage.weekStart))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: selectedStageIndex == index ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(isCurrentStage ? getStageColor(stageIndex: index).opacity(0.1) : Color.clear)
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            
            // 展開的週次詳情
            if selectedStageIndex == index {
                VStack(spacing: 4) {
                    // 階段描述
                    Text(stage.stageDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // 顯示該階段的每週訓練情況
                    weeklyDetailsList(startWeek: stage.weekStart, endWeek: stage.weekEnd ?? stage.weekStart)
                }
                .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
                .cornerRadius(8)
            }
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCurrentStage ? getStageColor(stageIndex: index) : Color.clear, lineWidth: 1)
        )
        .padding(.bottom, 8)
    }
    
    // 週次詳情列表
    private func weeklyDetailsList(startWeek: Int, endWeek: Int) -> some View {
        VStack(spacing: 0) {
            ForEach(startWeek...endWeek, id: \.self) { weekNumber in
                weekRow(weekNumber: weekNumber)
                
                if weekNumber < endWeek {
                    Divider()
                        .padding(.horizontal, 16)
                }
            }
        }
    }
    
    // 單週資訊行
    private func weekRow(weekNumber: Int) -> some View {
        let isCurrentWeek = viewModel.calculateCurrentTrainingWeek() == weekNumber
        
        // 從weeklySummaries查找對應週次的數據
        let weekSummary = viewModel.weeklySummaries.first { $0.weekIndex == weekNumber }
        let hasWeekPlan = weekSummary?.weekPlan != nil
        let hasSummary = weekSummary?.weekSummary != nil
        let completionPercentage = weekSummary?.completionPercentage
        
        return VStack(spacing: 8) {
            HStack {
                // 週數指示
                Text(L10n.Training.weekNumber.localized(with: weekNumber))
                    .font(.subheadline)
                    .fontWeight(isCurrentWeek ? .bold : .regular)
                    .foregroundColor(isCurrentWeek ? .primary : .secondary)
                
                // 完成度進度條
                if let percent = completionPercentage {
                    HStack(spacing: 8) {
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(.systemGray5))
                                .frame(width: 40, height: 6)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [.blue, .teal]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .frame(width: 40 * min(percent, 100) / 100, height: 6)
                        }
                        Text("\(Int(percent))%")
                            .fixedSize()
                            .font(.footnote.bold())
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                // 功能按鈕區域
                HStack(spacing: 8) {
                    // 週回顧按鈕
                    if hasSummary {
                        Button {
                            Task { 
                                await viewModel.fetchWeeklySummary(weekNumber: weekNumber) 
                                dismiss() // 關閉當前視圖以顯示回顧
                            }
                        } label: {
                            HStack(alignment: .center, spacing: 4) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: 12, weight: .medium))
                                Text(L10n.TrainingProgress.review.localized)
                                    .font(.footnote)
                                    .fontWeight(.medium)
                            }
                            .fixedSize()
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // 課表按鈕
                    if hasWeekPlan {
                        Button {
                            Task {
                                await viewModel.fetchWeekPlan(week: weekNumber)
                                dismiss() // 關閉當前視圖以顯示課表
                            }
                        } label: {
                            HStack(alignment: .center, spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 12, weight: .medium))
                                Text(L10n.TrainingProgress.schedule.localized)
                                    .font(.footnote)
                                    .fontWeight(.medium)
                            }
                            .fixedSize()
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color.green.opacity(0.1))
                            .foregroundColor(.green)
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // 當前週且沒有課表時的按鈕邏輯 - 與 TrainingPlanView 保持一致
                    if isCurrentWeek && !hasWeekPlan {
                        // 使用與 TrainingPlanView 完全相同的邏輯
                        if viewModel.isLoadingWeeklySummary {
                            // 正在載入週回顧時顯示載入狀態
                            HStack(alignment: .center, spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text(L10n.Common.loading.localized)
                                    .font(.footnote)
                                    .fontWeight(.medium)
                            }
                            .fixedSize()
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color.gray.opacity(0.1))
                            .foregroundColor(.gray)
                            .cornerRadius(8)
                        } else if viewModel.weeklySummaryError != nil {
                            // 載入失敗時顯示重試按鈕，使用強制更新模式
                            Button {
                                Task {
                                    await viewModel.retryCreateWeeklySummary()
                                    dismiss() // 關閉當前視圖以顯示回顧
                                }
                            } label: {
                                HStack(alignment: .center, spacing: 4) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 12, weight: .medium))
                                    Text(L10n.Common.retry.localized)
                                        .font(.footnote)
                                        .fontWeight(.medium)
                                }
                                .fixedSize()
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Color.red.opacity(0.1))
                                .foregroundColor(.red)
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else if viewModel.showWeeklySummary.wrappedValue && viewModel.weeklySummary != nil {
                            // 已有週回顧時顯示產生課表按鈕
                            Button {
                                Task {
                                    await viewModel.generateNextWeekPlan(targetWeek: weekNumber)
                                }
                            } label: {
                                HStack(alignment: .center, spacing: 4) {
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 12, weight: .medium))
                                    Text(L10n.TrainingProgress.generateSchedule.localized)
                                        .font(.footnote)
                                        .fontWeight(.medium)
                                }
                                .fixedSize()
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Color.orange.opacity(0.1))
                                .foregroundColor(.orange)
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            // 未獲取回顧時，顯示取得週回顧按鈕
                            Button {
                                Task {
                                    await viewModel.createWeeklySummary()
                                    dismiss() // 關閉當前視圖以顯示回顧
                                }
                            } label: {
                                HStack(alignment: .center, spacing: 4) {
                                    Image(systemName: "doc.text.magnifyingglass")
                                        .font(.system(size: 12, weight: .medium))
                                    Text(L10n.Training.getWeeklyReview.localized)
                                        .font(.footnote)
                                        .fontWeight(.medium)
                                }
                                .fixedSize()
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(isCurrentWeek ? Color.blue.opacity(0.05) : Color.clear)
    }
    
    // 獲取當前階段
    private func getCurrentStage(from overview: TrainingPlanOverview, currentWeek: Int) -> (index: Int, stageName: String, weekStart: Int, weekEnd: Int)? {
        for (index, stage) in overview.trainingStageDescription.enumerated() {
            let endWeek = stage.weekEnd ?? stage.weekStart
            if currentWeek >= stage.weekStart && currentWeek <= endWeek {
                return (index, stage.stageName, stage.weekStart, endWeek)
            }
        }
        return nil
    }
    
    // 獲取階段顏色
    private func getStageColor(stageIndex: Int) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink]
        return colors[stageIndex % colors.count]
    }

    // 自動展開當前週期對應的階段
    private func expandCurrentStage() {
        guard let overview = viewModel.trainingOverview else {
            return
        }
        let currentWeek = viewModel.calculateCurrentTrainingWeek()


        // 找到當前週期對應的階段 index
        for (index, stage) in overview.trainingStageDescription.enumerated() {
            let endWeek = stage.weekEnd ?? stage.weekStart
            if currentWeek >= stage.weekStart && currentWeek <= endWeek {
                selectedStageIndex = index
                break
            }
        }
    }

    // MARK: - 雙軌載入實現
    
    /// 使用雙軌模式載入週次數據：先顯示緩存，背景更新
    private func loadWeeklySummariesWithDualTrack() async {
        // 如果已有數據，直接返回
        guard viewModel.weeklySummaries.isEmpty else { return }
        
        isLoadingWeeklySummaries = true
        
        // 先嘗試從緩存載入
        if !viewModel.weeklySummaries.isEmpty {
            isLoadingWeeklySummaries = false
            
            // 背景更新
            Task.detached { [weak viewModel] in
                await viewModel?.fetchWeeklySummaries()
            }
            return
        }
        
        // 沒有緩存數據時直接載入
        await viewModel.fetchWeeklySummaries()
        isLoadingWeeklySummaries = false
    }
}

// MARK: - 預覽
struct TrainingProgressView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = TrainingPlanViewModel()
        return TrainingProgressView(viewModel: viewModel)
    }
}
