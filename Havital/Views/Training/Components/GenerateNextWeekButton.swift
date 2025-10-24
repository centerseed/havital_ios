import SwiftUI

/// 產生下週課表按鈕
/// 週六、週日顯示，用於提前產生下週課表
struct GenerateNextWeekButton: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    let nextWeekInfo: NextWeekInfo

    var body: some View {
        VStack(spacing: 16) {
            // 標題
            Text("🎯 準備好下週訓練了嗎？")
                .font(.headline)
                .foregroundColor(.primary)

            // 按鈕
            Button {
                Task {
                    await viewModel.generateNextWeekPlan(nextWeekInfo: nextWeekInfo)
                }
            } label: {
                VStack(spacing: 8) {
                    Text("產生第\(nextWeekInfo.weekNumber)週課表")
                        .font(.headline)

                    // 提示文字
                    if nextWeekInfo.requiresCurrentWeekSummary {
                        HStack(spacing: 4) {
                            Image(systemName: "lightbulb.fill")
                            Text("需要先完成本週回顧")
                        }
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("本週回顧已完成")
                        }
                        .font(.caption)
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
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.left.circle.fill")
                    .font(.body)
                Text("返回本週（第\(viewModel.currentWeek)週）")
                    .font(.subheadline)
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
                    .font(.title3)
                    .foregroundColor(.green)

                Text(message)
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            if isPresented {
                Button("返回本週") {
                    isPresented = false
                }
                .font(.subheadline)
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
