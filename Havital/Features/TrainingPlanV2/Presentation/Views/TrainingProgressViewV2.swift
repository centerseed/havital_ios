import SwiftUI

/// V2 訓練進度 Sheet - 顯示各階段週次列表，支援週次切換與歷史回顧
struct TrainingProgressViewV2: View {
    var viewModel: TrainingPlanV2ViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStageIndex: Int? = nil

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 當前訓練進度概覽
                    currentTrainingStatusCard

                    // 各階段訓練進度
                    trainingStagesSection
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
        .onAppear {
            expandCurrentStage()
        }
        .task {
            if viewModel.weeklySummaries.isEmpty {
                await viewModel.fetchWeeklySummaries()
            }
        }
    }

    // MARK: - 當前訓練進度卡片

    private var currentTrainingStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let overview = viewModel.planOverview, overview.totalWeeks > 0 {
                let totalWeeks = overview.totalWeeks
                let currentWeek = viewModel.currentWeek
                let progress = min(Double(currentWeek) / Double(totalWeeks), 1.0)

                HStack {
                    Text(NSLocalizedString("training.current_progress", comment: "Current Progress"))
                        .font(AppFont.headline())

                    Spacer()

                    Text(String(format: NSLocalizedString("training.current_week_of_total", comment: "Week %d / %d"), currentWeek, totalWeeks))
                        .font(AppFont.bodySmall())
                        .foregroundColor(.secondary)
                }

                // 進度條
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 12)

                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [.blue, .cyan]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(geometry.size.width * CGFloat(progress), 0), height: 12)
                    }
                }
                .frame(height: 12)

                // 當前階段
                if let currentStage = getCurrentStage(from: overview, currentWeek: currentWeek) {
                    HStack(alignment: .center, spacing: 12) {
                        Circle()
                            .fill(getStageColor(stageId: currentStage.stageId))
                            .frame(width: 12, height: 12)

                        Text(String(format: NSLocalizedString("training.current_stage", comment: "Current Stage: %@"), currentStage.stageName))
                            .font(AppFont.bodySmall())
                            .fontWeight(.medium)

                        Spacer()

                        Text(String(format: NSLocalizedString("training.week_range", comment: "Week %d-%d"), currentStage.weekStart, currentStage.weekEnd))
                            .font(AppFont.caption())
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text(NSLocalizedString("training.cannot_get_progress", comment: "Cannot Get Progress"))
                    .font(AppFont.body())
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - 各階段區塊

    private var trainingStagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("training.training_stages", comment: "Training Stages"))
                .font(AppFont.headline())

            if let overview = viewModel.planOverview {
                let currentWeek = viewModel.currentWeek
                ForEach(overview.trainingStages.indices, id: \.self) { index in
                    let stage = overview.trainingStages[index]
                    let isCurrentStage = currentWeek >= stage.weekStart && currentWeek <= stage.weekEnd

                    stageSection(stage: stage, index: index, isCurrentStage: isCurrentStage)
                }
            } else {
                Text(NSLocalizedString("training.cannot_get_stages", comment: "Cannot Get Stages"))
                    .font(AppFont.body())
                    .foregroundColor(.secondary)
            }
        }
    }

    private func stageSection(stage: TrainingStageV2, index: Int, isCurrentStage: Bool) -> some View {
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
                        .fill(getStageColor(stageId: stage.stageId))
                        .frame(width: 16, height: 16)

                    Text(stage.stageName)
                        .font(AppFont.bodySmall())
                        .fontWeight(.semibold)
                        .foregroundColor(isCurrentStage ? .primary : .secondary)

                    Spacer()

                    Text(String(format: NSLocalizedString("training.week_range", comment: "Week %d-%d"), stage.weekStart, stage.weekEnd))
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)

                    Image(systemName: selectedStageIndex == index ? "chevron.up" : "chevron.down")
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(isCurrentStage ? getStageColor(stageId: stage.stageId).opacity(0.1) : Color.clear)
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())

            // 展開的週次詳情
            if selectedStageIndex == index {
                VStack(spacing: 4) {
                    Text(stage.stageDescription)
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)

                    Divider()
                        .padding(.horizontal, 16)

                    weeklyDetailsList(startWeek: stage.weekStart, endWeek: stage.weekEnd)
                }
                .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
                .cornerRadius(8)
            }
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCurrentStage ? getStageColor(stageId: stage.stageId) : Color.clear, lineWidth: 1)
        )
        .padding(.bottom, 8)
    }

    // MARK: - 週次詳情列表

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

    private func weekRow(weekNumber: Int) -> some View {
        let isCurrentWeek = viewModel.currentWeek == weekNumber
        let isFutureWeek = weekNumber > viewModel.currentWeek

        // 從批次資料判斷各週是否有課表/回顧
        let weekSummaryItem = viewModel.weeklySummaries.first { $0.weekIndex == weekNumber }
        let hasWeekPlan = weekSummaryItem?.weekPlan != nil
        let hasSummary = weekSummaryItem?.weekSummary != nil

        // 若批次資料尚未載入，fallback 到位置推斷
        let summariesLoaded = !viewModel.weeklySummaries.isEmpty
        let showSchedule = summariesLoaded ? hasWeekPlan : !isFutureWeek
        let showReview = summariesLoaded ? hasSummary : false

        // 骨架資料：只對當前週及未來週顯示
        let skeletonWeek = weekNumber >= viewModel.currentWeek
            ? viewModel.weeklyPreview?.weeks.first { $0.week == weekNumber }
            : nil

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(String(format: NSLocalizedString("training.week_number", comment: "Week %d"), weekNumber))
                    .font(AppFont.bodySmall())
                    .fontWeight(isCurrentWeek ? .bold : .regular)
                    .foregroundColor(isCurrentWeek ? .primary : (isFutureWeek && summariesLoaded ? Color.secondary.opacity(0.5) : .secondary))

                if let skeleton = skeletonWeek {
                    HStack(spacing: 3) {
                        Image(systemName: "figure.run")
                            .font(AppFont.caption2())
                            .foregroundColor(.secondary)
                        Text("\(Int(skeleton.targetKmDisplay ?? skeleton.targetKm)) \(skeleton.distanceUnit ?? "km")")
                            .font(AppFont.caption())
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    if showReview {
                        Button {
                            Task {
                                await viewModel.viewHistoricalSummary(week: weekNumber)
                            }
                        } label: {
                            HStack(alignment: .center, spacing: 4) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(AppFont.systemScaled(size: 12, weight: .medium))
                                Text(NSLocalizedString("training_progress.review", comment: "Review"))
                                    .font(AppFont.footnote())
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

                    if showSchedule {
                        Button {
                            Task {
                                await viewModel.switchToWeek(weekNumber)
                                dismiss()
                            }
                        } label: {
                            HStack(alignment: .center, spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(AppFont.systemScaled(size: 12, weight: .medium))
                                Text(NSLocalizedString("training_progress.schedule", comment: "Schedule"))
                                    .font(AppFont.footnote())
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
                }
            }

            if let skeleton = skeletonWeek {
                if skeleton.isRecovery {
                    HStack(spacing: 12) {
                        Text(NSLocalizedString("training.recovery_week", comment: "恢復週"))
                            .font(AppFont.caption2())
                            .foregroundColor(.green)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(4)

                        Spacer()
                    }
                }

                let longRunDisplay = TrainingTypeDisplayName.longRunDisplay(skeleton.longRun)
                let qualityDisplay = TrainingTypeDisplayName.qualityOptionsDisplay(skeleton.qualityOptions)

                if longRunDisplay != "—" || qualityDisplay != "—" {
                    HStack(spacing: 12) {
                        if longRunDisplay != "—" {
                            HStack(spacing: 4) {
                                Text(NSLocalizedString("training.workout_type.long_run", comment: "長跑:"))
                                    .font(AppFont.caption2())
                                    .foregroundColor(.secondary)
                                Text(longRunDisplay)
                                    .font(AppFont.caption2())
                                    .fontWeight(.medium)
                            }
                        }
                        if qualityDisplay != "—" {
                            HStack(spacing: 4) {
                                Text(NSLocalizedString("training.quality_session", comment: "品質課:"))
                                    .font(AppFont.caption2())
                                    .foregroundColor(.secondary)
                                Text(qualityDisplay)
                                    .font(AppFont.caption2())
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(isCurrentWeek ? Color.blue.opacity(0.05) : Color.clear)
    }

    // MARK: - Helpers

    private func getCurrentStage(from overview: PlanOverviewV2, currentWeek: Int) -> (stageId: String, stageName: String, weekStart: Int, weekEnd: Int)? {
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

    private func expandCurrentStage() {
        guard let overview = viewModel.planOverview else { return }
        let currentWeek = viewModel.currentWeek
        for (index, stage) in overview.trainingStages.enumerated() {
            if currentWeek >= stage.weekStart && currentWeek <= stage.weekEnd {
                selectedStageIndex = index
                break
            }
        }
    }
}
