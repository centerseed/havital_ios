import SwiftUI

/// V2 訓練進度卡片 - 顯示整體訓練週數進度
struct TrainingProgressCardV2: View {
    @ObservedObject var viewModel: TrainingPlanV2ViewModel
    let plan: WeeklyPlanV2
    @State private var showTrainingProgress = false

    private var progress: Double {
        guard let overview = viewModel.planOverview, overview.totalWeeks > 0 else { return 0 }
        return min(Double(plan.weekOfTraining) / Double(overview.totalWeeks), 1.0)
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

                    if let overview = viewModel.planOverview {
                        Text(String(format: NSLocalizedString("training_plan_overview.week_progress", comment: ""), plan.weekOfTraining, overview.totalWeeks))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // 進度條
                ProgressView(value: progress)
                    .tint(.blue)
                    .scaleEffect(y: 1.8)

                // 當前階段指示器（簡化版 - 待實作完整階段邏輯）
                if let overview = viewModel.planOverview,
                   let currentStage = getCurrentStage(from: overview) {
                    HStack(alignment: .center, spacing: 8) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 10, height: 10)

                        Text(currentStage.stageName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Spacer()

                        Text(String(format: NSLocalizedString("training_plan_overview.week_range", comment: ""), currentStage.weekStart, currentStage.weekEnd))
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
        // TODO: 實作 TrainingProgressView V2 版本
        // .sheet(isPresented: $showTrainingProgress) {
        //     TrainingProgressViewV2(viewModel: viewModel)
        // }
    }

    // MARK: - Helper Functions

    /// 獲取當前階段（簡化版）
    private func getCurrentStage(from overview: PlanOverviewV2) -> (stageName: String, weekStart: Int, weekEnd: Int)? {
        let currentWeek = plan.weekOfTraining

        for stage in overview.trainingStages {
            if currentWeek >= stage.weekStart && currentWeek <= stage.weekEnd {
                return (stage.stageName, stage.weekStart, stage.weekEnd)
            }
        }

        return nil
    }
}

#Preview {
    // TODO: 實作正確的 Preview mock 資料
    Text("TrainingProgressCardV2 Preview")
        .padding()
}
