import SwiftUI

/// 訓練進度卡片 - 顯示整體訓練週數進度
struct TrainingProgressCard: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    let plan: WeeklyPlan
    @State private var showTrainingProgress = false

    private var progress: Double {
        let totalWeeks = Double(viewModel.trainingOverview?.totalWeeks ?? plan.totalWeeks)
        guard totalWeeks > 0 else { return 0 }
        return min(Double(plan.weekOfPlan) / totalWeeks, 1.0)
    }

    var body: some View {
        Button(action: {
            showTrainingProgress = true
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // 標題和週數
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.blue)
                        .font(.headline)

                    Text(NSLocalizedString("training.progress", comment: "Training Progress"))
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    Text("第 \(plan.weekOfPlan) / \(viewModel.trainingOverview?.totalWeeks ?? plan.totalWeeks) 週")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // 多階段彩色進度條
                if let overview = viewModel.trainingOverview, !overview.trainingStageDescription.isEmpty {
                    stageProgressBar(overview: overview)
                } else {
                    // 降級方案：簡單的單色進度條
                    ProgressView(value: progress)
                        .tint(.blue)
                        .scaleEffect(y: 1.8)
                }

                // 當前階段指示器
                if let overview = viewModel.trainingOverview,
                   let currentStage = getCurrentStage(from: overview, currentWeek: plan.weekOfPlan) {
                    HStack(alignment: .center, spacing: 8) {
                        Circle()
                            .fill(getStageColor(stageIndex: currentStage.index))
                            .frame(width: 10, height: 10)

                        Text(currentStage.stageName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Spacer()

                        Text("第 \(currentStage.weekStart)-\(currentStage.weekEnd) 週")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.tertiarySystemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showTrainingProgress) {
            TrainingProgressView(viewModel: viewModel)
        }
    }

    // MARK: - 階段進度條視圖

    /// 多階段彩色進度條
    private func stageProgressBar(overview: TrainingPlanOverview) -> some View {
        let totalWeeks = Double(overview.totalWeeks)
        let currentWeek = Double(plan.weekOfPlan)

        return GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景底色
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 12)

                // 各階段彩色段
                HStack(spacing: 0) {
                    ForEach(Array(overview.trainingStageDescription.enumerated()), id: \.offset) { index, stage in
                        let stageWeeks = Double((stage.weekEnd ?? stage.weekStart) - stage.weekStart + 1)
                        let stageWidth = geometry.size.width * (stageWeeks / totalWeeks)
                        let isFirst = index == 0
                        let isLast = index == overview.trainingStageDescription.count - 1

                        // 根據位置決定圓角樣式
                        if isFirst && isLast {
                            // 只有一個階段：全圓角
                            RoundedRectangle(cornerRadius: 6)
                                .fill(getStageColor(stageIndex: index))
                                .frame(width: stageWidth, height: 12)
                        } else if isFirst {
                            // 第一個階段：左側圓角，右側直角
                            UnevenRoundedRectangle(cornerRadii: .init(
                                topLeading: 6,
                                bottomLeading: 6,
                                bottomTrailing: 0,
                                topTrailing: 0
                            ))
                            .fill(getStageColor(stageIndex: index))
                            .frame(width: stageWidth, height: 12)
                        } else if isLast {
                            // 最後階段：左側直角，右側圓角
                            UnevenRoundedRectangle(cornerRadii: .init(
                                topLeading: 0,
                                bottomLeading: 0,
                                bottomTrailing: 6,
                                topTrailing: 6
                            ))
                            .fill(getStageColor(stageIndex: index))
                            .frame(width: stageWidth, height: 12)
                        } else {
                            // 中間階段：全直角
                            Rectangle()
                                .fill(getStageColor(stageIndex: index))
                                .frame(width: stageWidth, height: 12)
                        }
                    }
                }

                // 當前進度遮罩 - 顯示完成部分
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.4))
                    .frame(width: max(geometry.size.width * (1.0 - currentWeek / totalWeeks), 0), height: 12)
                    .offset(x: geometry.size.width * (currentWeek / totalWeeks))

                // 當前進度指示線
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 3, height: 16)
                    .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                    .offset(x: max(geometry.size.width * (currentWeek / totalWeeks) - 1.5, 0))
            }
        }
        .frame(height: 12)
    }

    // MARK: - Helper Functions

    /// 獲取當前階段
    private func getCurrentStage(from overview: TrainingPlanOverview, currentWeek: Int) -> (index: Int, stageName: String, weekStart: Int, weekEnd: Int)? {
        for (index, stage) in overview.trainingStageDescription.enumerated() {
            let endWeek = stage.weekEnd ?? stage.weekStart
            if currentWeek >= stage.weekStart && currentWeek <= endWeek {
                return (index, stage.stageName, stage.weekStart, endWeek)
            }
        }
        return nil
    }

    /// 獲取階段顏色（與 TrainingProgressView 保持一致）
    private func getStageColor(stageIndex: Int) -> Color {
        let colors: [Color] = [.blue, .mint, .orange, .purple, .pink]
        return colors[stageIndex % colors.count]
    }
}

#Preview {
    TrainingProgressCard(
        viewModel: TrainingPlanViewModel(),
        plan: WeeklyPlan(
            id: "preview",
            purpose: "預覽測試",
            weekOfPlan: 35,
            totalWeeks: 39,
            totalDistance: 50.0,
            designReason: ["測試用"],
            days: [],
            intensityTotalMinutes: WeeklyPlan.IntensityTotalMinutes(low: 120, medium: 45, high: 15)
        )
    )
    .padding()
}
