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

            // Metrics Grid (2x2)
            if viewModel.hasAnyMetric {
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

#Preview {
    VStack {
        TrainingReadinessView()
            .padding()
    }
}
