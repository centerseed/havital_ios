import SwiftUI

/// V2 週總覽卡片 - 顯示本週跑量和強度分配
struct WeekOverviewCardV2: View {
    var viewModel: TrainingPlanV2ViewModel
    @ObservedObject private var unitManager = UnitManager.shared
    @Environment(\.colorScheme) var colorScheme
    let plan: WeeklyPlanV2
    @State private var showWeekTargetDetail = false
    @State private var showTrainingCalendar = false

    // ✅ 從 intensityTotalMinutes 提取強度目標（分鐘）
    private var lowIntensityTarget: Int {
        return Int(plan.intensityTotalMinutes?.low ?? 0)
    }

    private var mediumIntensityTarget: Int {
        return Int(plan.intensityTotalMinutes?.medium ?? 0)
    }

    private var highIntensityTarget: Int {
        return Int(plan.intensityTotalMinutes?.high ?? 0)
    }

    // ✅ 直接從 WeeklyPlanV2 Entity 提取設計原因（V1 欄位）
    private var designReason: [String]? {
        return plan.designReason
    }

    private var weekProgress: Double {
        guard plan.totalDistance > 0 else { return 0 }
        return min(viewModel.loader.currentWeekDistance / plan.totalDistance, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 標題
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(.blue)
                    .font(AppFont.headline())

                Text(NSLocalizedString("training_plan.weekly_volume_and_intensity", comment: "週跑量和訓練強度"))
                    .font(AppFont.headline())
                    .foregroundColor(.primary)
            }

            // 上半部：圓形進度 + 可點擊項目
            HStack(spacing: 0) {
                Spacer()

                // 左側：圓形週跑量進度
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

                    VStack(spacing: 2) {
                        HStack(spacing: 1) {
                            Text(String(format: "%.0f", unitManager.convertedDistance(viewModel.loader.currentWeekDistance)))
                                .font(AppFont.systemScaled(size: 17, weight: .bold))
                                .foregroundColor(.primary)
                                .minimumScaleFactor(0.8)
                                .lineLimit(1)

                            Text("/")
                                .font(AppFont.systemScaled(size: 13))
                                .foregroundColor(.secondary)

                            Text(String(format: "%.0f", unitManager.convertedDistance(plan.totalDistance)))
                                .font(AppFont.systemScaled(size: 13))
                                .foregroundColor(.secondary)
                                .minimumScaleFactor(0.8)
                                .lineLimit(1)
                        }

                        Text(unitManager.currentUnitSystem.distanceSuffix)
                            .font(AppFont.caption2())
                            .foregroundColor(.secondary)
                    }
                    .offset(y: 3)
                }

                Spacer()

                // 右側：本週目標和訓練日曆按鈕
                VStack(alignment: .leading, spacing: 10) {
                    Button(action: {
                        showWeekTargetDetail = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "target")
                                .foregroundColor(.blue)
                                .font(AppFont.subheadline())

                            Text(NSLocalizedString("training_plan.week_target", comment: "Week Target"))
                                .font(AppFont.subheadline())
                                .foregroundColor(.primary)

                            Image(systemName: "chevron.right")
                                .font(AppFont.caption2())
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
                                .font(AppFont.subheadline())

                            Text(NSLocalizedString("training_plan.training_calendar", comment: "Training Calendar"))
                                .font(AppFont.subheadline())
                                .foregroundColor(.primary)

                            Image(systemName: "chevron.right")
                                .font(AppFont.caption2())
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

            // 下半部：強度分布（使用從 plan.plan 提取的目標值）
            HStack(spacing: 12) {
                // 低強度
                CompactIntensityBarV2(
                    label: NSLocalizedString("intensity.low", comment: "Low"),
                    intensityKey: "low",
                    current: Int(viewModel.loader.currentWeekIntensity.low),
                    target: lowIntensityTarget,
                    color: .green
                )

                // 中強度
                CompactIntensityBarV2(
                    label: NSLocalizedString("intensity.medium", comment: "Medium"),
                    intensityKey: "medium",
                    current: Int(viewModel.loader.currentWeekIntensity.medium),
                    target: mediumIntensityTarget,
                    color: .orange
                )

                // 高強度
                CompactIntensityBarV2(
                    label: NSLocalizedString("intensity.high", comment: "High"),
                    intensityKey: "high",
                    current: Int(viewModel.loader.currentWeekIntensity.high),
                    target: highIntensityTarget,
                    color: .red
                )
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("v2.weekly.intensity_distribution")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.tertiarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .accessibilityIdentifier("v2.weekly.overview_card")
        .sheet(isPresented: $showWeekTargetDetail) {
            NavigationView {
                WeekTargetDetailViewV2(
                    purpose: plan.purpose,  // ✅ 直接使用 V1 欄位
                    designReason: designReason
                )
            }
        }
        .sheet(isPresented: $showTrainingCalendar) {
            NavigationView {
                TrainingCalendarView()
            }
        }
    }
}

// MARK: - 緊湊型強度條組件 V2
struct CompactIntensityBarV2: View {
    let label: String
    let intensityKey: String
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
                .font(AppFont.caption())
                .foregroundColor(isUnscheduled ? .secondary.opacity(0.7) : .secondary)

            // 自定義進度條
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
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("v2.weekly.intensity.\(intensityKey)")
    }
}

// MARK: - 週目標詳情視圖 V2
struct WeekTargetDetailViewV2: View {
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
                            .font(AppFont.title3())

                        Text(NSLocalizedString("training_plan.week_target", comment: "Week Target"))
                            .font(AppFont.headline())
                            .foregroundColor(.primary)
                    }

                    Text(purpose)
                        .font(AppFont.body())
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
                                .font(AppFont.title3())

                            Text(NSLocalizedString("training.design_reason", comment: "Design Reason"))
                                .font(AppFont.headline())
                                .foregroundColor(.primary)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(designReason.enumerated()), id: \.offset) { index, reason in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("\(index + 1).")
                                        .font(AppFont.body())
                                        .fontWeight(.medium)
                                        .foregroundColor(.orange)

                                    Text(reason)
                                        .font(AppFont.body())
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

#Preview {
    // TODO: 實作正確的 Preview mock 資料
    Text("WeekOverviewCardV2 Preview")
        .padding()
}
