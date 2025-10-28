import SwiftUI
import Charts

/// Training Readiness View
/// Displays overall training readiness score and detailed metrics
struct TrainingReadinessView: View {
    @StateObject private var viewModel = TrainingReadinessViewModel()
    @State private var showingInfo = false
    @State private var showingMetricDescription = false
    @State private var metricDescriptionTitle = ""
    @State private var metricDescriptionText = ""
    @State private var showingDetailedMetricsExplanation = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.syncError {
                errorView(error: error)
            } else if !viewModel.hasData {
                emptyStateView
            } else {
                contentView
            }
        }
        .refreshable {
            await viewModel.refreshData()
        }
        .alert(metricDescriptionTitle, isPresented: $showingMetricDescription) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(metricDescriptionText)
        }
        .sheet(isPresented: $showingDetailedMetricsExplanation) {
            TrainingReadinessMetricsExplanationView()
        }
    }

    // MARK: - Helper Methods

    /// Show metric description alert
    private func showMetricDescription(title: String, description: String) {
        metricDescriptionTitle = title
        metricDescriptionText = description
        showingMetricDescription = true
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack {
            ProgressView(NSLocalizedString("common.loading", comment: ""))
                .foregroundColor(.secondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Error View
    private func errorView(error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await viewModel.refreshData()
                }
            } label: {
                Text(NSLocalizedString("common.retry", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text(NSLocalizedString("training_readiness.no_data", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Content View
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Overall Score
            overallScoreSection

            // Metrics Grid (2x2) with explanation button
            if viewModel.hasAnyMetric {
                HStack {
                    Text("訓練指標")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Button {
                        showingDetailedMetricsExplanation = true
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal)

                metricsGrid
            }
        }
    }

    // MARK: - Overall Score Section
    private var overallScoreSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                // Radar Chart
                RadarChartView(
                    metrics: radarMetrics,
                    size: 100
                )

                // Right side: Score + Status text
                VStack(alignment: .leading, spacing: 8) {
                    // Score with label
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.overallScoreFormatted)
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(scoreColor)
                    }

                    // Status text
                    Text(apiStatusText)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Radar Chart Data
    private var radarMetrics: [RadarChartView.RadarMetric] {
        var metrics: [RadarChartView.RadarMetric] = []

        if let speed = viewModel.speedMetric {
            metrics.append(RadarChartView.RadarMetric(label: "速度", value: speed.score, color: .blue))
        }
        if let endurance = viewModel.enduranceMetric {
            metrics.append(RadarChartView.RadarMetric(label: "耐力", value: endurance.score, color: .green))
        }
        if let raceFitness = viewModel.raceFitnessMetric {
            metrics.append(RadarChartView.RadarMetric(label: "比賽適能", value: raceFitness.score, color: .purple))
        }
        if let trainingLoad = viewModel.trainingLoadMetric {
            metrics.append(RadarChartView.RadarMetric(label: "訓練負荷", value: trainingLoad.score, color: .orange))
        }

        return metrics
    }

    // MARK: - Metrics Grid
    private var metricsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            // Speed Metric
            if let speed = viewModel.speedMetric {
                metricCardWithTrend(
                    title: NSLocalizedString("training_readiness.speed", comment: ""),
                    score: speed.score,
                    statusText: speed.statusText,
                    description: speed.description,
                    trendData: speed.trendData,
                    color: .blue
                )
                .id("speed_metric")
            }

            // Endurance Metric
            if let endurance = viewModel.enduranceMetric {
                metricCardWithTrend(
                    title: NSLocalizedString("training_readiness.endurance", comment: ""),
                    score: endurance.score,
                    statusText: endurance.statusText,
                    description: endurance.description,
                    trendData: endurance.trendData,
                    color: .green
                )
                .id("endurance_metric")
            }

            // Race Fitness Metric
            if let raceFitness = viewModel.raceFitnessMetric {
                metricCardWithTrend(
                    title: NSLocalizedString("training_readiness.race_fitness", comment: ""),
                    score: raceFitness.score,
                    statusText: raceFitness.statusText,
                    description: raceFitness.description,
                    trendData: raceFitness.trendData,
                    color: .purple
                )
                .id("race_fitness_metric")
            }

            // Training Load Metric
            if let trainingLoad = viewModel.trainingLoadMetric {
                trainingLoadCardWithTrend(metric: trainingLoad)
                    .id("training_load_metric")
            }
        }
    }

    // MARK: - Metric Card (Legacy - kept for backward compatibility)
    private func metricCard(
        title: String,
        score: Double,
        subtitle: String,
        color: Color,
        trend: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            // Score
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.0f", score))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(color)

                if let trend = trend {
                    trendIcon(trend: trend)
                }
            }

            // Subtitle
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 100)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Metric Card with Trend Chart (New)
    /// ✅ New metric card that displays status_text and trend chart
    private func metricCardWithTrend(
        title: String,
        score: Double,
        statusText: String?,
        description: String?,
        trendData: TrendData?,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title with info icon
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let desc = description {
                    Button {
                        showMetricDescription(title: title, description: desc)
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Score + Trend Chart (並排)
            HStack(alignment: .center, spacing: 8) {
                // Score
                Text(String(format: "%.0f", score))
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(color)
                    .fixedSize()

                // Trend Chart (右側，窄一點)
                TrendChartView(trendData: trendData, color: color)
                    .frame(width: 70, height: 40)
            }

            // Status Text (雙行文字)
            if let statusText = statusText {
                let lines = viewModel.getStatusLines(statusText)
                if !lines.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(lines.prefix(2), id: \.self) { line in
                            Text(line)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(minHeight: 28, alignment: .top)
                    .padding(.top, 4)
                }
            } else {
                // Placeholder to maintain consistent height
                Spacer()
                    .frame(height: 28)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 120)
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - Training Load Card (Legacy)
    private func trainingLoadCard(metric: TrainingLoadMetric) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            Text(NSLocalizedString("training_readiness.training_load", comment: ""))
                .font(.caption)
                .foregroundColor(.secondary)

            // Score
            Text(String(format: "%.0f", metric.score))
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.orange)

            // TSB Info
            if let tsb = metric.currentTsb {
                HStack(spacing: 4) {
                    Text("TSB")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(viewModel.formatTSB(tsb))
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }

            // Subtitle
            Text(metric.message ?? "")
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 100)
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Training Load Card with Trend Chart (New)
    /// ✅ New training load card with trend chart
    private func trainingLoadCardWithTrend(metric: TrainingLoadMetric) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title with info icon
            HStack(spacing: 4) {
                Text(NSLocalizedString("training_readiness.training_load", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let description = metric.description {
                    Button {
                        showMetricDescription(
                            title: NSLocalizedString("training_readiness.training_load", comment: ""),
                            description: description
                        )
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Score + Trend Chart (並排)
            HStack(alignment: .center, spacing: 8) {
                // Score
                Text(String(format: "%.0f", metric.score))
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.orange)
                    .fixedSize()

                // Trend Chart (右側，窄一點)
                TrendChartView(trendData: metric.trendData, color: .orange)
                    .frame(width: 70, height: 40)
            }

            // Status Text (雙行文字)
            if let statusText = metric.statusText {
                let lines = viewModel.getStatusLines(statusText)
                if !lines.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(lines.prefix(2), id: \.self) { line in
                            Text(line)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(minHeight: 28, alignment: .top)
                    .padding(.top, 4)
                }
            } else {
                // Placeholder to maintain consistent height
                Spacer()
                    .frame(height: 28)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 120)
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - Trend Icon
    private func trendIcon(trend: String) -> some View {
        Group {
            switch trend {
            case "improving":
                Image(systemName: "arrow.up.right")
                    .foregroundColor(.green)
                    .font(.caption)
            case "declining":
                Image(systemName: "arrow.down.right")
                    .foregroundColor(.red)
                    .font(.caption)
            case "stable":
                Image(systemName: "minus")
                    .foregroundColor(.secondary)
                    .font(.caption)
            default:
                EmptyView()
            }
        }
    }

    // MARK: - Computed Properties

    private var scoreColor: Color {
        guard let score = viewModel.overallScore else { return .secondary }

        if score >= 80 {
            return .green
        } else if score >= 60 {
            return .orange
        } else {
            return .red
        }
    }

    /// Get status text from API (first line of overall_status_text)
    /// Falls back to score-based text if API doesn't provide it
    private var apiStatusText: String {
        // Try to use API status text (first line)
        if let statusLines = viewModel.overallStatusLines.first, !statusLines.isEmpty {
            return statusLines
        }

        // Fallback to score-based text
        guard let score = viewModel.overallScore else {
            return NSLocalizedString("training_readiness.no_score", comment: "")
        }

        if score >= 80 {
            return NSLocalizedString("training_readiness.status_excellent", comment: "")
        } else if score >= 60 {
            return NSLocalizedString("training_readiness.status_good", comment: "")
        } else {
            return NSLocalizedString("training_readiness.status_needs_rest", comment: "")
        }
    }

    private var statusText: String {
        guard let score = viewModel.overallScore else {
            return NSLocalizedString("training_readiness.no_score", comment: "")
        }

        if score >= 80 {
            return NSLocalizedString("training_readiness.status_excellent", comment: "")
        } else if score >= 60 {
            return NSLocalizedString("training_readiness.status_good", comment: "")
        } else {
            return NSLocalizedString("training_readiness.status_needs_rest", comment: "")
        }
    }

    private var statusMessage: String? {
        guard let score = viewModel.overallScore else { return nil }

        if score >= 80 {
            return NSLocalizedString("training_readiness.message_excellent", comment: "")
        } else if score >= 60 {
            return NSLocalizedString("training_readiness.message_good", comment: "")
        } else {
            return NSLocalizedString("training_readiness.message_needs_rest", comment: "")
        }
    }
}

// MARK: - Training Readiness Metrics Detailed Explanation View
struct TrainingReadinessMetricsExplanationView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("訓練指標說明")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("了解每個指標的含義，學習如何提升分數")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    Divider()

                    // 速度指標卡片
                    metricCard(
                        icon: "speedometer",
                        iconColor: .blue,
                        title: "速度指標",
                        description: "評估您的跑步配速能力",
                        whatItMeans: "配速是否符合訓練進展的期望",
                        howToImprove: [
                            "儘量達成速度課表的計劃配速",
                            "跑好間歇跑的衝刺區間配速"
                        ],
                        whenDecreases: "無法跑到目標配速，或太久沒有訓練"
                    )

                    // 耐力指標卡片
                    metricCard(
                        icon: "figure.walk",
                        iconColor: .green,
                        title: "耐力指標",
                        description: "評估您的長距離跑穩定性",
                        whatItMeans: "長距離跑的心率和配速的穩定性",
                        howToImprove: [
                            "輕鬆跑、LSD 確實跑在 Zone 2 心率區間",
                            "逐週增加距離，保持配速穩定"
                        ],
                        whenDecreases: "心率提升幅度較配速提升還大，或太久沒有長跑"
                    )

                    // 比賽適能卡片
                    metricCard(
                        icon: "medal",
                        iconColor: .purple,
                        title: "比賽適能",
                        description: "評估為目標賽事的準備進度",
                        whatItMeans: "體能表現狀態離目標配速還有多遠",
                        howToImprove: [
                            "儘量跟上每週的課表安排",
                            "高品質的休息與恢復",
                            "適當的力量訓練"
                        ],
                        whenDecreases: "天氣過熱、身體狀況不佳，或缺乏多樣訓練"
                    )

                    // 訓練負荷卡片
                    metricCard(
                        icon: "chart.bar.fill",
                        iconColor: .orange,
                        title: "訓練負荷",
                        description: "評估訓練量是否適當",
                        whatItMeans: "訓練量是否過大",
                        howToImprove: [
                            "跑量、強度按照課表安排穩步提升",
                            "如果負荷過大，考慮安排休息週好好恢復",
                            "高強度訓練後安排恢復日"
                        ],
                        whenDecreases: "訓練量持續過高，且恢復狀態不好"
                    )

                    Divider()

                    // 快速建議
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                                .font(.headline)
                            Text("快速建議")
                                .font(.headline)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            bulletPoint("每週包含：3-4 次輕鬆跑 + 1 次速度課表 + 1-2 次長跑")
                            bulletPoint("保持訓練頻率，比偶爾的高強度訓練更重要")
                            bulletPoint("關注分數趨勢，不要糾結每日波動")
                            bulletPoint("如果訓練負荷分數很低，需要安排恢復時間")
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)

                    Spacer(minLength: 20)
                }
                .padding(.vertical)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func metricCard(
        icon: String,
        iconColor: Color,
        title: String,
        description: String,
        whatItMeans: String,
        howToImprove: [String],
        whenDecreases: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 標題
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.title3)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Divider()

            // 含義
            VStack(alignment: .leading, spacing: 4) {
                Text("這個指標代表什麼")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Text(whatItMeans)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }

            // 如何提升
            VStack(alignment: .leading, spacing: 6) {
                Text("如何提升分數")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(howToImprove, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(iconColor)
                                .font(.caption)
                                .padding(.top, 2)

                            Text(tip)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }

            // 分數下降
            VStack(alignment: .leading, spacing: 4) {
                Text("分數何時下降")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Text(whenDecreases)
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    @ViewBuilder
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.headline)
                .foregroundColor(.secondary)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    VStack {
        TrainingReadinessView()
            .padding()
    }
}
