import SwiftUI

struct TrainingProgressView: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStageIndex: Int? = nil
    @State private var isLoadingWeeklySummaries = false

    // 摺疊狀態管理
    @State private var isRacesSectionExpanded = true  // 賽事規劃默認展開
    @State private var isEvaluationExpanded = false   // 目標評估默認收起
    @State private var isHighlightExpanded = false    // 訓練重點默認收起
    @State private var isStagesExpanded = false       // 訓練階段默認收起

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 當前訓練進度概覽
                    currentTrainingStatusCard

                    // 賽事規劃區塊（可摺疊）
                    if let overview = viewModel.trainingOverview {
                        racesPlanningSection(overview: overview)
                    }

                    // 目標評估區塊（可摺疊）
                    if let overview = viewModel.trainingOverview {
                        evaluationSection(overview: overview)
                    }

                    // 訓練重點區塊（可摺疊）
                    if let overview = viewModel.trainingOverview {
                        highlightSection(overview: overview)
                    }

                    // 訓練階段區塊（可摺疊）
                    trainingStagesSectionCollapsible
                }
                .padding()
            }
            .navigationTitle(NSLocalizedString("training.progress", comment: "Training Progress"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("common.done", comment: "Done")) {
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
            if let plan = viewModel.weeklyPlan, let currentWeek = viewModel.calculateCurrentTrainingWeek() {
                HStack {
                    Text(NSLocalizedString("training.current_progress", comment: "Current Progress"))
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(String(format: NSLocalizedString("training.current_week_of_total", comment: "Week %d / Total %d weeks"), currentWeek, viewModel.trainingOverview?.totalWeeks ?? plan.totalWeeks))
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
                        
                        Text(String(format: NSLocalizedString("training.current_stage", comment: "Current Stage: %@"), currentStage.stageName))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(String(format: NSLocalizedString("training.week_range", comment: "Week %d-%d"), currentStage.weekStart, currentStage.weekEnd))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text(NSLocalizedString("training.cannot_get_progress", comment: "Unable to get current training progress"))
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 2)
    }
    
    // MARK: - 賽事規劃區塊（可摺疊）
    private func racesPlanningSection(overview: TrainingPlanOverview) -> some View {
        CollapsibleCard(
            title: "🎯 賽事規劃",
            isExpanded: $isRacesSectionExpanded,
            summary: overview.trainingPlanName
        ) {
            VStack(alignment: .leading, spacing: 12) {
                // 主要賽事資訊
                Text(overview.trainingPlanName)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Divider()

                // 這裡可以添加主要賽事和支援賽事的詳細信息
                // 暫時保持簡單，只顯示計畫名稱
                Text(NSLocalizedString("training.main_race", comment: "Main Race"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - 目標評估區塊（可摺疊）
    private func evaluationSection(overview: TrainingPlanOverview) -> some View {
        CollapsibleCard(
            title: "📊 目標評估",
            isExpanded: $isEvaluationExpanded,
            summary: String(overview.targetEvaluate.prefix(50)) + "..."
        ) {
            Text(overview.targetEvaluate)
                .font(.subheadline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 訓練重點區塊（可摺疊）
    private func highlightSection(overview: TrainingPlanOverview) -> some View {
        let stagesCount = overview.trainingStageDescription.count
        let summaryText = "\(stagesCount) 個階段 · \(overview.totalWeeks) 週訓練"

        return CollapsibleCard(
            title: "✨ 訓練重點",
            isExpanded: $isHighlightExpanded,
            summary: summaryText
        ) {
            Text(overview.trainingHighlight)
                .font(.subheadline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 訓練階段區塊（可摺疊）
    private var trainingStagesSectionCollapsible: some View {
        let currentWeek = viewModel.calculateCurrentTrainingWeek() ?? 0
        let currentStageName = viewModel.trainingOverview?.trainingStageDescription.first(where: { stage in
            currentWeek >= stage.weekStart && currentWeek <= (stage.weekEnd ?? stage.weekStart)
        })?.stageName ?? ""

        return CollapsibleCard(
            title: "📈 訓練階段",
            isExpanded: $isStagesExpanded,
            summary: "當前：\(currentStageName)（第 \(currentWeek) 週）"
        ) {
            trainingStagesContent
        }
    }

    // 訓練階段內容
    private var trainingStagesContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let overview = viewModel.trainingOverview,
               let currentWeek = viewModel.calculateCurrentTrainingWeek() {
                ForEach(overview.trainingStageDescription.indices, id: \.self) { index in
                    let stage = overview.trainingStageDescription[index]
                    let isCurrentStage = currentWeek >= stage.weekStart && currentWeek <= (stage.weekEnd ?? stage.weekStart)

                    stageSection(stage: stage, index: index, isCurrentStage: isCurrentStage)
                }
            } else {
                Text(NSLocalizedString("training.cannot_get_stages", comment: "Unable to get training stage information"))
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
                    
                    Text(String(format: NSLocalizedString("training.week_range", comment: "Week %d-%d"), stage.weekStart, stage.weekEnd ?? stage.weekStart))
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
        .background(Color(UIColor.secondarySystemBackground))  // ← 階段卡片使用次級背景，與主卡片區分
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
                Text(String(format: NSLocalizedString("training.week_number", comment: "Week %d"), weekNumber))
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
                                viewModel.selectedWeek = weekNumber
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
                                Text("載入中...")
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
                                    Text("重試")
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
                        } else if viewModel.showWeeklySummary && viewModel.weeklySummary != nil {
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
                                    Text(NSLocalizedString("training.get_weekly_review", comment: "Get Weekly Review"))
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
        guard let overview = viewModel.trainingOverview,
              let currentWeek = viewModel.calculateCurrentTrainingWeek() else {
            return
        }

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

// MARK: - 可摺疊卡片組件
struct CollapsibleCard<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    let summary: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 標題行（可點擊展開/收起）
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            // 摘要（收起時顯示）
            if !isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .padding(.horizontal, 16)

                    Text(summary)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                }
            }

            // 完整內容（展開時顯示）
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                        .padding(.horizontal, 16)

                    content()
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                }
            }
        }
        .background(Color(UIColor.systemBackground))  // ← 使用 systemBackground 確保對比度
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 2)  // ← 添加輕微陰影
    }
}

// MARK: - 預覽
struct TrainingProgressView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = TrainingPlanViewModel()
        return TrainingProgressView(viewModel: viewModel)
    }
}
