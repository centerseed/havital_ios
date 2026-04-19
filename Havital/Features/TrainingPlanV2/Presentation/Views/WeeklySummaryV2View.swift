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

// MARK: - Section ID

private enum SectionID: Hashable {
    case highlights
    case analysis
    case nextWeek
}

/// V2 週訓練摘要畫面（漸進式揭露單頁 ScrollView）
/// Hero 成績區塊永遠展開，三個折疊 section 按需展開
struct WeeklySummaryV2View: View {
    var viewModel: TrainingPlanV2ViewModel
    let weekOfPlan: Int
    var onGenerateNextWeek: (() -> Void)?
    var onSetNewGoal: (() -> Void)?

    @State private var expandedSections: Set<SectionID> = []

    var body: some View {
        Group {
            switch viewModel.summary.weeklySummary {
            case .loaded(let summary):
                loadedView(summary: summary)

            case .loading:
                loadingPlaceholder

            case .error(let error):
                errorView(error)

            case .empty:
                emptyView
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle(String(format: NSLocalizedString("training.week_summary_title", comment: "第 %d 週摘要"), weekOfPlan))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.summary.loadWeeklySummary(weekOfPlan: weekOfPlan)
        }
    }

    // MARK: - Loaded View

    private func loadedView(summary: WeeklySummaryV2) -> some View {
        ScrollView {
            VStack(spacing: Layout.sectionSpacing) {

                // Hero 成績區塊（永遠展開）
                CompletionSectionV2(completion: summary.trainingCompletion)

                // 本週亮點（折疊）
                CollapsibleSectionV2(
                    id: .highlights,
                    icon: "star.fill",
                    iconColor: .yellow,
                    title: NSLocalizedString("training.highlights", comment: "本週亮點"),
                    preview: highlightsPreview(summary.weeklyHighlights),
                    accessibilityIdentifier: "v2.summary.highlights_toggle",
                    expandedSections: $expandedSections
                ) {
                    HighlightsSectionV2(highlights: summary.weeklyHighlights, showImprovements: true)
                        .padding(.top, 8)
                }

                // 訓練分析（折疊）
                CollapsibleSectionV2(
                    id: .analysis,
                    icon: "chart.bar.fill",
                    iconColor: .purple,
                    title: NSLocalizedString("training.analysis", comment: "訓練分析"),
                    preview: analysisPreview(summary.trainingAnalysis),
                    accessibilityIdentifier: "v2.summary.analysis_toggle",
                    expandedSections: $expandedSections
                ) {
                    AnalysisSectionV2(analysis: summary.trainingAnalysis)
                        .padding(.top, 8)
                }

                // 下週計劃（折疊）
                CollapsibleSectionV2(
                    id: .nextWeek,
                    icon: "arrow.triangle.2.circlepath",
                    iconColor: .blue,
                    title: NSLocalizedString("training.next_week_adjustments", comment: "下週調整建議"),
                    preview: nextWeekPreview(summary.nextWeekAdjustments),
                    accessibilityIdentifier: "v2.summary.next_week_toggle",
                    expandedSections: $expandedSections
                ) {
                    VStack(spacing: Layout.contentSpacing) {
                        if !summary.weeklyHighlights.areasForImprovement.isEmpty {
                            ImprovementsSectionV2(areas: summary.weeklyHighlights.areasForImprovement)
                        }
                        AdjustmentsSectionV2(
                            adjustments: summary.nextWeekAdjustments,
                            coordinator: viewModel.summary,
                            showToggles: onGenerateNextWeek != nil
                        )
                    }
                    .padding(.top, 8)
                }

                // 行動按鈕（永遠可見）
                actionButtonsView(summary: summary)
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .accessibilityIdentifier("v2.summary.loaded_content")
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private func actionButtonsView(summary: WeeklySummaryV2) -> some View {
        if let onGenerateNextWeek {
            Button(action: onGenerateNextWeek) {
                Text(generateButtonText(summary: summary))
                    .font(AppFont.headline())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }

        if let onSetNewGoal {
            VStack(spacing: 12) {
                Text(NSLocalizedString("training.cycle_completed_message", comment: "Great job! Your training cycle is complete."))
                    .font(AppFont.subheadline())
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button(action: onSetNewGoal) {
                    HStack {
                        Image(systemName: "target")
                        Text(NSLocalizedString("training.set_new_goal", comment: "Set New Goal"))
                    }
                    .font(AppFont.headline())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.green)
                    .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Button Text Helpers

    private func generateButtonText(summary: WeeklySummaryV2) -> String {
        let selectedCount = viewModel.summary.selectedCount
        if summary.nextWeekAdjustments.items.isEmpty {
            return NSLocalizedString("training.generate_next_week_plan", comment: "產生下週課表")
        } else if selectedCount > 0 {
            return String(format: NSLocalizedString(
                "training.apply_n_adjustments_and_generate",
                comment: "套用 %d 條建議並產生下週課表"
            ), selectedCount)
        } else {
            return NSLocalizedString(
                "training.generate_without_adjustments",
                comment: "不套用調整，直接產生課表"
            )
        }
    }

    // MARK: - Preview Text Helpers

    private func highlightsPreview(_ highlights: WeeklyHighlightsV2) -> String {
        let count = highlights.highlights.count
        let achievements = highlights.achievements.count
        if count == 0 && achievements == 0 {
            return NSLocalizedString("training.no_highlights", comment: "無亮點資料")
        }
        var parts: [String] = []
        if count > 0 {
            parts.append(String(format: NSLocalizedString("training.highlights_count", comment: "%d 個亮點"), count))
        }
        if achievements > 0 {
            parts.append(String(format: NSLocalizedString("training.achievements_count", comment: "%d 項成就"), achievements))
        }
        return parts.joined(separator: " · ")
    }

    private func analysisPreview(_ analysis: TrainingAnalysisV2) -> String {
        if let hr = analysis.heartRate, let avg = hr.average {
            return String(format: NSLocalizedString("training.avg_heart_rate_preview", comment: "平均心率 %.0f bpm"), avg)
        }
        if let pace = analysis.pace, let avg = pace.average {
            return String(format: NSLocalizedString("training.avg_pace_preview", comment: "平均配速 %@"), avg)
        }
        return NSLocalizedString("training.view_analysis", comment: "查看數據分析")
    }

    private func nextWeekPreview(_ adjustments: NextWeekAdjustmentsV2) -> String {
        let summary = adjustments.summary
        if summary.count <= 30 {
            return summary
        }
        return String(summary.prefix(30)) + "..."
    }

    // MARK: - Loading Placeholder

    private var loadingPlaceholder: some View {
        VStack(spacing: Layout.contentSpacing) {
            ProgressView()
                .padding(.top, 60)
            Text(NSLocalizedString("common.loading", comment: "載入中..."))
                .font(AppFont.subheadline())
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("v2.summary.loading")
    }

    // MARK: - Error View

    private func errorView(_ error: DomainError) -> some View {
        VStack(spacing: Layout.contentSpacing) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(AppFont.systemScaled(size: 48))
                .foregroundColor(.orange)
                .padding(.top, 40)

            Text(error.localizedDescription)
                .font(AppFont.subheadline())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: {
                Task {
                    await viewModel.summary.loadWeeklySummary(weekOfPlan: weekOfPlan)
                }
            }) {
                Text(NSLocalizedString("common.retry", comment: "重試"))
                    .font(AppFont.headline())
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 32)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("v2.summary.error")
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: Layout.contentSpacing) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(AppFont.systemScaled(size: 48))
                .foregroundColor(.secondary)
                .padding(.top, 40)

            Text(NSLocalizedString("training.no_weekly_summary", comment: "尚無週摘要"))
                .font(AppFont.headline())
                .foregroundColor(.primary)

            Text(NSLocalizedString("training.no_weekly_summary_hint", comment: "本週摘要將在訓練結束後自動產生"))
                .font(AppFont.subheadline())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("v2.summary.empty")
    }
}

// MARK: - Collapsible Section

/// 折疊式 section 容器：header 永遠可見，內容按需展開
private struct CollapsibleSectionV2<Content: View>: View {
    let id: SectionID
    let icon: String
    let iconColor: Color
    let title: String
    let preview: String
    let accessibilityIdentifier: String
    @Binding var expandedSections: Set<SectionID>
    @ViewBuilder let content: () -> Content

    private var isExpanded: Bool {
        expandedSections.contains(id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Row（永遠可見）
            Button(action: toggleSection) {
                HStack(spacing: Layout.itemSpacing) {
                    Image(systemName: icon)
                        .foregroundColor(iconColor)
                        .font(AppFont.headline())
                        .frame(width: 22)

                    Text(title)
                        .font(AppFont.headline())
                        .foregroundColor(.primary)

                    Spacer()

                    if !isExpanded {
                        Text(preview)
                            .font(AppFont.caption())
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    Image(systemName: "chevron.right")
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.25), value: isExpanded)
                }
                .padding(Layout.cardPadding)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(accessibilityIdentifier)

            // 展開內容
            if isExpanded {
                content()
                    .padding(.horizontal, Layout.cardPadding)
                    .padding(.bottom, Layout.cardPadding)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.tertiarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }

    private func toggleSection() {
        withAnimation(.easeInOut(duration: 0.25)) {
            if expandedSections.contains(id) {
                expandedSections.remove(id)
            } else {
                expandedSections.insert(id)
            }
        }
    }
}

// MARK: - Completion Section

/// 完成度區塊：圓形進度 + 完成率 + 公里數&場次（永遠展開，不折疊）
private struct CompletionSectionV2: View {
    let completion: TrainingCompletionV2

    /// Some fixtures still encode completion as 0.0...1.0 while newer API contracts use 0...100.
    /// Normalize both forms so render output and progress ring stay stable.
    private var normalizedPercentage: Double {
        completion.percentage <= 1 ? completion.percentage : completion.percentage / 100.0
    }

    private var displayPercentage: Int {
        Int(round(normalizedPercentage * 100))
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
                    .font(AppFont.headline())
                Text(NSLocalizedString("training.completion", comment: "訓練完成度"))
                    .font(AppFont.headline())
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

                    Text("\(displayPercentage)%")
                        .font(AppFont.systemScaled(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                        .accessibilityIdentifier("v2.summary.completion_percentage")
                }

                // 統計數字
                VStack(alignment: .leading, spacing: Layout.itemSpacing) {
                    // 公里數
                    HStack(spacing: Layout.iconSpacing) {
                        Image(systemName: "figure.run")
                            .foregroundColor(.blue)
                            .font(AppFont.subheadline())
                        Text(String(format: "%.1f / %.1f km", completion.completedKm, completion.plannedKm))
                            .font(AppFont.subheadline())
                            .foregroundColor(.primary)
                    }

                    // 場次
                    HStack(spacing: Layout.iconSpacing) {
                        Image(systemName: "calendar.badge.checkmark")
                            .foregroundColor(.green)
                            .font(AppFont.subheadline())
                        Text(String(format: "%d / %d %@", completion.completedSessions, completion.plannedSessions, NSLocalizedString("training.sessions", comment: "場")))
                            .font(AppFont.subheadline())
                            .foregroundColor(.primary)
                    }

                    // 評語
                    Text(completion.evaluation)
                        .font(AppFont.caption())
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
        .accessibilityIdentifier("v2.summary.completion_card")
    }
}

// MARK: - Analysis Section

/// 訓練分析區塊：心率/配速/距離/強度分配（折疊內容，無外框卡片）
private struct AnalysisSectionV2: View {
    let analysis: TrainingAnalysisV2

    var body: some View {
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
                    .font(AppFont.subheadline())
                Text(NSLocalizedString("training.intensity_distribution", comment: "強度分配"))
                    .font(AppFont.subheadline())
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
                    .font(AppFont.caption())
                    .foregroundColor(.green)
                Label(String(format: "%.0f%%", intensity.moderatePercentage), systemImage: "circle.fill")
                    .font(AppFont.caption())
                    .foregroundColor(.orange)
                Label(String(format: "%.0f%%", intensity.hardPercentage), systemImage: "circle.fill")
                    .font(AppFont.caption())
                    .foregroundColor(.red)
            }

            if let evaluation = intensity.evaluation {
                Text(evaluation)
                    .font(AppFont.caption())
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
                    .font(AppFont.subheadline())
                Text(title)
                    .font(AppFont.subheadline())
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }

            ForEach(values, id: \.0) { label, value in
                HStack {
                    Text(label)
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(value)
                        .font(AppFont.caption())
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }

            if let evaluation = evaluation {
                Text(evaluation)
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
            }
        }
        .padding(Layout.subCardPadding)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

// MARK: - Highlights Section

/// 亮點區塊：亮點、成就（可選是否顯示待改善）
private struct HighlightsSectionV2: View {
    let highlights: WeeklyHighlightsV2
    /// 是否顯示待改善清單
    var showImprovements: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.contentSpacing) {
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
                        .font(AppFont.subheadline())
                        .fontWeight(.medium)
                        .foregroundColor(.green)

                    bulletList(
                        items: highlights.achievements,
                        icon: "trophy.fill",
                        color: .green
                    )
                }
            }

            // 待改善（由 showImprovements 控制是否顯示）
            if showImprovements && !highlights.areasForImprovement.isEmpty {
                VStack(alignment: .leading, spacing: Layout.itemSpacing) {
                    Text(NSLocalizedString("training.areas_for_improvement", comment: "待改善"))
                        .font(AppFont.subheadline())
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
    }

    private func bulletList(items: [String], icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: Layout.itemSpacing) {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(AppFont.caption())
                        .frame(width: 16)
                    Text(item)
                        .font(AppFont.subheadline())
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Improvements Section

/// 待改善清單區塊（折疊內容，無外框卡片）
private struct ImprovementsSectionV2: View {
    let areas: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.contentSpacing) {
            HStack(spacing: Layout.itemSpacing) {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(.orange)
                    .font(AppFont.headline())
                Text(NSLocalizedString("training.areas_for_improvement_title", comment: "待改善"))
                    .font(AppFont.headline())
                    .foregroundColor(.primary)
                Spacer()
            }

            VStack(alignment: .leading, spacing: Layout.itemSpacing) {
                ForEach(areas, id: \.self) { area in
                    HStack(alignment: .top, spacing: Layout.itemSpacing) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.orange)
                            .font(AppFont.caption())
                            .frame(width: 16)
                        Text(area)
                            .font(AppFont.subheadline())
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

// MARK: - Adjustments Section

/// 下週調整建議區塊（折疊內容，無外框卡片）
private struct AdjustmentsSectionV2: View {
    let adjustments: NextWeekAdjustmentsV2
    let coordinator: WeeklySummaryCoordinator
    let showToggles: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.contentSpacing) {
            HStack(spacing: Layout.itemSpacing) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.blue)
                    .font(AppFont.headline())
                Text(NSLocalizedString("training.next_week_adjustments", comment: "下週調整建議"))
                    .font(AppFont.headline())
                    .foregroundColor(.primary)
                Spacer()

                if showToggles && !adjustments.items.isEmpty {
                    Text(String(format: NSLocalizedString(
                        "training.adjustment_selected_count",
                        comment: "已選 %d / %d 條"
                    ), coordinator.selectedCount, adjustments.items.count))
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                }
            }

            // 摘要
            Text(adjustments.summary)
                .font(AppFont.subheadline())
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // 建議項目列表
            ForEach(Array(adjustments.items.enumerated()), id: \.offset) { index, item in
                AdjustmentItemCardV2(
                    item: item,
                    index: index,
                    isSelected: showToggles
                        ? Binding(
                            get: { coordinator.adjustmentSelections[index] ?? true },
                            set: { coordinator.adjustmentSelections[index] = $0 }
                          )
                        : .constant(true)
                )
            }
        }
    }
}

/// 調整建議項目卡片
private struct AdjustmentItemCardV2: View {
    let item: AdjustmentItemV2
    let index: Int
    @Binding var isSelected: Bool

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
            HStack {
                Image(systemName: categoryIcon)
                    .foregroundColor(priorityColor)
                    .font(AppFont.subheadline())

                Spacer()

                Toggle("", isOn: $isSelected)
                    .labelsHidden()
                    .accessibilityIdentifier("v2.summary.adjustment_toggle_\(index)")

                Text(item.priority.uppercased())
                    .font(AppFont.systemScaled(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(priorityColor)
                    .cornerRadius(4)
            }

            Text(item.content)
                .font(AppFont.subheadline())
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(item.reason)
                .font(AppFont.caption())
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !item.impact.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right.circle.fill")
                        .font(AppFont.caption())
                        .foregroundColor(.blue.opacity(0.7))
                    Text(item.impact)
                        .font(AppFont.caption())
                        .foregroundColor(.blue.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(Layout.subCardPadding)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(8)
        .opacity(isSelected ? 1.0 : 0.4)
        .grayscale(isSelected ? 0.0 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .accessibilityIdentifier("v2.summary.adjustment_item_\(index)")
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        Text("WeeklySummaryV2View Preview")
    }
}
