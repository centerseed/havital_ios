//
//  StartStageSelectionView.swift
//  Havital
//
//  訓練起始階段選擇頁面
//  當用戶的賽事時間較短時（2-12週），提供智能推薦起始階段
//

import SwiftUI

struct StartStageSelectionView: View {
    let weeksRemaining: Int
    let targetDistanceKm: Double
    @ObservedObject private var coordinator = OnboardingCoordinator.shared
    @StateObject private var viewModel = OnboardingFeatureViewModel()

    @State private var selectedStage: TrainingStagePhase?
    @State private var recommendation: StartStageRecommendation
    @Environment(\.dismiss) private var dismiss

    init(weeksRemaining: Int, targetDistanceKm: Double) {
        self.weeksRemaining = weeksRemaining
        self.targetDistanceKm = targetDistanceKm

        // 初始化推薦結果
        let rec = TrainingPlanCalculator.recommendStartStage(
            weeksRemaining: weeksRemaining,
            targetDistanceKm: targetDistanceKm
        )
        _recommendation = State(initialValue: rec)
        _selectedStage = State(initialValue: rec.recommendedStage)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                // 時間提示區塊
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.orange)
                            Text(NSLocalizedString("start_stage.time_notice_title", comment: "訓練時間提醒"))
                                .font(AppFont.headline())
                        }

                        Text(String(format: NSLocalizedString("start_stage.time_notice", comment: "你的賽事在 %d 週後"),
                                   weeksRemaining))
                            .font(AppFont.bodySmall())
                            .foregroundColor(.secondary)

                        // 訓練習慣提醒（重要）
                        // 只在有基礎期選項時顯示（即有足夠週數時）
                        if hasBaseStageOption {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(AppFont.bodySmall())

                                Text(NSLocalizedString("start_stage.training_habit_reminder", comment: "建議有規律訓練習慣的跑者選擇跳過基礎期"))
                                    .font(AppFont.caption())
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // 推薦階段
                Section {
                    VStack(alignment: .leading, spacing: 0) {
                        // 推薦標籤
                        HStack {
                            Text(NSLocalizedString("start_stage.recommendation", comment: "推薦起始階段"))
                                .font(AppFont.caption())
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.accentColor)
                                .cornerRadius(12)
                            Spacer()
                        }
                        .padding(.bottom, 12)

                        // 推薦階段選項卡
                        StageOptionCard(
                            stageName: recommendation.stageName,
                            reason: recommendation.reason,
                            riskLevel: recommendation.riskLevel,
                            isRecommended: true,
                            isSelected: selectedStage == recommendation.recommendedStage
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedStage = recommendation.recommendedStage
                        }
                    }
                    .padding(.vertical, 8)
                }

                // 其他選項
                if !recommendation.alternatives.isEmpty {
                    Section(header: Text(NSLocalizedString("start_stage.other_options", comment: "其他選項"))) {
                        ForEach(recommendation.alternatives) { alternative in
                            VStack(alignment: .leading, spacing: 0) {
                                StageAlternativeCard(
                                    alternative: alternative,
                                    isSelected: selectedStage == alternative.stage
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedStage = alternative.stage
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // 週數分配預覽
                Section(header: Text(NSLocalizedString("start_stage.training_distribution", comment: "訓練週數分配"))) {
                    if let stage = selectedStage {
                        let distribution = TrainingPlanCalculator.calculateTrainingPeriods(
                            trainingWeeks: weeksRemaining,
                            targetDistanceKm: targetDistanceKm,
                            startFromStage: stage
                        )

                        TrainingDistributionView(distribution: distribution, totalWeeks: weeksRemaining)
                    }
                }
            }

            // 底部繼續按鈕
            VStack {
                Button(action: {
                    coordinator.selectedStartStage = selectedStage?.apiIdentifier
                    if let stage = selectedStage {
                        UserDefaults.standard.set(stage.apiIdentifier, forKey: "selectedStartStage")
                    } else {
                        UserDefaults.standard.removeObject(forKey: "selectedStartStage")
                    }

                    // ⭐ 新增：檢查方法論後導航
                    Task {
                        Logger.debug("[StartStageSelectionView] 🎯 Button clicked - selectedTargetTypeV2: \(viewModel.selectedTargetTypeV2?.id ?? "nil")")

                        // 確保有 target type（如果沒有，重新載入）
                        if viewModel.selectedTargetTypeV2 == nil {
                            Logger.debug("[StartStageSelectionView] ⚠️ selectedTargetTypeV2 is nil, loading target types...")
                            await viewModel.loadTargetTypes()

                            if let raceRunType = viewModel.availableTargetTypes.first(where: { $0.isRaceRunTarget }) {
                                viewModel.selectedTargetTypeV2 = raceRunType
                                Logger.debug("[StartStageSelectionView] ✅ Loaded and set selectedTargetTypeV2 to: \(raceRunType.id)")
                            }
                        }

                        if let targetType = viewModel.selectedTargetTypeV2 {
                            Logger.debug("[StartStageSelectionView] 📥 Loading methodologies for: \(targetType.id)")
                            await viewModel.loadMethodologiesForTargetType(targetType.id)

                            await MainActor.run {
                                let methodCount = viewModel.availableMethodologies.count
                                Logger.debug("[StartStageSelectionView] 📊 Loaded \(methodCount) methodologies")

                                if methodCount > 1 {
                                    Logger.info("[StartStageSelectionView] ✅ Navigating to methodologySelection")
                                    coordinator.navigate(to: .methodologySelection)
                                } else {
                                    Logger.info("[StartStageSelectionView] ⏭️ Skipping methodology selection (count=\(methodCount)), navigating to trainingDays")
                                    coordinator.navigate(to: .trainingDays)
                                }
                            }
                        } else {
                            Logger.error("[StartStageSelectionView] ❌ Failed to load targetType, navigating to trainingDays")
                            coordinator.navigate(to: .trainingDays)
                        }
                    }
                }) {
                    Text(NSLocalizedString("start_stage.continue", comment: "繼續"))
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground))
        }
        .navigationTitle(NSLocalizedString("start_stage.title", comment: "訓練計劃起始階段"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // ⭐ 載入 V2 target types 並設置 race_run 類型
            await viewModel.loadTargetTypes()

            // 找到 race_run 目標類型並設置
            if let raceRunType = viewModel.availableTargetTypes.first(where: { $0.isRaceRunTarget }) {
                viewModel.selectedTargetTypeV2 = raceRunType
                Logger.debug("[StartStageSelectionView] ✅ Set selectedTargetTypeV2 to: \(raceRunType.id)")
            }
        }
    }

    /// 判斷是否有基礎期選項可用（用於條件顯示提醒訊息）
    private var hasBaseStageOption: Bool {
        // 基礎期選項只在有足夠週數時提供（≥6週）
        return recommendation.alternatives.contains { $0.stage == .base }
    }
}

// MARK: - 階段選項卡片
struct StageOptionCard: View {
    let stageName: String
    let reason: String
    let riskLevel: TrainingRiskLevel
    let isRecommended: Bool
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 階段名稱
            HStack {
                Text(stageName)
                    .font(AppFont.title3())
                    .fontWeight(.bold)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(AppFont.title3())
                }
            }

            // 推薦理由
            Text(reason)
                .font(AppFont.bodySmall())
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // 風險等級標籤
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(AppFont.caption())
                Text(String(format: NSLocalizedString("start_stage.risk_level", comment: "風險等級: %@"),
                           riskLevel.displayName))
                    .font(AppFont.caption())
            }
            .foregroundColor(riskLevelColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(riskLevelColor.opacity(0.15))
            .cornerRadius(8)
        }
        .padding()
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }

    private var riskLevelColor: Color {
        switch riskLevel {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
}

// MARK: - 替代階段卡片
struct StageAlternativeCard: View {
    let alternative: StageAlternative
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(alternative.stageName)
                    .font(AppFont.headline())

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }

            Text(alternative.suitableFor)
                .font(AppFont.bodySmall())
                .foregroundColor(.primary)

            Text(alternative.description)
                .font(AppFont.caption())
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - 訓練週數分配視圖
struct TrainingDistributionView: View {
    let distribution: TrainingDistribution
    let totalWeeks: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 週數長條圖
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    if distribution.baseWeeks > 0 {
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * CGFloat(distribution.baseWeeks) / CGFloat(totalWeeks))
                    }

                    if distribution.buildWeeks > 0 {
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: geometry.size.width * CGFloat(distribution.buildWeeks) / CGFloat(totalWeeks))
                    }

                    if distribution.peakWeeks > 0 {
                        Rectangle()
                            .fill(Color.orange)
                            .frame(width: geometry.size.width * CGFloat(distribution.peakWeeks) / CGFloat(totalWeeks))
                    }

                    if distribution.taperWeeks > 0 {
                        Rectangle()
                            .fill(Color.purple)
                            .frame(width: geometry.size.width * CGFloat(distribution.taperWeeks) / CGFloat(totalWeeks))
                    }
                }
            }
            .frame(height: 30)
            .cornerRadius(8)

            // 階段說明
            VStack(alignment: .leading, spacing: 6) {
                if distribution.baseWeeks > 0 {
                    StageDistributionRow(
                        color: .blue,
                        stageName: NSLocalizedString("stage.base", comment: "基礎期"),
                        weeks: distribution.baseWeeks
                    )
                }

                if distribution.buildWeeks > 0 {
                    StageDistributionRow(
                        color: .green,
                        stageName: NSLocalizedString("stage.build", comment: "增強期"),
                        weeks: distribution.buildWeeks
                    )
                }

                if distribution.peakWeeks > 0 {
                    StageDistributionRow(
                        color: .orange,
                        stageName: NSLocalizedString("stage.peak", comment: "巔峰期"),
                        weeks: distribution.peakWeeks
                    )
                }

                if distribution.taperWeeks > 0 {
                    StageDistributionRow(
                        color: .purple,
                        stageName: NSLocalizedString("stage.taper", comment: "減量期"),
                        weeks: distribution.taperWeeks
                    )
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct StageDistributionRow: View {
    let color: Color
    let stageName: String
    let weeks: Int

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(stageName)
                .font(AppFont.caption())
                .foregroundColor(.secondary)

            Spacer()

            Text(String(format: NSLocalizedString("start_stage.weeks_count", comment: "%d 週"), weeks))
                .font(AppFont.caption())
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview
struct StartStageSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            StartStageSelectionView(
                weeksRemaining: 8,
                targetDistanceKm: 21.1
            )
        }
    }
}
