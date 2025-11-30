import SwiftUI

struct WeekOverviewCard: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    @Environment(\.colorScheme) var colorScheme
    let plan: WeeklyPlan
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var showWeekTargetDetail = false
    @State private var showTrainingCalendar = false

    private var weekProgress: Double {
        guard plan.totalDistance > 0 else { return 0 }
        return min(viewModel.currentWeekDistance / plan.totalDistance, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 標題（更換 icon）
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(.blue)
                    .font(.headline)

                Text(NSLocalizedString("training_plan.weekly_volume_and_intensity", comment: "週跑量和訓練強度"))
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            // 上半部：圓形進度 + 可點擊項目（居中佈局）
            HStack(spacing: 0) {
                Spacer()

                // 左側：圓形週跑量進度（縮小並調整文字位置）
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 9)
                        .frame(width: 90, height: 90)

                    Circle()
                        .trim(from: 0, to: weekProgress)
                        .stroke(
                            Color.blue,
                            style: StrokeStyle(lineWidth: 9, lineCap: .round)
                        )
                        .frame(width: 90, height: 90)
                        .rotationEffect(.degrees(-90))

                    // 文字稍微下移，爭取最大寬度空間
                    VStack(spacing: 2) {
                        HStack(spacing: 1) {
                            Text(viewModel.formatDistance(viewModel.currentWeekDistance, unit: nil))
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.primary)
                                .minimumScaleFactor(0.8)
                                .lineLimit(1)

                            Text("/")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)

                            Text(viewModel.formatDistance(plan.totalDistance, unit: nil))
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .minimumScaleFactor(0.8)
                                .lineLimit(1)
                        }

                        Text("km")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .offset(y: 3)  // 下移 3pt
                }

                Spacer()

                // 右側：本週目標和訓練日曆按鈕
                VStack(alignment: .leading, spacing: 10) {
                    // 本週目標
                    Button(action: {
                        showWeekTargetDetail = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "target")
                                .foregroundColor(.blue)
                                .font(.subheadline)

                            Text(NSLocalizedString("training_plan.week_target", comment: "Week Target"))
                                .font(.subheadline)
                                .foregroundColor(.primary)

                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())

                    // 訓練日曆
                    Button(action: {
                        showTrainingCalendar = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .foregroundColor(.green)
                                .font(.subheadline)

                            Text(NSLocalizedString("training_plan.training_calendar", comment: "Training Calendar"))
                                .font(.subheadline)
                                .foregroundColor(.primary)

                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Spacer()
            }

            // 下半部：強度分布（一行三個進度條，移除標題）
            if let intensity = plan.intensityTotalMinutes {
                HStack(spacing: 12) {
                    // 低強度
                    CompactIntensityBar(
                        label: NSLocalizedString("intensity.low", comment: "Low"),
                        current: Int(viewModel.currentWeekIntensity.low),
                        target: Int(intensity.low),
                        color: .green
                    )

                    // 中強度
                    CompactIntensityBar(
                        label: NSLocalizedString("intensity.medium", comment: "Medium"),
                        current: Int(viewModel.currentWeekIntensity.medium),
                        target: Int(intensity.medium),
                        color: .orange
                    )

                    // 高強度
                    CompactIntensityBar(
                        label: NSLocalizedString("intensity.high", comment: "High"),
                        current: Int(viewModel.currentWeekIntensity.high),
                        target: Int(intensity.high),
                        color: .red
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.tertiarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .sheet(isPresented: $showWeekTargetDetail) {
            NavigationView {
                WeekTargetDetailView(purpose: plan.purpose, designReason: plan.designReason)
            }
        }
        .sheet(isPresented: $showTrainingCalendar) {
            NavigationView {
                TrainingCalendarView()
            }
        }
    }
}

// MARK: - 緊湊型強度條組件
struct CompactIntensityBar: View {
    let label: String
    let current: Int
    let target: Int
    let color: Color

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(Double(current) / Double(target), 1.0)
    }

    private var isUnscheduled: Bool {
        target == 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 標籤和數字
            Text("\(label) \(current)/\(target)")
                .font(.caption)
                .foregroundColor(isUnscheduled ? .secondary.opacity(0.7) : .secondary)

            // 自定義進度條（確保截圖時顏色正確）
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)

                    // 前景進度
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isUnscheduled ? Color.gray.opacity(0.3) : color)
                        .frame(width: geometry.size.width * progress, height: 4)
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - 週目標詳情視圖（整合週目標和設計原因）
struct WeekTargetDetailView: View {
    let purpose: String
    let designReason: [String]?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 週目標區域
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "target")
                            .foregroundColor(.blue)
                            .font(.title3)

                        Text(NSLocalizedString("training_plan.week_target", comment: "Week Target"))
                            .font(.headline)
                            .foregroundColor(.primary)
                    }

                    Text(purpose)
                        .font(.body)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 4)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.08))
                )

                // 設計原因區域（如果有的話）
                if let designReason = designReason, !designReason.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb.circle.fill")
                                .foregroundColor(.orange)
                                .font(.title3)

                            Text(NSLocalizedString("training.design_reason", comment: "Design Reason"))
                                .font(.headline)
                                .foregroundColor(.primary)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(designReason.enumerated()), id: \.offset) { index, reason in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("\(index + 1).")
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundColor(.orange)

                                    Text(reason)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(.leading, 4)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.orange.opacity(0.08))
                    )
                }
            }
            .padding()
        }
        .navigationTitle(NSLocalizedString("training_plan.week_target", comment: "Week Target"))
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

// MARK: - 預覽
#Preview {
    WeekOverviewCard(
        viewModel: TrainingPlanViewModel(),
        plan: WeeklyPlan(
            id: "preview",
            purpose: "本週目標是讓身體在速度與耐力上達到更佳的平衡，為接下來的挑戰累積能量。",
            weekOfPlan: 35,
            totalWeeks: 39,
            totalDistance: 43.0,
            designReason: [
                "根據上週訓練狀況調整強度",
                "增加間歇訓練以提升速度",
                "保持充足恢復時間"
            ],
            days: [],
            intensityTotalMinutes: WeeklyPlan.IntensityTotalMinutes(low: 246, medium: 60, high: 39)
        )
    )
    .environmentObject(HealthKitManager())
    .padding()
}
