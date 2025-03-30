import SwiftUI

struct TrainingProgressView: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStageIndex: Int? = nil
    
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
            .navigationTitle("訓練計劃進度")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
        }
    }
    
    // 當前訓練進度卡片
    private var currentTrainingStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let plan = viewModel.weeklyPlan, let currentWeek = viewModel.calculateCurrentTrainingWeek() {
                HStack {
                    Text("當前進度")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("第 \(currentWeek) 週 / 共 \(plan.totalWeeks) 週")
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
                            .frame(width: max(geometry.size.width * CGFloat(Double(currentWeek) / Double(plan.totalWeeks)), 0), height: 12)
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
                        
                        Text("當前階段：\(currentStage.stageName)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("第\(currentStage.weekStart)-\(currentStage.weekEnd)週")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("無法獲取當前訓練進度")
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
            Text("目標賽事")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(overview.trainingPlanName)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                // 分隔線
                Divider()
                
                Text("賽事評估")
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
            Text("訓練階段")
                .font(.headline)
            
            if let overview = viewModel.trainingOverview,
               let currentWeek = viewModel.calculateCurrentTrainingWeek() {
                ForEach(overview.trainingStageDescription.indices, id: \.self) { index in
                    let stage = overview.trainingStageDescription[index]
                    let isCurrentStage = currentWeek >= stage.weekStart && currentWeek <= (stage.weekEnd ?? stage.weekStart)
                    
                    stageSection(stage: stage, index: index, isCurrentStage: isCurrentStage)
                }
            } else {
                Text("無法獲取訓練階段資訊")
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
                    
                    Text("第\(stage.weekStart)-\(stage.weekEnd ?? stage.weekStart)週")
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
        let hasWeekPlan = viewModel.weeklyPlan?.weekOfPlan == weekNumber
        let hasSummary = viewModel.weeklySummary != nil && viewModel.lastFetchedWeekNumber == weekNumber
        
        return HStack {
            // 週數指示
            Text("第 \(weekNumber) 週")
                .font(.subheadline)
                .fontWeight(isCurrentWeek ? .bold : .regular)
                .foregroundColor(isCurrentWeek ? .primary : .secondary)
            
            Spacer()
            
            // 課表按鈕
            if hasWeekPlan {
                Button {
                    // 這裡可以導向該週的詳細課表
                } label: {
                    Label("查看課表", systemImage: "list.bullet")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // 週回顧按鈕
            if hasSummary {
                Button {
                    // 導向該週的訓練回顧
                } label: {
                    Label("訓練回顧", systemImage: "chart.bar")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // 當前週或未來週但尚未產生課表
            if isCurrentWeek && !hasWeekPlan {
                Button {
                    Task {
                        await viewModel.generateNextWeekPlan(targetWeek: weekNumber)
                    }
                } label: {
                    Label("產生課表", systemImage: "plus.circle")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
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
}

// MARK: - 預覽
struct TrainingProgressView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = TrainingPlanViewModel()
        return TrainingProgressView(viewModel: viewModel)
    }
}
