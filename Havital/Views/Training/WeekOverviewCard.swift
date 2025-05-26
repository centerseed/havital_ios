import SwiftUI

struct WeekOverviewCard: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    @Environment(\.colorScheme) var colorScheme
    let plan: WeeklyPlan
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var showWeekSelector = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("本週概覽")
                .font(.headline)
                .padding(.horizontal, 4)
            
            // 卡片內容
            VStack(spacing: 0) {
                // 主要內容
                VStack(spacing: 16) {
                    // 當有強度數據時才顯示頂部進度條
                    if plan.intensityTotalMinutes != nil {
                        WeekProgressHeader(plan: plan, showWeekSelector: $showWeekSelector)
                    }

                    HStack(spacing: 8) {
                        Text("本週跑量和訓練負荷")
                            .font(.system(size: 14, weight: .bold))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    
                    // 進度圓環和強度進度條
                    if let intensity = plan.intensityTotalMinutes {
                        // 有強度數據時顯示跑量環和強度進度條
                        ProgressWithIntensitySection(
                            plan: plan,
                            planIntensity: intensity,                // 計劃目標值
                            actualIntensity: viewModel.currentWeekIntensity, // 實際計算出的值
                            currentWeekDistance: viewModel.currentWeekDistance,
                            formatDistance: { viewModel.formatDistance($0, unit: nil) }
                        )
                    } else {
                        // 沒有強度數據時顯示週進度環和跑量環
                        ProgressCirclesSection(
                            plan: plan,
                            currentWeekDistance: viewModel.currentWeekDistance,
                            formatDistance: { viewModel.formatDistance($0, unit: nil) },
                            showWeekSelector: $showWeekSelector
                        )
                    }
                    
                    // 訓練目的
                    VStack(alignment: .leading, spacing: 2) {
                        Text("週目標")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        Text(plan.purpose)
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, 4)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.tertiarySystemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
        }
        .sheet(isPresented: $showWeekSelector) {
            WeekSelectorSheet(viewModel: viewModel, isPresented: $showWeekSelector)
        }
        .sheet(isPresented: $viewModel.showWeeklySummary) {
            if let summary = viewModel.weeklySummary {
                WeeklySummaryView(
                    summary: summary,
                    weekNumber: viewModel.lastFetchedWeekNumber,
                    isVisible: $viewModel.showWeeklySummary
                )
            }
        }
    }
}

// MARK: - 預覽
#Preview {
    WeekOverviewCard(
        viewModel: TrainingPlanViewModel(),
        plan: WeeklyPlan(
            id: "preview",
            purpose: "預覽測試",
            weekOfPlan: 1,
            totalWeeks: 12,
            totalDistance: 50.0,
            designReason: ["測試用"],
            days: [],
            intensityTotalMinutes: WeeklyPlan.IntensityTotalMinutes(low: 120, medium: 45, high: 15)
        )
    )
    .environmentObject(HealthKitManager())
}


