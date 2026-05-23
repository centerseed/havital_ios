import SwiftUI

// MARK: - EditTargetStageSelectionView

/// 修改目標後的起始階段選擇 Sheet（不依賴 OnboardingCoordinator）
/// Extracted from PlanOverviewSheetV2.swift — used by TrainingOverviewV2View.
struct EditTargetStageSelectionView: View {
    let weeksRemaining: Int
    let targetDistanceKm: Double
    let onConfirm: (String?) -> Void

    @State private var selectedStage: TrainingStagePhase?
    @State private var recommendation: StartStageRecommendation
    @Environment(\.dismiss) private var dismiss

    init(weeksRemaining: Int, targetDistanceKm: Double, onConfirm: @escaping (String?) -> Void) {
        self.weeksRemaining = weeksRemaining
        self.targetDistanceKm = targetDistanceKm
        self.onConfirm = onConfirm

        let rec = TrainingPlanCalculator.recommendStartStage(
            weeksRemaining: weeksRemaining,
            targetDistanceKm: targetDistanceKm
        )
        _recommendation = State(initialValue: rec)
        _selectedStage = State(initialValue: rec.recommendedStage)
    }

    var body: some View {
        NavigationStack {
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
                                StageAlternativeCard(
                                    alternative: alternative,
                                    isSelected: selectedStage == alternative.stage
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedStage = alternative.stage
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

                // 底部確認按鈕
                VStack {
                    Button(action: {
                        onConfirm(selectedStage?.apiIdentifier)
                    }) {
                        Text(NSLocalizedString("common.confirm", comment: "確認"))
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("common.close", comment: "關閉")) {
                        dismiss()
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
        }
    }

    private var hasBaseStageOption: Bool {
        recommendation.alternatives.contains { $0.stage == .base }
    }
}
