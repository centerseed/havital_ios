import SwiftUI

struct WeekOverviewCard: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    @Environment(\.colorScheme) var colorScheme
    let plan: WeeklyPlan
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var showWeekSelector = false
    @State private var showTrainingProgress = false
    @State private var isExpanded = false  // 控制展開/摺疊

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 摺疊/展開按鈕
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(alignment: .center, spacing: 8) {
                    // 圖示
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.blue)
                        .font(.headline)

                    if isExpanded {
                        // 展開狀態：顯示標題
                        Text(NSLocalizedString("training_plan.week_overview", comment: "Week Overview"))
                            .font(.headline)
                            .foregroundColor(.primary)
                    } else {
                        // 摺疊狀態：顯示精簡信息
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("第 \(plan.weekOfPlan)/\(viewModel.trainingOverview?.totalWeeks ?? plan.totalWeeks) 週")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Text("·")
                                    .foregroundColor(.secondary)

                                Text(viewModel.formatDistance(viewModel.currentWeekDistance, unit: nil))
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Text("/")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Text(viewModel.formatDistance(plan.totalDistance, unit: nil))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Text("·")
                                    .foregroundColor(.secondary)

                                let percentage = Int((viewModel.currentWeekDistance / max(plan.totalDistance, 1.0)) * 100)
                                Text("\(percentage)%")
                                    .font(.headline)
                                    .foregroundColor(percentage >= 80 ? .green : (percentage >= 50 ? .orange : .blue))
                            }
                        }
                    }

                    Spacer()

                    // 展開/收起圖示
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(.horizontal, 4)
            }
            .buttonStyle(PlainButtonStyle())

            // 摺疊狀態的進度條和迷你強度分布
            if !isExpanded {
                let progress = min(viewModel.currentWeekDistance / max(plan.totalDistance, 1.0), 1.0)
                let percentage = Int(progress * 100)

                VStack(spacing: 8) {
                    // 距離進度條
                    ProgressView(value: progress)
                        .tint(percentage >= 80 ? .green : (percentage >= 50 ? .orange : .blue))
                        .scaleEffect(y: 1.5)

                    // 迷你強度分布（3個小橫條）
                    if let intensity = plan.intensityTotalMinutes {
                        HStack(spacing: 6) {
                            // 低強度
                            MiniIntensityBar(
                                label: NSLocalizedString("training.low_intensity", comment: "Low"),
                                minutes: viewModel.currentWeekIntensity?.low ?? 0,
                                targetMinutes: intensity.low,
                                color: .green
                            )

                            // 中強度
                            MiniIntensityBar(
                                label: NSLocalizedString("training.medium_intensity", comment: "Medium"),
                                minutes: viewModel.currentWeekIntensity?.medium ?? 0,
                                targetMinutes: intensity.medium,
                                color: .orange
                            )

                            // 高強度
                            MiniIntensityBar(
                                label: NSLocalizedString("training.high_intensity", comment: "High"),
                                minutes: viewModel.currentWeekIntensity?.high ?? 0,
                                targetMinutes: intensity.high,
                                color: .red
                            )
                        }
                    }
                }
            }

            // 展開狀態的完整內容
            if isExpanded {
                VStack(spacing: 16) {
                    // 週進度條（合併在頂部）
                    if plan.intensityTotalMinutes != nil {
                        WeekProgressHeader(
                            plan: plan,
                            overview: viewModel.trainingOverview,
                            showWeekSelector: $showWeekSelector,
                            showTrainingProgress: $showTrainingProgress
                        )
                    }

                    // 標題
                    Text(ViewModelUtils.isCurrentLanguageChinese()
                         ? NSLocalizedString("training_plan.weekly_volume_load_zh", comment: "週跑量和訓練強度")
                         : NSLocalizedString("training_plan.weekly_volume_load", comment: "Weekly Volume and Training Intensity"))
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // 進度圓環和強度進度條（橫向佈局）
                    if let intensity = plan.intensityTotalMinutes {
                        ProgressWithIntensitySection(
                            plan: plan,
                            planIntensity: intensity,
                            actualIntensity: viewModel.currentWeekIntensity,
                            currentWeekDistance: viewModel.currentWeekDistance,
                            formatDistance: { viewModel.formatDistance($0, unit: nil) },
                            showTrainingProgress: $showTrainingProgress
                        )
                    } else {
                        ProgressCirclesSection(
                            plan: plan,
                            overview: viewModel.trainingOverview,
                            currentWeekDistance: viewModel.currentWeekDistance,
                            formatDistance: { viewModel.formatDistance($0, unit: nil) },
                            showWeekSelector: $showWeekSelector,
                            showTrainingProgress: $showTrainingProgress
                        )
                    }

                    // 訓練目的
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text(NSLocalizedString("training_plan.week_target", comment: "Week Target"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }

                        Text(plan.purpose)
                            .font(.body)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.tertiarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .sheet(isPresented: $showWeekSelector) {
            WeekSelectorSheet(viewModel: viewModel, isPresented: $showWeekSelector)
        }
        .sheet(isPresented: $showTrainingProgress) {
            TrainingProgressView(viewModel: viewModel)
        }
    }
}

// MARK: - 迷你強度條組件
struct MiniIntensityBar: View {
    let label: String
    let minutes: Int
    let targetMinutes: Int
    let color: Color

    private var progress: Double {
        guard targetMinutes > 0 else { return 0 }
        return min(Double(minutes) / Double(targetMinutes), 1.0)
    }

    private var isUnscheduled: Bool {
        targetMinutes == 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // 標籤和數字
            HStack(spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(isUnscheduled ? .secondary.opacity(0.7) : .secondary)

                Spacer()

                Text("\(minutes)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(isUnscheduled ? .secondary.opacity(0.7) : .primary)
            }

            // 進度條
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))

                    // 進度
                    if !isUnscheduled {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color)
                            .frame(width: geometry.size.width * progress)
                    }
                }
            }
            .frame(height: 4)
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


