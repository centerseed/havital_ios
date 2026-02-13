import SwiftUI

// MARK: - Layout Constants

private enum Layout {
    static let sectionSpacing: CGFloat = 16
    static let contentSpacing: CGFloat = 12
    static let itemSpacing: CGFloat = 8
    static let iconSpacing: CGFloat = 6
    static let cardPadding: CGFloat = 16
    static let subCardPadding: CGFloat = 12
}

/// V2 週訓練摘要畫面
/// 顯示完成度、訓練分析、亮點、下週調整建議
struct WeeklySummaryV2View: View {
    @ObservedObject var viewModel: TrainingPlanV2ViewModel
    let weekOfPlan: Int
    var onGenerateNextWeek: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(spacing: Layout.sectionSpacing) {
                switch viewModel.weeklySummary {
                case .loaded(let summary):
                    CompletionSectionV2(completion: summary.trainingCompletion)
                    AnalysisSectionV2(analysis: summary.trainingAnalysis)
                    HighlightsSectionV2(highlights: summary.weeklyHighlights)
                    AdjustmentsSectionV2(adjustments: summary.nextWeekAdjustments)

                    if let onGenerateNextWeek {
                        Button(action: onGenerateNextWeek) {
                            Text(NSLocalizedString("training.generate_next_week_plan", comment: "產生下週課表"))
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        .padding(.top, 8)
                    }

                case .loading:
                    loadingPlaceholder

                case .error(let error):
                    errorView(error)

                case .empty:
                    emptyView
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle(String(format: NSLocalizedString("training.week_summary_title", comment: "第 %d 週摘要"), weekOfPlan))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadWeeklySummary(weekOfPlan: weekOfPlan)
        }
    }

    // MARK: - Loading Placeholder

    private var loadingPlaceholder: some View {
        VStack(spacing: Layout.contentSpacing) {
            ProgressView()
                .padding(.top, 60)
            Text(NSLocalizedString("common.loading", comment: "載入中..."))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Error View

    private func errorView(_ error: DomainError) -> some View {
        VStack(spacing: Layout.contentSpacing) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
                .padding(.top, 40)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: {
                Task {
                    await viewModel.loadWeeklySummary(weekOfPlan: weekOfPlan)
                }
            }) {
                Text(NSLocalizedString("common.retry", comment: "重試"))
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 32)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: Layout.contentSpacing) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
                .padding(.top, 40)

            Text(NSLocalizedString("training.no_weekly_summary", comment: "尚無週摘要"))
                .font(.headline)
                .foregroundColor(.primary)

            Text(NSLocalizedString("training.no_weekly_summary_hint", comment: "本週摘要將在訓練結束後自動產生"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}

// MARK: - Completion Section

/// 完成度區塊：圓形進度 + 完成率 + 公里數&場次
private struct CompletionSectionV2: View {
    let completion: TrainingCompletionV2

    /// API returns percentage as 0-100+ (e.g. 12.0 = 12%, 105.0 = 105%)
    private var normalizedPercentage: Double {
        completion.percentage / 100.0
    }

    private var progressColor: Color {
        if normalizedPercentage >= 0.9 { return .green }
        if normalizedPercentage >= 0.7 { return .orange }
        return .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.contentSpacing) {
            // 標題
            HStack(spacing: Layout.itemSpacing) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.headline)
                Text(NSLocalizedString("training.completion", comment: "訓練完成度"))
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }

            HStack(spacing: 20) {
                // 圓形進度
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                        .frame(width: 100, height: 100)

                    Circle()
                        .trim(from: 0, to: min(normalizedPercentage, 1.0))
                        .stroke(progressColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(completion.percentage))%")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                }

                // 統計數字
                VStack(alignment: .leading, spacing: Layout.itemSpacing) {
                    // 公里數
                    HStack(spacing: Layout.iconSpacing) {
                        Image(systemName: "figure.run")
                            .foregroundColor(.blue)
                            .font(.subheadline)
                        Text(String(format: "%.1f / %.1f km", completion.completedKm, completion.plannedKm))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }

                    // 場次
                    HStack(spacing: Layout.iconSpacing) {
                        Image(systemName: "calendar.badge.checkmark")
                            .foregroundColor(.green)
                            .font(.subheadline)
                        Text(String(format: "%d / %d %@", completion.completedSessions, completion.plannedSessions, NSLocalizedString("training.sessions", comment: "場")))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }

                    // 評語
                    Text(completion.evaluation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(Layout.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.tertiarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Analysis Section

/// 訓練分析區塊：心率/配速/距離/強度分配
private struct AnalysisSectionV2: View {
    let analysis: TrainingAnalysisV2

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.contentSpacing) {
            HStack(spacing: Layout.itemSpacing) {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.purple)
                    .font(.headline)
                Text(NSLocalizedString("training.analysis", comment: "訓練分析"))
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }

            VStack(spacing: Layout.contentSpacing) {
                // 心率分析
                if let hr = analysis.heartRate {
                    AnalysisCardV2(
                        icon: "heart.fill",
                        iconColor: .red,
                        title: NSLocalizedString("training.heart_rate", comment: "心率"),
                        values: [
                            hr.average.map { (NSLocalizedString("training.average", comment: "平均"), String(format: "%.0f bpm", $0)) },
                            hr.max.map { (NSLocalizedString("training.max", comment: "最高"), String(format: "%.0f bpm", $0)) }
                        ].compactMap { $0 },
                        evaluation: hr.evaluation
                    )
                }

                // 配速分析
                if let pace = analysis.pace {
                    AnalysisCardV2(
                        icon: "speedometer",
                        iconColor: .orange,
                        title: NSLocalizedString("training.pace", comment: "配速"),
                        values: [
                            pace.average.map { (NSLocalizedString("training.average", comment: "平均"), $0) },
                            pace.trend.map { (NSLocalizedString("training.trend", comment: "趨勢"), $0) }
                        ].compactMap { $0 },
                        evaluation: pace.evaluation
                    )
                }

                // 距離分析
                if let distance = analysis.distance {
                    AnalysisCardV2(
                        icon: "point.topleft.down.to.point.bottomright.curvepath.fill",
                        iconColor: .blue,
                        title: NSLocalizedString("training.distance", comment: "距離"),
                        values: [
                            (NSLocalizedString("training.total", comment: "總計"), String(format: "%.1f km", distance.total)),
                            distance.comparisonToPlan.map { (NSLocalizedString("training.vs_plan", comment: "對比計畫"), $0) }
                        ].compactMap { $0 },
                        evaluation: distance.evaluation
                    )
                }

                // 強度分配
                if let intensity = analysis.intensityDistribution {
                    IntensityDistributionCardV2(intensity: intensity)
                }
            }
        }
        .padding(Layout.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.tertiarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

/// 強度分配卡片
private struct IntensityDistributionCardV2: View {
    let intensity: IntensityDistributionAnalysisV2

    private var totalPercentage: Double {
        intensity.easyPercentage + intensity.moderatePercentage + intensity.hardPercentage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            HStack(spacing: Layout.iconSpacing) {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                    .font(.subheadline)
                Text(NSLocalizedString("training.intensity_distribution", comment: "強度分配"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }

            // 強度條 - 使用 GeometryReader 自適應寬度
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    if intensity.easyPercentage > 0 {
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: barWidth(for: intensity.easyPercentage, in: geometry.size.width))
                    }
                    if intensity.moderatePercentage > 0 {
                        Rectangle()
                            .fill(Color.orange)
                            .frame(width: barWidth(for: intensity.moderatePercentage, in: geometry.size.width))
                    }
                    if intensity.hardPercentage > 0 {
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: barWidth(for: intensity.hardPercentage, in: geometry.size.width))
                    }
                }
                .cornerRadius(4)
            }
            .frame(height: 8)

            // 標籤
            HStack(spacing: Layout.contentSpacing) {
                Label(String(format: "%.0f%%", intensity.easyPercentage), systemImage: "circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                Label(String(format: "%.0f%%", intensity.moderatePercentage), systemImage: "circle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                Label(String(format: "%.0f%%", intensity.hardPercentage), systemImage: "circle.fill")
                    .font(.caption)
                    .foregroundColor(.red)
            }

            if let evaluation = intensity.evaluation {
                Text(evaluation)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(Layout.subCardPadding)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(8)
    }

    private func barWidth(for percentage: Double, in totalWidth: CGFloat) -> CGFloat {
        guard totalPercentage > 0 else { return 0 }
        return max(totalWidth * CGFloat(percentage / totalPercentage), 4)
    }
}

/// 分析卡片元件
private struct AnalysisCardV2: View {
    let icon: String
    let iconColor: Color
    let title: String
    let values: [(String, String)]
    let evaluation: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            HStack(spacing: Layout.iconSpacing) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.subheadline)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }

            ForEach(values, id: \.0) { label, value in
                HStack {
                    Text(label)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(value)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }

            if let evaluation = evaluation {
                Text(evaluation)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(Layout.subCardPadding)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

// MARK: - Highlights Section

/// 亮點區塊：亮點、成就、待改善
private struct HighlightsSectionV2: View {
    let highlights: WeeklyHighlightsV2

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.contentSpacing) {
            HStack(spacing: Layout.itemSpacing) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.headline)
                Text(NSLocalizedString("training.highlights", comment: "本週亮點"))
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }

            // 亮點
            if !highlights.highlights.isEmpty {
                bulletList(
                    items: highlights.highlights,
                    icon: "sparkle",
                    color: .yellow
                )
            }

            // 成就
            if !highlights.achievements.isEmpty {
                VStack(alignment: .leading, spacing: Layout.itemSpacing) {
                    Text(NSLocalizedString("training.achievements", comment: "成就"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.green)

                    bulletList(
                        items: highlights.achievements,
                        icon: "trophy.fill",
                        color: .green
                    )
                }
            }

            // 待改善
            if !highlights.areasForImprovement.isEmpty {
                VStack(alignment: .leading, spacing: Layout.itemSpacing) {
                    Text(NSLocalizedString("training.areas_for_improvement", comment: "待改善"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)

                    bulletList(
                        items: highlights.areasForImprovement,
                        icon: "arrow.up.circle.fill",
                        color: .orange
                    )
                }
            }
        }
        .padding(Layout.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.tertiarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }

    private func bulletList(items: [String], icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: Layout.itemSpacing) {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.caption)
                        .frame(width: 16)
                    Text(item)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Adjustments Section

/// 下週調整建議區塊
private struct AdjustmentsSectionV2: View {
    let adjustments: NextWeekAdjustmentsV2

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.contentSpacing) {
            HStack(spacing: Layout.itemSpacing) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.blue)
                    .font(.headline)
                Text(NSLocalizedString("training.next_week_adjustments", comment: "下週調整建議"))
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }

            // 摘要
            Text(adjustments.summary)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // 建議項目列表
            ForEach(Array(adjustments.items.enumerated()), id: \.offset) { _, item in
                AdjustmentItemCardV2(item: item)
            }
        }
        .padding(Layout.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.tertiarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

/// 調整建議項目卡片
private struct AdjustmentItemCardV2: View {
    let item: AdjustmentItemV2

    private var priorityColor: Color {
        switch item.priority.lowercased() {
        case "high": return .red
        case "medium": return .orange
        default: return .blue
        }
    }

    private var categoryIcon: String {
        switch item.category.lowercased() {
        case "volume": return "chart.bar.fill"
        case "intensity": return "flame.fill"
        case "recovery": return "bed.double.fill"
        case "technique": return "figure.run"
        default: return "arrow.right.circle.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            // 第一行：icon + Spacer + priority badge
            HStack {
                Image(systemName: categoryIcon)
                    .foregroundColor(priorityColor)
                    .font(.subheadline)

                Spacer()

                Text(item.priority.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(priorityColor)
                    .cornerRadius(4)
            }

            // 第二行：content text
            Text(item.content)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            // 第三行：reason
            Text(item.reason)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Layout.subCardPadding)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        Text("WeeklySummaryV2View Preview")
    }
}
