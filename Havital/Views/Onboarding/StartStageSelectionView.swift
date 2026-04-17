//
//  StartStageSelectionView.swift
//  Havital
//
//  訓練起始階段選擇頁面
//  當用戶的賽事時間較短時（2-12週），提供智能推薦起始階段
//  Refactored to use shared OnboardingFeatureViewModel via @EnvironmentObject
//

import SwiftUI

struct StartStageSelectionView: View {
    let weeksRemaining: Int
    let targetDistanceKm: Double
    @ObservedObject private var coordinator = OnboardingCoordinator.shared
    @EnvironmentObject private var viewModel: OnboardingFeatureViewModel

    @State private var selectedStage: TrainingStagePhase?
    @State private var recommendation: StartStageRecommendation
    @Environment(\.dismiss) private var dismiss

    init(weeksRemaining: Int, targetDistanceKm: Double) {
        self.weeksRemaining = weeksRemaining
        self.targetDistanceKm = targetDistanceKm

        let rec = TrainingPlanCalculator.recommendStartStage(
            weeksRemaining: weeksRemaining,
            targetDistanceKm: targetDistanceKm
        )
        _recommendation = State(initialValue: rec)
        _selectedStage = State(initialValue: rec.recommendedStage)
    }

    var body: some View {
        OnboardingPageTemplate(
            ctaTitle: NSLocalizedString("start_stage.continue", comment: "繼續"),
            ctaEnabled: selectedStage != nil,
            isLoading: false,
            skipTitle: nil,
            ctaAccessibilityId: "StartStage_NextButton",
            ctaAction: {
                coordinator.selectedStartStage = selectedStage?.apiIdentifier
                if let stage = selectedStage {
                    UserDefaults.standard.set(stage.apiIdentifier, forKey: OnboardingCoordinator.startStageUserDefaultsKey)
                } else {
                    UserDefaults.standard.removeObject(forKey: OnboardingCoordinator.startStageUserDefaultsKey)
                }
                coordinator.navigate(to: .trainingDays)
            },
            skipAction: nil
        ) {
            VStack(alignment: .leading, spacing: OnboardingLayout.sectionSpacing) {
                // 時間提示區塊
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

                // 推薦階段
                VStack(alignment: .leading, spacing: 0) {
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

                    StageOptionCard(
                        stageName: recommendation.stageName,
                        reason: recommendation.reason,
                        riskLevel: recommendation.riskLevel,
                        isRecommended: true,
                        isSelected: selectedStage == recommendation.recommendedStage
                    )
                    .accessibilityIdentifier("StartStage_\(recommendation.recommendedStage.apiIdentifier)")
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedStage = recommendation.recommendedStage
                    }
                }
                .padding(.vertical, 8)

                // 其他選項
                if !recommendation.alternatives.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("start_stage.other_options", comment: "其他選項"))
                            .font(AppFont.caption())
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        ForEach(recommendation.alternatives) { alternative in
                            VStack(alignment: .leading, spacing: 0) {
                                StageAlternativeCard(
                                    alternative: alternative,
                                    isSelected: selectedStage == alternative.stage
                                )
                                .accessibilityIdentifier("StartStage_\(alternative.stage.apiIdentifier)")
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
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("start_stage.training_distribution", comment: "訓練週數分配"))
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

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
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("StartStage_Screen")
        .navigationTitle(NSLocalizedString("start_stage.title", comment: "訓練計劃起始階段"))
        .task {
            await viewModel.loadTargetTypes()

            if let targetTypeId = coordinator.selectedTargetTypeId,
               let targetType = viewModel.availableTargetTypes.first(where: { $0.id == targetTypeId }) {
                viewModel.selectedTargetTypeV2 = targetType
                Logger.debug("[StartStageSelectionView] Set selectedTargetTypeV2 to: \(targetType.id)")
            } else if let raceRunType = viewModel.availableTargetTypes.first(where: { $0.isRaceRunTarget }) {
                viewModel.selectedTargetTypeV2 = raceRunType
                Logger.debug("[StartStageSelectionView] Fallback: Set selectedTargetTypeV2 to race_run: \(raceRunType.id)")
            }
        }
    }

    private var hasBaseStageOption: Bool {
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

            Text(reason)
                .font(AppFont.bodySmall())
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

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
