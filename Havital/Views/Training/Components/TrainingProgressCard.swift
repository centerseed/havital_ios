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
                        .font(AppFont.headline())

                    Text(NSLocalizedString("training.progress", comment: "Training Progress"))
                        .font(AppFont.headline())
                        .foregroundColor(.primary)

                    Spacer()

                    Text(String(format: NSLocalizedString("training_plan_overview.week_progress", comment: ""), plan.weekOfPlan, viewModel.trainingOverview?.totalWeeks ?? plan.totalWeeks))
                        .font(AppFont.bodySmall())
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Image(systemName: "chevron.right")
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                }

                // 多階段彩色進度條
                if let overview = viewModel.trainingOverview, !overview.trainingStageDescription.isEmpty {
                    stageProgressBar(overview: overview)
                        .padding(.vertical, 4)
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
                            .fill(getStageColor(stageId: currentStage.stageId))
                            .frame(width: 10, height: 10)

                        Text(currentStage.stageName)
                            .font(AppFont.caption())
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Spacer()

                        Text(String(format: NSLocalizedString("training_plan_overview.week_range", comment: ""), currentStage.weekStart, currentStage.weekEnd))
                            .font(AppFont.captionSmall())
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

    /// Slider 風格的多階段進度條，階段交界處以漸層平滑過渡
    private func stageProgressBar(overview: TrainingPlanOverview) -> some View {
        let totalWeeks = Double(overview.totalWeeks)
        let currentWeek = Double(plan.weekOfPlan)
        let currentProgress = min(currentWeek / totalWeeks, 1.0)
        let barHeight: CGFloat = 8
        let knobSize: CGFloat = 18

        let stops = makeGradientStops(stages: overview.trainingStageDescription, totalWeeks: totalWeeks)
        let knobColor = stageColorFor(week: plan.weekOfPlan, stages: overview.trainingStageDescription)

        return GeometryReader { geo in
            let barWidth = geo.size.width
            let filledWidth = barWidth * currentProgress

            ZStack(alignment: .leading) {
                // 全階段低透明度背景（顯示尚未到達的階段顏色）
                if !stops.isEmpty {
                    LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
                        .frame(width: barWidth, height: barHeight)
                        .clipShape(Capsule())
                        .opacity(0.25)
                } else {
                    Capsule()
                        .fill(Color(UIColor.systemGray5))
                        .frame(width: barWidth, height: barHeight)
                }

                // 已完成的漸層彩色部分（mask 到 filledWidth）
                if filledWidth > 0 && !stops.isEmpty {
                    LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
                        .frame(width: barWidth, height: barHeight)
                        .mask(
                            HStack(spacing: 0) {
                                UnevenRoundedRectangle(cornerRadii: .init(
                                    topLeading: barHeight / 2, bottomLeading: barHeight / 2,
                                    bottomTrailing: 0, topTrailing: 0
                                ))
                                .frame(width: filledWidth, height: barHeight)
                                Color.clear
                            }
                            .frame(width: barWidth, height: barHeight)
                        )
                }

                // 圓圈 knob
                Circle()
                    .fill(Color.white)
                    .frame(width: knobSize, height: knobSize)
                    .overlay(Circle().stroke(knobColor, lineWidth: 2.5))
                    .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 1)
                    .offset(x: max(min(filledWidth - knobSize / 2, barWidth - knobSize), 0))
            }
            .frame(width: barWidth, height: knobSize)
        }
        .frame(height: knobSize)
    }

    /// 建立漸層 stops：每個階段邊界兩側各留 3% 的過渡帶
    private func makeGradientStops(stages: [TrainingStage], totalWeeks: Double) -> [Gradient.Stop] {
        guard !stages.isEmpty else { return [] }
        var stops: [Gradient.Stop] = []
        let blend = 0.03

        for (i, stage) in stages.enumerated() {
            let color = getStageColor(stageId: stage.stageId)
            let start = Double(stage.weekStart - 1) / totalWeeks
            let end   = Double(stage.weekEnd ?? stage.weekStart) / totalWeeks
            stops.append(.init(color: color, location: i == 0 ? max(start, 0) : start + blend))
            stops.append(.init(color: color, location: i == stages.count - 1 ? min(end, 1) : end - blend))
        }
        return stops
    }

    /// 回傳當前週所在階段的顏色，用於 knob 邊框
    private func stageColorFor(week: Int, stages: [TrainingStage]) -> Color {
        stages.first { week >= $0.weekStart && week <= ($0.weekEnd ?? $0.weekStart) }
            .map { getStageColor(stageId: $0.stageId) }
            ?? (stages.last.map { getStageColor(stageId: $0.stageId) } ?? .blue)
    }

    // MARK: - Helper Functions

    /// 獲取當前階段
    private func getCurrentStage(from overview: TrainingPlanOverview, currentWeek: Int) -> (stageId: String, stageName: String, weekStart: Int, weekEnd: Int)? {
        for stage in overview.trainingStageDescription {
            let endWeek = stage.weekEnd ?? stage.weekStart
            if currentWeek >= stage.weekStart && currentWeek <= endWeek {
                return (stage.stageId, stage.stageName, stage.weekStart, endWeek)
            }
        }
        return nil
    }

    /// 獲取階段顏色（與 TrainingProgressView 保持一致）
    private func getStageColor(stageId: String) -> Color {
        switch stageId {
        case "conversion": return .teal
        case "base":       return .blue
        case "build":      return .green
        case "peak":       return .orange
        case "taper":      return .purple
        default:           return .gray
        }
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
