import SwiftUI

/// 產生下週課表按鈕
/// 週六、週日顯示，用於提前產生下週課表
struct GenerateNextWeekButton: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    let nextWeekInfo: NextWeekInfo
    @State private var showConfirmation = false

    var body: some View {
        VStack(spacing: 16) {
            // 標題
            Text(NSLocalizedString("training.ready_for_next_week", comment: "🎯 準備好下週訓練了嗎？"))
                .font(AppFont.headline())
                .foregroundColor(.primary)

            // 按鈕
            Button {
                // 顯示確認對話框
                Logger.debug("🖱️ [GenerateNextWeekButton] 按鈕被點擊，顯示確認對話框")
                showConfirmation = true
            } label: {
                VStack(spacing: 8) {
                    Text(String(format: NSLocalizedString("training.generate_week_plan", comment: "產生第%d週課表"), nextWeekInfo.weekNumber))
                        .font(AppFont.headline())

                    // 提示文字
                    if nextWeekInfo.requiresCurrentWeekSummary {
                        HStack(spacing: 4) {
                            Image(systemName: "lightbulb.fill")
                            Text(NSLocalizedString("training.need_complete_review", comment: "需要先完成本週回顧"))
                        }
                        .font(AppFont.caption())
                        .foregroundColor(.white.opacity(0.8))
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text(NSLocalizedString("training.review_completed", comment: "本週回顧已完成"))
                        }
                        .font(AppFont.caption())
                        .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(viewModel.isLoading || viewModel.isLoadingAnimation)
            .alert(
                NSLocalizedString("training.confirm_training_completed_title", comment: "確認訓練完成"),
                isPresented: $showConfirmation
            ) {
                Button(NSLocalizedString("common.cancel", comment: "取消"), role: .cancel) {
                    Logger.debug("❌ [GenerateNextWeekButton] 用戶取消產生課表")
                }
                Button(NSLocalizedString("common.confirm", comment: "確認")) {
                    Logger.debug("✅ [GenerateNextWeekButton] 用戶確認產生課表")
                    Task {
                        await viewModel.generateNextWeekPlan(nextWeekInfo: nextWeekInfo)
                    }.tracked(from: "GenerateNextWeekButton: generateNextWeekPlan")
                }
            } message: {
                Text(NSLocalizedString("training.confirm_training_completed_message", comment: "請確認本週訓練是否皆已完成？產生週回顧需要本週的完整訓練數據才能獲得準確的分析。"))
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

/// 返回本週按鈕
/// 當用戶查看未來週課表時顯示，提供快速返回當前週的功能
struct ReturnToCurrentWeekButton: View {
    @ObservedObject var viewModel: TrainingPlanViewModel

    var body: some View {
        Button {
            Task {
                await viewModel.fetchWeekPlan(week: viewModel.currentWeek)
            }.tracked(from: "ReturnToCurrentWeekButton: fetchWeekPlan")
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.left.circle.fill")
                    .font(AppFont.body())
                Text("返回本週（第\(viewModel.currentWeek)週）")
                    .font(AppFont.bodySmall())
            }
            .foregroundColor(.blue)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
    }
}

/// 成功 Toast 通知
struct SuccessToast: View {
    let message: String
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(AppFont.title3())
                    .foregroundColor(.green)

                Text(message)
                    .font(AppFont.headline())
                    .foregroundColor(.primary)
            }

            if isPresented {
                Button("返回本週") {
                    isPresented = false
                }
                .font(AppFont.bodySmall())
                .foregroundColor(.blue)
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }
}

/// 資訊 Toast 通知（用於顯示處理中狀態）
struct InfoToast: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.blue)

            Text(message)
                .font(AppFont.bodySmall())
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }
}

// MARK: - Preview

struct GenerateNextWeekButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // 需要先產生週回顧
            GenerateNextWeekButton(
                viewModel: TrainingPlanViewModel(),
                nextWeekInfo: NextWeekInfo(
                    weekNumber: 4,
                    hasPlan: false,
                    canGenerate: true,
                    requiresCurrentWeekSummary: true,
                    nextAction: "create_summary_for_week_3"
                )
            )

            // 可直接產生課表
            GenerateNextWeekButton(
                viewModel: TrainingPlanViewModel(),
                nextWeekInfo: NextWeekInfo(
                    weekNumber: 4,
                    hasPlan: false,
                    canGenerate: true,
                    requiresCurrentWeekSummary: false,
                    nextAction: "create_plan_for_week_4"
                )
            )

            // 返回本週按鈕
            ReturnToCurrentWeekButton(viewModel: TrainingPlanViewModel())

            // 成功 Toast
            SuccessToast(
                message: "第4週課表已產生！",
                isPresented: .constant(true)
            )
        }
        .padding()
    }
}
