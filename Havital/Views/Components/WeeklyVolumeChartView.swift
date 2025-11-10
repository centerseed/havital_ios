import SwiftUI
import Charts

// MARK: - Weekly Volume Chart View
struct WeeklyVolumeChartView: View {
    @StateObject private var weeklyVolumeManager = WeeklyVolumeManager.shared
    @State private var selectedWeekStart: String?
    @State private var isLoading = false
    @State private var error: String?

    let showTitle: Bool

    init(showTitle: Bool = true) {
        self.showTitle = showTitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title and Info (only show if showTitle is true)
            if showTitle {
                HStack {
                    Text(NSLocalizedString("weekly_volume.trend", comment: "Weekly Volume Trend"))
                        .font(.headline)
                        .foregroundColor(.primary)

                    Button {
                        // Info alert could be added here
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Loading indicator
                    if weeklyVolumeManager.isLoading || isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(NSLocalizedString("weekly_volume.loading", comment: "Loading..."))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                // Loading indicator only when title is hidden
                if weeklyVolumeManager.isLoading || isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(NSLocalizedString("weekly_volume.loading", comment: "Loading..."))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Chart Content
            if let errorMessage = weeklyVolumeManager.syncError ?? error {
                EmptyStateView(
                    type: .loadingFailed,
                    customMessage: errorMessage,
                    showRetryButton: true
                ) {
                    Task {
                        await loadWeeklyVolumeData()
                    }
                }
            } else if weeklyVolumeManager.weeklyVolumes.isEmpty {
                EmptyStateView(
                    type: .noData(dataType: NSLocalizedString("weekly_volume.trend", comment: "Weekly Volume Trend")),
                    customMessage: NSLocalizedString("weekly_volume.no_data", comment: "No weekly volume data available")
                )
                .frame(height: 150)
            } else {
                chartView
            }

            // Selected week info
            if let weekStart = selectedWeekStart,
               let volume = weeklyVolumeManager.weeklyVolumes.first(where: { $0.weekStart == weekStart }) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(weekStart)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if let distance = volume.distanceKm, distance > 0 {
                            Text(String(format: NSLocalizedString("weekly_volume.kilometers", comment: "Kilometers"), distance))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        } else {
                            Text(NSLocalizedString("weekly_volume.no_running_records", comment: "No running records"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Button {
                        selectedWeekStart = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(UIColor.tertiarySystemBackground))
                .cornerRadius(8)
            }
        }
        .task {
            await TrackedTask("WeeklyVolumeChartView: loadWeeklyVolumeData") {
                await loadWeeklyVolumeData()
            }.value
        }
    }

    @ViewBuilder
    private var chartView: some View {
        VStack(spacing: 16) {
            GeometryReader { geometry in
                let trend = weeklyVolumeManager.getDistanceTrend()
                let data = Array(trend.suffix(8))

                if !data.isEmpty {
                    customBarChart(data: data, geometry: geometry)
                }
            }
            .frame(height: 180)
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func customBarChart(data: [(weekStart: String, date: Date, distance: Double)], geometry: GeometryProxy) -> some View {
        let maxDistance = data.map { $0.distance }.max() ?? 1
        let chartWidth = geometry.size.width
        let chartHeight = geometry.size.height - 40
        let barWidth = chartWidth / CGFloat(data.count) * 0.7

        ZStack {
            // Grid lines
            ForEach(0..<5) { i in
                let y = chartHeight * CGFloat(i) / 4

                Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: chartWidth, y: y))
                }
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)

                Text("\(Int(maxDistance * Double(4 - i) / 4))km")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .position(x: -20, y: y)
            }

            // Bars and labels
            ForEach(0..<data.count, id: \.self) { index in
                let item = data[index]
                let xPosition = CGFloat(index) * (chartWidth / CGFloat(data.count))
                let barHeight = maxDistance > 0 ? chartHeight * item.distance / maxDistance : 0
                let yPosition = chartHeight - barHeight

                // Bar
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.7), .blue],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: barWidth, height: barHeight)
                    .position(x: xPosition + barWidth/2, y: yPosition + barHeight/2)
                    .onTapGesture {
                        selectedWeekStart = item.weekStart
                    }

                // Date label
                Text(formatDate(item.date))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .position(x: xPosition + barWidth/2, y: chartHeight + 15)
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        // 使用用户设置的时区，如果未设置则使用设备当前时区
        if let userTimezone = UserPreferenceManager.shared.timezonePreference {
            formatter.timeZone = TimeZone(identifier: userTimezone)
        } else {
            formatter.timeZone = TimeZone.current
        }
        return formatter.string(from: date)
    }

    // MARK: - Data Loading
    private func loadWeeklyVolumeData() async {
        await MainActor.run {
            isLoading = true
            error = nil
        }

        await weeklyVolumeManager.loadData()

        await MainActor.run {
            isLoading = false

            if weeklyVolumeManager.weeklyVolumes.isEmpty {
                if let syncError = weeklyVolumeManager.syncError {
                    error = syncError
                } else {
                    error = NSLocalizedString("weekly_volume.no_data_message", comment: "No weekly volume data available, please ensure you have training records")
                }
            } else {
                error = nil
            }
        }
    }
}

#Preview {
    WeeklyVolumeChartView(showTitle: true)
        .padding()
}
