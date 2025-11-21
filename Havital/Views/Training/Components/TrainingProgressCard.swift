import SwiftUI

/// 訓練進度卡片 - 顯示整體訓練週數進度
struct TrainingProgressCard: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    let plan: WeeklyPlan

    private var progress: Double {
        let totalWeeks = Double(viewModel.trainingOverview?.totalWeeks ?? plan.totalWeeks)
        guard totalWeeks > 0 else { return 0 }
        return min(Double(plan.weekOfPlan) / totalWeeks, 1.0)
    }

    private var percentage: Int {
        Int(progress * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
            }

            // 進度條（移除百分比）
            ProgressView(value: progress)
                .tint(.blue)
                .scaleEffect(y: 1.8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.tertiarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
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
