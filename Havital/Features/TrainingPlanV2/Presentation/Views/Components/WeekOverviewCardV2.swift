import SwiftUI

/// V2 週總覽卡片 - 顯示本週跑量和強度分配
struct WeekOverviewCardV2: View {
    @ObservedObject var viewModel: TrainingPlanV2ViewModel
    @Environment(\.colorScheme) var colorScheme
    let plan: WeeklyPlanV2
    @State private var showWeekTargetDetail = false

    // 從 plan.plan 中提取總跑量（簡化版）
    private var targetDistance: Double {
        return plan.plan.double(forKey: "total_distance") ?? 0.0
    }

    private var weekProgress: Double {
        guard targetDistance > 0 else { return 0 }
        return min(viewModel.currentWeekDistance / targetDistance, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 標題
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(.blue)
                    .font(.headline)

                Text(NSLocalizedString("training_plan.weekly_volume_and_intensity", comment: "週跑量和訓練強度"))
                    .font(.headline)
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
                            Text(String(format: "%.0f", viewModel.currentWeekDistance))
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.primary)
                                .minimumScaleFactor(0.8)
                                .lineLimit(1)

                            Text("/")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)

                            Text(String(format: "%.0f", targetDistance))
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .minimumScaleFactor(0.8)
                                .lineLimit(1)
                        }

                        Text(L10n.Unit.km.localized)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .offset(y: 3)
                }

                Spacer()

                // 右側：本週目標按鈕
                VStack(alignment: .leading, spacing: 10) {
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
                }

                Spacer()
            }

            // 下半部：強度分布（簡化版 - 使用 ViewModel 中的數據）
            HStack(spacing: 12) {
                // 低強度
                CompactIntensityBarV2(
                    label: NSLocalizedString("intensity.low", comment: "Low"),
                    current: Int(viewModel.currentWeekIntensity.low),
                    target: 100,  // TODO: 從 plan.plan 中提取目標值
                    color: .green
                )

                // 中強度
                CompactIntensityBarV2(
                    label: NSLocalizedString("intensity.medium", comment: "Medium"),
                    current: Int(viewModel.currentWeekIntensity.medium),
                    target: 40,   // TODO: 從 plan.plan 中提取目標值
                    color: .orange
                )

                // 高強度
                CompactIntensityBarV2(
                    label: NSLocalizedString("intensity.high", comment: "High"),
                    current: Int(viewModel.currentWeekIntensity.high),
                    target: 15,   // TODO: 從 plan.plan 中提取目標值
                    color: .red
                )
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
                WeekTargetDetailViewV2(
                    purpose: plan.plan.string(forKey: "purpose") ?? "本週訓練",
                    designReason: nil  // TODO: 從 plan.plan 中提取
                )
            }
        }
    }
}

// MARK: - 緊湊型強度條組件 V2
struct CompactIntensityBarV2: View {
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

#Preview {
    // TODO: 實作正確的 Preview mock 資料
    Text("WeekOverviewCardV2 Preview")
        .padding()
}
