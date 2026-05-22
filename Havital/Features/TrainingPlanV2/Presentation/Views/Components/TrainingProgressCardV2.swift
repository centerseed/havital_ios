import SwiftUI

/// V2 訓練進度卡片 - 顯示整體訓練週數進度
struct TrainingProgressCardV2: View {
    var viewModel: TrainingPlanV2ViewModel
    let plan: WeeklyPlanV2
    @State private var showTrainingProgress = false

    private var progress: Double {
        guard let overview = viewModel.loader.planOverview, overview.totalWeeks > 0 else { return 0 }
        return min(Double(plan.effectiveWeek) / Double(overview.totalWeeks), 1.0)
    }

    var body: some View {
        // MARK: - PACERIZ REDESIGN 2026-05
        // Layout change: 3-row → single header row + slider.
        // Old rows (title row / stage indicator row) merged into one header row with PRChip.
        Button(action: {
            showTrainingProgress = true
        }) {
            VStack(alignment: .leading, spacing: 12) {

                // Row 1 (新): single-row header
                // trend icon · stage name · week chip · spacer · chevron
                HStack(spacing: 8) {
                    if let overview = viewModel.loader.planOverview,
                       let currentStage = getCurrentStage(from: overview) {
                        let stageColor = stageColorFor(week: plan.effectiveWeek, stages: overview.trainingStages)

                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(AppFont.bodyStrong())
                            .foregroundColor(stageColor)

                        Text(currentStage.stageName)
                            .font(AppFont.titleM())
                            .foregroundColor(.primary)

                        PRChip(
                            text: String(format: NSLocalizedString("training_plan_overview.week_progress", comment: ""), plan.effectiveWeek, overview.totalWeeks),
                            fg: stageColor,
                            bg: stageColor.opacity(0.13),
                            fontSize: 12
                        )
                    } else {
                        // PHASE-fallback: planOverview nil → show generic title, no crash
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(AppFont.bodyStrong())
                            .foregroundColor(.blue)

                        Text(NSLocalizedString("training.progress", comment: "Training Progress"))
                            .font(AppFont.titleM())
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(AppFont.label())
                        .foregroundColor(.secondary)
                }

                // Row 2: 多階段彩色進度條 (unchanged)
                if let overview = viewModel.loader.planOverview, !overview.trainingStages.isEmpty {
                    stageProgressBar(overview: overview)
                        .padding(.vertical, 4)
                } else {
                    ProgressView(value: progress)
                        .tint(.blue)
                        .scaleEffect(y: 1.8)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: PacerizRadius.card)
                    .fill(Color(UIColor.tertiarySystemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier("v2.weekly.progress_card")
        .sheet(isPresented: $showTrainingProgress) {
            TrainingOverviewV2View(viewModel: viewModel)
        }
    }

    // MARK: - Helper Functions

    /// Slider 風格的多階段進度條，階段交界處以漸層平滑過渡
    private func stageProgressBar(overview: PlanOverviewV2) -> some View {
        let totalWeeks = Double(overview.totalWeeks)
        let currentWeek = Double(plan.effectiveWeek)
        let currentProgress = min(currentWeek / totalWeeks, 1.0)
        let barHeight: CGFloat = 8
        let knobSize: CGFloat = 18

        let stops = makeGradientStops(stages: overview.trainingStages, totalWeeks: totalWeeks)
        let knobColor = stageColorFor(week: Int(currentWeek), stages: overview.trainingStages)

        return GeometryReader { geo in
            let barWidth = geo.size.width
            let filledWidth = barWidth * currentProgress

            ZStack(alignment: .leading) {
                // 全階段低透明度背景（顯示尚未到達的階段顏色）
                if !stops.isEmpty {
                    LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
                        .frame(width: barWidth, height: barHeight)
                        .clipShape(Capsule())
                        .opacity(0.45)
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

                // F11.b: 白色邊界 tick（各 stage 交界處，高 12pt 寬 2pt）
                let boundaries: [Double] = {
                    guard !overview.trainingStages.isEmpty else { return [] }
                    var positions: [Double] = []
                    var cursor = 0
                    for stage in overview.trainingStages.dropLast() {
                        cursor += stage.weekEnd - stage.weekStart + 1
                        positions.append(Double(cursor) / totalWeeks)
                    }
                    return positions
                }()
                ForEach(boundaries.indices, id: \.self) { i in
                    Rectangle()
                        .fill(Color(UIColor.tertiarySystemBackground))
                        .frame(width: 2, height: 12)
                        .cornerRadius(1)
                        .offset(x: barWidth * boundaries[i] - 1, y: 0)
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

    /// 建立漸層 stops：hard-stop 各段純色，無過渡帶
    private func makeGradientStops(stages: [TrainingStageV2], totalWeeks: Double) -> [Gradient.Stop] {
        guard !stages.isEmpty else { return [] }
        var stops: [Gradient.Stop] = []
        let blend = 0.0  // F11.a: hard-stop，各段純色，邊界直接切換

        for (i, stage) in stages.enumerated() {
            let color = getStageColor(stageId: stage.stageId)
            let start = Double(stage.weekStart - 1) / totalWeeks
            let end   = Double(stage.weekEnd) / totalWeeks
            stops.append(.init(color: color, location: i == 0 ? max(start, 0) : start + blend))
            stops.append(.init(color: color, location: i == stages.count - 1 ? min(end, 1) : end - blend))
        }
        return stops
    }

    /// 回傳當前週所在階段的顏色，用於 knob 邊框
    private func stageColorFor(week: Int, stages: [TrainingStageV2]) -> Color {
        stages.first { week >= $0.weekStart && week <= $0.weekEnd }
            .map { getStageColor(stageId: $0.stageId) }
            ?? (stages.last.map { getStageColor(stageId: $0.stageId) } ?? .blue)
    }

    /// 獲取當前階段
    private func getCurrentStage(from overview: PlanOverviewV2) -> (stageId: String, stageName: String, weekStart: Int, weekEnd: Int)? {
        let currentWeek = plan.effectiveWeek

        for stage in overview.trainingStages {
            if currentWeek >= stage.weekStart && currentWeek <= stage.weekEnd {
                return (stage.stageId, stage.stageName, stage.weekStart, stage.weekEnd)
            }
        }

        return nil
    }

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
    // TODO: 實作正確的 Preview mock 資料
    Text("TrainingProgressCardV2 Preview")
        .padding()
}
