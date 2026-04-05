import SwiftUI

// MARK: - WeeklyPreviewSheetV2
/// Bottom Sheet 顯示未來四週訓練骨架
struct WeeklyPreviewSheetV2: View {
    @ObservedObject var viewModel: TrainingPlanV2ViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Disclaimer
                    Text(NSLocalizedString("training.weekly_skeleton_disclaimer", comment: "The following is the weekly training skeleton, actual schedule will be dynamically adjusted based on your training status"))
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    // Week cards
                    weekPreviewList
                }
                .padding(.vertical, 12)
            }
            .navigationTitle(NSLocalizedString("training.weekly_skeleton_title", comment: "Weekly Training Skeleton"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("common.close", comment: "Close")) {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Week Preview List

    @ViewBuilder
    private var weekPreviewList: some View {
        let weeks = viewModel.upcomingWeeks
        let stages = viewModel.planOverview?.trainingStages ?? []

        ForEach(weeks) { week in
            let isCurrentWeek = week.week == viewModel.currentWeek
            WeekPreviewRowV2(
                week: week,
                stageInfo: WeekPreviewRowV2.stageInfo(for: week, stages: stages),
                isCurrentWeek: isCurrentWeek
            )
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - StageDisplayInfo

/// 階段顯示資訊
struct StageDisplayInfo {
    let name: String
    let positionInStage: Int
    let totalStageWeeks: Int
}

// MARK: - WeekPreviewRowV2

/// 單週預覽卡片（Sheet 和 PlanOverview inline section 共用）
struct WeekPreviewRowV2: View {
    let week: WeekPreview
    let stageInfo: StageDisplayInfo
    let isCurrentWeek: Bool

    /// 計算某週在其 stage 內的位置資訊
    static func stageInfo(for week: WeekPreview, stages: [TrainingStageV2]) -> StageDisplayInfo {
        guard let stage = stages.first(where: { $0.contains(week: week.week) }) else {
            return StageDisplayInfo(name: week.stageId, positionInStage: 1, totalStageWeeks: 1)
        }
        let positionInStage = week.week - stage.weekStart + 1
        let totalStageWeeks = stage.durationWeeks
        return StageDisplayInfo(name: stage.stageName, positionInStage: positionInStage, totalStageWeeks: totalStageWeeks)
    }

    var body: some View {
        HStack(spacing: 0) {
            // 左側邊線（當前週為藍色）
            RoundedRectangle(cornerRadius: 2)
                .fill(isCurrentWeek ? Color.blue : Color.clear)
                .frame(width: 4)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 10) {
                // Header: 週次 + 階段名 + 週跑量
                HStack {
                    Text(String(format: NSLocalizedString("training.week_n", comment: "Week N"), week.week))
                        .font(AppFont.bodySmall())
                        .fontWeight(.semibold)

                    Text("·")
                        .foregroundColor(.secondary)

                    Text("\(stageInfo.name) \(stageInfo.positionInStage)/\(stageInfo.totalStageWeeks)")
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)

                    Spacer()

                    if week.isRecovery {
                        Text(NSLocalizedString("training.recovery_week", comment: "Recovery Week"))
                            .font(.caption2)
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(4)
                    }

                    HStack(spacing: 3) {
                        Image(systemName: "figure.run")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(Int(week.targetKmDisplay ?? week.targetKm)) \(week.distanceUnit ?? "km")")
                            .font(AppFont.caption())
                            .fontWeight(.medium)
                    }
                }

                // 強度比例視覺條
                if let ratio = week.intensityRatio {
                    IntensityBarView(ratio: ratio)
                }

                // 長跑 + 品質課
                HStack(spacing: 16) {
                    // 長跑
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("training.workout_type.long_run", comment: "Long Run"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(TrainingTypeDisplayName.longRunDisplay(week.longRun))
                            .font(AppFont.caption())
                            .fontWeight(.medium)
                    }

                    // 品質課
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("training.quality_session", comment: "Quality Session"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(TrainingTypeDisplayName.qualityOptionsDisplay(week.qualityOptions))
                            .font(AppFont.caption())
                            .fontWeight(.medium)
                            .lineLimit(2)
                    }
                }
            }
            .padding(.leading, 12)
            .padding(.vertical, 12)
            .padding(.trailing, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCurrentWeek
                    ? Color.blue.opacity(0.06)
                    : Color(UIColor.secondarySystemGroupedBackground))
        )
    }
}

// MARK: - IntensityBarView

/// 強度比例水平視覺條（低=綠、中=橙、高=紅）
struct IntensityBarView: View {
    let ratio: IntensityDistributionV2

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geometry in
                HStack(spacing: 1) {
                    // 低強度（綠色）
                    if ratio.low > 0 {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.green)
                            .frame(width: geometry.size.width * CGFloat(ratio.low))
                    }
                    // 中強度（橙色）
                    if ratio.medium > 0 {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.orange)
                            .frame(width: geometry.size.width * CGFloat(ratio.medium))
                    }
                    // 高強度（紅色）
                    if ratio.high > 0 {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.red)
                            .frame(width: geometry.size.width * CGFloat(ratio.high))
                    }
                }
            }
            .frame(height: 6)
            .clipShape(RoundedRectangle(cornerRadius: 3))

            // 比例文字標籤
            HStack(spacing: 8) {
                intensityLabel(color: .green, text: "低 \(Int(ratio.low * 100))%")
                intensityLabel(color: .orange, text: "中 \(Int(ratio.medium * 100))%")
                intensityLabel(color: .red, text: "高 \(Int(ratio.high * 100))%")
                Spacer()
            }
        }
    }

    private func intensityLabel(color: Color, text: String) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}
