import SwiftUI
import Charts


// MARK: - Weekly Volume Chart View
struct WeeklyVolumeChartView: View {
    @StateObject private var weeklySummaryManager = WeeklySummaryManager.shared
    @State private var selectedWeek: (week: Int, distance: Double)? = nil
    @State private var isLoading = false
    @State private var error: String?
    
    let showTitle: Bool
    
    init(showTitle: Bool = true) {
        self.showTitle = showTitle
    }
    
    // Fixed 8-week display: start from week 1 or show latest 8 weeks
    private var filteredVolumeData: [(week: Int, distance: Double)] {
        let trend = weeklySummaryManager.getDistanceTrend()
        guard !trend.isEmpty else { return [] }
        
        // Sort by week number
        let sortedTrend = trend.sorted { $0.week < $1.week }
        guard let latestWeek = sortedTrend.last?.week else { return [] }
        
        // If latest week is 8 or less, show weeks 1-8
        if latestWeek <= 8 {
            var completeData: [(week: Int, distance: Double)] = []
            for week in 1...8 {
                if let existingData = sortedTrend.first(where: { $0.week == week }) {
                    completeData.append(existingData)
                } else {
                    completeData.append((week: week, distance: 0.0))
                }
            }
            return completeData
        } else {
            // If more than 8 weeks, show the latest 8 weeks
            let recentData = Array(sortedTrend.suffix(8))
            
            // Fill any gaps in the 8-week range
            guard let firstWeek = recentData.first?.week,
                  let lastWeek = recentData.last?.week else { return recentData }
            
            var completeData: [(week: Int, distance: Double)] = []
            for week in firstWeek...lastWeek {
                if let existingData = recentData.first(where: { $0.week == week }) {
                    completeData.append(existingData)
                } else {
                    completeData.append((week: week, distance: 0.0))
                }
            }
            return completeData
        }
    }
    
    
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title and Info (only show if showTitle is true)
            if showTitle {
                HStack {
                    Text("週跑量趨勢")
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
                    if weeklySummaryManager.isLoading || isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("載入中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                // Loading indicator only when title is hidden
                if weeklySummaryManager.isLoading || isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("載入中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Chart Content
            if let errorMessage = weeklySummaryManager.syncError ?? error {
                EmptyStateView(
                    type: .loadingFailed,
                    customMessage: errorMessage,
                    showRetryButton: true
                ) {
                    Task {
                        await loadWeeklyVolumeData()
                    }
                }
            } else if filteredVolumeData.isEmpty {
                EmptyStateView(
                    type: .noData(dataType: "週跑量"),
                    customMessage: "暫無週跑量數據"
                )
                .frame(height: 150)
            } else {
                chartView
            }
            
            // Selected week info
            if let selected = selectedWeek {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("第 \(selected.week) 週")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if selected.distance > 0 {
                            Text("\(String(format: "%.1f", selected.distance)) 公里")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        } else {
                            Text("無跑步記錄")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        selectedWeek = nil
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
            await loadWeeklyVolumeData()
        }
    }
    
    @ViewBuilder
    private var chartView: some View {
        VStack(spacing: 16) {
            GeometryReader { geometry in
                customBarChart(geometry: geometry)
            }
            .frame(height: 180)
        }
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private func customBarChart(geometry: GeometryProxy) -> some View {
        let maxDistance = filteredVolumeData.map { $0.distance }.max() ?? 1
        let chartWidth = geometry.size.width
        let chartHeight = geometry.size.height - 40
        let dataCount = CGFloat(filteredVolumeData.count)
        let barWidth = chartWidth / dataCount * 0.7
        
        ZStack {
            gridLines(chartWidth: chartWidth, chartHeight: chartHeight, maxDistance: maxDistance)
            barElements(chartWidth: chartWidth, chartHeight: chartHeight, barWidth: barWidth, maxDistance: maxDistance)
        }
    }
    
    @ViewBuilder
    private func gridLines(chartWidth: CGFloat, chartHeight: CGFloat, maxDistance: Double) -> some View {
        ForEach(0..<5, id: \.self) { i in
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
    }
    
    @ViewBuilder
    private func barElements(chartWidth: CGFloat, chartHeight: CGFloat, barWidth: CGFloat, maxDistance: Double) -> some View {
        ForEach(Array(filteredVolumeData.enumerated()), id: \.offset) { index, data in
            let xPosition = CGFloat(index) * (chartWidth / CGFloat(filteredVolumeData.count))
            let barHeight = maxDistance > 0 ? chartHeight * data.distance / maxDistance : 0
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
                    selectedWeek = data
                }
            
            // Week label
            Text("\(data.week)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .position(x: xPosition + barWidth/2, y: chartHeight + 15)
        }
    }
    
    // MARK: - Data Loading
    private func loadWeeklyVolumeData() async {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            // Use WeeklySummaryManager's loadData method which implements dual-track caching
            await weeklySummaryManager.loadData()
            
            await MainActor.run {
                isLoading = false
                
                // Check if we have data after loading
                if weeklySummaryManager.weeklySummaries.isEmpty {
                    error = "暫無週跑量數據，請確保已有訓練記錄"
                } else {
                    error = nil
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                // Check if it's a cancellation error
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                    print("週跑量數據載入被取消，忽略錯誤")
                    return
                }
                self.error = "載入失敗: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    WeeklyVolumeChartView(showTitle: true)
        .padding()
}